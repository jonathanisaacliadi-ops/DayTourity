import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../profile/presentation/providers/active_mode_provider.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../tour_discovery/presentation/pages/tour_discovery_page.dart';
import '../../../bookings/presentation/pages/my_trips_page.dart';
import '../../../history/presentation/pages/history_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../tours/presentation/pages/create_tour_page.dart';
import '../../../chat/presentation/pages/conversations_page.dart';

const _kRailBreakpoint = 600.0;

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();

  static void jumpTo(BuildContext context, int index) {
    context.findAncestorStateOfType<_MainShellState>()?.jumpTo(index);
  }
}

class _MainShellState extends ConsumerState<MainShell> {
  late int _currentIndex;

  static const _travellerPages = [
    HomePage(),
    TourDiscoveryPage(),
    MyTripsPage(),
    ConversationsPage(),
    ProfilePage(),
  ];

  static const _travellerDestinations = [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    _NavItem(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore,
        label: 'Discover'),
    _NavItem(
        icon: Icons.luggage_outlined,
        activeIcon: Icons.luggage,
        label: 'My Trips'),
    _NavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'Messages'),
    _NavItem(
        icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
  ];

  static const _guidePages = [
    HomePage(),
    TourDiscoveryPage(),
    HistoryPage(),
    ConversationsPage(),
    ProfilePage(),
  ];

  static const _guideDestinations = [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    _NavItem(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore,
        label: 'Discover'),
    _NavItem(
        icon: Icons.event_available_outlined,
        activeIcon: Icons.event_available,
        label: 'Reservations'),
    _NavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'Messages'),
    _NavItem(
        icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void jumpTo(int index) => setState(() => _currentIndex = index);

  void _openCreateTour() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateTourPage()),
      );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= _kRailBreakpoint;
    final isGuide = ref.watch(activeModeProvider) == 'GUIDE';
    final pages = isGuide ? _guidePages : _travellerPages;
    final destinations = isGuide ? _guideDestinations : _travellerDestinations;

    final safeIndex = _currentIndex.clamp(0, pages.length - 1);
    if (safeIndex != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _currentIndex = safeIndex);
      });
    }

    return useRail
        ? _RailLayout(
            currentIndex: safeIndex,
            destinations: destinations,
            pages: pages,
            onDestinationSelected: jumpTo,
            isGuide: isGuide,
            onCreateTour: _openCreateTour,
          )
        : _BottomBarLayout(
            currentIndex: safeIndex,
            destinations: destinations,
            pages: pages,
            onDestinationSelected: jumpTo,
            isGuide: isGuide,
            onCreateTour: _openCreateTour,
          );
  }
}

class _RailLayout extends StatelessWidget {
  const _RailLayout({
    required this.currentIndex,
    required this.destinations,
    required this.pages,
    required this.onDestinationSelected,
    required this.isGuide,
    required this.onCreateTour,
  });

  final int currentIndex;
  final List<_NavItem> destinations;
  final List<Widget> pages;
  final ValueChanged<int> onDestinationSelected;
  final bool isGuide;
  final VoidCallback onCreateTour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      drawer: _AppDrawer(
        currentIndex: currentIndex,
        destinations: destinations,
        onSelect: onDestinationSelected,
      ),
      body: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              border: Border(
                right: BorderSide(color: cs.outlineVariant, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
              backgroundColor: cs.surfaceContainer,
              indicatorColor: cs.primary.withOpacity(0.2),
              selectedIconTheme: IconThemeData(color: cs.primary),
              unselectedIconTheme:
                  IconThemeData(color: cs.onSurface.withOpacity(0.5)),
              selectedLabelTextStyle: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelTextStyle:
                  TextStyle(color: cs.onSurface.withOpacity(0.5)),
              useIndicator: true,
              labelType: NavigationRailLabelType.none,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Builder(
                      builder: (context) => IconButton(
                        icon: Icon(Icons.menu_rounded, color: cs.primary),
                        tooltip: 'Open menu',
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.forest_rounded,
                          color: cs.primary, size: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'day',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: cs.primary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              trailing: isGuide
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          FloatingActionButton.small(
                            onPressed: onCreateTour,
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            tooltip: 'New Tour',
                            child: const Icon(Icons.add),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'New Tour',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : null,

              destinations: destinations
                  .map((d) => NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.activeIcon),
                        label: Text(d.label),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: IndexedStack(index: currentIndex, children: pages),
          ),
        ],
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.currentIndex,
    required this.destinations,
    required this.onSelect,
  });

  final int currentIndex;
  final List<_NavItem> destinations;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Drawer(
      backgroundColor: cs.surface,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(Icons.forest_rounded, color: cs.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'daytourity',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Menu',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            for (final (i, d) in destinations.indexed)
              _DrawerItem(
                item: d,
                selected: i == currentIndex,
                onTap: () {
                  Navigator.pop(context);
                  onSelect(i);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withOpacity(0.15)
              : cs.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(
          selected ? item.activeIcon : item.icon,
          size: 18,
          color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.6),
        ),
      ),
      title: Text(
        item.label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? cs.primary : cs.onSurface,
        ),
      ),
    );
  }
}


class _BottomBarLayout extends StatelessWidget {
  const _BottomBarLayout({
    required this.currentIndex,
    required this.destinations,
    required this.pages,
    required this.onDestinationSelected,
    required this.isGuide,
    required this.onCreateTour,
  });

  final int currentIndex;
  final List<_NavItem> destinations;
  final List<Widget> pages;
  final ValueChanged<int> onDestinationSelected;
  final bool isGuide;
  final VoidCallback onCreateTour;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: isGuide
          ? FloatingActionButton.extended(
              onPressed: onCreateTour,
              icon: const Icon(Icons.add),
              label: const Text('New Tour'),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? cs.primary : cs.onSurface.withOpacity(0.5),
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? cs.primary : cs.onSurface.withOpacity(0.5),
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onDestinationSelected,
          backgroundColor: cs.surface,
          indicatorColor: cs.primary.withOpacity(0.15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: destinations
              .map((d) => NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.activeIcon),
                    label: d.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}
