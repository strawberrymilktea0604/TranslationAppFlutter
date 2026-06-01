import 'package:flutter/material.dart';
import 'package:frontend/features/admin/presentation/layout/admin_layout.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/injection_container.dart';
import 'package:frontend/main.dart';
import 'package:frontend/services/admin_dashboard_service.dart';
import 'package:http/http.dart' as http;

/// Admin page for monitoring translation service records.
class AdminTranslationsPage extends StatefulWidget {
  const AdminTranslationsPage({super.key});

  @override
  State<AdminTranslationsPage> createState() => _AdminTranslationsPageState();
}

class _AdminTranslationsPageState extends State<AdminTranslationsPage> {
  final _searchController = TextEditingController();
  late final AdminDashboardService _service;
  String _selectedType = 'all';
  int _currentPage = 1;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    final client = sl.isRegistered<http.Client>() ? sl<http.Client>() : null;
    _service = AdminDashboardService(baseUrl: config.apiUrl, client: client);
    _loadData();
  }

  Future<void> _loadData({int page = 1}) async {
    try {
      final token = await sl<AuthLocalDataSource>().getAccessToken();
      await _service.fetchServiceSummary(accessToken: token);
      await _service.fetchTranslations(
        page: page,
        pageSize: _pageSize,
        search: _searchController.text,
        translationType: _selectedType,
        accessToken: token,
      );
      if (mounted) {
        setState(() => _currentPage = page);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_service.error ?? error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      child: ListenableBuilder(
        listenable: _service,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: () => _loadData(page: _currentPage),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TranslationsHeader(onRefresh: () => _loadData()),
                  const SizedBox(height: 24),
                  _buildStats(context),
                  const SizedBox(height: 24),
                  _buildFilters(context),
                  const SizedBox(height: 24),
                  if (_service.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    _buildTable(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    final summary = _service.serviceSummary;
    if (summary == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatCard(
            title: 'Tổng dịch',
            value: _formatInt(summary.totalTranslations),
            color: Colors.blue,
          ),
          const SizedBox(width: 16),
          _StatCard(
            title: 'Hôm nay',
            value: _formatInt(summary.todayTranslations),
            color: Colors.green,
          ),
          const SizedBox(width: 16),
          _StatCard(
            title: 'Tuần này',
            value: _formatInt(summary.weekTranslations),
            color: Colors.orange,
          ),
          const SizedBox(width: 16),
          _StatCard(
            title: 'Tháng này',
            value: _formatInt(summary.monthTranslations),
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm kiếm bản dịch...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _loadData();
                      },
                      icon: const Icon(Icons.clear),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _loadData(),
          ),
        ),
        const SizedBox(width: 16),
        DropdownMenu<String>(
          initialSelection: _selectedType,
          onSelected: (value) {
            if (value == null) {
              return;
            }
            setState(() => _selectedType = value);
            _loadData();
          },
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: 'all', label: 'Tất cả'),
            DropdownMenuEntry(value: 'text', label: 'Văn bản'),
            DropdownMenuEntry(value: 'image', label: 'Hình ảnh'),
            DropdownMenuEntry(value: 'voice', label: 'Giọng nói'),
          ],
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => _loadData(),
          icon: const Icon(Icons.search),
          label: const Text('Tìm'),
        ),
      ],
    );
  }

  Widget _buildTable(BuildContext context) {
    final translations = _service.translations;
    if (translations.isEmpty) {
      return const _EmptyTranslationsState();
    }

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
              _buildTableHeader(context),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: translations.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                itemBuilder: (context, index) {
                  return _TranslationRow(
                    translation: translations[index],
                    onView: () => _showTranslationDetail(translations[index]),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildPagination(context),
      ],
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('Dịch', style: labelStyle)),
          Expanded(child: Text('Loại', style: labelStyle)),
          Expanded(child: Text('Người dùng', style: labelStyle)),
          Expanded(child: Text('Thời gian', style: labelStyle)),
          SizedBox(width: 80, child: Text('Hành động', style: labelStyle)),
        ],
      ),
    );
  }

  Widget _buildPagination(BuildContext context) {
    final hasNext = _currentPage * _pageSize < _service.translationTotal;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Trang $_currentPage - ${_service.translations.length} '
          'trên ${_service.translationTotal} bản dịch',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Row(
          children: [
            FilledButton.tonal(
              onPressed: _currentPage > 1
                  ? () => _loadData(page: _currentPage - 1)
                  : null,
              child: const Text('Trước'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: hasNext
                  ? () => _loadData(page: _currentPage + 1)
                  : null,
              child: const Text('Tiếp'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showTranslationDetail(
    AdminTranslationRecord translation,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Translation #${translation.id}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _DetailLine(
                  label: 'Người dùng',
                  value: translation.displayUser,
                ),
                _DetailLine(
                  label: 'Ngôn ngữ',
                  value:
                      '${translation.sourceLanguage} -> ${translation.targetLanguage}',
                ),
                _DetailLine(
                  label: 'Loại',
                  value: _typeLabel(translation.translationType),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nội dung gốc',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                SelectableText(translation.sourceText),
                const SizedBox(height: 12),
                Text('Bản dịch', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                SelectableText(translation.translatedText),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}

class _TranslationsHeader extends StatelessWidget {
  const _TranslationsHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quản lý Dịch vụ',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Theo dõi và quản lý tất cả các bản dịch',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        FilledButton.tonalIcon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Làm mới'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranslationRow extends StatelessWidget {
  const _TranslationRow({required this.translation, required this.onView});

  final AdminTranslationRecord translation;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(translation.translationType);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Translation #${translation.id}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(_typeLabel(translation.translationType)),
                backgroundColor: typeColor.withValues(alpha: 0.1),
                labelStyle: TextStyle(color: typeColor, fontSize: 12),
              ),
            ),
          ),
          Expanded(
            child: Text(
              translation.displayUser,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(child: Text(_formatTime(translation.createdAt))),
          SizedBox(
            width: 80,
            child: IconButton(
              tooltip: 'Xem',
              onPressed: onView,
              icon: const Icon(Icons.visibility_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTranslationsState extends StatelessWidget {
  const _EmptyTranslationsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.translate,
            size: 56,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có bản dịch phù hợp',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _formatInt(int value) {
  return value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
}

String _formatTime(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

String _typeLabel(String? type) {
  switch (type) {
    case 'image':
      return 'Hình ảnh';
    case 'voice':
      return 'Giọng nói';
    case 'text':
      return 'Văn bản';
    default:
      return type ?? 'Khác';
  }
}

Color _typeColor(String? type) {
  switch (type) {
    case 'image':
      return Colors.green;
    case 'voice':
      return Colors.purple;
    case 'text':
      return Colors.blue;
    default:
      return Colors.grey;
  }
}
