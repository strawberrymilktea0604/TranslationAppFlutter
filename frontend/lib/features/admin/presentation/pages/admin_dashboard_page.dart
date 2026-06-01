import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/admin/presentation/layout/admin_layout.dart';
import 'package:frontend/services/admin_dashboard_service.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/injection_container.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/core/error/api_error_handler.dart';
import 'package:http/http.dart' as http;

/// Admin Dashboard Page
/// Main dashboard showing system overview and statistics
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late AdminDashboardService _dashboardService;

  @override
  void initState() {
    super.initState();
    final client = sl.isRegistered<http.Client>() ? sl<http.Client>() : null;
    _dashboardService = AdminDashboardService(client: client);
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final token = await sl<AuthLocalDataSource>().getAccessToken();
      if (mounted && token != null) {
        await _dashboardService.fetchStats(accessToken: token);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi: Token không tìm thấy. Vui lòng đăng nhập lại.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isAuthError = ApiErrorHandler.isAuthError(e);
        final errorMessage = ApiErrorHandler.formatErrorMessage(e);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: isAuthError ? Colors.red : Colors.red.shade600,
          ),
        );

        // If auth error, redirect to login
        if (isAuthError) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              context.read<AuthCubit>().logout();
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _dashboardService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      child: ListenableBuilder(
        listenable: _dashboardService,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Dashboard',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Tổng quan hệ thống',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Error or Stats
              if (_dashboardService.error != null)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _dashboardService.error ?? 'Unknown error',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_dashboardService.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(),
                )
              else
                _buildStatsGrid(context),

              // Recent Activity Section
              const SizedBox(height: 32),
              Text(
                'Hoạt động gần đây',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildActivityList(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    final stats = _dashboardService.stats;
    if (stats == null) return const SizedBox.shrink();

    return GridView.count(
      crossAxisCount: _getGridCount(context),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildStatCard(
          context,
          title: 'Tổng người dùng',
          value: stats.totalUsers.toString(),
          icon: Icons.people,
          color: Colors.blue,
        ),
        _buildStatCard(
          context,
          title: 'Tổng dịch',
          value: stats.totalTranslations.toString(),
          icon: Icons.translate,
          color: Colors.green,
        ),
        _buildStatCard(
          context,
          title: 'Dung lượng sử dụng',
          value: stats.storageUsed,
          icon: Icons.storage,
          color: Colors.orange,
        ),
        _buildStatCard(
          context,
          title: 'Hoạt động',
          value: '${stats.uptime.toStringAsFixed(1)}%',
          icon: Icons.trending_up,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildActivityList(BuildContext context) {
    final stats = _dashboardService.stats;
    if (stats == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: stats.recentActivity.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final activity = stats.recentActivity[index];
          final now = DateTime.now();
          final diff = now.difference(activity.timestamp);

          String timeago;
          if (diff.inMinutes < 1) {
            timeago = 'vừa xong';
          } else if (diff.inMinutes < 60) {
            timeago = '${diff.inMinutes} phút trước';
          } else if (diff.inHours < 24) {
            timeago = '${diff.inHours} giờ trước';
          } else {
            timeago = '${diff.inDays} ngày trước';
          }

          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                _getActivityIcon(activity.type),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(activity.message),
            subtitle: Text(timeago),
            trailing: Text(
              activity.username,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        },
      ),
    );
  }


  int _getGridCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 1;
    if (width < 900) return 2;
    return 4;
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'user_signup':
        return Icons.person_add;
      case 'translation':
        return Icons.translate;
      case 'quiz_created':
        return Icons.quiz;
      case 'user_login':
        return Icons.login;
      case 'user_banned':
        return Icons.block;
      default:
        return Icons.info;
    }
  }
}
