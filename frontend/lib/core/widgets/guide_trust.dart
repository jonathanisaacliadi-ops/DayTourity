import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../features/tours/domain/entities/tour.dart';

class GuideAvatar extends StatelessWidget {
  const GuideAvatar({super.key, required this.guide, this.size = 36, this.ring = true});
  final TourGuide guide;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = guide.name.trim().split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? '' : w[0]).take(2).join().toUpperCase();

    final child = guide.avatarUrl != null
        ? CachedNetworkImage(
            imageUrl: guide.avatarUrl!,
            width: size, height: size, fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _initialsBox(cs, initials),
          )
        : _initialsBox(cs, initials);

    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: ring ? Border.all(color: Colors.white, width: 2) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _initialsBox(ColorScheme cs, String initials) => Container(
        color: cs.secondaryContainer,
        alignment: Alignment.center,
        child: Text(initials,
            style: TextStyle(
              color: cs.onSecondaryContainer,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.34,
            )),
      );
}

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, required this.guide, this.compact = true});
  final TourGuide guide;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!guide.isVerified) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.verified_user_rounded, size: compact ? 11 : 14, color: cs.primary),
        const SizedBox(width: 3),
        Text('Verified',
            style: TextStyle(
              color: cs.primary, fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 12,
            )),
      ]),
    );
  }
}

class GuideRating extends StatelessWidget {
  const GuideRating({super.key, required this.guide, this.showCount = true});
  final TourGuide guide;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!guide.hasRating) {
      return Text('New guide',
          style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.45),
              fontWeight: FontWeight.w500));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFBC02D)),
      const SizedBox(width: 2),
      Text(guide.ratingAvg!.toStringAsFixed(2),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
      if (showCount && guide.reviewCount > 0)
        Text(' (${guide.reviewCount})',
            style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.45))),
    ]);
  }
}