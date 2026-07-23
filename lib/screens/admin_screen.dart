import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/complaint_status.dart';
import '../widgets/complaint_image.dart';
import '../widgets/state_feedback.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<List<dynamic>> _future;
  final Map<int, String> _draftStatuses = {};
  final Set<int> _updating = {};

  @override
  void initState() {
    super.initState();
    _future = ApiService.getAllComplaints();
  }

  void _reload() {
    setState(() => _future = ApiService.getAllComplaints());
  }

  Future<void> _saveStatus(Map<String, dynamic> complaint) async {
    final id = complaint['id'] as int;
    final status = _draftStatuses[id];
    if (status == null) return;

    setState(() => _updating.add(id));
    try {
      await ApiService.updateComplaintStatus(complaintId: id, status: status);
      if (!mounted) return;
      setState(() => complaint['status'] = status);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _updating.remove(id));
    }
  }

  void _showDetails(Map<String, dynamic> complaint) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (complaint['image_url'] != null) ...[
                      ComplaintImage(
                        imageUrl: complaint['image_url'] as String,
                        height: 180,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      (complaint['ai_department'] ??
                              complaint['issue_type'] ??
                              '')
                          .toString(),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      complaint['description']?.toString() ?? '',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    const Divider(height: 32),
                    _detailRow(
                      'Reported by',
                      '${complaint['username'] ?? '-'} (${complaint['email'] ?? '-'})',
                    ),
                    _detailRow(
                      'AI Urgency',
                      (complaint['ai_urgency'] ?? '-').toString().toUpperCase(),
                    ),
                    _detailRow(
                      'Department',
                      complaint['ai_department']?.toString() ?? '-',
                    ),
                    _detailRow(
                      'Coordinates',
                      '${complaint['latitude']}, ${complaint['longitude']}',
                    ),
                    _detailRow('Upvotes', '${complaint['upvote_count'] ?? 0}'),
                    _detailRow(
                      'Filed on',
                      complaint['created_at']?.toString().split('T').first ??
                          '-',
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _urgencyBgColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'high':
        return AppTheme.statusRejected.withAlpha(30);
      case 'medium':
        return AppTheme.statusPending.withAlpha(30);
      default:
        return AppTheme.statusResolved.withAlpha(30);
    }
  }

  Color _urgencyTextColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'high':
        return AppTheme.statusRejected;
      case 'medium':
        return AppTheme.statusPending;
      default:
        return AppTheme.statusResolved;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'All Complaints',
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
            child: FutureBuilder<List<dynamic>>(
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

                final complaints = (snapshot.data ?? [])
                    .map((c) => Map<String, dynamic>.from(c as Map))
                    .toList();

                if (complaints.isEmpty) {
                  return const StateFeedback(
                    icon: Icons.inbox_outlined,
                    title: 'No complaints yet',
                    message: 'Citizen complaints will appear here.',
                  );
                }

                return ListView.separated(
                  itemCount: complaints.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final c = complaints[index];
                    final id = c['id'] as int;
                    final currentStatus = ComplaintStatus.normalize(
                      c['status']?.toString(),
                    );
                    final selectedStatus = _draftStatuses[id] ?? currentStatus;
                    final hasChanges = selectedStatus != currentStatus;
                    final isUpdating = _updating.contains(id);

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (c['image_url'] != null) ...[
                            SizedBox(
                              width: 64,
                              height: 64,
                              child: ComplaintImage(
                                imageUrl: c['image_url'] as String,
                                height: 64,
                                width: 64,
                              ),
                            ),
                            const SizedBox(width: 14),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        (c['ai_department'] ??
                                                c['issue_type'] ??
                                                '')
                                            .toString(),
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (c['ai_urgency'] != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _urgencyBgColor(
                                            c['ai_urgency'].toString(),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          c['ai_urgency']
                                              .toString()
                                              .toUpperCase(),
                                          style: TextStyle(
                                            color: _urgencyTextColor(
                                              c['ai_urgency'].toString(),
                                            ),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  c['description']?.toString() ?? '',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${c['username'] ?? 'Unknown'}',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(
                                      Icons.thumb_up_outlined,
                                      size: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${c['upvote_count'] ?? 0}',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedStatus,
                                  dropdownColor: AppTheme.surface,
                                  style: TextStyle(
                                    color: ComplaintStatus.foreground(
                                      selectedStatus,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  items: ComplaintStatus.options.map((s) {
                                    return DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    );
                                  }).toList(),
                                  onChanged: isUpdating
                                      ? null
                                      : (v) => setState(
                                          () => _draftStatuses[id] = v!,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () => _showDetails(c),
                                    child: const Text(
                                      'Details',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  if (hasChanges)
                                    isUpdating
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : TextButton(
                                            onPressed: () => _saveStatus(c),
                                            child: const Text(
                                              'Save',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
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