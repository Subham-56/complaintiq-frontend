import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'report_screen.dart';
import 'history_screen.dart';
import 'map_screen.dart';
import 'admin_screen.dart';
import 'admin_map_screen.dart';
import 'analytics_screen.dart';
import 'community_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _isAdmin = false;
  String _username = "";
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final data = await SessionService.readUserData();
    if (!mounted) return;
    setState(() {
      _username = (data['username'] ?? 'User').toString();
      _isAdmin = data['role'] == 'admin';
      _loaded = true;
    });
  }

  List<_NavItem> get _navItems {
    if (_isAdmin) {
      return [
        _NavItem(
          'Dashboard',
          Icons.dashboard_outlined,
          Icons.dashboard_rounded,
          const HomeScreen(),
        ),
        _NavItem(
          'All Complaints',
          Icons.list_alt_outlined,
          Icons.list_alt_rounded,
          const AdminScreen(),
        ),
        _NavItem(
          'City Map',
          Icons.public_outlined,
          Icons.public_rounded,
          const AdminMapScreen(),
        ),
        _NavItem(
          'Analytics',
          Icons.bar_chart_outlined,
          Icons.bar_chart_rounded,
          const AnalyticsScreen(),
        ),
      ];
    }
    return [
      _NavItem(
        'Dashboard',
        Icons.dashboard_outlined,
        Icons.dashboard_rounded,
        HomeScreen(onReportTap: () => setState(() => _selectedIndex = 1)),
      ),
      _NavItem(
        'Report Issue',
        Icons.add_circle_outline,
        Icons.add_circle_rounded,
        ReportScreen(onSubmitted: () => setState(() => _selectedIndex = 3)),
      ),
      _NavItem(
        'Community',
        Icons.groups_outlined,
        Icons.groups_rounded,
        const CommunityScreen(),
      ),
      _NavItem(
        'My Complaints',
        Icons.history_outlined,
        Icons.history_rounded,
        const HistoryScreen(),
      ),
      _NavItem('Map', Icons.map_outlined, Icons.map_rounded, const MapScreen()),
    ];
  }

  Future<void> _logout() async {
    await SessionService.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final items = _navItems;

        final header = Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            color: AppTheme.background,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              Text(
                items[_selectedIndex].label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              if (!isWide)
                IconButton(
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: _logout,
                ),
            ],
          ),
        );

        final content = Column(
          children: [
            header,
            Expanded(child: items[_selectedIndex].screen),
          ],
        );

        if (isWide) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            body: Row(
              children: [
                _buildSidebar(items),
                Expanded(child: content),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: content,
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: SafeArea(
              child: Row(
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final selected = index == _selectedIndex;
                  return Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedIndex = index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              selected ? item.activeIcon : item.icon,
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                              size: 22,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? AppTheme.primary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebar(List<_NavItem> items) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.accent],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'ComplaintIQ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...List.generate(items.length, (index) {
            final item = items[index];
            final selected = index == _selectedIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              child: Material(
                color: selected
                    ? AppTheme.primary.withAlpha(30)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _selectedIndex = index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected ? item.activeIcon : item.icon,
                          size: 20,
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primary.withAlpha(50),
                  child: Text(
                    _username.isNotEmpty ? _username[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _username,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.activeIcon, this.screen);
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget screen;
}