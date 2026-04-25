import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/location_data.dart';

enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<LocationData> _locationController = 
      StreamController<LocationData>.broadcast();

  Stream<LocationData> get locationStream => _locationController.stream;

  /// Check and request location permissions
  Future<LocationPermissionStatus> checkPermissions() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionStatus.serviceDisabled;
    }

    // Check location permission
    var status = await Permission.locationWhenInUse.status;
    
    if (status.isGranted) {
      return LocationPermissionStatus.granted;
    }
    
    if (status.isDenied) {
      // Request permission
      status = await Permission.locationWhenInUse.request();
      
      if (status.isGranted) {
        return LocationPermissionStatus.granted;
      }
      
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

  /// Request background location permission (for continuous tracking)
  Future<bool> requestBackgroundPermission() async {
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  /// Get current position once
  Future<LocationData?> getCurrentPosition() async {
    try {
      final permissionStatus = await checkPermissions();
      if (permissionStatus != LocationPermissionStatus.granted) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
        altitude: position.altitude,
        timestamp: position.timestamp,
      );
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  /// Start continuous location tracking
  Future<bool> startTracking({
    int distanceFilter = 10,
    int intervalMs = 5000,
  }) async {
    final permissionStatus = await checkPermissions();
    if (permissionStatus != LocationPermissionStatus.granted) {
      return false;
    }

    // Stop any existing tracking
    await stopTracking();

    late LocationSettings locationSettings;
    
    // Configure platform-specific settings
    locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
      intervalDuration: Duration(milliseconds: intervalMs),
      forceLocationManager: false,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: 'Cliotel Driver is tracking your location',
        notificationTitle: 'Location Tracking Active',
        enableWakeLock: true,
        notificationIcon: AndroidResource(
          name: 'ic_launcher',
          defType: 'mipmap',
        ),
      ),
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        final locationData = LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          speed: position.speed,
          heading: position.heading,
          altitude: position.altitude,
          timestamp: position.timestamp,
        );
        _locationController.add(locationData);
      },
      onError: (error) {
        print('Location stream error: $error');
      },
    );

    return true;
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Calculate distance between two points in meters
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Open location settings
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Open app settings (for permission changes)
  Future<void> openAppSettings() async {
    await openAppSettings();
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
    _locationController.close();
  }
}

// Singleton instance
final locationService = LocationService();
