import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/navigation/bottom_nav.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/device_service.dart';
import 'package:nature_biotic/core/widgets/animations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController =
      TextEditingController(); // Modified from _emailController
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await SupabaseService.signIn(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted && response.user != null) {
        // Validation: Is this device authorized?
        final isAuthorized = await SupabaseService.isDeviceAuthorized();
        final deviceInfo = await DeviceService.getDeviceInfo();
        final currentId = deviceInfo['id']!;

        if (!isAuthorized) {
          // Device mismatch detected
          await SupabaseService.logLoginActivity(
            deviceId: currentId,
            deviceName: deviceInfo['name']!,
            osVersion: deviceInfo['os']!,
            status: 'DEVICE_MISMATCH',
          );

          await SupabaseService.client.auth.signOut();
          if (mounted) {
            _showSecurityAlert(
              'Access Denied',
              'This account is locked to a different device. Your unauthorized login attempt has been logged for Admin review.',
            );
            setState(() => _isLoading = false);
            return;
          }
        }

        // DEVICE AUTHORIZED (or Admin)
        final profile = await SupabaseService.getProfile();

        if (profile == null) {
          // Super Admin or no profile
          await SupabaseService.logLoginActivity(
            deviceId: currentId,
            deviceName: deviceInfo['name']!,
            osVersion: deviceInfo['os']!,
            status: 'SUCCESS (No Profile)',
          );
        } else {
          final registeredId = profile['registered_device_id'];

          if ((registeredId == null || registeredId.isEmpty) &&
              profile['role'] != 'admin') {
            // First time login - bind this device (executives only)
            await SupabaseService.updateRegisteredDevice(currentId);
            await SupabaseService.logLoginActivity(
              deviceId: currentId,
              deviceName: deviceInfo['name']!,
              osVersion: deviceInfo['os']!,
              status: 'SUCCESS (Bound)',
            );
          } else {
            // Re-login on authorized device
            await SupabaseService.logLoginActivity(
              deviceId: currentId,
              deviceName: deviceInfo['name']!,
              osVersion: deviceInfo['os']!,
              status: 'SUCCESS',
            );
          }
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const BottomNav()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _identifierController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address to reset password'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService.resetPasswordForEmail(email);
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Reset Link Sent'),
                content: Text(
                  'A password reset link has been sent to $email. Please check your inbox.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSecurityAlert(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.security_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Text(title),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('I Understand'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              AppColors.secondary.withOpacity(0.4),
              const Color(0xFFEBF3EC),
              Colors.white,
            ],
            stops: const [0.0, 0.4, 0.8, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: EntranceAnimation(
                  delay: 100,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.05),
                          blurRadius: 60,
                          offset: const Offset(0, 24),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Brand Header
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Image.asset('assets/logo.png', width: 90),
                              ),
                              const SizedBox(height: 24),
                              RichText(
                                text: const TextSpan(
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    fontFamily: 'Outfit',
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'NATURE BIOTIC',
                                      style: TextStyle(color: AppColors.textBlack),
                                    ),
                                    TextSpan(
                                      text: ' CRM',
                                      style: TextStyle(color: AppColors.primary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Sign in to manage your farming hub',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textGray.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 44),

                        // Input Fields
                        TextField(
                          controller: _identifierController,
                          decoration: InputDecoration(
                            hintText: 'Username or Email',
                            prefixIcon: Icon(
                              Icons.alternate_email_rounded,
                              color: AppColors.textGray.withOpacity(0.6),
                              size: 20,
                            ),
                            filled: true,
                            fillColor: AppColors.background,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            prefixIcon: Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.textGray.withOpacity(0.6),
                              size: 20,
                            ),
                            filled: true,
                            fillColor: AppColors.background,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          child: ScaleButton(
                            onTap: _isLoading ? null : _handleLogin,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: null, // Tap handled by ScaleButton
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text(
                                        'Secure Login',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Forgot Password
                        TextButton(
                          onPressed: _isLoading ? null : _handleForgotPassword,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                          child: const Text(
                            'Recover Access',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
