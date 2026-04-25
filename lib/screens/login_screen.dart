import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/tenant_provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
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
    context.read<AuthProvider>().sendOtp(phone);
  }

  void _verifyOtp() {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      _showError('Please enter the OTP');
      return;
    }
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
    
    context.read<AuthProvider>().loginWithPassword(phone, password);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
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
            // Navigate to dashboard on successful auth
            if (authProvider.isAuthenticated) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                );
              });
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button to change tenant
                  TextButton.icon(
                    onPressed: _changeTenant,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Change Hotel'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Header
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Center(
                    child: Text(
                      tenant?.name ?? 'Driver Login',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  const Center(
                    child: Text(
                      'Sign in to start tracking',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Error message
                  if (authProvider.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authProvider.error!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Phone input
                  const Text(
                    'Phone Number',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    enabled: authProvider.status != AuthStatus.otpSent,
                    style: const TextStyle(color: AppColors.textPrimary),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                    ],
                    decoration: const InputDecoration(
                      hintText: '+212 600 000 000',
                      prefixIcon: Icon(Icons.phone, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Toggle between OTP and Password
                  if (authProvider.status != AuthStatus.otpSent) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildToggleButton(
                            'OTP Login',
                            !_usePassword,
                            () => setState(() => _usePassword = false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildToggleButton(
                            'Password',
                            _usePassword,
                            () => setState(() => _usePassword = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // OTP Flow
                  if (!_usePassword && authProvider.status == AuthStatus.otpSent) ...[
                    if (authProvider.message != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: AppColors.success,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                authProvider.message!,
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    const Text(
                      'Enter OTP',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        letterSpacing: 8,
                      ),
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        hintText: '------',
                        hintStyle: TextStyle(letterSpacing: 8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextButton(
                      onPressed: () => authProvider.resetToPhone(),
                      child: const Text('Change phone number'),
                    ),
                  ],
                  
                  // Password input
                  if (_usePassword && authProvider.status != AuthStatus.otpSent) ...[
                    const Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(
                          Icons.lock,
                          color: AppColors.textMuted,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword 
                                ? Icons.visibility_off 
                                : Icons.visibility,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () {
                            setState(() => _showPassword = !_showPassword);
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  
                  // Action button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading(authProvider) 
                          ? null 
                          : () => _handleSubmit(authProvider),
                      child: _isLoading(authProvider)
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

  Widget _buildToggleButton(String text, bool isActive, VoidCallback onTap) {
    return Material(
      color: isActive ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isLoading(AuthProvider provider) {
    return provider.status == AuthStatus.sendingOtp ||
           provider.status == AuthStatus.verifying;
  }

  String _getButtonText(AuthProvider provider) {
    if (provider.status == AuthStatus.otpSent) {
      return 'Verify OTP';
    }
    if (_usePassword) {
      return 'Sign In';
    }
    return 'Send OTP';
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
