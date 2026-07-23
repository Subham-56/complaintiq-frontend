import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/state_feedback.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getAnalytics();
  }

  void _reload() {
    setState(() => _future = ApiService.getAnalytics());
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Analytics',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  );
                }
                if (snapshot.hasError) {
                  return StateFeedback(
                    icon: Icons.error_outline,
                    title: 'Unable to load analytics',
                    message: snapshot.error.toString().replaceFirst(
                      'Exception: ',
                      '',
                    ),
                    actionLabel: 'Retry',
                    onAction: _reload,
                  );
                }

                final data = snapshot.data!;
                final statusCounts = Map<String, dynamic>.from(
                  data['status_counts'] as Map,
                );
                final departmentCounts = Map<String, dynamic>.from(
                  data['department_counts'] as Map,
                );
                final topUpvoted = (data['top_upvoted'] as List)
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KPI Cards
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: isWide ? 4 : 2,
                        childAspectRatio: isWide ? 1.4 : 1.2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        children: [
                          _kpiCard(
                            'Total Complaints',
                            '${data['total_complaints']}',
                            Icons.report_outlined,
                            AppTheme.primary,
                          ),
                          _kpiCard(
                            'Total Citizens',
                            '${data['total_users']}',
                            Icons.people_outline,
                            AppTheme.accent,
                          ),
                          _kpiCard(
                            'Resolution Rate',
                            '${data['resolution_rate']}%',
                            Icons.check_circle_outline,
                            AppTheme.statusResolved,
                          ),
                          _kpiCard(
                            'Pending',
                            '${statusCounts['Pending'] ?? 0}',
                            Icons.hourglass_empty_rounded,
                            AppTheme.statusPending,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _statusBreakdown(statusCounts)),
                          const SizedBox(width: 16),
                          Expanded(child: _departmentBreakdown(departmentCounts)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      _topUpvotedSection(topUpvoted),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _statusBreakdown(Map<String, dynamic> counts) {
    final total = counts.values.fold<int>(0, (sum, v) => sum + (v as int));
    final colors = {
      'Pending': AppTheme.statusPending,
      'In Progress': AppTheme.statusInProgress,
      'Resolved': AppTheme.statusResolved,
      'Rejected': AppTheme.statusRejected,
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status Breakdown',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          ...counts.entries.map((entry) {
            final ratio = total == 0 ? 0.0 : (entry.value as int) / total;
            final color = colors[entry.key] ?? AppTheme.primary;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${entry.value}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: AppTheme.background,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _departmentBreakdown(Map<String, dynamic> counts) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Departments',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          if (sorted.isEmpty)
            const Text(
              'No data yet',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            )
          else
            ...sorted.take(5).map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.value}',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _topUpvotedSection(List<Map<String, dynamic>> items) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Most Upvoted Complaints',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Text(
              'No upvoted complaints yet',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            )
          else
            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.thumb_up_rounded,
                            size: 14,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${item['upvote_count']}',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item['description']?.toString() ?? '',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}