import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_state.dart';
import 'package:frontend/core/router/app_router.dart';

/// Splash page — displayed when the app starts.
///
/// Shows the app logo and waits for authentication check.
/// Automatically navigates to appropriate screen after auth check completes.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    // Trigger auth status check via AuthCubit
    context.read<AuthCubit>().checkAuthStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          // Navigate based on auth state
          if (state is AuthAuthenticated) {
            context.go(AppRoutes.home);
          } else if (state is AuthFailureState || state is AuthInitial) {
            // Check if user has seen welcome screen
            // If not, navigate to welcome; otherwise navigate to login
            context.go('/welcome');
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF2563EB), // Blue 600
                Color(0xFF1E40AF), // Blue 800
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'images/logo.png',
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 24),
                // App name
                const Text(
                  'Translation App',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 80),
                // Loading indicator
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
