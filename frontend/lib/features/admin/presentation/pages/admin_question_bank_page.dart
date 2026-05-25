import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/admin/presentation/layout/admin_layout.dart';

/// Admin Question Bank Management Page
/// Manages learning questions and answer options
class AdminQuestionBankPage extends StatefulWidget {
  const AdminQuestionBankPage({super.key});

  @override
  State<AdminQuestionBankPage> createState() => _AdminQuestionBankPageState();
}

class _AdminQuestionBankPageState extends State<AdminQuestionBankPage> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedLanguage = 'All';

  // Placeholder data
  final List<Map<String, String>> _questions = [
    {
      'id': 'Q001',
      'question': 'What is the capital of France?',
      'category': 'Geography',
      'language': 'English',
      'difficulty': 'Easy',
      'answers': '4',
      'status': 'Published'
    },
    {
      'id': 'Q002',
      'question': '法国的首都是什么?',
      'category': 'Geography',
      'language': 'Chinese',
      'difficulty': 'Easy',
      'answers': '4',
      'status': 'Published'
    },
    {
      'id': 'Q003',
      'question': 'Which planet is known as the Red Planet?',
      'category': 'Science',
      'language': 'English',
      'difficulty': 'Medium',
      'answers': '4',
      'status': 'Draft'
    },
    {
      'id': 'Q004',
      'question': '哪个国家位于东南亚?',
      'category': 'Geography',
      'language': 'Chinese',
      'difficulty': 'Medium',
      'answers': '4',
      'status': 'Published'
    },
    {
      'id': 'Q005',
      'question': 'What is 15 + 27?',
      'category': 'Mathematics',
      'language': 'English',
      'difficulty': 'Easy',
      'answers': '4',
      'status': 'Published'
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AdminLayout(
      child: SingleChildScrollView(
        child: Padding(
        padding: const EdgeInsets.all(24),
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
                      'Question Bank Management',
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage learning questions and answer options',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () {
                    // TODO: Open create question dialog
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New Question'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filters & Search
            Row(
              children: [
                // Search field
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search questions...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Category filter
                Expanded(
                  child: DropdownMenu<String>(
                    initialSelection: _selectedCategory,
                    onSelected: (value) {
                      setState(() => _selectedCategory = value ?? 'All');
                    },
                    dropdownMenuEntries: [
                      'All',
                      'Geography',
                      'Science',
                      'Mathematics',
                      'Language'
                    ].map((category) {
                      return DropdownMenuEntry(
                        value: category,
                        label: category,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 12),

                // Language filter
                Expanded(
                  child: DropdownMenu<String>(
                    initialSelection: _selectedLanguage,
                    onSelected: (value) {
                      setState(() => _selectedLanguage = value ?? 'All');
                    },
                    dropdownMenuEntries: [
                      'All',
                      'English',
                      'Chinese',
                      'Vietnamese'
                    ].map((language) {
                      return DropdownMenuEntry(
                        value: language,
                        label: language,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Statistics cards
            Row(
              children: [
                _StatCard(
                  title: 'Total Questions',
                  value: '${_questions.length}',
                  color: AppTheme.primaryColor,
                  icon: Icons.help_outline_rounded,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  title: 'Published',
                  value: '${_questions.where((q) => q['status'] == 'Published').length}',
                  color: AppTheme.successColor,
                  icon: Icons.check_circle_outline_rounded,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  title: 'Drafts',
                  value: '${_questions.where((q) => q['status'] == 'Draft').length}',
                  color: AppTheme.warningColor,
                  icon: Icons.edit_note_rounded,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Questions Table
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Checkbox(
                            value: false,
                            onChanged: (_) {},
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Question',
                            style: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Category',
                            style: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Language',
                            style: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Difficulty',
                            style: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Status',
                            style: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 60),
                      ],
                    ),
                  ),

                  // Table rows
                  ..._questions.map((question) {
                    return _QuestionRow(
                      question: question,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

class _QuestionRow extends StatelessWidget {
  final Map<String, String> question;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _QuestionRow({
    required this.question,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final isPublished = question['status'] == 'Published';

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Open question editor
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Checkbox(
                  value: false,
                  onChanged: (_) {},
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question['id'] ?? '',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      question['question'] ?? '',
                      style: textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  question['category'] ?? '',
                  style: textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: Text(
                  question['language'] ?? '',
                  style: textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: _DifficultyChip(difficulty: question['difficulty'] ?? ''),
              ),
              Expanded(
                child: Chip(
                  label: Text(question['status'] ?? ''),
                  backgroundColor: isPublished
                      ? AppTheme.successColor.withValues(alpha: 0.15)
                      : AppTheme.warningColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: isPublished
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                      onTap: () {
                        // TODO: Edit question
                      },
                    ),
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                      onTap: () {
                        // TODO: Delete question
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final String difficulty;

  const _DifficultyChip({required this.difficulty});

  Color _getDifficultyColor() {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return AppTheme.successColor;
      case 'medium':
        return AppTheme.warningColor;
      case 'hard':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(difficulty),
      backgroundColor: _getDifficultyColor().withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: _getDifficultyColor(),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: textTheme.bodySmall?.copyWith(
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
