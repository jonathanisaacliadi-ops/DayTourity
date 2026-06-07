import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../features/tours/domain/entities/tour.dart';
import '../../../../features/tours/presentation/pages/tour_detail_page.dart';
import '../../../../features/tours/presentation/providers/tours_provider.dart';
import '../../../../core/widgets/green_page_header.dart';
import '../../../../core/widgets/guide_trust.dart';


String _picsumUrl(String seed, {int w = 600, int h = 400}) =>
    'https://picsum.photos/seed/$seed/$w/$h';


class TourDiscoveryPage extends ConsumerStatefulWidget {
  const TourDiscoveryPage({super.key});

  @override
  ConsumerState<TourDiscoveryPage> createState() => _TourDiscoveryPageState();
}

class _TourDiscoveryPageState extends ConsumerState<TourDiscoveryPage> {
  final _searchCtrl = TextEditingController();
  final _focusNode  = FocusNode();
  String  _cityQuery        = '';
  String? _selectedCategory;
  bool    _searchFocused    = false;
  Timer?  _debounce;

  static const _categories = [
    (null,       'All',      Icons.explore_outlined),
    ('BUDGET',   'Budget',   Icons.savings_outlined),
    ('STANDARD', 'Standard', Icons.tune_outlined),
    ('PREMIUM',  'Premium',  Icons.workspace_premium_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _searchFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _cityQuery = value.trim());
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _debounce?.cancel();
    setState(() => _cityQuery = '');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final toursAsync = ref.watch(
      toursProvider(ToursFilter(
        city: _cityQuery.isEmpty ? null : _cityQuery,
        priceCategory: _selectedCategory,
      )),
    );

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          _DiscoverHeader(
            controller:    _searchCtrl,
            focusNode:     _focusNode,
            focused:       _searchFocused,
            onChanged:     _onSearch,
            onClear:       _clearSearch,
            selectedCat:   _selectedCategory,
            categories:    _categories,
            onSelectCat:   (v) => setState(() => _selectedCategory = v),
          ),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve:  Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: KeyedSubtree(
                key: ValueKey((_cityQuery, _selectedCategory)),
                child: toursAsync.when(
                  loading: () => const _SkeletonGrid(),
                  error: (e, _) => _ErrorState(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(toursProvider),
                  ),
                  data: (tours) => tours.isEmpty
                      ? _EmptyState(city: _cityQuery, category: _selectedCategory)
                      : _TourGrid(tours: tours),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader({
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.onChanged,
    required this.onClear,
    required this.selectedCat,
    required this.categories,
    required this.onSelectCat,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String? selectedCat;
  final List<(String?, String, IconData)> categories;
  final ValueChanged<String?> onSelectCat;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GreenPageHeader(title: 'Discover Tours'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: 54,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: focused
                      ? cs.primary
                      : cs.outline.withValues(alpha: 0.4),
                  width: focused ? 2 : 1,
                ),
                boxShadow: focused
                    ? [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  AnimatedRotation(
                    turns: focused ? 0.05 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.search, size: 20,
                        color: focused
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: 0.4)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode:  focusNode,
                      onChanged:  onChanged,
                      style: TextStyle(
                          fontSize: 15, color: cs.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Search by city…',
                        hintStyle: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.35),
                            fontSize: 15),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  if (controller.text.isNotEmpty)
                    GestureDetector(
                      onTap: onClear,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.close, size: 18,
                            color: cs.onSurface.withValues(alpha: 0.5)),
                      ),
                    ),
                ],
              ),
            ),
          ),

          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final (val, label, icon) = categories[i];
                final active = selectedCat == val;
                return _CategoryChip(
                  label: label,
                  icon:  icon,
                  active: active,
                  onTap: () => onSelectCat(val),
                );
              },
            ),
          ),

          const SizedBox(height: 8),
          Divider(height: 1, color: cs.outline.withValues(alpha: 0.25)),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatefulWidget {
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
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: widget.active
                ? cs.primary
                : _hovered
                    ? cs.primary.withValues(alpha: 0.08)
                    : cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.active
                  ? cs.primary
                  : cs.outline.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14,
                  color: widget.active
                      ? cs.onPrimary
                      : cs.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.active
                      ? cs.onPrimary
                      : cs.onSurface.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _TourGrid extends StatelessWidget {
  const _TourGrid({required this.tours});
  final List<Tour> tours;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final useGrid = constraints.maxWidth >= 580;
      if (!useGrid) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          itemCount: tours.length,
          separatorBuilder: (_, __) => const SizedBox(height: 20),
          itemBuilder: (_, i) => AspectRatio(
            aspectRatio: 0.72,
            child: _DiscoveryCard(tour: tours[i]),
          ),
        );
      }
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 340,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.72,
        ),
        itemCount: tours.length,
        itemBuilder: (_, i) => _DiscoveryCard(tour: tours[i]),
      );
    });
  }
}


