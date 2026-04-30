import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_state.dart';
import 'package:frontend/core/theme/app_theme.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final isAuth = state is AuthAuthenticated;
        final user = isAuth ? state.user : null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Hồ sơ cá nhân'),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (isAuth)
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Đăng xuất',
                  onPressed: () {
                    context.read<AuthCubit>().logout();
                    context.go('/');
                  },
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: isAuth
                ? _buildAuthView(context, cs, theme, user)
                : _buildGuestView(context, cs, theme),
          ),
        );
      },
    );
  }

  Widget _buildGuestView(BuildContext context, ColorScheme cs, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          CircleAvatar(
            radius: 50,
            backgroundColor: cs.surfaceContainerHighest,
            child: Icon(Icons.person_outline_rounded, size: 50, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Text(
            'Khách',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Đăng nhập để đồng bộ dữ liệu, mở khóa các tính năng giọng nói, hình ảnh và lưu từ vựng.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.push('/login'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Đăng nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.push('/signup'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Đăng ký tài khoản mới', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthView(BuildContext context, ColorScheme cs, ThemeData theme, dynamic user) {
    final name = user?.name ?? 'Người dùng';
    final email = user?.email ?? '';

    return Column(
      children: [
        // User Info Section
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: cs.primaryContainer,
                child: Icon(Icons.person_rounded, size: 50, color: cs.onPrimaryContainer),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  email,
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  context.push('/edit-profile');
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Chỉnh sửa tài khoản'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Settings List
        _buildSectionHeader('Cài đặt ứng dụng', theme),
        _buildListTile(
          context,
          icon: Icons.dark_mode_outlined,
          title: 'Giao diện',
          subtitle: 'Sáng / Tối (Tính năng sắp ra mắt)',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tính năng sắp ra mắt 🚀')),
            );
          },
        ),
        _buildListTile(
          context,
          icon: Icons.sync_rounded,
          title: 'Lịch sử đồng bộ',
          subtitle: 'Trạng thái: Đang trực tuyến (Tính năng sắp ra mắt)',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tính năng sắp ra mắt 🚀')),
            );
          },
        ),
        _buildListTile(
          context,
          icon: Icons.language_rounded,
          title: 'Ngôn ngữ ứng dụng',
          subtitle: 'Tiếng Việt',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tính năng sắp ra mắt 🚀')),
            );
          },
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Bảo mật & Hỗ trợ', theme),
        _buildListTile(
          context,
          icon: Icons.security_rounded,
          title: 'Mật khẩu & Bảo mật',
          onTap: () {
            context.push('/change-password');
          },
        ),
        _buildListTile(
          context,
          icon: Icons.help_outline_rounded,
          title: 'Trợ giúp & Phản hồi',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tính năng sắp ra mắt 🚀')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: cs.primary, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)) : null,
        trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}
