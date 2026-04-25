import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/router/app_router.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';

/// Sign Up form page — allows users to enter basic account information.
///
/// This is the first step of the signup flow where users enter:
/// - First Name
/// - Last Name
/// - Email
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Image anchored to the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: 0.45,
              child: Image.asset('images/Symbols1.png', fit: BoxFit.fitWidth),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  // Logo
                  Image.asset('images/logo.png', width: 80, height: 80),
                  const SizedBox(height: 32),

                  // Title
                  const Text(
                    'Translation App',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2563EB),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Subtitle
                  const Text(
                    'Welcome! Let\'s break the language barrier together',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // "Create an account" heading
                  const Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Create an account',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // First Name
                        TextFormField(
                          controller: _firstNameController,
                          decoration: InputDecoration(
                            labelText: 'First Name',
                            labelStyle: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter first name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Last Name
                        TextFormField(
                          controller: _lastNameController,
                          decoration: InputDecoration(
                            labelText: 'Last Name',
                            labelStyle: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter last name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Email
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          validator: _validateEmail,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _onContinuePressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Already you member? Login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already you member? ',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Or Browse as Guest
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.guestHome),
                    child: const Text(
                      'Or Browse as Guest',
                      style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onContinuePressed() async {
    if (_formKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      setState(() => _isLoading = true);

      try {
        final errorMsg = await context.read<AuthCubit>().checkEmail(email);

        if (!mounted) return;
        setState(() => _isLoading = false);

        if (errorMsg != null) {
          _showError(_friendlyError(errorMsg));
        } else {
          final userData = {
            'email': email,
            'firstName': firstName,
            'lastName': lastName,
          };
          context.go('/password-setup', extra: userData);
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showError('Cannot connect to server. Please check your connection.');
      }
    }
  }

  /// Maps raw error strings to user-friendly Vietnamese messages.
  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('network') ||
        lower.contains('no internet')) {
      return 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra internet.';
    }
    if (lower.contains('already registered') || lower.contains('email')) {
      return 'Email này đã được đăng ký. Vui lòng đăng nhập.';
    }
    if (lower.contains('timeout')) {
      return 'Kết nối quá chậm. Vui lòng thử lại.';
    }
    return raw;
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 40),
        title: const Text(
          'Có lỗi xảy ra',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(120, 44),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
