import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/complaint_status_chip.dart';
import '../widgets/state_feedback.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onReportTap});

  final VoidCallback? onReportTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _username = "User";
  bool _isAdmin = false;
  bool _loading = true;
  List<dynamic> _recentComplaints = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userData = await SessionService.readUserData();
    if (!mounted) return;
    setState(() {
      _username = (userData['username'] ?? 'User').toString();
      _isAdmin = userData['role'] == 'admin';
    });

    try {
      final complaints = _isAdmin
          ? await ApiService.getAllComplaints()
          : await ApiService.getComplaints();
      if (!mounted) return;
      setState(() {
        _recentComplaints = complaints.take(5).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _isAdmin ? 'ADMIN DASHBOARD' : 'CITIZEN DASHBOARD',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome back, $_username',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isAdmin
                      ? 'Monitor and manage complaints across the city'
                      : 'Report civic issues and track their resolution',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              const Text(
                'Recent Complaints',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(onPressed: _load, child: const Text('Refresh')),
            ],
          ),
          const SizedBox(height: 12),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            )
          else if (_error != null)
            StateFeedback(
              icon: Icons.error_outline,
              title: 'Unable to load complaints',
              message: _error!,
              actionLabel: 'Retry',
              onAction: _load,
            )
          else if (_recentComplaints.isEmpty)
            StateFeedback(
              icon: Icons.inbox_outlined,
              title: 'No complaints yet',
              message: _isAdmin
                  ? 'Citizen complaints will appear here.'
                  : 'Submitted complaints will appear here.',
              actionLabel: _isAdmin ? null : 'Report an Issue',
              onAction: _isAdmin ? null : widget.onReportTap,
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 2 : 1,
                mainAxisExtent: 100,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: _recentComplaints.length,
              itemBuilder: (context, index) {
                final c = Map<String, dynamic>.from(
                  _recentComplaints[index] as Map,
                );
                return _RecentCard(complaint: c);
              },
            ),
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.complaint});
  final Map<String, dynamic> complaint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.report_problem_outlined,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (complaint['ai_department'] ??
                          complaint['issue_type'] ??
                          'Unknown')
                      .toString(),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  (complaint['description'] ?? '').toString(),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ComplaintStatusChip(status: complaint['status']?.toString()),
        ],
      ),
    );
  }
}