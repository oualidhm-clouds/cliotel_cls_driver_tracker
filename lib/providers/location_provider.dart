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

class LocationProvider with ChangeNotifier {
  TrackingStatus _status = TrackingStatus.idle;
  LocationData? _currentLocation;
  LocationPermissionStatus? _permissionStatus;
  String? _error;
  bool _isOnline = false;
  
  StreamSubscription<LocationData>? _locationSubscription;
  Timer? _lastUpdateTimer;
  DateTime? _lastUpdateTime;

  TrackingStatus get status => _status;
  LocationData? get currentLocation => _currentLocation;
  LocationPermissionStatus? get permissionStatus => _permissionStatus;
  String? get error => _error;
  bool get isOnline => _isOnline;
  bool get isTracking => _status == TrackingStatus.tracking;
  
  String get lastUpdateText {
    if (_lastUpdateTime == null) return 'Never';
    final diff = DateTime.now().difference(_lastUpdateTime!);
    if (diff.inSeconds < 10) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  Future<void> initialize({
    required Tenant tenant,
    required Driver driver,
  }) async {
    // Initialize Firebase with driver info
    firebaseService.initialize(
      tenantId: tenant.id,
      driver: driver,
    );

    // Check if tracking was enabled before
    final wasTracking = storageService.isTrackingEnabled();
    if (wasTracking) {
      await startTracking();
    }
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

    // Check permissions first
    _permissionStatus = await locationService.checkPermissions();
    
    if (_permissionStatus != LocationPermissionStatus.granted) {
      _status = TrackingStatus.error;
      _error = _getPermissionErrorMessage(_permissionStatus!);
      notifyListeners();
      return false;
    }

    // Get initial location
    final initialLocation = await locationService.getCurrentPosition();
    if (initialLocation != null) {
      _currentLocation = initialLocation;
      _lastUpdateTime = DateTime.now();
      await _sendLocationToFirebase(initialLocation);
    }

    // Start continuous tracking
    final started = await locationService.startTracking(
      distanceFilter: 10,
      intervalMs: 5000,
    );

    if (!started) {
      _status = TrackingStatus.error;
      _error = 'Failed to start location tracking';
      notifyListeners();
      return false;
    }

    // Listen to location updates
    _locationSubscription = locationService.locationStream.listen(
      (location) {
        _currentLocation = location;
        _lastUpdateTime = DateTime.now();
        _sendLocationToFirebase(location);
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );

    // Set online status
    _isOnline = true;
    await firebaseService.setOnlineStatus(true);

    _status = TrackingStatus.tracking;
    await storageService.setTrackingEnabled(true);
    
    // Start timer to update "last updated" text
    _lastUpdateTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => notifyListeners(),
    );

    notifyListeners();
    return true;
  }

  Future<void> stopTracking() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    
    _lastUpdateTimer?.cancel();
    _lastUpdateTimer = null;

    await locationService.stopTracking();

    // Set offline status
    _isOnline = false;
    await firebaseService.setOnlineStatus(false);

    _status = TrackingStatus.idle;
    await storageService.setTrackingEnabled(false);
    
    notifyListeners();
  }

  Future<void> pauseTracking() async {
    if (_status != TrackingStatus.tracking) return;

    await _locationSubscription?.cancel();
    _locationSubscription = null;
    
    await locationService.stopTracking();
    
    _status = TrackingStatus.paused;
    notifyListeners();
  }

  Future<void> resumeTracking() async {
    if (_status != TrackingStatus.paused) return;
    await startTracking();
  }

  Future<void> _sendLocationToFirebase(LocationData location) async {
    try {
      await firebaseService.updateLocation(location);
    } catch (e) {
      print('Error sending location to Firebase: $e');
    }
  }

  String _getPermissionErrorMessage(LocationPermissionStatus status) {
    switch (status) {
      case LocationPermissionStatus.denied:
        return 'Location permission denied. Please allow location access.';
      case LocationPermissionStatus.deniedForever:
        return 'Location permission permanently denied. Please enable in Settings.';
      case LocationPermissionStatus.serviceDisabled:
        return 'Location services are disabled. Please enable GPS.';
      default:
        return 'Unknown permission error';
    }
  }

  Future<void> openSettings() async {
    if (_permissionStatus == LocationPermissionStatus.serviceDisabled) {
      await locationService.openLocationSettings();
    } else {
      await locationService.openAppSettings();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _lastUpdateTimer?.cancel();
    locationService.dispose();
    super.dispose();
  }
}
