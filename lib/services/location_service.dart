import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:permission_handler/permission_handler.dart';

import '../models/location_data.dart';
import 'background_task_handler.dart';

enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

/// Public surface used by the UI / providers.
///
/// Behind the scenes we delegate the actual location stream + Firebase writes
/// to a [flutter_foreground_task] background isolate. That isolate keeps
/// running (with a persistent notification) even after the user swipes the
/// app away from recents — which the previous geolocator-only setup could
/// not survive.
class LocationService {
  static const _serviceId = 256;

  final StreamController<LocationData> _locationController =
      StreamController<LocationData>.broadcast();

  bool _wired = false;

  Stream<LocationData> get locationStream => _locationController.stream;

  // ---------------------------------------------------------------------------
  // One-time setup
  // ---------------------------------------------------------------------------

  /// Configure the foreground task. Must be called once early in `main`.
  Future<void> configure() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'cliotel_driver_location',
        channelName: 'Driver location tracking',
        channelDescription:
            'Persistent notification shown while your live location is being '
            'shared with the dispatcher.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        showBadge: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Wire the data callback that receives location pings from the background
  /// isolate. Idempotent — safe to call from `LocationProvider.initialize`.
  void attachDataPort() {
    if (_wired) return;
    _wired = true;
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
  }

  void _onTaskData(Object data) {
    if (data is! Map) return;
    if (data['type'] != 'location') return;

    final loc = LocationData(
      latitude: (data['lat'] as num).toDouble(),
      longitude: (data['lng'] as num).toDouble(),
      accuracy: (data['accuracy'] as num?)?.toDouble(),
      speed: (data['speed'] as num?)?.toDouble(),
      heading: (data['heading'] as num?)?.toDouble(),
      altitude: (data['altitude'] as num?)?.toDouble(),
      timestamp: data['timestamp'] is int
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
    _locationController.add(loc);
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

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

  /// Request "Allow all the time" so the OS lets us keep streaming with the
  /// screen off. Best effort — returns false if the user denies.
  Future<bool> requestBackgroundPermission() async {
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  /// Android 13+: notification channel needs runtime permission to be visible.
  Future<bool> requestNotificationPermission() async {
    final res = await FlutterForegroundTask.requestNotificationPermission();
    return res == NotificationPermission.granted;
  }

  /// Ask the user to exempt the app from battery optimization. Without this,
  /// some OEM skins (Xiaomi, OPPO, Samsung) will still kill the service after
  /// a few minutes even with a foreground notification.
  Future<void> requestIgnoreBatteryOptimization() async {
    final canIgnore =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!canIgnore) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  // ---------------------------------------------------------------------------
  // One-shot fix (used for the initial UI display before the service starts)
  // ---------------------------------------------------------------------------

  Future<LocationData?> getCurrentPosition() async {
    try {
      final permissionStatus = await checkPermissions();
      if (permissionStatus != LocationPermissionStatus.granted) return null;

      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      return _toLocationData(position);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Service control
  // ---------------------------------------------------------------------------

  Future<bool> isRunning() async {
    return FlutterForegroundTask.isRunningService;
  }

  /// Start the foreground service. The background isolate takes it from here.
  Future<bool> startTracking() async {
    final permissionStatus = await checkPermissions();
    if (permissionStatus != LocationPermissionStatus.granted) return false;

    // Best-effort upgrade to "always" so updates keep flowing with screen off.
    await requestBackgroundPermission();

    // On Android 13+ the notification needs runtime permission or it won't be
    // visible — without a visible notification the foreground service rule
    // is violated and Android will kill us.
    await requestNotificationPermission();

    // Encourage the user to opt out of battery optimization. Non-fatal.
    await requestIgnoreBatteryOptimization();

    attachDataPort();

    if (await FlutterForegroundTask.isRunningService) {
      return true;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      notificationTitle: 'Cliotel Driver — Tracking active',
      notificationText: 'Sharing your live location with the dispatcher.',
      notificationButtons: const [
        NotificationButton(id: 'stop', text: 'Stop'),
      ],
      callback: startLocationServiceCallback,
    );

    return result is ServiceRequestSuccess;
  }

  Future<void> stopTracking() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  // ---------------------------------------------------------------------------
  // Misc
  // ---------------------------------------------------------------------------

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
    if (_wired) {
      FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
      _wired = false;
    }
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
