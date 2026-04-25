import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tenant.dart';
import '../models/driver.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  ApiException(this.message, {this.statusCode, this.errors});

  @override
  String toString() => message;
}

class ApiService {
  static const String centralApiUrl = 'https://cls.cliotel.com/api';
  
  String? _tenantBaseUrl;
  String? _authToken;

  void setTenant(String baseUrl) {
    _tenantBaseUrl = baseUrl;
  }

  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuth() {
    _authToken = null;
  }

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // ============ TENANT API ============

  /// Fetch all active tenants from central API
  Future<List<Tenant>> fetchTenants() async {
    try {
      final response = await http.get(
        Uri.parse('$centralApiUrl/tenants'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Tenant.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch tenants',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  // ============ AUTH API ============

  /// Send OTP to phone number
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    if (_tenantBaseUrl == null) {
      throw ApiException('Tenant not selected');
    }

    try {
      final response = await http.post(
        Uri.parse('$_tenantBaseUrl/api/auth/send-otp'),
        headers: _headers,
        body: json.encode({'phone': phone}),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw ApiException(
          data['message'] ?? 'Failed to send OTP',
          statusCode: response.statusCode,
          errors: data['errors'],
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  /// Verify OTP and login
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    if (_tenantBaseUrl == null) {
      throw ApiException('Tenant not selected');
    }

    try {
      final response = await http.post(
        Uri.parse('$_tenantBaseUrl/api/auth/verify-otp'),
        headers: _headers,
        body: json.encode({
          'phone': phone,
          'otp': otp,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (data['token'] != null) {
          _authToken = data['token'];
        }
        return data;
      } else {
        throw ApiException(
          data['message'] ?? 'Invalid OTP',
          statusCode: response.statusCode,
          errors: data['errors'],
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  /// Login with password
  Future<Map<String, dynamic>> loginWithPassword(String phone, String password) async {
    if (_tenantBaseUrl == null) {
      throw ApiException('Tenant not selected');
    }

    try {
      final response = await http.post(
        Uri.parse('$_tenantBaseUrl/api/auth/login'),
        headers: _headers,
        body: json.encode({
          'phone': phone,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (data['token'] != null) {
          _authToken = data['token'];
        }
        return data;
      } else {
        throw ApiException(
          data['message'] ?? 'Invalid credentials',
          statusCode: response.statusCode,
          errors: data['errors'],
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  /// Get current user profile
  Future<Driver> getProfile() async {
    if (_tenantBaseUrl == null) {
      throw ApiException('Tenant not selected');
    }
    if (_authToken == null) {
      throw ApiException('Not authenticated');
    }

    try {
      final response = await http.get(
        Uri.parse('$_tenantBaseUrl/api/auth/me'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return Driver.fromJson(data['user'] ?? data);
      } else {
        throw ApiException(
          data['message'] ?? 'Failed to fetch profile',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  /// Logout
  Future<void> logout() async {
    if (_tenantBaseUrl == null || _authToken == null) {
      _authToken = null;
      return;
    }

    try {
      await http.post(
        Uri.parse('$_tenantBaseUrl/api/auth/logout'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
    } catch (e) {
      // Ignore logout errors
    } finally {
      _authToken = null;
    }
  }
}

// Singleton instance
final apiService = ApiService();
