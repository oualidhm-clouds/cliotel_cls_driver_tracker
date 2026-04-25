import 'package:flutter/foundation.dart';
import '../models/driver.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';

enum AuthStatus {
  initial,
  unauthenticated,
  sendingOtp,
  otpSent,
  verifying,
  authenticated,
  error,
}

class AuthProvider with ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;
  Driver? _driver;
  String? _error;
  String? _phoneNumber;
  String? _message;

  AuthStatus get status => _status;
  Driver? get driver => _driver;
  String? get error => _error;
  String? get phoneNumber => _phoneNumber;
  String? get message => _message;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    await storageService.init();
    
    final token = storageService.getAuthToken();
    final savedDriver = storageService.getDriver();
    
    if (token != null && savedDriver != null) {
      apiService.setAuthToken(token);
      _driver = savedDriver;
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    
    notifyListeners();
  }

  Future<void> sendOtp(String phone) async {
    _status = AuthStatus.sendingOtp;
    _error = null;
    _phoneNumber = phone;
    notifyListeners();

    try {
      final response = await apiService.sendOtp(phone);
      _message = response['message'];
      _status = AuthStatus.otpSent;
    } catch (e) {
      _error = e.toString();
      _status = AuthStatus.error;
    }
    
    notifyListeners();
  }

  Future<void> verifyOtp(String otp) async {
    if (_phoneNumber == null) {
      _error = 'Phone number not set';
      _status = AuthStatus.error;
      notifyListeners();
      return;
    }

    _status = AuthStatus.verifying;
    _error = null;
    notifyListeners();

    try {
      final response = await apiService.verifyOtp(_phoneNumber!, otp);
      await _handleAuthSuccess(response);
    } catch (e) {
      _error = e.toString();
      _status = AuthStatus.error;
    }
    
    notifyListeners();
  }

  Future<void> loginWithPassword(String phone, String password) async {
    _status = AuthStatus.verifying;
    _error = null;
    _phoneNumber = phone;
    notifyListeners();

    try {
      final response = await apiService.loginWithPassword(phone, password);
      await _handleAuthSuccess(response);
    } catch (e) {
      _error = e.toString();
      _status = AuthStatus.error;
    }
    
    notifyListeners();
  }

  Future<void> _handleAuthSuccess(Map<String, dynamic> response) async {
    final token = response['token'];
    final userData = response['user'] ?? response['driver'];
    
    if (token != null) {
      await storageService.saveAuthToken(token);
      apiService.setAuthToken(token);
    }
    
    if (userData != null) {
      _driver = Driver.fromJson(userData);
      await storageService.saveDriver(_driver!);
    }
    
    _status = AuthStatus.authenticated;
  }

  Future<void> refreshProfile() async {
    try {
      _driver = await apiService.getProfile();
      await storageService.saveDriver(_driver!);
      notifyListeners();
    } catch (e) {
      // Ignore refresh errors
    }
  }

  Future<void> logout() async {
    try {
      await firebaseService.dispose();
      await apiService.logout();
    } catch (e) {
      // Ignore logout errors
    } finally {
      _driver = null;
      _phoneNumber = null;
      _error = null;
      _message = null;
      _status = AuthStatus.unauthenticated;
      
      await storageService.clearDriver();
      await storageService.clearAuthToken();
      
      notifyListeners();
    }
  }

  void resetToPhone() {
    _status = AuthStatus.unauthenticated;
    _error = null;
    _message = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
