import 'package:flutter/material.dart';
import 'package:frontend/main.dart';
import 'package:frontend/features/admin/presentation/layout/admin_layout.dart';
import 'package:frontend/services/admin_users_service.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_state.dart';
import 'package:frontend/injection_container.dart';

/// Admin Users Management Page
/// Displays and manages all application users
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  late AdminUsersService _usersService;
  final _searchController = TextEditingController();
  String? _accessToken;
  int _currentPage = 1;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  /// Initialize service
  Future<void> _initializeService() async {
    final apiUrl = config.apiUrl;
    _usersService = AdminUsersService(baseUrl: apiUrl);
    await _loadUsers();
  }

  /// Load users from API
  Future<void> _loadUsers({int page = 1}) async {
    try {
      final token = await sl<AuthLocalDataSource>().getAccessToken();
      if (token == null) {
        throw Exception('Token not found in local storage. Please login again.');
      }
      _accessToken = token;
      
      await _usersService.fetchUsers(
        page: page,
        pageSize: _pageSize,
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        accessToken: _accessToken, 
      );
      setState(() => _currentPage = page);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Ban a user
  Future<void> _banUser(AdminUser user) async {
    if (_accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lỗi: Không có quyền truy cập. Vui lòng đăng nhập lại.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _usersService.banUser(user.id, _accessToken!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã khóa tài khoản ${user.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Unban a user
  Future<void> _unbanUser(AdminUser user) async {
    if (_accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lỗi: Không có quyền truy cập. Vui lòng đăng nhập lại.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _usersService.unbanUser(user.id, _accessToken!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã mở khóa tài khoản ${user.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      child: RefreshIndicator(
        onRefresh: () => _loadUsers(page: _currentPage),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quản lý Người dùng',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Quản lý tài khoản và quyền truy cập người dùng',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Add new user dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tính năng thêm người dùng sắp được cập nhật')),
                      );
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Thêm người dùng'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Filters and Search
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm theo tên, email...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _loadUsers(page: 1);
                          },
                        )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _loadUsers(page: 1),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: () => _loadUsers(page: 1),
                    icon: const Icon(Icons.search),
                    label: const Text('Tìm kiếm'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Users Table or Empty State or Loading
              _buildUsersList(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build users list, loading, or empty state
  Widget _buildUsersList() {
    // Loading state
    if (_usersService.isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Đang tải danh sách người dùng...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    // Empty state
    if (_usersService.users.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Không tìm thấy người dùng',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _searchController.text.isNotEmpty
                    ? 'Thử tìm kiếm với từ khóa khác'
                    : 'Chưa có người dùng nào trong hệ thống',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Users table
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Tên',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Email',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Vai trò',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Trạng thái',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                        'Hành động',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              // Table Rows
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _usersService.users.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                itemBuilder: (context, index) {
                  return _buildUserRow(context, _usersService.users[index]);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Pagination info and controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Trang $_currentPage - ${_usersService.users.length} trên ${_usersService.totalCount} người dùng',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Row(
              children: [
                if (_currentPage > 1)
                  FilledButton.tonal(
                    onPressed: () => _loadUsers(page: _currentPage - 1),
                    child: const Text('Trước'),
                  )
                else
                  FilledButton.tonal(
                    onPressed: null,
                    child: const Text('Trước'),
                  ),
                const SizedBox(width: 8),
                if (_currentPage * _pageSize < _usersService.totalCount)
                  FilledButton.tonal(
                    onPressed: () => _loadUsers(page: _currentPage + 1),
                    child: const Text('Tiếp'),
                  )
                else
                  FilledButton.tonal(
                    onPressed: null,
                    child: const Text('Tiếp'),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserRow(BuildContext context, AdminUser user) {
    String? currentUserId;
    final authState = sl<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      currentUserId = authState.user.id;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: user.avatarUrl == null
                      ? Text(user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : 'U')
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              user.email,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Chip(
              label: Text(
                user.role == 'admin' ? 'Admin' : 'Người dùng',
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.1),
              labelStyle: TextStyle(
                color: _getRoleColor(user.role),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Chip(
              label: Text(
                user.isBanned ? 'Đã khóa' : 'Hoạt động',
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: _getStatusColor(user.isBanned).withValues(alpha: 0.1),
              labelStyle: TextStyle(
                color: _getStatusColor(user.isBanned),
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user.id.toString() != currentUserId) ...[
                  if (user.isBanned)
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      onPressed: () => _showConfirmDialog(
                        context,
                        'Mở khóa người dùng?',
                        'Người dùng ${user.displayName} sẽ có thể đăng nhập lại.',
                        () => _unbanUser(user),
                      ),
                      tooltip: 'Mở khóa',
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.block, size: 20),
                      onPressed: () => _showConfirmDialog(
                        context,
                        'Khóa người dùng?',
                        'Người dùng ${user.displayName} sẽ không thể đăng nhập.',
                        () => _banUser(user),
                      ),
                      tooltip: 'Khóa',
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show confirmation dialog
  Future<void> _showConfirmDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      onConfirm();
    }
  }

  /// Get color for role badge
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  /// Get color for status badge
  Color _getStatusColor(bool isBanned) {
    return isBanned ? Colors.red : Colors.green;
  }
}
