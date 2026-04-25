// Background isolate handler for the foreground service.
//
// IMPORTANT: this code runs in a SEPARATE Dart isolate that
// `flutter_foreground_task` spawns when the service starts. It survives the
// Flutter activity being destroyed (e.g. swipe-kill from recents), which is
// exactly what we need so the location stream + Firebase writes keep going
// while the app is closed.
//
// Anything we want to share with this isolate has to be persisted to disk
// (SharedPreferences) — we cannot reach the singletons from the UI isolate.

import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/firebase_options.dart';

/// Top-level entry point that the OS calls when the foreground service spawns
/// the background isolate. Must be a top-level function annotated with
/// `vm:entry-point` so tree-shaking and AOT compilation keep it.
@pragma('vm:entry-point')
void startLocationServiceCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

class LocationTaskHandler extends TaskHandler {
  StreamSubscription<geo.Position>? _positionSub;
  DatabaseReference? _ref;

  String? _tenantId;
  int? _driverId;
  String? _driverName;

  int _updateCount = 0;
  DateTime? _sessionStart;
  DateTime? _lastUpdate;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _sessionStart = timestamp;
    _updateCount = 0;

    try {
      // Init Firebase in this isolate. The UI isolate has its own instance —
      // they are independent, so we have to bootstrap our own here.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      // Pull the active session from disk. If something's missing we still
      // keep the service alive so the user gets a clear notification message.
      final prefs = await SharedPreferences.getInstance();
      final tenantJson = prefs.getString('cliotel_tenant');
      final driverJson = prefs.getString('cliotel_driver');

      if (tenantJson == null || driverJson == null) {
        await _setNotification(
          title: 'Cliotel Driver',
          text: 'No active session. Open the app to sign in.',
        );
        return;
      }

      final tenant = json.decode(tenantJson) as Map<String, dynamic>;
      final driver = json.decode(driverJson) as Map<String, dynamic>;

      _tenantId = tenant['id']?.toString();
      _driverId = driver['id'] is int
          ? driver['id'] as int
          : int.tryParse(driver['id']?.toString() ?? '');
      _driverName = driver['name']?.toString();

      if (_tenantId == null || _driverId == null) {
        await _setNotification(
          title: 'Cliotel Driver',
          text: 'Session is invalid. Please sign in again.',
        );
        return;
      }

      _ref = FirebaseDatabase.instance
          .ref('locations')
          .child(_tenantId!)
          .child('drivers')
          .child(_driverId.toString());

      // Mark online + register an onDisconnect handler so the dashboard sees
      // us go offline if the device loses connectivity.
      await _ref!.update({
        'driver_id': _driverId,
        'driver_name': _driverName,
        'tenant_id': _tenantId,
        'is_online': true,
        'connected_at': ServerValue.timestamp,
      });
      await _ref!.onDisconnect().update({
        'is_online': false,
        'disconnected_at': ServerValue.timestamp,
      });

      await _setNotification(
        title: 'Cliotel Driver',
        text: 'Acquiring GPS signal...',
      );

      // Start the geolocator stream. distanceFilter = 0 means we always get a
      // fix every interval, even when the driver is stationary.
      const intervalMs = 4000;
      final settings = geo.AndroidSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: intervalMs),
      );

      _positionSub = geo.Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        _onPosition,
        onError: (Object e) {
          _setNotification(
            title: 'Cliotel Driver — GPS error',
            text: e.toString(),
          );
        },
      );
    } catch (e) {
      await _setNotification(
        title: 'Cliotel Driver — error',
        text: 'Failed to start tracking: $e',
      );
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // We use a continuous geolocator stream in onStart, so no work here.
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _positionSub?.cancel();
    _positionSub = null;

    try {
      await _ref?.update({
        'is_online': false,
        'disconnected_at': ServerValue.timestamp,
      });
    } catch (_) {
      // Network may be gone — ignore.
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      FlutterForegroundTask.stopService();
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _onPosition(geo.Position p) async {
    _updateCount++;
    _lastUpdate = DateTime.now();

    final payload = <String, Object?>{
      'driver_id': _driverId,
      'driver_name': _driverName,
      'tenant_id': _tenantId,
      'lat': p.latitude,
      'lng': p.longitude,
      'accuracy': p.accuracy,
      'speed': p.speed,
      'heading': p.heading,
      'altitude': p.altitude,
      'timestamp': p.timestamp.millisecondsSinceEpoch,
      'updated_at': DateTime.now().toIso8601String(),
      'is_online': true,
    };

    try {
      await _ref?.update(payload);
    } catch (e) {
      if (kDebugMode) print('[bg] firebase update failed: $e');
    }

    // Keep the persistent notification informative.
    final t = _lastUpdate!;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    await _setNotification(
      title: 'Cliotel Driver — Tracking active',
      text: 'Last update $hh:$mm:$ss · $_updateCount sent',
    );

    // Forward the fix to the UI isolate (if one is attached). The dashboard
    // listens to this stream to keep its stats live.
    FlutterForegroundTask.sendDataToMain({
      'type': 'location',
      'lat': p.latitude,
      'lng': p.longitude,
      'accuracy': p.accuracy,
      'speed': p.speed,
      'heading': p.heading,
      'altitude': p.altitude,
      'timestamp': p.timestamp.millisecondsSinceEpoch,
      'count': _updateCount,
      'sessionStart': _sessionStart?.millisecondsSinceEpoch,
    });
  }

  Future<void> _setNotification({
    required String title,
    required String text,
  }) async {
    try {
      FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    } catch (_) {
      // Service might not be ready yet — safe to swallow.
    }
  }
}
