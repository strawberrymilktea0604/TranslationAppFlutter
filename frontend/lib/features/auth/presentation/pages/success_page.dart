import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Success page — displayed after successful sign up or login.
///
/// Shows a success message with the "你好" image and a continue button
/// that navigates to the home page.
class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 80),

                // "你好" image
                Image.asset(
                  'images/nihao.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 40),

                // "Successful" text
                const Text(
                  'Successfull',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Description
                const Text(
                  'Type, speak, or scan to start translating!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => context.go('/home'),
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
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
