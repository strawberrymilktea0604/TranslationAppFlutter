import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/admin/presentation/layout/admin_layout.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/injection_container.dart';
import 'package:frontend/main.dart';
import 'package:frontend/services/admin_question_bank_service.dart';

/// Admin Question Bank Management Page
/// Full CRUD for question banks: list, create, edit, toggle active, delete
class AdminQuestionBankPage extends StatefulWidget {
  const AdminQuestionBankPage({super.key});

  @override
  State<AdminQuestionBankPage> createState() => _AdminQuestionBankPageState();
}

class _AdminQuestionBankPageState extends State<AdminQuestionBankPage> {
  late AdminQuestionBankService _service;
  final _searchController = TextEditingController();
  String? _accessToken;
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _includeDeleted = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    _service = AdminQuestionBankService(baseUrl: config.apiUrl);
    await _loadBanks();
  }

  Future<void> _loadBanks({int page = 1}) async {
    try {
      final token = await sl<AuthLocalDataSource>().getAccessToken();
      if (token == null) throw Exception('Token không tìm thấy. Vui lòng đăng nhập lại.');
      _accessToken = token;

      await _service.fetchBanks(
        page: page,
        pageSize: _pageSize,
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        includeDeleted: _includeDeleted,
        accessToken: token,
      );
      if (mounted) setState(() => _currentPage = page);
    } catch (e) {
      if (mounted) {
        setState(() {});
        _showError(e.toString());
      }
    } finally {
      if (mounted) setState(() => _initialized = true);
    }
  }

  // ─────────────────── CRUD Helpers ───────────────────

  Future<void> _createBank(String title, String? description, int? duration) async {
    if (_accessToken == null) return;
    try {
      await _service.createBank(
        title: title,
        description: description,
        durationMinutes: duration,
        accessToken: _accessToken!,
      );
      if (mounted) {
        setState(() {});
        _showSuccess('Đã tạo ngân hàng câu hỏi "$title"');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _updateBank(int id, String title, String? description, int? duration) async {
    if (_accessToken == null) return;
    try {
      await _service.updateBank(
        bankId: id,
        title: title,
        description: description,
        durationMinutes: duration,
        accessToken: _accessToken!,
      );
      if (mounted) {
        setState(() {});
        _showSuccess('Đã cập nhật ngân hàng câu hỏi');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _toggleBank(AdminQuestionBank bank) async {
    if (_accessToken == null) return;
    try {
      await _service.toggleBank(bankId: bank.id, accessToken: _accessToken!);
      if (mounted) {
        setState(() {});
        final action = bank.isActive ? 'vô hiệu hóa' : 'kích hoạt';
        _showSuccess('Đã $action "${bank.title}"');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _deleteBank(AdminQuestionBank bank) async {
    if (_accessToken == null) return;
    final confirmed = await _showConfirmDialog(
      title: 'Xóa ngân hàng câu hỏi?',
      message: 'Ngân hàng "${bank.title}" sẽ bị xóa. Hành động này không thể hoàn tác.',
      confirmLabel: 'Xóa',
      isDanger: true,
    );
    if (confirmed != true) return;
    try {
      await _service.deleteBank(bankId: bank.id, accessToken: _accessToken!);
      if (mounted) {
        setState(() {});
        _showSuccess('Đã xóa "${bank.title}"');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  // ─────────────────── Dialogs ───────────────────

  Future<void> _showCreateDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _QuestionBankFormDialog(title: 'Tạo ngân hàng câu hỏi'),
    );
    if (result != null) {
      await _createBank(
        result['title'] as String,
        result['description'] as String?,
        result['duration'] as int?,
      );
    }
  }

  Future<void> _showEditDialog(AdminQuestionBank bank) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _QuestionBankFormDialog(
        title: 'Sửa ngân hàng câu hỏi',
        initialTitle: bank.title,
        initialDescription: bank.description,
        initialDuration: bank.durationMinutes,
      ),
    );
    if (result != null) {
      await _updateBank(
        bank.id,
        result['title'] as String,
        result['description'] as String?,
        result['duration'] as int?,
      );
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    String confirmLabel = 'Xác nhận',
    bool isDanger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: isDanger
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  // ─────────────────── Snackbars ───────────────────

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Handle auth errors
    final isAuthError = msg.contains('Unauthorized') || msg.contains('Forbidden');
    if (isAuthError) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          context.read<AuthCubit>().logout();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─────────────────── Build ───────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AdminLayout(
      child: RefreshIndicator(
        onRefresh: () => _loadBanks(page: _currentPage),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ngân hàng câu hỏi',
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quản lý danh sách ngân hàng câu hỏi và cấu hình',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Tạo mới'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Stat Cards ──
              if (_initialized) _buildStatCards(colorScheme, textTheme),
              if (_initialized) const SizedBox(height: 24),

              // ── Search & Filters ──
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm theo tiêu đề...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadBanks(page: 1);
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
                      onSubmitted: (_) => _loadBanks(page: 1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: const Text('Bao gồm đã ẩn'),
                    selected: _includeDeleted,
                    onSelected: (v) {
                      setState(() => _includeDeleted = v);
                      _loadBanks(page: 1);
                    },
                    avatar: Icon(
                      _includeDeleted ? Icons.visibility : Icons.visibility_off,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _loadBanks(page: 1),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Tìm kiếm'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Banks List / Loading / Empty / Error ──
              _buildContent(colorScheme, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCards(ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      children: [
        _StatCard(
          title: 'Tổng số',
          value: '${_service.totalCount}',
          icon: Icons.library_books_rounded,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 16),
        _StatCard(
          title: 'Đang hoạt động',
          value: '${_service.banks.where((b) => b.isActive).length}',
          icon: Icons.check_circle_rounded,
          color: AppTheme.successColor,
        ),
        const SizedBox(width: 16),
        _StatCard(
          title: 'Đã vô hiệu hóa',
          value: '${_service.banks.where((b) => !b.isActive).length}',
          icon: Icons.pause_circle_rounded,
          color: AppTheme.warningColor,
        ),
      ],
    );
  }

  Widget _buildContent(ColorScheme colorScheme, TextTheme textTheme) {
    // Loading state
    if (!_initialized || _service.isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(64),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Đang tải danh sách ngân hàng câu hỏi...',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Error state
    if (_service.error != null && _service.banks.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Không thể tải dữ liệu',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _service.error ?? 'Đã xảy ra lỗi không xác định',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _loadBanks(page: _currentPage),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state
    if (_service.banks.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(64),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.library_books_outlined,
                size: 72,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isNotEmpty
                    ? 'Không tìm thấy kết quả'
                    : 'Chưa có ngân hàng câu hỏi nào',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchController.text.isNotEmpty
                    ? 'Thử tìm kiếm với từ khóa khác'
                    : 'Nhấn "Tạo mới" để thêm ngân hàng câu hỏi đầu tiên',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tạo ngân hàng câu hỏi'),
              ),
            ],
          ),
        ),
      );
    }

    // Data table
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              // Table header
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Tiêu đề',
                        style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Mô tả',
                        style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Thời lượng',
                        style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Số câu hỏi',
                        style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Trạng thái',
                        style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 60),
                  ],
                ),
              ),
              // Table rows
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _service.banks.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: colorScheme.outlineVariant,
                ),
                itemBuilder: (context, index) {
                  return _buildBankRow(context, _service.banks[index]);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Pagination
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Trang $_currentPage / ${_service.totalPages} — ${_service.totalCount} kết quả',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: _currentPage > 1 ? () => _loadBanks(page: _currentPage - 1) : null,
                  child: const Text('Trước'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _currentPage < _service.totalPages
                      ? () => _loadBanks(page: _currentPage + 1)
                      : null,
                  child: const Text('Tiếp'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBankRow(BuildContext context, AdminQuestionBank bank) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => _showEditDialog(bank),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Title
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bank.title,
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'ID: ${bank.id}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            // Description
            Expanded(
              flex: 2,
              child: Text(
                bank.description ?? '—',
                style: textTheme.bodySmall?.copyWith(
                  color: bank.description != null
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Duration
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      bank.durationLabel,
                      style: textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Question count
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.quiz_rounded,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${bank.questionCount}',
                    style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            // Status badge
            Expanded(
              child: _StatusBadge(isActive: bank.isActive),
            ),
            // Actions
            SizedBox(
              width: 60,
              child: PopupMenuButton<String>(
                tooltip: 'Tùy chọn',
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text('Chỉnh sửa'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          bank.isActive
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                          size: 18,
                          color: bank.isActive ? AppTheme.warningColor : AppTheme.successColor,
                        ),
                        const SizedBox(width: 8),
                        Text(bank.isActive ? 'Vô hiệu hóa' : 'Kích hoạt'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Xóa',
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showEditDialog(bank);
                    case 'toggle':
                      _toggleBank(bank);
                    case 'delete':
                      _deleteBank(bank);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Form Dialog
// ═══════════════════════════════════════════════════════

class _QuestionBankFormDialog extends StatefulWidget {
  final String title;
  final String? initialTitle;
  final String? initialDescription;
  final int? initialDuration;

  const _QuestionBankFormDialog({
    required this.title,
    this.initialTitle,
    this.initialDescription,
    this.initialDuration,
  });

  @override
  State<_QuestionBankFormDialog> createState() => _QuestionBankFormDialogState();
}

class _QuestionBankFormDialogState extends State<_QuestionBankFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _durationController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _descriptionController = TextEditingController(text: widget.initialDescription ?? '');
    _durationController = TextEditingController(
      text: widget.initialDuration != null ? '${widget.initialDuration}' : '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final durationText = _durationController.text.trim();
    final duration = durationText.isNotEmpty ? int.tryParse(durationText) : null;

    Navigator.pop(context, {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'duration': duration,
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.library_books_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Title field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Tiêu đề *',
                  hintText: 'Nhập tiêu đề ngân hàng câu hỏi',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Tiêu đề không được để trống';
                  if (v.trim().length < 3) return 'Tiêu đề phải có ít nhất 3 ký tự';
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Description field
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Mô tả',
                  hintText: 'Nhập mô tả (tùy chọn)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.description_outlined),
                ),
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Duration field
              TextFormField(
                controller: _durationController,
                decoration: InputDecoration(
                  labelText: 'Thời lượng làm bài (phút)',
                  hintText: 'Để trống = không giới hạn',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.timer_outlined),
                  suffixText: 'phút',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Thời lượng phải là số dương';
                  if (n > 300) return 'Thời lượng tối đa là 300 phút';
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(widget.initialTitle != null ? 'Lưu thay đổi' : 'Tạo mới'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Status Badge Widget
// ═══════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.successColor : AppTheme.warningColor;
    final label = isActive ? 'Hoạt động' : 'Vô hiệu';
    final icon = isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Stat Card Widget
// ═══════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
