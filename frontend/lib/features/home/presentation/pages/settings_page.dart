import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_state.dart';

/// Placeholder page for the Settings tab.
///
/// Displays current user information from [AuthCubit]
/// and provides a logout action.
/// Actual settings options (language, theme, sync, etc.)
/// will be implemented in future tasks.
class SettingsPlaceholderPage extends StatelessWidget {
  const SettingsPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
        centerTitle: true,
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // User info card
              Card(
                elevation: 0,
                color: colorScheme.primaryContainer
                    .withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: colorScheme.primary,
                        child: Icon(
                          Icons.person,
                          color: colorScheme.onPrimary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getUserName(state),
                              style: textTheme.titleMedium
                                  ?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getUserEmail(state),
                              style: textTheme.bodySmall
                                  ?.copyWith(
                                color: colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Placeholder settings items
              _SettingsTile(
                icon: Icons.language,
                title: 'Ngôn ngữ ứng dụng',
                subtitle: 'Tiếng Việt',
                onTap: () {
                  // TODO: Implement language selection
                },
              ),
              _SettingsTile(
                icon: Icons.dark_mode_outlined,
                title: 'Giao diện',
                subtitle: 'Theo hệ thống',
                onTap: () {
                  // TODO: Implement theme selection
                },
              ),
              _SettingsTile(
                icon: Icons.sync,
                title: 'Đồng bộ dữ liệu',
                subtitle: 'Tự động khi có mạng',
                onTap: () {
                  // TODO: Implement sync settings
                },
              ),
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'Về ứng dụng',
                subtitle: 'Phiên bản 1.0.0',
                onTap: () {
                  // TODO: Implement about page
                },
              ),

              const SizedBox(height: 32),

              // Logout button
              FilledButton.tonal(
                onPressed: () {
                  context.read<AuthCubit>().logout();
                },
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: colorScheme.errorContainer,
                  foregroundColor:
                      colorScheme.onErrorContainer,
                ),
                child: const Text('Đăng xuất'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getUserName(AuthState state) {
    if (state is AuthAuthenticated) {
      return state.user.name ?? 'Người dùng';
    }
    return 'Người dùng';
  }

  String _getUserEmail(AuthState state) {
    if (state is AuthAuthenticated) {
      return state.user.email;
    }
    return '';
  }
}

/// Reusable settings list tile widget.
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onTap: onTap,
    );
  }
}
