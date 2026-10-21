import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

/// Wide screens (tablets, desktop web) get a side rail instead of the bottom bar.
const railBreakpoint = 1000.0;

/// The four main areas: Home · Portfolio · Practice · Learn. Each tab keeps its own page
/// stack, so switching tabs and coming back returns to where the user was.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _select(int index) =>
      // Tapping the current tab again goes back to its first page.
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = [
      (Icons.home_outlined, Icons.home, l10n.navHome),
      (Icons.pie_chart_outline, Icons.pie_chart, l10n.navPortfolio),
      (Icons.sports_esports_outlined, Icons.sports_esports, l10n.navPractice),
      (Icons.school_outlined, Icons.school, l10n.navLearn),
    ];
    final wide = MediaQuery.sizeOf(context).width >= railBreakpoint;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final (icon, selected, label) in destinations)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selected),
                    label: Text(label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            // Its own semantics container: pages block the semantics of what was painted
            // before them, which otherwise hid the rail from screen readers.
            Expanded(child: Semantics(container: true, child: shell)),
          ],
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _select,
        destinations: [
          for (final (icon, selected, label) in destinations)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selected),
              label: label,
            ),
        ],
      ),
    );
  }
}

/// Where an asset page opens: inside the current tab, so "back" returns to that tab.
String assetLocation(BuildContext context, int assetId) {
  final path = GoRouter.of(context).state.uri.path;
  for (final tab in const ['/portfolio', '/practice', '/learn']) {
    if (path.startsWith(tab)) return '$tab/assets/$assetId';
  }
  return '/assets/$assetId';
}
