import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/location_data.dart';
import '../models/driver.dart';
import '../models/tenant.dart';
import '../services/location_service.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';

enum TrackingStatus {
  idle,
  requesting,
  tracking,
  paused,
  error,
}

/// Update cadence — sits inside the user-requested "every 3-5 seconds" window.
const int kLocationIntervalMs = 4000;

class LocationProvider with ChangeNotifier {
  TrackingStatus _status = TrackingStatus.idle;
  LocationData? _currentLocation;
  LocationPermissionStatus? _permissionStatus;
  String? _error;
  bool _isOnline = false;

  // Session stats
  DateTime? _sessionStart;
  int _updateCount = 0;
  double _totalDistanceMeters = 0;

  StreamSubscription<LocationData>? _locationSubscription;
  Timer? _uiRefreshTimer;
  DateTime? _lastUpdateTime;

  TrackingStatus get status => _status;
  LocationData? get currentLocation => _currentLocation;
  LocationPermissionStatus? get permissionStatus => _permissionStatus;
  String? get error => _error;
  bool get isOnline => _isOnline;
  bool get isTracking => _status == TrackingStatus.tracking;
  int get updateCount => _updateCount;
  double get totalDistanceMeters => _totalDistanceMeters;
  Duration get sessionDuration =>
      _sessionStart == null ? Duration.zero : DateTime.now().difference(_sessionStart!);

  String get lastUpdateText {
    if (_lastUpdateTime == null) return 'Never';
    final diff = DateTime.now().difference(_lastUpdateTime!);
    if (diff.inSeconds < 5) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  String get sessionDurationText {
    final d = sessionDuration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get totalDistanceText {
    if (_totalDistanceMeters < 1000) {
      return '${_totalDistanceMeters.toStringAsFixed(0)} m';
    }
    return '${(_totalDistanceMeters / 1000).toStringAsFixed(2)} km';
  }

  Future<void> initialize({
    required Tenant tenant,
    required Driver driver,
  }) async {
    // Always wire the cross-isolate data port — even if we don't start a new
    // session, the foreground service may already be running from a previous
    // launch and pushing locations. We want the UI to pick those up.
    locationService.attachDataPort();

    // Reset transient session state so a previous driver's stats don't leak
    // into a new session.
    if (!isTracking) {
      _currentLocation = null;
      _lastUpdateTime = null;
      _updateCount = 0;
      _totalDistanceMeters = 0;
      _sessionStart = null;
      _error = null;
    }

    firebaseService.initialize(tenantId: tenant.id, driver: driver);

    // If the foreground service survived the app being killed (which is the
    // whole point of running it in a separate isolate), reflect that in the
    // UI immediately.
    final isAlreadyRunning = await locationService.isRunning();
    if (isAlreadyRunning && !isTracking) {
      _status = TrackingStatus.tracking;
      _isOnline = true;
      _sessionStart ??= DateTime.now();
      _attachStreamListener();
      _startUiTicker();
      notifyListeners();
      return;
    }

    // Auto-resume if the driver had tracking enabled before app was killed
    // and the service didn't survive (e.g. a hard reboot).
    final wasTracking = storageService.isTrackingEnabled();
    if (wasTracking && !isTracking) {
      await startTracking();
    }
  }

  void _attachStreamListener() {
    _locationSubscription?.cancel();
    _locationSubscription = locationService.locationStream.listen(
      (location) {
        if (_currentLocation != null) {
          _totalDistanceMeters += locationService.calculateDistance(
            _currentLocation!.latitude,
            _currentLocation!.longitude,
            location.latitude,
            location.longitude,
          );
        }
        _currentLocation = location;
        _lastUpdateTime = DateTime.now();
        _updateCount++;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  void _startUiTicker() {
    _uiRefreshTimer?.cancel();
    _uiRefreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => notifyListeners(),
    );
  }

  Future<LocationPermissionStatus> checkPermissions() async {
    _permissionStatus = await locationService.checkPermissions();
    notifyListeners();
    return _permissionStatus!;
  }

  Future<bool> startTracking() async {
    _status = TrackingStatus.requesting;
    _error = null;
    notifyListeners();

    _permissionStatus = await locationService.checkPermissions();
    if (_permissionStatus != LocationPermissionStatus.granted) {
      _status = TrackingStatus.error;
      _error = _getPermissionErrorMessage(_permissionStatus!);
      notifyListeners();
      return false;
    }

    // Reset session stats
    _sessionStart = DateTime.now();
    _updateCount = 0;
    _totalDistanceMeters = 0;

    // Optimistic initial fix so the UI shows coordinates instantly while the
    // background isolate spins up. The actual stream (and Firebase writes)
    // come from the foreground service.
    final initialLocation = await locationService.getCurrentPosition();
    if (initialLocation != null) {
      _currentLocation = initialLocation;
      _lastUpdateTime = DateTime.now();
    }

    // Hand off to the foreground service. Firebase writes happen in the
    // background isolate from now on, surviving swipe-kill.
    final started = await locationService.startTracking();

    if (!started) {
      _status = TrackingStatus.error;
      _error = 'Failed to start the background tracking service.';
      notifyListeners();
      return false;
    }

    _attachStreamListener();
    _startUiTicker();

    _isOnline = true;
    _status = TrackingStatus.tracking;
    await storageService.setTrackingEnabled(true);

    notifyListeners();
    return true;
  }

  Future<void> stopTracking() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    _uiRefreshTimer?.cancel();
    _uiRefreshTimer = null;

    // Stops the foreground service AND its isolate. The background handler's
    // onDestroy marks the driver offline in Firebase before exiting.
    await locationService.stopTracking();

    _isOnline = false;
    // Belt-and-braces: also nudge the offline flag from this isolate in case
    // the service was already gone.
    await firebaseService.setOnlineStatus(false);

    _status = TrackingStatus.idle;
    _sessionStart = null;
    await storageService.setTrackingEnabled(false);

    notifyListeners();
  }

  String _getPermissionErrorMessage(LocationPermissionStatus status) {
    switch (status) {
      case LocationPermissionStatus.denied:
        return 'Location permission denied. Please allow location access.';
      case LocationPermissionStatus.deniedForever:
        return 'Location permission permanently denied. Please enable it in Settings.';
      case LocationPermissionStatus.serviceDisabled:
        return 'Location services are disabled. Please turn on GPS.';
      default:
        return 'Unknown permission error';
    }
  }

  Future<void> openSettings() async {
    if (_permissionStatus == LocationPermissionStatus.serviceDisabled) {
      await locationService.openLocationSettings();
    } else {
      await locationService.openAppPermissionSettings();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _uiRefreshTimer?.cancel();
    locationService.dispose();
    super.dispose();
  }
}
