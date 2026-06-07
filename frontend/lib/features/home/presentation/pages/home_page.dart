import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../shell/presentation/pages/main_shell.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../tours/presentation/providers/tours_provider.dart';
import '../../../tours/presentation/pages/tour_detail_page.dart';
import '../widgets/tour_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String? _selectedCategory;

  static const _categories = [
    (null, 'All', Icons.explore_outlined),
    ('BUDGET', 'Budget', Icons.savings_outlined),
    ('STANDARD', 'Standard', Icons.tune_outlined),
    ('PREMIUM', 'Premium', Icons.workspace_premium_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final authState = ref.watch(authProvider).valueOrNull;
    final locState = ref.watch(locationProvider).valueOrNull;

    final city = locState is LocationDetected ? locState.city : null;
    final userName = authState is AuthAuthenticated
        ? authState.user.name.split(' ').first
        : 'Explorer';

    final toursAsync = ref.watch(
      toursProvider(
        ToursFilter(city: city, priceCategory: _selectedCategory),
      ),
    );

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: false,
            expandedHeight: 240,
            backgroundColor: cs.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 1,
            shadowColor: cs.outline.withValues(alpha: 0.3),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _HeroHeader(
                userName: userName,
                locState: locState,
                onLocationTap: () => _showCityPicker(context),
                onAvatarTap: () => MainShell.jumpTo(context, 4),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (val, label, icon) = _categories[i];
                  final active = _selectedCategory == val;
                  return _CategoryChip(
                    label: label,
                    icon: icon,
                    active: active,
                    onTap: () => setState(() => _selectedCategory = val),
                  );
                },
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recommended for you',
                      style: theme.textTheme.titleLarge),
                  TextButton(
                    onPressed: () => MainShell.jumpTo(context, 1),
                    child: const Text('See all'),
                  ),
                ],
              ),
            ),
          ),

          toursAsync.when(
            loading: () => SliverToBoxAdapter(
              child: SizedBox(
                height: kCompactTourCardHeight,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (_, __) => const CompactTourCardShimmer(),
                ),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: _ErrorState(message: e.toString()),
            ),
            data: (tours) => tours.isEmpty
                ? const SliverToBoxAdapter(child: _EmptyState())
                : SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: SizedBox(
                        height: kCompactTourCardHeight,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          scrollDirection: Axis.horizontal,
                          itemCount: tours.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 16),
                          itemBuilder: (_, i) => CompactTourCard(
                            tour: tours[i],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TourDetailPage(
                                  tourId: tours[i].id,
                                  heroTour: tours[i],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showCityPicker(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Set your city'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Jakarta, Bali, Bandung…',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => _submitCity(ctx, ctrl),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => _submitCity(ctx, ctrl),
              child: const Text('Set')),
        ],
      ),
    );
  }

  void _submitCity(BuildContext ctx, TextEditingController ctrl) {
    final city = ctrl.text.trim();
    if (city.isNotEmpty) {
      ref.read(locationProvider.notifier).setManualCity(city);
      Navigator.pop(ctx);
    }
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.userName,
    required this.locState,
    required this.onLocationTap,
    required this.onAvatarTap,
  });

  final String userName;
  final LocationState? locState;
  final VoidCallback onLocationTap;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final locationLabel = switch (locState) {
      LocationDetected(:final city) => city,
      LocationLoading() => 'Detecting location…',
      _ => 'Set location',
    };
    final canTapLocation =
        locState is! LocationDetected && locState is! LocationLoading;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/bgcimage.jpg',
          fit: BoxFit.cover,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primary.withValues(alpha: 0.85),
                cs.primary.withValues(alpha: 0.55),
              ],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $userName 👋',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: canTapLocation ? onLocationTap : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  canTapLocation
                                      ? Icons.add_location_alt_outlined
                                      : Icons.location_on,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  locationLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (canTapLocation) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.keyboard_arrow_down,
                                      size: 14, color: Colors.white),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: onAvatarTap,
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        child: const Icon(Icons.person_outline,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Where will you explore next?',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        decoration: BoxDecoration(
          color: active ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? cs.primary : cs.outline.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: active
                    ? cs.onPrimary
                    : cs.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color:
                    active ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.explore_off_outlined,
              size: 56, color: cs.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('No tours found in this area',
              style: TextStyle(
                  fontSize: 15, color: cs.onSurface.withValues(alpha: 0.45))),
          const SizedBox(height: 6),
          Text('Try changing your location or category',
              style: TextStyle(
                  fontSize: 13, color: cs.onSurface.withValues(alpha: 0.3))),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text('Error: $message',
          style: TextStyle(color: Theme.of(context).colorScheme.error)),
    );
  }
}
