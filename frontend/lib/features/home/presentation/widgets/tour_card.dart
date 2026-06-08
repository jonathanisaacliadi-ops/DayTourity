import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/currency/price_text.dart';
import '../../../tours/domain/entities/tour.dart';

String _picsumUrl(String seed, {int w = 800, int h = 520}) =>
    'https://picsum.photos/seed/$seed/$w/$h';

(String, Color, Color) _categoryStyle(PriceCategory c, ColorScheme cs) =>
    switch (c) {
      PriceCategory.budget => (
          'Budget',
          const Color(0xFF0F766E),
          const Color(0xFFCCFBF1)
        ),
      PriceCategory.standard => (
          'Standard',
          cs.primary,
          const Color(0xFFDCEDC8)
        ),
      PriceCategory.premium => (
          'Premium',
          const Color(0xFFB45309),
          const Color(0xFFFEF3C7)
        ),
      PriceCategory.outlier => (
          'Exclusive',
          const Color(0xFFC2410C),
          const Color(0xFFFFEDD5)
        ),
    };

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.fg, required this.bg});
  final String label;
  final Color fg, bg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: bg.withValues(alpha: 0.93),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.cs, required this.height});
  final ColorScheme cs;
  final double height;
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: cs.surfaceContainerHighest,
        highlightColor: AppColors.surface,
        child: Container(height: height, color: cs.surfaceContainerHighest),
      );
}

class _GreenPlaceholder extends StatelessWidget {
  const _GreenPlaceholder({required this.cs});
  final ColorScheme cs;
  @override
  Widget build(BuildContext context) => Container(
        color: cs.primaryContainer,
        child: Icon(Icons.forest_rounded, size: 56, color: cs.primary),
      );
}
const double kCompactTourCardWidth = 200;
const double kCompactTourCardHeight = 300;

class CompactTourCard extends StatelessWidget {
  const CompactTourCard({super.key, required this.tour, this.onTap});
  final Tour tour;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final imageUrl = tour.coverImageUrl ??
        (tour.photos.isNotEmpty ? tour.photos.first.url : _picsumUrl(tour.id));
    final (catLabel, catFg, catBg) = _categoryStyle(tour.priceCategory, cs);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: kCompactTourCardWidth,
        height: kCompactTourCardHeight,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 5),
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
              Stack(children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _Shimmer(cs: cs, height: 180),
                    errorWidget: (_, __, ___) => _GreenPlaceholder(cs: cs),
                  ),
                ),
                Positioned(
                    top: 10,
                    left: 10,
                    child: _Pill(label: catLabel, fg: catFg, bg: catBg)),
              ]),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tour.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.location_on_outlined,
                            size: 12, color: cs.primary),
                        const SizedBox(width: 3),
                        Expanded(
                            child: Text(tour.city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color:
                                        cs.onSurface.withValues(alpha: 0.55)))),
                      ]),
                      const Spacer(),
                      Text('from',
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: cs.onSurface.withValues(alpha: 0.4))),
                      PriceText(
                        amountIdr: tour.minTotalPrice,
                        style: theme.textTheme.titleSmall?.copyWith(
                            color: cs.primary, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompactTourCardShimmer extends StatelessWidget {
  const CompactTourCardShimmer({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: cs.surfaceContainerHighest,
      highlightColor: AppColors.surface,
      child: Container(
        width: kCompactTourCardWidth,
        height: kCompactTourCardHeight,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}
