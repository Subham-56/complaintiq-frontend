import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/complaint_image.dart';
import '../widgets/complaint_status_chip.dart';
import '../widgets/state_feedback.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final raw = await ApiService.getComplaints();
    // Cast (not clone) so the SAME map objects persist across rebuilds —
    // otherwise an upvote mutation gets discarded on the next rebuild.
    return raw.map((e) => e as Map<String, dynamic>).toList();
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _handleUpvote(Map<String, dynamic> complaint) async {
    try {
      final id = (complaint['id'] as num?)?.toInt();
      if (id == null) throw Exception('This complaint has an invalid ID');
      final result = await ApiService.toggleUpvote(id);
      if (!mounted) return;
      setState(() {
        complaint['upvote_count'] = result['upvote_count'];
        complaint['user_has_upvoted'] = result['user_has_upvoted'];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
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
          const Text(
            'My Complaints',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
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
                    title: 'Unable to load complaints',
                    message: snapshot.error.toString().replaceFirst(
                      'Exception: ',
                      '',
                    ),
                    actionLabel: 'Retry',
                    onAction: _reload,
                  );
                }

                final complaints = snapshot.data ?? [];

                if (complaints.isEmpty) {
                  return const StateFeedback(
                    icon: Icons.inbox_outlined,
                    title: 'No complaints yet',
                    message: 'Submitted complaints will appear here.',
                  );
                }

                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isWide ? 2 : 1,
                    mainAxisExtent: 340,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: complaints.length,
                  itemBuilder: (context, index) {
                    final c = complaints[index];
                    return _ComplaintCard(
                      key: ValueKey(c['id']),
                      complaint: c,
                      onUpvote: () => _handleUpvote(c),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({super.key, required this.complaint, required this.onUpvote});

  final Map<String, dynamic> complaint;
  final VoidCallback onUpvote;

  @override
  Widget build(BuildContext context) {
    final hasUpvoted = complaint['user_has_upvoted'] == true;
    final upvoteCount = complaint['upvote_count'] ?? 0;
    final aiUrgency = complaint['ai_urgency']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (complaint['image_url'] != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: ComplaintImage(
                imageUrl: complaint['image_url'] as String,
                height: 140,
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (complaint['ai_department'] ??
                                  complaint['issue_type'] ??
                                  'Unknown')
                              .toString(),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ComplaintStatusChip(
                        status: complaint['status']?.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (complaint['description'] ?? '').toString(),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (aiUrgency != null)
                    Row(
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 14,
                          color: _urgencyColor(aiUrgency),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${aiUrgency.toUpperCase()} URGENCY',
                          style: TextStyle(
                            color: _urgencyColor(aiUrgency),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Icon(
                          Icons.hourglass_empty_rounded,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          complaint['status']?.toString() == 'Under Review'
                              ? 'AWAITING AI REVIEW'
                              : 'NOT YET CLASSIFIED',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  const Spacer(),
                  Row(
                    children: [
                      InkWell(
                        onTap: onUpvote,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hasUpvoted
                                    ? Icons.thumb_up_rounded
                                    : Icons.thumb_up_outlined,
                                size: 16,
                                color: hasUpvoted
                                    ? AppTheme.primary
                                    : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$upvoteCount',
                                style: TextStyle(
                                  color: hasUpvoted
                                      ? AppTheme.primary
                                      : AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _urgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'high':
        return AppTheme.statusRejected;
      case 'medium':
        return AppTheme.statusPending;
      default:
        return AppTheme.statusResolved;
    }
  }
}