import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tenant.dart';
import '../models/driver.dart';

class StorageService {
  static const String _keyTenant = 'cliotel_tenant';
  static const String _keyDriver = 'cliotel_driver';
  static const String _keyAuthToken = 'cliotel_auth_token';
  static const String _keyTrackingEnabled = 'cliotel_tracking_enabled';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ============ TENANT ============

  Future<void> saveTenant(Tenant tenant) async {
    await _prefs?.setString(_keyTenant, json.encode(tenant.toJson()));
  }

  Tenant? getTenant() {
    final data = _prefs?.getString(_keyTenant);
    if (data == null) return null;
    
    try {
      return Tenant.fromJson(json.decode(data));
    } catch (e) {
      return null;
    }
  }

  Future<void> clearTenant() async {
    await _prefs?.remove(_keyTenant);
  }

  // ============ DRIVER ============

  Future<void> saveDriver(Driver driver) async {
    await _prefs?.setString(_keyDriver, json.encode(driver.toJson()));
  }

  Driver? getDriver() {
    final data = _prefs?.getString(_keyDriver);
    if (data == null) return null;
    
    try {
      return Driver.fromJson(json.decode(data));
    } catch (e) {
      return null;
    }
  }

  Future<void> clearDriver() async {
    await _prefs?.remove(_keyDriver);
  }

  // ============ AUTH TOKEN ============

  Future<void> saveAuthToken(String token) async {
    await _prefs?.setString(_keyAuthToken, token);
  }

  String? getAuthToken() {
    return _prefs?.getString(_keyAuthToken);
  }

  Future<void> clearAuthToken() async {
    await _prefs?.remove(_keyAuthToken);
  }

  // ============ TRACKING PREFERENCE ============

  Future<void> setTrackingEnabled(bool enabled) async {
    await _prefs?.setBool(_keyTrackingEnabled, enabled);
  }

  bool isTrackingEnabled() {
    return _prefs?.getBool(_keyTrackingEnabled) ?? false;
  }

  // ============ CLEAR ALL ============

  Future<void> clearAll() async {
    await _prefs?.remove(_keyTenant);
    await _prefs?.remove(_keyDriver);
    await _prefs?.remove(_keyAuthToken);
    await _prefs?.remove(_keyTrackingEnabled);
  }
}

// Singleton instance
final storageService = StorageService();
