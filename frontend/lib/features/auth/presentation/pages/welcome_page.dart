import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/router/app_router.dart';

/// Welcome/Onboarding page — introduces app features to first-time users.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late PageController _pageController;
  int _currentPage = 0;

  final List<WelcomeSlide> _slides = [
    WelcomeSlide(
      image: 'images/intro1.png',
      title: 'Translate Instantly',
      description:
          'Fast and accurate text translations for over 100 languages, right at your fingertips',
    ),
    WelcomeSlide(
      image: 'images/intro2.png',
      title: 'Speak & Scan',
      description:
          'Use your voice for real-time conversations, or snap a photo to translate menus and signs instantly',
    ),
    WelcomeSlide(
      image: 'images/intro3.png',
      title: 'Your History, Anywhere',
      description:
          'Access your past translations offline anytime. We\'ll automatically sync your history when you\'re back online',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Thay vì dùng IntrinsicHeight (gây lỗi với PageView),
            // Ta tính toán chiều cao an toàn tối thiểu là 680px để không bao giờ bị overflow.
            // Nếu màn hình cao hơn 680, nó chiếm toàn bộ màn hình.
            // Nếu màn hình thấp hơn 680, nó cho phép cuộn!
            final double contentHeight = constraints.maxHeight > 680.0
                ? constraints.maxHeight
                : 680.0;

            return SingleChildScrollView(
              child: SizedBox(
                height: contentHeight,
                child: Stack(
                  children: [
                    // 1. Sliding Content (PageView)
                    Column(
                      children: [
                        // Top Bar with Skip Button
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Only show Skip on slide 1 and 2
                              AnimatedOpacity(
                                opacity: _currentPage < 2 ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 300),
                                child: IgnorePointer(
                                  ignoring: _currentPage >= 2,
                                  child: GestureDetector(
                                    onTap: () {
                                      // Skip jumps instantly to slide 3
                                      _pageController.animateToPage(
                                        2,
                                        duration: const Duration(
                                          milliseconds: 600,
                                        ),
                                        curve: Curves.easeOutCubic,
                                      );
                                    },
                                    child: const Text(
                                      'Skip',
                                      style: TextStyle(
                                        color: Color(0xFF1868F8),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Expanded PageView
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _slides.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentPage = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              return AnimatedBuilder(
                                animation: _pageController,
                                builder: (context, child) {
                                  double value = 1.0;
                                  if (_pageController.position.haveDimensions) {
                                    value = _pageController.page! - index;
                                    value = (1 - (value.abs() * 0.3)).clamp(
                                      0.0,
                                      1.0,
                                    );
                                  }
                                  return Transform.scale(
                                    scale: Curves.easeOut.transform(value),
                                    child: Opacity(
                                      opacity: value.clamp(0.4, 1.0),
                                      child: child,
                                    ),
                                  );
                                },
                                child: _buildSlideContent(
                                  _slides[index],
                                  index,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    // 2. Fixed Dots Overlay
                    // Được cố định tuyệt đối ở lớp Stack bằng Positioned, do đó
                    // khi quẹt ngang PageView thì Dấu Chấm KHÔNG bị trôi ngang,
                    // nhưng khi cuộn dọc màn hình thì nó cuộn theo văn bản cực khớp!
                    Positioned(
                      bottom: 375, // Cố định chuẩn xác bên trên khối text 360px
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _slides.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: _currentPage == index ? 20 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: _currentPage == index
                                  ? const Color(0xFF1868F8)
                                  : Colors.grey[300],
                            ),
                          ),
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
    );
  }

  Widget _buildSlideContent(WelcomeSlide slide, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image Area
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 200),
              padding: const EdgeInsets.only(bottom: 24, top: 12),
              child: Center(
                child: Image.asset(slide.image, fit: BoxFit.contain),
              ),
            ),
          ),

          // Fixed Bottom Area: Cố định độ cao 360 pixel trên mọi slide.
          // Điều này đảm bảo cụm Dots tĩnh nằm chính xác ở vị trí trống ở trên!
          SizedBox(
            height: 360,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // Title
                Text(
                  slide.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1868F8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  slide.description,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280), // Gray 500
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(),

                // Footer Dynamic Content
                // Ẩn đi ở những trang đầu mà không làm mất khoảng không (Opactiy).
                // Dính chặt IgnorePointer cùng với chỉ mục 'index' đảm bảo slide 1, 2 không bấm lầm được.
                Opacity(
                  opacity: index == 2 ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: index != 2,
                    child: _buildFinalSlideButtons(),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalSlideButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Login Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => context.go('/login'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF1868F8), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'Login',
              style: TextStyle(
                color: Color(0xFF1868F8),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Sign Up Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => context.go('/signup'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF1868F8), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'Sign Up',
              style: TextStyle(
                color: Color(0xFF1868F8),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Continue as Guest Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => context.go(AppRoutes.home),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1868F8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Continue as Guest',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class WelcomeSlide {
  final String image;
  final String title;
  final String description;

  WelcomeSlide({
    required this.image,
    required this.title,
    required this.description,
  });
}
