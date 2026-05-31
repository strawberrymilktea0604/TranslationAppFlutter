import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/admin/presentation/layout/admin_layout.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/injection_container.dart';
import 'package:frontend/main.dart';
import 'package:frontend/services/admin_question_bank_service.dart';
import 'package:frontend/services/admin_question_service.dart';

/// Admin Quiz Editor Page
/// Manages questions within question banks: list, create, edit, toggle, delete
class AdminQuizEditorPage extends StatefulWidget {
  final int? initialBankId;

  const AdminQuizEditorPage({super.key, this.initialBankId});

  @override
  State<AdminQuizEditorPage> createState() => _AdminQuizEditorPageState();
}

class _AdminQuizEditorPageState extends State<AdminQuizEditorPage> {
  late AdminQuestionBankService _bankService;
  late AdminQuestionService _questionService;
  final _searchController = TextEditingController();
  String? _accessToken;
  int? _selectedBankId;
  int _currentPage = 1;
  final int _pageSize = 20;
  final bool _includeDeleted = false;
  bool _banksInitialized = false;
  bool _questionsInitialized = false;

  @override
  void initState() {
    super.initState();
    _selectedBankId = widget.initialBankId;
    _initServices();
  }

  Future<void> _initServices() async {
    _bankService = AdminQuestionBankService(baseUrl: config.apiUrl);
    _questionService = AdminQuestionService(baseUrl: config.apiUrl);
    await _loadBanks();
  }

  Future<void> _loadBanks({int page = 1}) async {
    try {
      final token = await sl<AuthLocalDataSource>().getAccessToken();
      if (token == null) throw Exception('Token không tìm thấy. Vui lòng đăng nhập lại.');
      _accessToken = token;

      await _bankService.fetchBanks(
        page: page,
        pageSize: _pageSize,
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        includeDeleted: _includeDeleted,
        accessToken: token,
      );
      if (mounted) {
        setState(() {
          _banksInitialized = true;
          _currentPage = page;
        });
        // If no bank selected yet and we have banks, select the first
        if (_selectedBankId == null && _bankService.banks.isNotEmpty) {
          _selectedBankId = _bankService.banks.first.id;
          _loadQuestions();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _banksInitialized = true);
        _showError(e.toString());
      }
    }
  }

