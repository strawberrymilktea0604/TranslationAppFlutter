import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/router/app_router.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_state.dart';
import 'package:frontend/features/translation/presentation/widgets/translation_widgets.dart';

class AuthenticatedHomeMockupPage extends StatelessWidget {
  const AuthenticatedHomeMockupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          context.go(AppRoutes.login);
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                expandedHeight: 80,
                flexibleSpace: FlexibleSpaceBar(
                  background: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.primaryColor.withValues(
                            alpha: 0.2,
                          ),
                          child: const Text(
                            'MT',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chào buổi sáng,',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                'Minh Trí',
                                style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.notifications_none),
                          color: colorScheme.onSurface,
                          onPressed: () {},
                        ),
                        IconButton(
                          tooltip: 'Đăng xuất',
                          icon: const Icon(Icons.logout_rounded),
                          color: Colors.red[400],
                          onPressed: () => _confirmLogout(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context,
                              icon: Icons.translate,
                              title: 'Bản dịch',
                              value: '1,248',
                              color: const Color(0xFF1868F8),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              icon: Icons.book,
                              title: 'Từ vựng',
                              value: '342',
                              color: const Color(0xFF4CAF50),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              icon: Icons.local_fire_department,
                              title: 'Chuỗi ngày',
                              value: '14',
                              color: const Color(0xFFFF9800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Quick Translate — shared widget (same as guest home)
                      Text(
                        'Dịch Nhanh',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const QuickTranslateWidget(isAuthenticated: true),
                      const SizedBox(height: 32),

                      // Recent History
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Lịch sử gần đây',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('Xem tất cả'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildHistoryItem(
                        context,
                        sourceText: 'Good morning, how are you?',
                        translatedText: 'Chào buổi sáng, bạn khỏe không?',
                        sourceLang: 'EN',
                        targetLang: 'VI',
                      ),
                      const SizedBox(height: 12),
                      _buildHistoryItem(
                        context,
                        sourceText: 'I would like to order a coffee.',
                        translatedText: 'Tôi muốn gọi một tách cà phê.',
                        sourceLang: 'EN',
                        targetLang: 'VI',
                      ),
                      const SizedBox(height: 12),
                      _buildHistoryItem(
                        context,
                        sourceText: 'Cảm ơn bạn rất nhiều!',
                        translatedText: 'Thank you very much!',
                        sourceLang: 'VI',
                        targetLang: 'EN',
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(
    BuildContext context, {
    required String sourceText,
    required String translatedText,
    required String sourceLang,
    required String targetLang,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$sourceLang → $targetLang',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.bookmark_border, size: 20, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            sourceText,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            translatedText,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.primaryColor),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    final authCubit = context.read<AuthCubit>();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 36),
        title: const Text(
          'Đăng xuất?',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bạn có chắc muốn đăng xuất không?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: const Size(110, 44),
            ),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              authCubit.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: const Size(110, 44),
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}
