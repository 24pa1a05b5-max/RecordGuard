import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/providers/app_providers.dart';

class AppScaffold extends ConsumerWidget {
  final Widget child;
  final String currentRoute;

  const AppScaffold({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    final healthAsync = ref.watch(systemHealthProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: AppTheme.accentTeal,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "RecordGuard AI",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryNavy,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (isDesktop) ...[
                        const SizedBox(width: 8),
                        const Text(
                          "• PS-11R3",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (isDesktop)
                    const Text(
                      "Healthcare Record Contradiction Detector & Provenance Audit Engine",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Live Backend Health Indicator
          healthAsync.when(
            data: (health) => Tooltip(
              message: "AI Engine Status: Active & Operational",
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 10 : 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.successLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.successGreen.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppTheme.successGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (isDesktop) ...[
                      const SizedBox(width: 6),
                      const Text(
                        "AI Backend Live",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successGreen,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (err, stack) => Tooltip(
              message: "Standalone Clinical Mode Active",
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 10 : 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accentTeal.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, size: 12, color: AppTheme.accentTeal),
                    if (isDesktop) ...[
                      const SizedBox(width: 4),
                      const Text(
                        "Standalone Engine",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentTeal,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // User Profile Indicator (Click to view Account & Saved Reports)
          if (isDesktop)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.go('/account'),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: currentRoute.startsWith('/account')
                      ? AppTheme.accentTeal.withOpacity(0.12)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: currentRoute.startsWith('/account')
                        ? AppTheme.accentTeal
                        : AppTheme.borderSubtle,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_circle,
                      size: 16,
                      color: AppTheme.secondaryNavy,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      user?.fullName ?? (user?.username ?? "Clinician Reviewer"),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 14, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            )
          else
            Tooltip(
              message: "Account: ${user?.fullName ?? (user?.username ?? "Clinician Reviewer")}",
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.go('/account'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppTheme.accentTeal.withOpacity(0.15),
                    child: const Icon(
                      Icons.person,
                      size: 16,
                      color: AppTheme.accentTeal,
                    ),
                  ),
                ),
              ),
            ),

          if (user?.isAdmin == true) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: const Text(
                "ADMIN",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Color(0xFFF59E0B), size: 20),
              tooltip: "Admin Console",
              onPressed: () => context.go('/admin'),
            ),
          ],

          // Logout
          IconButton(
            icon: const Icon(Icons.logout, size: 18, color: Color(0xFF64748B)),
            tooltip: "Logout",
            onPressed: () async {
              await ref.read(currentUserProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: _buildDrawer(context, user, currentRoute),
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              selectedIndex: _getSelectedIndex(currentRoute),
              onDestinationSelected: (idx) => _navigate(context, idx),
              labelType: NavigationRailLabelType.all,
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Dashboard'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.people_alt_outlined),
                  selectedIcon: Icon(Icons.people_alt),
                  label: Text('Patients'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.compare_arrows_outlined),
                  selectedIcon: Icon(Icons.compare_arrows),
                  label: Text('Compare'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.checklist_rtl_outlined),
                  selectedIcon: Icon(Icons.checklist_rtl),
                  label: Text('Workspace'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.assignment_late_outlined),
                  selectedIcon: Icon(Icons.assignment_late),
                  label: Text('Review Queue'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.psychology_outlined),
                  selectedIcon: Icon(Icons.psychology),
                  label: Text('Model Info'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.account_box_outlined),
                  selectedIcon: Icon(Icons.account_box),
                  label: Text('Account'),
                ),
                if (user?.isAdmin == true)
                  const NavigationRailDestination(
                    icon: Icon(Icons.admin_panel_settings_outlined, color: Color(0xFFF59E0B)),
                    selectedIcon: Icon(Icons.admin_panel_settings, color: Color(0xFFF59E0B)),
                    label: Text('Admin', style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          if (isDesktop)
            const VerticalDivider(
              thickness: 1,
              width: 1,
              color: AppTheme.borderSubtle,
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: !isDesktop
          ? NavigationBar(
              selectedIndex: _getSelectedIndex(currentRoute) > 4 ? 0 : _getSelectedIndex(currentRoute),
              onDestinationSelected: (idx) => _navigate(context, idx),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  label: 'Patients',
                ),
                NavigationDestination(
                  icon: Icon(Icons.compare_arrows),
                  label: 'Compare',
                ),
                NavigationDestination(
                  icon: Icon(Icons.checklist_rtl),
                  label: 'Workspace',
                ),
                NavigationDestination(
                  icon: Icon(Icons.assignment_late),
                  label: 'Queue',
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildDrawer(BuildContext context, CurrentUser? user, String currentRoute) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentTeal.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.local_hospital, color: AppTheme.accentTeal, size: 24),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "RecordGuard AI",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  user?.fullName ?? (user?.username ?? "Clinician Reviewer"),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      user?.role ?? "Clinical Reviewer",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    if (user?.isAdmin == true) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "ADMIN",
                          style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text("Dashboard"),
            selected: currentRoute == '/dashboard',
            onTap: () {
              Navigator.pop(context);
              context.go('/dashboard');
            },
          ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text("Patients & Records"),
            selected: currentRoute.startsWith('/patients'),
            onTap: () {
              Navigator.pop(context);
              context.go('/patients');
            },
          ),
          ListTile(
            leading: const Icon(Icons.compare_arrows),
            title: const Text("Compare Documents"),
            selected: currentRoute.startsWith('/compare'),
            onTap: () {
              Navigator.pop(context);
              context.go('/compare');
            },
          ),
          ListTile(
            leading: const Icon(Icons.checklist_rtl),
            title: const Text("Clinical Workspace"),
            selected: currentRoute.startsWith('/workspace'),
            onTap: () {
              Navigator.pop(context);
              context.go('/workspace');
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment_late_outlined),
            title: const Text("Review Queue"),
            selected: currentRoute.startsWith('/queue'),
            onTap: () {
              Navigator.pop(context);
              context.go('/queue');
            },
          ),
          ListTile(
            leading: const Icon(Icons.psychology_outlined),
            title: const Text("Model & Algorithm Info"),
            selected: currentRoute.startsWith('/model-info'),
            onTap: () {
              Navigator.pop(context);
              context.go('/model-info');
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_box_outlined),
            title: const Text("My Account & Saved Reports"),
            selected: currentRoute.startsWith('/account'),
            onTap: () {
              Navigator.pop(context);
              context.go('/account');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text("Settings"),
            selected: currentRoute.startsWith('/settings'),
            onTap: () {
              Navigator.pop(context);
              context.go('/settings');
            },
          ),
          if (user?.isAdmin == true) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: Color(0xFFF59E0B)),
              title: const Text(
                "Admin Console",
                style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
              ),
              subtitle: const Text("Staff directory & audit logs", style: TextStyle(fontSize: 11)),
              selected: currentRoute.startsWith('/admin'),
              onTap: () {
                Navigator.pop(context);
                context.go('/admin');
              },
            ),
          ],
        ],
      ),
    );
  }

  int _getSelectedIndex(String route) {
    if (route.startsWith('/patients')) return 1;
    if (route.startsWith('/compare')) return 2;
    if (route.startsWith('/workspace')) return 3;
    if (route.startsWith('/queue')) return 4;
    if (route.startsWith('/model-info')) return 5;
    if (route.startsWith('/settings')) return 6;
    if (route.startsWith('/account')) return 7;
    if (route.startsWith('/admin')) return 8;
    return 0; // dashboard
  }

  void _navigate(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/patients');
        break;
      case 2:
        context.go('/compare');
        break;
      case 3:
        context.go('/workspace');
        break;
      case 4:
        context.go('/queue');
        break;
      case 5:
        context.go('/model-info');
        break;
      case 6:
        context.go('/settings');
        break;
      case 7:
        context.go('/account');
        break;
      case 8:
        context.go('/admin');
        break;
    }
  }
}


