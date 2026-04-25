import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tenant_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../config/theme.dart';
import 'login_screen.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeTracking());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    final tenant = context.read<TenantProvider>().selectedTenant;
    final driver = context.read<AuthProvider>().driver;
    if (tenant != null && driver != null) {
      await context
          .read<LocationProvider>()
          .initialize(tenant: tenant, driver: driver);
    }
  }

  Future<void> _toggleTracking() async {
    final lp = context.read<LocationProvider>();
    if (lp.isTracking) {
      await _confirmStopTracking();
    } else {
      final started = await lp.startTracking();
      if (!started && mounted) _showPermissionDialog();
    }
  }

  Future<void> _confirmStopTracking() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stop tracking?'),
        content: const Text(
          'You will stop sharing your location. The notification will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<LocationProvider>().stopTracking();
    }
  }

  void _showPermissionDialog() {
    final lp = context.read<LocationProvider>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Location permission needed'),
        content: Text(
          lp.error ??
              'Cliotel Driver needs precise location access to track deliveries. Please enable it in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              lp.openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    // Stop tracking before clearing auth so the foreground service shuts down.
    await context.read<LocationProvider>().stopTracking();
    await context.read<AuthProvider>().logout();
    // NOTE: tenant is intentionally preserved — user goes back to login,
    // not to the tenant selection screen.
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will be signed out and tracking will stop. Your hotel selection will be remembered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>().selectedTenant;
    final driver = context.watch<AuthProvider>().driver;
    final lp = context.watch<LocationProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _TopBar(
                    tenantName: tenant?.name ?? 'Cliotel Driver',
                    onLogout: _showLogoutDialog,
                  ),
                  const SizedBox(height: 24),
                  _DriverGreeting(name: driver?.name ?? 'Driver'),
                  const SizedBox(height: 20),
                  _TrackingHeroCard(provider: lp),
                  const SizedBox(height: 16),
                  _StatsGrid(provider: lp),
                  const SizedBox(height: 16),
                  if (lp.currentLocation != null)
                    _CoordinatesCard(provider: lp),
                  const SizedBox(height: 24),
                  _PrimaryActionButton(
                    isTracking: lp.isTracking,
                    isLoading: lp.status == TrackingStatus.requesting,
                    onPressed: _toggleTracking,
                  ),
                  const SizedBox(height: 16),
                  _BackgroundHint(isTracking: lp.isTracking),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// Top bar
// =============================================================
class _TopBar extends StatelessWidget {
  final String tenantName;
  final VoidCallback onLogout;

  const _TopBar({required this.tenantName, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(
            Icons.business_rounded,
            color: AppColors.primaryLight,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CONNECTED TO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tenantName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            onTap: onLogout,
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.logout_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================
// Greeting
// =============================================================
class _DriverGreeting extends StatelessWidget {
  final String name;
  const _DriverGreeting({required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              name.isEmpty ? 'D' : name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryLight,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================
// Hero card with pulsing status indicator
// =============================================================
class _TrackingHeroCard extends StatefulWidget {
  final LocationProvider provider;
  const _TrackingHeroCard({required this.provider});

  @override
  State<_TrackingHeroCard> createState() => _TrackingHeroCardState();
}

class _TrackingHeroCardState extends State<_TrackingHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTracking = widget.provider.isTracking;
    final color = isTracking ? AppColors.success : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isTracking ? null : AppColors.card,
        gradient: isTracking
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.success.withOpacity(0.10),
                  AppColors.card,
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTracking
              ? AppColors.success.withOpacity(0.3)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isTracking)
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) {
                          return Container(
                            width: 16 * (0.6 + _pulse.value * 0.6),
                            height: 16 * (0.6 + _pulse.value * 0.6),
                            decoration: BoxDecoration(
                              color: color.withOpacity(
                                  0.5 * (1 - _pulse.value)),
                              shape: BoxShape.circle,
                            ),
                          );
                        },
                      ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isTracking ? 'Live tracking' : 'Tracking off',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              if (isTracking)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.successLight,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            isTracking
                ? 'Sharing your location'
                : 'You are not visible to dispatch',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isTracking
                ? 'Updates every ~4 seconds. Last update ${widget.provider.lastUpdateText.toLowerCase()}.'
                : 'Tap "Start tracking" to begin sending location updates.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// Stats grid (2x2)
// =============================================================
class _StatsGrid extends StatelessWidget {
  final LocationProvider provider;
  const _StatsGrid({required this.provider});

  @override
  Widget build(BuildContext context) {
    final speedKmh = provider.currentLocation?.speed != null &&
            provider.currentLocation!.speed! > 0
        ? '${(provider.currentLocation!.speed! * 3.6).toStringAsFixed(1)} km/h'
        : '— km/h';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.timer_outlined,
                label: 'Session',
                value: provider.isTracking
                    ? provider.sessionDurationText
                    : '00:00',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.sync_rounded,
                label: 'Updates',
                value: provider.updateCount.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.route_rounded,
                label: 'Distance',
                value: provider.totalDistanceText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.speed_rounded,
                label: 'Speed',
                value: speedKmh,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// Coordinates card
// =============================================================
class _CoordinatesCard extends StatelessWidget {
  final LocationProvider provider;
  const _CoordinatesCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final loc = provider.currentLocation!;
    return Container(
      padding: const EdgeInsets.all(18),
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Current location',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _coordRow('Latitude', loc.latitude.toStringAsFixed(6)),
          const SizedBox(height: 10),
          _coordRow('Longitude', loc.longitude.toStringAsFixed(6)),
          if (loc.accuracy != null) ...[
            const SizedBox(height: 10),
            _coordRow('Accuracy', '±${loc.accuracy!.toStringAsFixed(1)} m'),
          ],
        ],
      ),
    );
  }

  Widget _coordRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// =============================================================
// Action button
// =============================================================
class _PrimaryActionButton extends StatelessWidget {
  final bool isTracking;
  final bool isLoading;
  final VoidCallback onPressed;

  const _PrimaryActionButton({
    required this.isTracking,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isTracking ? AppColors.error : AppColors.success;

    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: bg.withOpacity(0.5),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
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
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isTracking ? 'Stop tracking' : 'Start tracking',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// =============================================================
// Footer hint about background tracking
// =============================================================
class _BackgroundHint extends StatelessWidget {
  final bool isTracking;
  const _BackgroundHint({required this.isTracking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              size: 16,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isTracking
                  ? 'Tracking continues in the background. A notification keeps the service running — do not swipe it away.'
                  : 'When tracking starts, a persistent notification will keep your location updates flowing in the background.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
