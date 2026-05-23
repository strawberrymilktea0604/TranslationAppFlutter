import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';

/// Admin Quiz Editor Page
/// Manages quiz creation, editing, and question composition
class AdminQuizEditorPage extends StatefulWidget {
  const AdminQuizEditorPage({super.key});

  @override
  State<AdminQuizEditorPage> createState() => _AdminQuizEditorPageState();
}

class _AdminQuizEditorPageState extends State<AdminQuizEditorPage> {
  final _searchController = TextEditingController();
  String _selectedDifficulty = 'All';
  String _selectedStatus = 'All';

  // Placeholder data
  final List<Map<String, String>> _quizzes = [
    {
      'id': 'QUIZ001',
      'title': 'Geography Basics',
      'description': 'Learn about world capitals and landmarks',
      'questions': '15',
      'language': 'English',
      'difficulty': 'Easy',
      'status': 'Published',
      'author': 'Admin'
    },
    {
      'id': 'QUIZ002',
      'title': '地理基础',
      'description': '学习世界首都和地标',
      'questions': '20',
      'language': 'Chinese',
      'difficulty': 'Medium',
      'status': 'Published',
      'author': 'Admin'
    },
    {
      'id': 'QUIZ003',
      'title': 'Science & Nature',
      'description': 'Explore planets, elements, and ecosystems',
      'questions': '18',
      'language': 'English',
      'difficulty': 'Hard',
      'status': 'Draft',
      'author': 'Admin'
    },
    {
      'id': 'QUIZ004',
      'title': 'Mathematics Advanced',
      'description': 'Advanced mathematical concepts',
      'questions': '25',
      'language': 'English',
      'difficulty': 'Hard',
      'status': 'Draft',
      'author': 'Editor'
    },
    {
      'id': 'QUIZ005',
      'title': 'English Vocabulary',
      'description': 'Build your English word knowledge',
      'questions': '30',
      'language': 'English',
      'difficulty': 'Medium',
      'status': 'Published',
      'author': 'Admin'
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

    return SingleChildScrollView(
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
                      'Quiz Editor',
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create and manage learning quizzes with multiple questions',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () {
                    // TODO: Open create quiz dialog
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Quiz'),
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
                      hintText: 'Search quizzes...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Difficulty filter
                Expanded(
                  child: DropdownMenu<String>(
                    initialSelection: _selectedDifficulty,
                    onSelected: (value) {
                      setState(() => _selectedDifficulty = value ?? 'All');
                    },
                    dropdownMenuEntries: [
                      'All',
                      'Easy',
                      'Medium',
                      'Hard'
                    ].map((difficulty) {
                      return DropdownMenuEntry(
                        value: difficulty,
                        label: difficulty,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 12),

                // Status filter
                Expanded(
                  child: DropdownMenu<String>(
                    initialSelection: _selectedStatus,
                    onSelected: (value) {
                      setState(() => _selectedStatus = value ?? 'All');
                    },
                    dropdownMenuEntries: [
                      'All',
                      'Draft',
                      'Published'
                    ].map((status) {
                      return DropdownMenuEntry(
                        value: status,
                        label: status,
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
                  title: 'Total Quizzes',
                  value: '${_quizzes.length}',
                  color: AppTheme.primaryColor,
                  icon: Icons.quiz_rounded,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  title: 'Published',
                  value: '${_quizzes.where((q) => q['status'] == 'Published').length}',
                  color: AppTheme.successColor,
                  icon: Icons.check_circle_outline_rounded,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  title: 'Drafts',
                  value: '${_quizzes.where((q) => q['status'] == 'Draft').length}',
                  color: AppTheme.warningColor,
                  icon: Icons.edit_note_rounded,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Quizzes Grid
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
                          flex: 2,
                          child: Text(
                            'Title',
                            style: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Questions',
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
                        Expanded(
                          child: Text(
                            'Author',
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
                  ..._quizzes.map((quiz) {
                    return _QuizRow(
                      quiz: quiz,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizRow extends StatelessWidget {
  final Map<String, String> quiz;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _QuizRow({
    required this.quiz,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final isPublished = quiz['status'] == 'Published';

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
          // TODO: Open quiz editor
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
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quiz['title'] ?? '',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quiz['description'] ?? '',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Chip(
                  label: Text('${quiz['questions']} Q'),
                  backgroundColor: colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: _DifficultyChip(difficulty: quiz['difficulty'] ?? ''),
              ),
              Expanded(
                child: Chip(
                  label: Text(quiz['status'] ?? ''),
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
              Expanded(
                child: Text(
                  quiz['author'] ?? '',
                  style: textTheme.bodySmall,
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
                        // TODO: Edit quiz
                      },
                    ),
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.preview_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Preview'),
                        ],
                      ),
                      onTap: () {
                        // TODO: Preview quiz
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
                        // TODO: Delete quiz
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
