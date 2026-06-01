import 'package:flutter/material.dart';
import 'package:frontend/features/admin/presentation/layout/admin_layout.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/injection_container.dart';
import 'package:frontend/main.dart';
import 'package:frontend/services/admin_dashboard_service.dart';
import 'package:http/http.dart' as http;

/// Admin analytics page backed by period-based analytics API endpoints.
class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  late final AdminDashboardService _service;
  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();
    final client = sl.isRegistered<http.Client>() ? sl<http.Client>() : null;
    _service = AdminDashboardService(baseUrl: config.apiUrl, client: client);
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      final token = await sl<AuthLocalDataSource>().getAccessToken();
      await _service.fetchAnalytics(days: _selectedDays, accessToken: token);
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
            onRefresh: _loadAnalytics,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thống kê & Phân tích',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Phân tích hiệu suất hệ thống',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildRangeSelector(context),
                  const SizedBox(height: 24),
                  if (_service.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    _buildMetricsGrid(context),
                    const SizedBox(height: 32),
                    _buildBreakdowns(context),
                    const SizedBox(height: 16),
                    _buildServiceMetrics(context),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRangeSelector(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final days in [7, 30, 90]) ...[
            _DateRangeButton(
              label: '$days ngày',
              isActive: _selectedDays == days,
              onPressed: () {
                setState(() => _selectedDays = days);
                _loadAnalytics();
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    final overview = _service.analyticsOverview;
    if (overview == null) {
      return const _EmptyAnalyticsState();
    }

    return GridView.count(
      crossAxisCount: _getGridCount(context),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _MetricCard(
          title: 'Dịch trung bình/ngày',
          value: _formatNumber(overview.averageTranslationsPerDay.value),
          metric: overview.averageTranslationsPerDay,
        ),
        _MetricCard(
          title: 'Người dùng hoạt động',
          value: _formatNumber(overview.activeUsers.value),
          metric: overview.activeUsers,
        ),
        _MetricCard(
          title: 'Thời gian phản hồi (ms)',
          value: _formatNumber(overview.averageResponseTimeMs.value),
          metric: overview.averageResponseTimeMs,
          inverseTrend: true,
        ),
        _MetricCard(
          title: 'Độ chính xác dịch',
          value:
              '${overview.translationAccuracyPercent.value.toStringAsFixed(1)}%',
          metric: overview.translationAccuracyPercent,
        ),
      ],
    );
  }

  Widget _buildBreakdowns(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final cards = [
      _BreakdownCard<ServiceTypeCount>(
        title: 'Dịch theo loại',
        items: _service.translationTypeBreakdown,
        labelBuilder: (item) => _typeLabel(item.type),
        countBuilder: (item) => item.count,
        percentBuilder: (item) => item.percentage,
      ),
      _BreakdownCard<LanguageUsageItem>(
        title: 'Ngôn ngữ đích phổ biến',
        items: _service.languageUsage?.targetLanguages ?? [],
        labelBuilder: (item) => item.language,
        countBuilder: (item) => item.count,
        percentBuilder: (item) => item.percentage,
      ),
    ];

    if (!isWide) {
      return Column(
        children: [
          for (final card in cards) ...[card, const SizedBox(height: 16)],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 16),
        Expanded(child: cards[1]),
      ],
    );
  }

  Widget _buildServiceMetrics(BuildContext context) {
    final metrics = _service.serviceMetrics;
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hiệu suất dịch vụ',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (metrics.isEmpty)
              const Text('Chưa có dữ liệu API trong khoảng thời gian này.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: metrics.length,
                separatorBuilder: (context, index) => Divider(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                itemBuilder: (context, index) {
                  final metric = metrics[index];
                  return _ServiceMetricRow(metric: metric);
                },
              ),
          ],
        ),
      ),
    );
  }

  int _getGridCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return 1;
    }
    if (width < 900) {
      return 2;
    }
    return 4;
  }
}

class _DateRangeButton extends StatelessWidget {
  const _DateRangeButton({
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        backgroundColor: isActive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: isActive
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.metric,
    this.inverseTrend = false,
  });

  final String title;
  final String value;
  final AdminMetricCard metric;
  final bool inverseTrend;

  @override
  Widget build(BuildContext context) {
    final positive = inverseTrend
        ? metric.changePercent <= 0
        : metric.changePercent >= 0;
    final color = positive ? Colors.green : Colors.red;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Icon(
                  metric.changePercent >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  '${metric.changePercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'vs. kỳ trước',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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

class _BreakdownCard<T> extends StatelessWidget {
  const _BreakdownCard({
    required this.title,
    required this.items,
    required this.labelBuilder,
    required this.countBuilder,
    required this.percentBuilder,
  });

  final String title;
  final List<T> items;
  final String Function(T item) labelBuilder;
  final int Function(T item) countBuilder;
  final double Function(T item) percentBuilder;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const SizedBox(
                height: 160,
                child: Center(child: Text('Chưa có dữ liệu.')),
              )
            else
              for (final item in items.take(8)) ...[
                _ProgressRow(
                  label: labelBuilder(item),
                  count: countBuilder(item),
                  percent: percentBuilder(item),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.count,
    required this.percent,
  });

  final String label;
  final int count;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.3),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 112,
          child: Text(
            '$count (${percent.toStringAsFixed(1)}%)',
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _ServiceMetricRow extends StatelessWidget {
  const _ServiceMetricRow({required this.metric});

  final AdminServiceMetric metric;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(metric.endpoint, overflow: TextOverflow.ellipsis),
        ),
        Expanded(child: Text(metric.aiModel ?? '-')),
        Expanded(child: Text('${metric.totalRequests} requests')),
        Expanded(
          child: Text('${metric.averageResponseTimeMs.toStringAsFixed(1)} ms'),
        ),
        Expanded(child: Text('${metric.failedRequests} lỗi')),
      ],
    );
  }
}

class _EmptyAnalyticsState extends StatelessWidget {
  const _EmptyAnalyticsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: Text('Chưa có dữ liệu thống kê.')),
    );
  }
}

String _formatNumber(double value) {
  final rounded = value.round();
  return rounded.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
}

String _typeLabel(String type) {
  switch (type) {
    case 'image':
      return 'Hình ảnh';
    case 'voice':
      return 'Giọng nói';
    case 'text':
      return 'Văn bản';
    default:
      return type;
  }
}
