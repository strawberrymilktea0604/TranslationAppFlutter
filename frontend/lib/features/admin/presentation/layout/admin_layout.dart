import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/router/admin_router.dart';

/// Admin Layout with Sidebar and Topbar
/// Provides a standard dashboard layout for admin interface
class AdminLayout extends StatefulWidget {
  final Widget child;

  const AdminLayout({super.key, required this.child});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  final bool _isSidebarExpanded = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isSmallScreen = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildTopBar(context, colorScheme, textTheme, isSmallScreen),
      drawer: isSmallScreen ? _buildSidebar(context, colorScheme, textTheme) : null,
      body: Row(
        children: [
          // Sidebar - only on large screens
          if (!isSmallScreen)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _isSidebarExpanded ? 280 : 80,
              color: colorScheme.surfaceContainer,
              child: _buildSidebar(context, colorScheme, textTheme),
            ),
          // Main content
          Expanded(
            child: Container(
              color: colorScheme.surface,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the top navigation bar
  PreferredSizeWidget _buildTopBar(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isSmallScreen,
  ) {
    return AppBar(
      elevation: 0.5,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      title: Row(
        children: [
          if (isSmallScreen)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ),
          Text(
            'Admin Dashboard',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
      actions: [
        // Search button
        Tooltip(
          message: 'Tìm kiếm',
          child: IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
        ),
        // Notifications button
        Tooltip(
          message: 'Thông báo',
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  // TODO: Show notifications
                },
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        // User profile menu
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                // TODO: Handle logout
              } else if (value == 'profile') {
                // TODO: Navigate to profile
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 8),
                    Text('Hồ sơ'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined),
                    SizedBox(width: 8),
                    Text('Cài đặt'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Đăng xuất'),
                  ],
                ),
              ),
            ],
            child: Tooltip(
              message: 'Tài khoản',
              child: CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.person,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// Builds the sidebar navigation
  Widget _buildSidebar(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final isSmallScreen = MediaQuery.of(context).size.width < 900;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo / Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colorScheme.primary, colorScheme.primaryContainer],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                if (!isSmallScreen && _isSidebarExpanded) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Admin',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'v1.0',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(),

          // Navigation Items
          _buildNavItem(
            context: context,
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            route: AdminRoutes.dashboard,
            colorScheme: colorScheme,
            textTheme: textTheme,
            isSmallScreen: isSmallScreen,
          ),
          _buildNavItem(
            context: context,
            icon: Icons.people_outline,
            label: 'Người dùng',
            route: AdminRoutes.users,
            colorScheme: colorScheme,
            textTheme: textTheme,
            isSmallScreen: isSmallScreen,
          ),
          _buildNavItem(
            context: context,
            icon: Icons.help_outline_rounded,
            label: 'Ngân hàng câu hỏi',
            route: AdminRoutes.questionBank,
            colorScheme: colorScheme,
            textTheme: textTheme,
            isSmallScreen: isSmallScreen,
          ),
          _buildNavItem(
            context: context,
            icon: Icons.quiz_rounded,
            label: 'Trình soạn bài kiểm tra',
            route: AdminRoutes.quizEditor,
            colorScheme: colorScheme,
            textTheme: textTheme,
            isSmallScreen: isSmallScreen,
          ),
          _buildNavItem(
            context: context,
            icon: Icons.translate_outlined,
            label: 'Dịch vụ',
            route: AdminRoutes.translations,
            colorScheme: colorScheme,
            textTheme: textTheme,
            isSmallScreen: isSmallScreen,
          ),
          _buildNavItem(
            context: context,
            icon: Icons.analytics_outlined,
            label: 'Thống kê',
            route: AdminRoutes.analytics,
            colorScheme: colorScheme,
            textTheme: textTheme,
            isSmallScreen: isSmallScreen,
          ),

          const Divider(),

          // Settings section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Text(
              'Khác',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildNavItem(
            context: context,
            icon: Icons.settings_outlined,
            label: 'Cài đặt',
            route: AdminRoutes.settings,
            colorScheme: colorScheme,
            textTheme: textTheme,
            isSmallScreen: isSmallScreen,
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Builds a navigation item
  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String route,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required bool isSmallScreen,
  }) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final isActive = currentRoute == route;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.go(route);
            if (isSmallScreen) {
              Navigator.of(context).pop(); // Close drawer
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: isActive
                  ? colorScheme.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isActive
                  ? Border(
                      left: BorderSide(
                        color: colorScheme.primary,
                        width: 3,
                      ),
                    )
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  size: 22,
                ),
                if (_isSidebarExpanded && !isSmallScreen) ...[
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: textTheme.bodyMedium?.copyWith(
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
