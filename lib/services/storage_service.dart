import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tenant.dart';
import '../models/driver.dart';

/// Lightweight wrapper around [SharedPreferences].
///
/// IMPORTANT: [init] must be called once (from `main`) before any getter is
/// used. After [init] returns, every getter is fully synchronous which lets
/// the splash screen route correctly without any race condition.
class StorageService {
  static const String _keyTenant = 'cliotel_tenant';
  static const String _keyDriver = 'cliotel_driver';
  static const String _keyAuthToken = 'cliotel_auth_token';
  static const String _keyTrackingEnabled = 'cliotel_tracking_enabled';
  static const String _keyLastPhone = 'cliotel_last_phone';

  SharedPreferences? _prefs;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
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

  // ============ LAST PHONE (UX nicety) ============

  Future<void> saveLastPhone(String phone) async {
    await _prefs?.setString(_keyLastPhone, phone);
  }

  String? getLastPhone() => _prefs?.getString(_keyLastPhone);

  // ============ CLEAR ALL ============

  Future<void> clearAuth() async {
    await _prefs?.remove(_keyDriver);
    await _prefs?.remove(_keyAuthToken);
    await _prefs?.remove(_keyTrackingEnabled);
  }

  Future<void> clearAll() async {
    await _prefs?.remove(_keyTenant);
    await _prefs?.remove(_keyDriver);
    await _prefs?.remove(_keyAuthToken);
    await _prefs?.remove(_keyTrackingEnabled);
    await _prefs?.remove(_keyLastPhone);
  }
}

// Singleton instance
final storageService = StorageService();
