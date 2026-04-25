import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/location_data.dart';
import '../models/driver.dart';

class FirebaseService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  String? _currentTenantId;
  int? _currentDriverId;
  String? _currentDriverName;
  
  DatabaseReference? _driverLocationRef;
  StreamSubscription? _connectionSubscription;
  
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  /// Initialize Firebase tracking for a specific driver
  void initialize({
    required String tenantId,
    required Driver driver,
  }) {
    _currentTenantId = tenantId;
    _currentDriverId = driver.id;
    _currentDriverName = driver.name;
    
    // Create reference to driver's location in Firebase
    _driverLocationRef = _database
        .ref('locations')
        .child(tenantId)
        .child('drivers')
        .child(driver.id.toString());
    
    // Monitor connection state
    _connectionSubscription = _database
        .ref('.info/connected')
        .onValue
        .listen((event) {
          _isConnected = event.snapshot.value == true;
          if (_isConnected) {
            _setupPresence();
          }
        });
  }

  /// Setup presence system for online/offline detection
  void _setupPresence() {
    if (_driverLocationRef == null) return;

    // When this client disconnects, update the driver status
    _driverLocationRef!.onDisconnect().update({
      'is_online': false,
      'disconnected_at': ServerValue.timestamp,
    });
  }

  /// Update driver's location in Firebase
  Future<void> updateLocation(LocationData location) async {
    if (_driverLocationRef == null || 
        _currentDriverId == null || 
        _currentDriverName == null ||
        _currentTenantId == null) {
      return;
    }

    try {
      final data = location.toFirebaseJson(
        driverId: _currentDriverId!,
        driverName: _currentDriverName!,
        tenantId: _currentTenantId!,
        isOnline: true,
      );

      await _driverLocationRef!.update(data);
    } catch (e) {
      print('Error updating location in Firebase: $e');
    }
  }

  /// Set driver online status
  Future<void> setOnlineStatus(bool isOnline) async {
    if (_driverLocationRef == null) return;

    try {
      await _driverLocationRef!.update({
        'is_online': isOnline,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  /// Get stream of driver's own location (for debugging/display)
  Stream<LocationData?> getDriverLocationStream() {
    if (_driverLocationRef == null) {
      return Stream.value(null);
    }

    return _driverLocationRef!.onValue.map((event) {
      if (event.snapshot.value == null) return null;
      
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return LocationData.fromJson(data);
    });
  }

  /// Get all drivers' locations for a tenant (admin use)
  Stream<List<Map<String, dynamic>>> getAllDriversStream(String tenantId) {
    return _database
        .ref('locations')
        .child(tenantId)
        .child('drivers')
        .onValue
        .map((event) {
          if (event.snapshot.value == null) return [];
          
          final driversMap = Map<String, dynamic>.from(event.snapshot.value as Map);
          return driversMap.entries.map((entry) {
            final data = Map<String, dynamic>.from(entry.value as Map);
            data['firebase_key'] = entry.key;
            return data;
          }).toList();
        });
  }

  /// Remove driver location from Firebase (on logout)
  Future<void> removeDriverLocation() async {
    if (_driverLocationRef == null) return;

    try {
      await _driverLocationRef!.update({
        'is_online': false,
        'disconnected_at': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error removing driver location: $e');
    }
  }

  /// Cleanup and dispose
  Future<void> dispose() async {
    await setOnlineStatus(false);
    await _connectionSubscription?.cancel();
    _driverLocationRef = null;
    _currentTenantId = null;
    _currentDriverId = null;
    _currentDriverName = null;
  }
}

// Singleton instance
final firebaseService = FirebaseService();
