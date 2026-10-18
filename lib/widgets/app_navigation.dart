import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../routes/app_routes.dart';

// V5 — Dot Minimal: small dot below active icon, label animates in/out with AnimatedSize
class AppNavigation extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const AppNavigation({required this.navigationShell, super.key});

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  int get _selectedIndex => widget.navigationShell.currentIndex;

  static const List<_TabSpec> _tabs = [
    _TabSpec(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      branchIndex: 0,
    ),
    _TabSpec(
      icon: Icons.description_outlined,
      selectedIcon: Icons.description_rounded,
      branchIndex: 1,
    ),
    _TabSpec(
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      branchIndex: null,
      route: AppRoutes.templatesScreen, // real templates
    ),
    _TabSpec(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      branchIndex: null,
      route: AppRoutes.settingsScreen,
    ),
  ];

  void _onTabTap(int index) {
    final tab = _tabs[index];
    if (tab.branchIndex == null) {
      if (tab.route != null) {
        context.push(tab.route!);
      }
      return;
    }
    widget.navigationShell.goBranch(
      tab.branchIndex!,
      initialLocation: tab.branchIndex == _selectedIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.navHome,
      l10n.navDocuments,
      l10n.templates,
      l10n.navSettings,
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withAlpha(60),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final isActive =
                  tab.branchIndex != null && tab.branchIndex == _selectedIndex;

              return Expanded(
                child: GestureDetector(
                  onTap: () => _onTabTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.primary.withAlpha(12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isActive ? tab.selectedIcon : tab.icon,
                          size: 22,
                          color: isActive
                              ? AppTheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isActive
                              ? AppTheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  final IconData icon;
  final IconData selectedIcon;
  final int? branchIndex;
  final String? route;

  const _TabSpec({
    required this.icon,
    required this.selectedIcon,
    required this.branchIndex,
    this.route,
  });
}
