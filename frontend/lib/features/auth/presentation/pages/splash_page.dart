import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/main.dart' show config;
import 'package:frontend/app_config.dart';
import 'package:frontend/core/utils/api_url_resolver.dart';
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
  bool _serverReady = false;
  bool _showConnectingText = false;

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

    // Bắt đầu animation
    _animationController.forward().then((_) {
      // Đợi hoàn thành nốt thời gian linger (1000ms) rồi mới cho phép chuyển trang
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _animationFinished = true;
          });
          _tryNavigate();
        }
      });
    });

    // Check server health đồng thời với lúc animation đang chạy
    _checkServerHealth();
  }

  Future<void> _checkServerHealth() async {
    // Thử kết nối tối đa 3 lần, mỗi lần 2 giây. Nếu thất bại thì vẫn cho vào app (Offline mode).
    const maxRetries = 3;
    
    for (int i = 0; i < maxRetries; i++) {
      if (!mounted) return;
      
      try {
        final healthUrl = Uri.parse(config.apiUrl).replace(path: '/health');
        
        final response = await http.get(healthUrl).timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) {
          if (mounted) {
            setState(() {
              _serverReady = true;
            });
            _tryNavigate();
          }
          return; // Kết nối thành công, thoát hàm.
        }
      } catch (_) {
        // Thất bại, thử scan lại mạng LAN nếu đang ở IP mặc định
        if (mounted) {
          try {
            final newUrl = await ApiUrlResolver.scanForBackend();
            if (newUrl != null && newUrl != config.apiUrl) {
              config = AppConfig(appName: config.appName, apiUrl: newUrl);
            }
          } catch (_) {}
        }
      }
      
      if (i < maxRetries - 1) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    
    // Hết số lần thử mà vẫn chưa được -> Chấp nhận cho vào app (Offline mode)
    if (mounted) {
      setState(() {
        _serverReady = true; // Set true để lừa UI đi tiếp
      });
      _tryNavigate();
    }
  }

  void _tryNavigate([AuthState? state]) {
    if (!_animationFinished) return;

    if (!_serverReady) {
      // Nếu animation đã xong nhưng server chưa dậy, hiện text "Đang kết nối..."
      if (!_showConnectingText && mounted) {
        setState(() {
          _showConnectingText = true;
        });
      }
      return;
    }

    final currentState = state ?? context.read<AuthCubit>().state;
    if (currentState is AuthAuthenticated) {
      context.go(AppRoutes.home);
    } else if (currentState is AuthUnauthenticated || currentState is AuthFailureState) {
      context.go(AppRoutes.welcome);
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
        listenWhen: (previous, current) => _animationFinished && _serverReady,
        listener: (context, state) {
          _tryNavigate(state);
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
            
            // Connecting Text (hiện lên nếu animation xong mà server chưa dậy)
            if (_showConnectingText)
              const Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 30.0),
                  child: Text(
                    'Đang kết nối tới máy chủ...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
