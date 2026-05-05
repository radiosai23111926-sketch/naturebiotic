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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),
                  EntranceAnimation(
                    delay: 100,
                    child: Center(
                      child: Image.asset('assets/logo.png', width: 150),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const EntranceAnimation(
                    delay: 300,
                    child: Center(
                      child: Text(
                        'Welcome Back',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textBlack,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const EntranceAnimation(
                    delay: 450,
                    child: Center(
                      child: Text(
                        'Sign in to manage your farming activities',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textGray,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  EntranceAnimation(
                    delay: 600,
                    child: TextField(
                      controller: _identifierController,
                      decoration: const InputDecoration(
                        hintText: 'Username or Email',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  EntranceAnimation(
                    delay: 750,
                    child: TextField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  EntranceAnimation(
                    delay: 1050,
                    child: SizedBox(
                      width: double.infinity,
                      child: ScaleButton(
                        onTap: _isLoading ? null : _handleLogin,
                        child: ElevatedButton(
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
                                  : const Text('Login'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _isLoading ? null : _handleForgotPassword,
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
