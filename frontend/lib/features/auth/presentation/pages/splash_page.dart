import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_state.dart';
import 'package:frontend/core/router/app_router.dart';

/// Splash page — displayed when the app starts.
///
/// Features a unique and smooth animation of the logo and bottom wave shape
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  bool _animationFinished = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 1.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOutCirc),
          ),
        );

    // Kích hoạt check auth ngầm dưới nền ngay khi bắt đầu
    context.read<AuthCubit>().checkAuthStatus();

    _animationController.forward().then((_) {
      // Đợi hoàn thành nốt thời gian linger (1000ms) rồi mới cho phép chuyển trang
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _animationFinished = true;
          });
          _navigateBasedOnAuth(context.read<AuthCubit>().state);
        }
      });
    });
  }

  void _navigateBasedOnAuth(AuthState state) {
    if (!_animationFinished) {
      return; // Tuyệt đối không điều hướng khi animation chưa xong
    }

    if (state is AuthAuthenticated) {
      context.go(AppRoutes.home);
    } else if (state is AuthUnauthenticated || state is AuthFailureState) {
      context.go('/welcome');
    }
    // Nếu vẫn đang AuthInProgress, thì không làm gì, sẽ do BlocListener lo phần việc sau.
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF1868F8,
      ), // Match the bright blue background
      body: BlocListener<AuthCubit, AuthState>(
        listenWhen: (previous, current) => _animationFinished,
        listener: (context, state) {
          _navigateBasedOnAuth(state);
        },
        child: Stack(
          children: [
            // Center content
            Center(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'images/logo.png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Translation App',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(
                            height: 100,
                          ), // Slightly offset upwards
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom wave decoration
            Align(
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: _slideAnimation,
                child: Image.asset(
                  'images/trangtri1.png',
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
