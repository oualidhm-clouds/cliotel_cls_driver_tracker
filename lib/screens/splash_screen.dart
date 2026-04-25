import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tenant_provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
import 'tenant_selection_screen.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
    _route();
  }

  Future<void> _route() async {
    // Brief delay so the splash is felt, but no async loading needed —
    // providers were hydrated synchronously in main().
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;

    final tenantProvider = context.read<TenantProvider>();
    final authProvider = context.read<AuthProvider>();

    final Widget next;
    if (authProvider.isAuthenticated && tenantProvider.hasTenant) {
      // Already logged in — go straight to the dashboard.
      next = const DashboardScreen();
    } else if (tenantProvider.hasTenant) {
      // Tenant selected previously — only need to log in.
      next = const LoginScreen();
    } else {
      // Fresh install — pick a hotel first.
      next = const TenantSelectionScreen();
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => next,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Subtle radial vignette
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    AppColors.primary.withOpacity(0.10),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),

          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _LogoMark(),
                        const SizedBox(height: 28),
                        const Text(
                          'Cliotel Driver',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Real-time location tracking',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 56),
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(
        Icons.local_shipping_rounded,
        size: 44,
        color: Colors.white,
      ),
    );
  }
}
