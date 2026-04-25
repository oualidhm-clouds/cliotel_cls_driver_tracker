import 'package:flutter/foundation.dart';
import '../models/tenant.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

enum TenantStatus {
  initial,
  loading,
  loaded,
  error,
}

class TenantProvider with ChangeNotifier {
  TenantStatus _status = TenantStatus.initial;
  List<Tenant> _tenants = [];
  Tenant? _selectedTenant;
  String? _error;

  TenantStatus get status => _status;
  List<Tenant> get tenants => _tenants;
  Tenant? get selectedTenant => _selectedTenant;
  String? get error => _error;
  bool get hasTenant => _selectedTenant != null;

  TenantProvider() {
    _loadSavedTenant();
  }

  Future<void> _loadSavedTenant() async {
    await storageService.init();
    final savedTenant = storageService.getTenant();
    if (savedTenant != null) {
      _selectedTenant = savedTenant;
      apiService.setTenant(savedTenant.baseUrl!);
      notifyListeners();
    }
  }

  Future<void> fetchTenants() async {
    _status = TenantStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _tenants = await apiService.fetchTenants();
      _status = TenantStatus.loaded;
    } catch (e) {
      _error = e.toString();
      _status = TenantStatus.error;
    }
    
    notifyListeners();
  }

  Future<void> selectTenant(Tenant tenant) async {
    _selectedTenant = tenant;
    
    if (tenant.baseUrl != null) {
      apiService.setTenant(tenant.baseUrl!);
      await storageService.saveTenant(tenant);
    }
    
    notifyListeners();
  }

  Future<void> clearTenant() async {
    _selectedTenant = null;
    await storageService.clearTenant();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
