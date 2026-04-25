import 'dart:async';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:permission_handler/permission_handler.dart';
import '../models/location_data.dart';

enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class LocationService {
  StreamSubscription<geo.Position>? _positionSubscription;
  final StreamController<LocationData> _locationController =
      StreamController<LocationData>.broadcast();

  Stream<LocationData> get locationStream => _locationController.stream;

  /// Check the in-use location permission and that GPS is enabled.
  Future<LocationPermissionStatus> checkPermissions() async {
    final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionStatus.serviceDisabled;
    }

    var status = await Permission.locationWhenInUse.status;

    if (status.isGranted) return LocationPermissionStatus.granted;

    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
      if (status.isGranted) return LocationPermissionStatus.granted;
      if (status.isPermanentlyDenied) {
        return LocationPermissionStatus.deniedForever;
      }
      return LocationPermissionStatus.denied;
    }

    if (status.isPermanentlyDenied) {
      return LocationPermissionStatus.deniedForever;
    }

    return LocationPermissionStatus.denied;
  }

  /// Request "Allow all the time" — required for tracking when the screen is
  /// off / app is in the background. Best effort: returns false if not granted.
  Future<bool> requestBackgroundPermission() async {
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  /// One-shot location read.
  Future<LocationData?> getCurrentPosition() async {
    try {
      final permissionStatus = await checkPermissions();
      if (permissionStatus != LocationPermissionStatus.granted) return null;

      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      return _toLocationData(position);
    } catch (e) {
      return null;
    }
  }

  /// Start a continuous, foreground-service-backed stream of location
  /// updates. Defaults to a ~4 second cadence with no distance filter so we
  /// keep emitting even when the driver is stationary.
  Future<bool> startTracking({
    int distanceFilter = 0,
    int intervalMs = 4000,
  }) async {
    final permissionStatus = await checkPermissions();
    if (permissionStatus != LocationPermissionStatus.granted) return false;

    // Best-effort upgrade to background permission so updates keep flowing
    // when the screen is off. We don't fail tracking if this is denied —
    // the foreground service notification still keeps the app alive.
    await requestBackgroundPermission();

    await stopTracking();

    final locationSettings = geo.AndroidSettings(
      accuracy: geo.LocationAccuracy.high,
      distanceFilter: distanceFilter,
      intervalDuration: Duration(milliseconds: intervalMs),
      forceLocationManager: false,
      foregroundNotificationConfig: const geo.ForegroundNotificationConfig(
        notificationText:
            'Sharing your live location with Cliotel — tap to open the app.',
        notificationTitle: 'Cliotel Driver — Tracking active',
        enableWakeLock: true,
        setOngoing: true,
        notificationIcon: geo.AndroidResource(
          name: 'ic_launcher',
          defType: 'mipmap',
        ),
      ),
    );

    _positionSubscription = geo.Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) => _locationController.add(_toLocationData(position)),
      onError: (_) {},
    );

    return true;
  }

  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return geo.Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  Future<void> openLocationSettings() async {
    await geo.Geolocator.openLocationSettings();
  }

  Future<void> openAppPermissionSettings() async {
    await openAppSettings();
  }

  void dispose() {
    stopTracking();
    _locationController.close();
  }

  LocationData _toLocationData(geo.Position p) {
    return LocationData(
      latitude: p.latitude,
      longitude: p.longitude,
      accuracy: p.accuracy,
      speed: p.speed,
      heading: p.heading,
      altitude: p.altitude,
      timestamp: p.timestamp,
    );
  }
}

// Singleton instance
final locationService = LocationService();
