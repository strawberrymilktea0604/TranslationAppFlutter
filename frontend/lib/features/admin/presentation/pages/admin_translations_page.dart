import 'package:flutter/material.dart';
import 'package:frontend/features/admin/presentation/layout/admin_layout.dart';

/// Admin Translations Management Page
/// Displays and manages all translations in the system
class AdminTranslationsPage extends StatefulWidget {
  const AdminTranslationsPage({super.key});

  @override
  State<AdminTranslationsPage> createState() => _AdminTranslationsPageState();
}

class _AdminTranslationsPageState extends State<AdminTranslationsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
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
                      'Quản lý Dịch vụ',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Theo dõi và quản lý tất cả các bản dịch',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Export data
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Xuất dữ liệu'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stats Cards
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatCard(context, 'Tổng dịch', '12,450', Colors.blue),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    context,
                    'Hôm nay',
                    '856',
                    Colors.green,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    context,
                    'Tuần này',
                    '5,230',
                    Colors.orange,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    context,
                    'Tháng này',
                    '18,900',
                    Colors.purple,
                  ),
                ],
              ),
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
                      hintText: 'Tìm kiếm bản dịch...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownMenu<String>(
                  initialSelection: 'all',
                  onSelected: (value) {
                    setState(() {});
                  },
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 'all', label: 'Tất cả'),
                    DropdownMenuEntry(value: 'text', label: 'Dịch văn bản'),
                    DropdownMenuEntry(value: 'image', label: 'Dịch hình ảnh'),
                    DropdownMenuEntry(value: 'voice', label: 'Dịch giọng nói'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Translations Table
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
                            'Dịch',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Loại',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Người dùng',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Thời gian',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(
                          width: 80,
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
                    itemCount: 10,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    itemBuilder: (context, index) {
                      return _buildTranslationRow(context, index);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, Color color) {
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
              ),
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

  Widget _buildTranslationRow(BuildContext context, int index) {
    final types = ['Văn bản', 'Hình ảnh', 'Giọng nói'];
    final type = types[index % types.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text('Translation #${index + 1000}'),
          ),
          Expanded(
            child: Chip(
              label: Text(type),
              backgroundColor: _getTypeColor(type).withValues(alpha: 0.1),
              labelStyle: TextStyle(
                color: _getTypeColor(type),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text('User ${(index % 5) + 1}'),
          ),
          Expanded(
            child: Text('${DateTime.now().subtract(Duration(minutes: index)).hour}:${DateTime.now().subtract(Duration(minutes: index)).minute.toString().padLeft(2, '0')}'),
          ),
          SizedBox(
            width: 80,
            child: PopupMenuButton(
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 18),
                      SizedBox(width: 8),
                      Text('Xem'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18),
                      SizedBox(width: 8),
                      Text('Xóa'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Văn bản':
        return Colors.blue;
      case 'Hình ảnh':
        return Colors.green;
      case 'Giọng nói':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
