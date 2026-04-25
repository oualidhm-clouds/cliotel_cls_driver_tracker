import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tenant_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../config/theme.dart';
import '../services/location_service.dart';
import 'tenant_selection_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> 
    with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final locationProvider = context.read<LocationProvider>();
    
    if (state == AppLifecycleState.paused) {
      // App going to background - tracking continues via foreground service
    } else if (state == AppLifecycleState.resumed) {
      // App coming back - refresh UI
      if (locationProvider.isTracking) {
        locationProvider.notifyListeners();
      }
    }
  }

  Future<void> _initializeTracking() async {
    final tenant = context.read<TenantProvider>().selectedTenant;
    final driver = context.read<AuthProvider>().driver;
    
    if (tenant != null && driver != null) {
      await context.read<LocationProvider>().initialize(
        tenant: tenant,
        driver: driver,
      );
    }
  }

  void _toggleTracking() async {
    final locationProvider = context.read<LocationProvider>();
    
    if (locationProvider.isTracking) {
      await locationProvider.stopTracking();
    } else {
      final started = await locationProvider.startTracking();
      if (!started && mounted) {
        _showPermissionDialog();
      }
    }
  }

  void _showPermissionDialog() {
    final locationProvider = context.read<LocationProvider>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Location Permission Required',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          locationProvider.error ?? 
          'Please enable location permissions to use tracking.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              locationProvider.openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    // Stop tracking first
    await context.read<LocationProvider>().stopTracking();
    
    // Then logout
    await context.read<AuthProvider>().logout();
    await context.read<TenantProvider>().clearTenant();
    
    if (!mounted) return;
    
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TenantSelectionScreen()),
      (route) => false,
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Logout',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to logout? Location tracking will be stopped.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>().selectedTenant;
    final driver = context.watch<AuthProvider>().driver;
    final locationProvider = context.watch<LocationProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(tenant?.name ?? 'Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Driver info card
              _buildDriverCard(driver),
              const SizedBox(height: 24),
              
              // Tracking status card
              _buildTrackingCard(locationProvider),
              const SizedBox(height: 24),
              
              // Location info card
              if (locationProvider.currentLocation != null)
                _buildLocationCard(locationProvider),
              const SizedBox(height: 24),
              
              // Main tracking button
              _buildTrackingButton(locationProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriverCard(driver) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                (driver?.name ?? 'D').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver?.name ?? 'Driver',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  driver?.phone ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingCard(LocationProvider locationProvider) {
    final isTracking = locationProvider.isTracking;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isTracking ? AppColors.success : AppColors.textMuted,
                  shape: BoxShape.circle,
                  boxShadow: isTracking
                      ? [
                          BoxShadow(
                            color: AppColors.success.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isTracking ? 'Tracking Active' : 'Tracking Inactive',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildInfoRow(
            Icons.update,
            'Last Update',
            locationProvider.lastUpdateText,
          ),
          const SizedBox(height: 12),
          
          _buildInfoRow(
            Icons.wifi,
            'Connection',
            locationProvider.isOnline ? 'Online' : 'Offline',
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(LocationProvider locationProvider) {
    final location = locationProvider.currentLocation!;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Current Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildInfoRow(
            Icons.my_location,
            'Latitude',
            location.latitude.toStringAsFixed(6),
          ),
          const SizedBox(height: 12),
          
          _buildInfoRow(
            Icons.my_location,
            'Longitude',
            location.longitude.toStringAsFixed(6),
          ),
          
          if (location.accuracy != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.gps_fixed,
              'Accuracy',
              '${location.accuracy!.toStringAsFixed(1)}m',
            ),
          ],
          
          if (location.speed != null && location.speed! > 0) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.speed,
              'Speed',
              '${(location.speed! * 3.6).toStringAsFixed(1)} km/h',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingButton(LocationProvider locationProvider) {
    final isTracking = locationProvider.isTracking;
    final isLoading = locationProvider.status == TrackingStatus.requesting;
    
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : _toggleTracking,
        style: ElevatedButton.styleFrom(
          backgroundColor: isTracking ? AppColors.error : AppColors.success,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isTracking 
                        ? Icons.stop_circle_outlined 
                        : Icons.play_circle_outline,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isTracking ? 'Stop Tracking' : 'Start Tracking',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
