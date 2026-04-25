import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/tenant_provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
import '../services/storage_service.dart';
import 'tenant_selection_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _usePassword = false;
  bool _showPassword = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill the phone number from the last successful login.
    final last = storageService.getLastPhone();
    if (last != null && last.isNotEmpty) {
      _phoneController.text = last;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _sendOtp() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showError('Please enter your phone number');
      return;
    }
    FocusScope.of(context).unfocus();
    context.read<AuthProvider>().sendOtp(phone);
  }

  void _verifyOtp() {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      _showError('Please enter the OTP');
      return;
    }
    FocusScope.of(context).unfocus();
    context.read<AuthProvider>().verifyOtp(otp);
  }

  void _loginWithPassword() {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    if (phone.isEmpty) {
      _showError('Please enter your phone number');
      return;
    }
    if (password.isEmpty) {
      _showError('Please enter your password');
      return;
    }
    FocusScope.of(context).unfocus();
    context.read<AuthProvider>().loginWithPassword(phone, password);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _changeTenant() {
    context.read<TenantProvider>().clearTenant();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TenantSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>().selectedTenant;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            // Auto-navigate when authentication succeeds.
            if (authProvider.isAuthenticated && !_navigated) {
              _navigated = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                );
              });
            }

            final loading = authProvider.status == AuthStatus.sendingOtp ||
                authProvider.status == AuthStatus.verifying;
            final inOtpStep = authProvider.status == AuthStatus.otpSent;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar — change hotel
                  _ChangeHotelChip(
                    tenantName: tenant?.name ?? 'Hotel',
                    onTap: _changeTenant,
                  ),
                  const SizedBox(height: 32),

                  // Branding
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryDark],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Welcome back',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to start tracking for ${tenant?.name ?? 'your hotel'}.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),

                  // Errors
                  if (authProvider.error != null) ...[
                    _Banner(
                      icon: Icons.error_outline_rounded,
                      color: AppColors.error,
                      message: authProvider.error!,
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Mode toggle (hidden in OTP step)
                  if (!inOtpStep) ...[
                    _SegmentedToggle(
                      left: 'OTP',
                      right: 'Password',
                      selectedIndex: _usePassword ? 1 : 0,
                      onChanged: (i) =>
                          setState(() => _usePassword = i == 1),
                    ),
                    const SizedBox(height: 22),
                  ],

                  // Phone field
                  const _FieldLabel('Phone number'),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    enabled: !inOtpStep,
                    style: const TextStyle(color: AppColors.textPrimary),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
                    ],
                    decoration: const InputDecoration(
                      hintText: '+212 600 000 000',
                      prefixIcon: Icon(
                        Icons.phone_rounded,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // OTP step
                  if (inOtpStep) ...[
                    if (authProvider.message != null) ...[
                      _Banner(
                        icon: Icons.check_circle_outline_rounded,
                        color: AppColors.success,
                        message: authProvider.message!,
                      ),
                      const SizedBox(height: 14),
                    ],
                    const _FieldLabel('Verification code'),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 10,
                      ),
                      textAlign: TextAlign.center,
                      autofocus: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        hintText: '------',
                        hintStyle: TextStyle(
                          letterSpacing: 10,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            context.read<AuthProvider>().resetToPhone(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Use a different phone number'),
                      ),
                    ),
                  ],

                  // Password step
                  if (_usePassword && !inOtpStep) ...[
                    const _FieldLabel('Password'),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.textMuted,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Action button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: loading ? null : () => _handleSubmit(authProvider),
                      child: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_getButtonText(authProvider)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _getButtonText(AuthProvider provider) {
    if (provider.status == AuthStatus.otpSent) return 'Verify code';
    if (_usePassword) return 'Sign in';
    return 'Send code';
  }

  void _handleSubmit(AuthProvider provider) {
    if (provider.status == AuthStatus.otpSent) {
      _verifyOtp();
    } else if (_usePassword) {
      _loginWithPassword();
    } else {
      _sendOtp();
    }
  }
}

class _ChangeHotelChip extends StatelessWidget {
  final String tenantName;
  final VoidCallback onTap;
  const _ChangeHotelChip({required this.tenantName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.business_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  tenantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.swap_horiz_rounded,
                size: 14,
                color: AppColors.primaryLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _Banner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  final String left;
  final String right;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentedToggle({
    required this.left,
    required this.right,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _segment(left, 0)),
          Expanded(child: _segment(right, 1)),
        ],
      ),
    );
  }

  Widget _segment(String label, int index) {
    final isActive = selectedIndex == index;
    return GestureDetector(
      onTap: () => onChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
