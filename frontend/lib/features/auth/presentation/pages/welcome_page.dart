import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Welcome/Onboarding page — introduces app features to first-time users.
///
/// Features:
/// - 3 slides with swipe navigation
/// - Dot indicators (gray -> blue on swipe)
/// - Skip button to proceed directly to login
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

  void _goToSlide(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // PageView for slides
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: _slides
                .map((slide) => WelcomeSlideWidget(slide: slide))
                .toList(),
          ),
          // Skip button (top right)
          Positioned(
            top: 48,
            right: 20,
            child: GestureDetector(
              onTap: () => context.go('/login'),
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // Dot indicators (bottom)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? const Color(0xFF2563EB)
                          : Colors.grey[300],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Navigation buttons (bottom)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _slides.length - 1) {
                        _goToSlide(_currentPage + 1);
                      } else {
                        context.go('/login');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Swipe hint
                Text(
                  _currentPage < _slides.length - 1
                      ? 'Swipe left to continue'
                      : 'Ready to get started?',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Data model for welcome slide
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

/// Widget to display a single welcome slide
class WelcomeSlideWidget extends StatelessWidget {
  final WelcomeSlide slide;

  const WelcomeSlideWidget({
    required this.slide,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Image
            Image.asset(
              slide.image,
              height: 300,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 40),
            // Title
            Text(
              slide.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2563EB),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Description
            Text(
              slide.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
