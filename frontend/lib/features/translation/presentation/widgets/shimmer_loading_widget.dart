import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Reusable shimmer loading widget for the translation result area.
///
/// Displays animated placeholder lines that mimic the appearance
/// of translated text, providing visual feedback while waiting
/// for the translation API response.
class ShimmerTranslationLoading extends StatelessWidget {
  /// Number of shimmer lines to display.
  final int lineCount;

  /// Whether to use compact mode (smaller lines, for quick translate).
  final bool compact;

  const ShimmerTranslationLoading({
    super.key,
    this.lineCount = 4,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark
        ? cs.surfaceContainerHighest
        : cs.primary.withValues(alpha: 0.08);
    final highlightColor = isDark
        ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
        : cs.primary.withValues(alpha: 0.18);

    final lineHeight = compact ? 10.0 : 14.0;
    final lineSpacing = compact ? 8.0 : 12.0;
    final borderRadius = compact ? 5.0 : 8.0;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1500),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(lineCount, (index) {
          // Vary line widths for realistic appearance.
          // Last line is shorter, middle lines are full width.
          final double widthFactor;
          if (index == lineCount - 1) {
            widthFactor = 0.45;
          } else if (index == lineCount - 2 && lineCount > 2) {
            widthFactor = 0.75;
          } else {
            widthFactor = 1.0;
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: index < lineCount - 1 ? lineSpacing : 0,
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: widthFactor,
              child: Container(
                height: lineHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Compact shimmer for inline/quick translate loading.
/// Shows a subtle progress indication in a smaller space.
class ShimmerTranslationLoadingCompact extends StatelessWidget {
  const ShimmerTranslationLoadingCompact({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 12),
      child: ShimmerTranslationLoading(lineCount: 2, compact: true),
    );
  }
}