class _DiscoveryCard extends StatefulWidget {
  const _DiscoveryCard({required this.tour});
  final Tour tour;

  @override
  State<_DiscoveryCard> createState() => _DiscoveryCardState();
}

class _DiscoveryCardState extends State<_DiscoveryCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;

  late final AnimationController _ctrl;
  late final Animation<double>    _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final tour  = widget.tour;
    final imageUrl = tour.coverImageUrl ??
        (tour.photos.isNotEmpty ? tour.photos.first.url : null);
    final (catLabel, catFg, catBg) = _categoryStyle(tour.priceCategory, cs);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown:   (_) { _ctrl.forward(); setState(() => _pressed = true); },
        onTapUp:     (_) { _ctrl.reverse(); setState(() => _pressed = false); },
        onTapCancel: ()  { _ctrl.reverse(); setState(() => _pressed = false); },
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TourDetailPage(tourId: tour.id, heroTour: tour),
          ),
        ),
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(
                      alpha: _hovered ? 0.10 : 0.04),
                  blurRadius:  _hovered ? 24 : 10,
                  offset: Offset(0, _hovered ? 8 : 3),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 11,
                      child: imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                  color: cs.surfaceContainerHighest),
                              errorWidget: (_, __, ___) =>
                                  _placeholderImg(cs),
                            )
                          : _placeholderImg(cs),
                    ),
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.center,
                            colors: [
                              Colors.black.withValues(
                                  alpha: _hovered ? 0.62 : 0.48),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: catBg.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(catLabel,
                            style: TextStyle(
                                color: catFg,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    Positioned(
                      left: 10, right: 10, bottom: 10,
                      child: Row(
                        children: [
                          GuideAvatar(guide: tour.guide, size: 28),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              tour.guide.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(blurRadius: 4,
                                      color: Colors.black45),
                                ],
                              ),
                            ),
                          ),
                          if (tour.guide.isVerified) ...[
                            const SizedBox(width: 4),
                            VerifiedBadge(guide: tour.guide),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tour.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                              height: 1.3),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 12, color: cs.primary),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                tour.city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.5)),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('from',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.4))),
                                Text(
                                  'Rp ${_fmt(tour.minTotalPrice)}',
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            GuideRating(guide: tour.guide, showCount: false),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static (String, Color, Color) _categoryStyle(
      PriceCategory c, ColorScheme cs) =>
      switch (c) {
        PriceCategory.budget =>
          ('Budget', const Color(0xFF0F766E), const Color(0xFFCCFBF1)),
        PriceCategory.standard =>
          ('Standard', cs.primary, const Color(0xFFDCEDC8)),
        PriceCategory.premium =>
          ('Premium', const Color(0xFFB45309), const Color(0xFFFEF3C7)),
        PriceCategory.outlier =>
          ('Exclusive', const Color(0xFFC2410C), const Color(0xFFFFEDD5)),
      };

  static String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  Widget _placeholderImg(ColorScheme cs) {
    return CachedNetworkImage(
      imageUrl: _picsumUrl(widget.tour.id),
      fit: BoxFit.cover,
      placeholder: (_, __) =>
          Container(color: cs.surfaceContainerHighest),
      errorWidget: (_, __, ___) => Container(
        color: cs.primaryContainer,
        child: Icon(Icons.forest_rounded, size: 40, color: cs.primary),
      ),
    );
  }
}


class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final twoCol = constraints.maxWidth >= 680;
      if (!twoCol) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(height: 20),
          itemBuilder: (_, __) => _SkeletonCard(cs: cs),
        );
      }
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 18,
          mainAxisSpacing: 18,
          childAspectRatio: 0.68,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => _SkeletonCard(cs: cs),
      );
    });
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: cs.surfaceContainerHighest,
      highlightColor: cs.surface,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.city, this.category});
  final String city;
  final String? category;

  static const _categoryLabels = {
    'BUDGET': 'Budget',
    'STANDARD': 'Standard',
    'PREMIUM': 'Premium',
  };

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final catLabel = _categoryLabels[category];
    final String title;
    final String subtitle;
    if (catLabel != null) {
      title = city.isNotEmpty
          ? 'Sorry, no $catLabel tours found in "$city"'
          : 'Sorry, no $catLabel tours available right now';
      subtitle = 'Try a different price range or city';
    } else {
      title = city.isNotEmpty
          ? 'No tours found in "$city"'
          : 'No tours available';
      subtitle = 'Try a different city or category';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.explore_off_outlined, size: 38,
                  color: cs.primary.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.45)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_outlined, size: 48,
                color: cs.error.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text('Could not load tours',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: cs.onSurface)),
            const SizedBox(height: 8),
            Text(message,
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.45)),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}