  Future<void> _loadQuestions({int page = 1}) async {
    if (_selectedBankId == null || _accessToken == null) return;
    try {
      await _questionService.fetchQuestions(
        bankId: _selectedBankId!,
        page: page,
        pageSize: _pageSize,
        includeDeleted: _includeDeleted,
        accessToken: _accessToken!,
      );
      if (mounted) {
        setState(() {
          _questionsInitialized = true;
          _currentPage = page;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _questionsInitialized = true);
        _showError(e.toString());
      }
    }
  }

  // ─────────────────── CRUD Helpers ───────────────────

  Future<void> _createQuestion(
    String content,
    Map<String, dynamic> choices,
    String correctAnswer,
  ) async {
    if (_selectedBankId == null || _accessToken == null) return;
    try {
      await _questionService.createQuestion(
        bankId: _selectedBankId!,
        content: content,
        choices: choices,
        correctAnswer: correctAnswer,
        accessToken: _accessToken!,
      );
      if (mounted) {
        setState(() {});
        _showSuccess('Đã tạo câu hỏi mới');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _updateQuestion(
    int questionId,
    String? content,
    Map<String, dynamic>? choices,
    String? correctAnswer,
  ) async {
    if (_accessToken == null) return;
    try {
      await _questionService.updateQuestion(
        questionId: questionId,
        content: content,
        choices: choices,
        correctAnswer: correctAnswer,
        accessToken: _accessToken!,
      );
      if (mounted) {
        setState(() {});
        _showSuccess('Đã cập nhật câu hỏi');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _toggleQuestion(int questionId) async {
    if (_accessToken == null) return;
    try {
      await _questionService.toggleQuestion(
        questionId: questionId,
        accessToken: _accessToken!,
      );
      if (mounted) {
        setState(() {});
        _showSuccess('Đã cập nhật trạng thái câu hỏi');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _deleteQuestion(int questionId) async {
    if (_accessToken == null) return;
    final confirmed = await _showConfirmDialog(
      title: 'Xóa câu hỏi?',
      message: 'Hành động này không thể hoàn tác.',
      confirmLabel: 'Xóa',
      isDanger: true,
    );
    if (confirmed != true) return;
    try {
      await _questionService.deleteQuestion(
        questionId: questionId,
        accessToken: _accessToken!,
      );
      if (mounted) {
        setState(() {});
        _showSuccess('Đã xóa câu hỏi');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  // ─────────────────── Dialogs ───────────────────

  Future<void> _showCreateQuestionDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const _QuestionFormDialog(title: 'Tạo câu hỏi'),
    );
    if (result != null) {
      await _createQuestion(
        result['content'] as String,
        result['choices'] as Map<String, dynamic>,
        result['correct_answer'] as String,
      );
    }
  }

  Future<void> _showEditQuestionDialog(int questionId, String initialContent,
      Map<String, dynamic> initialChoices, String initialCorrectAnswer) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _QuestionFormDialog(
        title: 'Sửa câu hỏi',
        initialContent: initialContent,
        initialChoices: initialChoices,
        initialCorrectAnswer: initialCorrectAnswer,
      ),
    );
    if (result != null) {
      await _updateQuestion(
        questionId,
        result['content'] as String,
        result['choices'] as Map<String, dynamic>,
        result['correct_answer'] as String,
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
        onRefresh: () async {
          await _loadBanks(page: _currentPage);
          if (_selectedBankId != null) {
            await _loadQuestions();
          }
        },
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
                        'Quiz Editor',
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quản lý câu hỏi trong ngân hàng câu hỏi',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedBankId != null)
                    FilledButton.icon(
                      onPressed: _showCreateQuestionDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Thêm câu hỏi'),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Bank Selection ──
              if (_banksInitialized)
                _buildBankSelector(colorScheme, textTheme)
              else
                _buildLoadingState(colorScheme, textTheme),
              const SizedBox(height: 24),

              // ── Questions Content ──
              if (_selectedBankId != null)
                _buildQuestionsContent(colorScheme, textTheme)
              else
                _buildNoBankSelectedState(colorScheme, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme, TextTheme textTheme) {
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

  Widget _buildNoBankSelectedState(ColorScheme colorScheme, TextTheme textTheme) {
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
              'Chọn ngân hàng câu hỏi để bắt đầu',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hãy chọn một ngân hàng từ danh sách bên dưới để xem và quản lý các câu hỏi',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankSelector(ColorScheme colorScheme, TextTheme textTheme) {
    if (_bankService.banks.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.library_books_outlined,
                size: 64,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Chưa có ngân hàng câu hỏi nào',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vui lòng tạo ngân hàng câu hỏi trước',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chọn ngân hàng câu hỏi',
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _bankService.banks.map((bank) {
              final isSelected = _selectedBankId == bank.id;
              return FilterChip(
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedBankId = bank.id;
                      _questionsInitialized = false;
                    });
                    _loadQuestions();
                  }
                },
                label: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      bank.title,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Text(
                      '${bank.questionCount} câu',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                avatar: Icon(
                  bank.isActive ? Icons.check_circle : Icons.pause_circle,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsContent(ColorScheme colorScheme, TextTheme textTheme) {
    // Loading state
    if (!_questionsInitialized || _questionService.isLoading) {
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
                'Đang tải danh sách câu hỏi...',
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
    if (_questionService.error != null && _questionService.questions.isEmpty) {
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
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadQuestions,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state
    if (_questionService.questions.isEmpty) {
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
                Icons.quiz_outlined,
                size: 72,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Chưa có câu hỏi nào',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nhấn "Thêm câu hỏi" để tạo câu hỏi đầu tiên',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _showCreateQuestionDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Thêm câu hỏi'),
              ),
            ],
          ),
        ),
      );
    }

    // Questions table
    return Column(
      children: [
        // Stat cards
        Row(
          children: [
            _StatCard(
              title: 'Tổng câu hỏi',
              value: '${_questionService.totalCount}',
              icon: Icons.quiz_rounded,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 16),
            _StatCard(
              title: 'Đang hoạt động',
              value: '${_questionService.activeCount}',
              icon: Icons.check_circle_rounded,
              color: AppTheme.successColor,
            ),
            const SizedBox(width: 16),
            _StatCard(
              title: 'Đã vô hiệu hóa',
              value: '${_questionService.inactiveCount}',
              icon: Icons.pause_circle_rounded,
              color: AppTheme.warningColor,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Questions list
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            children: _questionService.questions.asMap().entries.map((entry) {
              final q = entry.value;
              return _QuestionRow(
                question: q,
                colorScheme: colorScheme,
                textTheme: textTheme,
                onEdit: () => _showEditQuestionDialog(
                  q.id,
                  q.content,
                  q.choices,
                  q.correctAnswer,
                ),
                onToggle: () => _toggleQuestion(q.id),
                onDelete: () => _deleteQuestion(q.id),
                isLast: entry.key == _questionService.questions.length - 1,
              );
            }).toList(),
          ),
        ),

        // Pagination
        if (_questionService.totalPages > 1) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_questionService.hasPrev)
                FilledButton.icon(
                  onPressed: () => _loadQuestions(page: _currentPage - 1),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                  label: const Text('Trang trước'),
                ),
              const SizedBox(width: 16),
              Text(
                'Trang ${_questionService.currentPage}/${_questionService.totalPages}',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(width: 16),
              if (_questionService.hasNext)
                FilledButton.icon(
                  onPressed: () => _loadQuestions(page: _currentPage + 1),
                  label: const Text('Trang sau'),
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Widget for a single question row in the list
class _QuestionRow extends StatelessWidget {
  final AdminQuestion question;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final bool isLast;

  const _QuestionRow({
    required this.question,
    required this.colorScheme,
    required this.textTheme,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question content header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Câu ${question.id}',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    question.isActive ? 'Đang hoạt động' : 'Vô hiệu hóa',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: question.isActive
                      ? AppTheme.successColor.withValues(alpha: 0.15)
                      : AppTheme.warningColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: question.isActive
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Question content
            Text(
              question.content,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Choices
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: question.choiceKeys.map((key) {
                final choice = question.getChoice(key) ?? '';
                final isCorrect = key == question.correctAnswer;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? AppTheme.successColor.withValues(alpha: 0.15)
                        : colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: isCorrect
                          ? AppTheme.successColor
                          : colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        key,
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isCorrect ? AppTheme.successColor : null,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        choice,
                        style: textTheme.bodySmall?.copyWith(
                          color: isCorrect ? AppTheme.successColor : null,
                        ),
                      ),
                      if (isCorrect) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: AppTheme.successColor,
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Sửa'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                    question.isActive ? Icons.pause_circle_outline : Icons.check_circle_outline,
                    size: 16,
                  ),
                  label: Text(question.isActive ? 'Vô hiệu hóa' : 'Kích hoạt'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Xóa'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for creating/editing questions
class _QuestionFormDialog extends StatefulWidget {
  final String title;
  final String? initialContent;
  final Map<String, dynamic>? initialChoices;
  final String? initialCorrectAnswer;

  const _QuestionFormDialog({
    required this.title,
    this.initialContent,
    this.initialChoices,
    this.initialCorrectAnswer,
  });

  @override
  State<_QuestionFormDialog> createState() => _QuestionFormDialogState();
}

class _QuestionFormDialogState extends State<_QuestionFormDialog> {
  late TextEditingController _contentController;
  late Map<String, TextEditingController> _choiceControllers;
  String? _selectedCorrectAnswer;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialContent ?? '');

    // Initialize choice controllers
    _choiceControllers = {};
    const defaultChoices = {'A': '', 'B': '', 'C': '', 'D': ''};
    final choices = widget.initialChoices ?? defaultChoices;

    choices.forEach((key, value) {
      _choiceControllers[key] = TextEditingController(text: value.toString());
    });

    _selectedCorrectAnswer = widget.initialCorrectAnswer;
  }

  @override
  void dispose() {
    _contentController.dispose();
    _choiceControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // Validate that all choices are filled
    final choices = <String, dynamic>{};
    for (final entry in _choiceControllers.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng điền đầy đủ tất cả các đáp án')),
        );
        return;
      }
      choices[entry.key] = value;
    }

    if (_selectedCorrectAnswer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn đáp án đúng')),
      );
      return;
    }

    Navigator.pop(context, {
      'content': _contentController.text.trim(),
      'choices': choices,
      'correct_answer': _selectedCorrectAnswer,
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Content field
                Text(
                  'Nội dung câu hỏi *',
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _contentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Nhập nội dung câu hỏi...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nội dung câu hỏi không được trống';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Choices
                Text(
                  'Danh sách đáp án *',
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ..._choiceControllers.entries.map((entry) {
                  final key = entry.key;
                  final controller = entry.value;
                  final isCorrect = _selectedCorrectAnswer == key;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 50,
                          child: Radio<String>(
                            value: key,
                            // ignore: deprecated_member_use
                            groupValue: _selectedCorrectAnswer,
                            // ignore: deprecated_member_use
                            onChanged: (value) {
                              setState(() => _selectedCorrectAnswer = value);
                            },
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: controller,
                            decoration: InputDecoration(
                              labelText: 'Đáp án $key',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              suffixIcon: isCorrect
                                  ? Icon(
                                      Icons.check_circle,
                                      color: colorScheme.primary,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _submit,
                      child: const Text('Lưu'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stat card for statistics display
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
