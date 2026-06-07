import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/green_page_header.dart';
import '../../data/datasources/bookings_remote_datasource.dart';
import '../../domain/entities/booking_entity.dart';
import '../providers/my_tours_provider.dart';
import '../providers/reservations_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../shell/presentation/pages/main_shell.dart';
import '../../../tours/presentation/pages/tour_detail_page.dart';

class MyTripsPage extends ConsumerWidget {
  const MyTripsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(myToursProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: asyncState.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(myToursProvider)),
        data: (state) {
          if (state.isLoading) {
            return _buildBody(context, ref, state, showRefreshing: true);
          }
          if (state.hasError) {
            return _ErrorView(
              message: state.errorMessage!,
              onRetry: () => ref.read(myToursProvider.notifier).refresh(),
            );
          }
          return _buildBody(context, ref, state);
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    MyToursState state, {
    bool showRefreshing = false,
  }) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: GreenPageHeader(
            title: 'My Trips',
            actions: [
              if (showRefreshing)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                IconButton(
                  onPressed: () => ref.read(myToursProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  tooltip: 'Refresh',
                ),
            ],
          ),
        ),
        if (state.bookings.isEmpty)
          const SliverFillRemaining(child: _EmptyStateView())
        else ...[
          if (state.bookings.any((b) => b.status == TourStatus.ongoing)) ...[
            _SliverSectionHeader(
              label: 'Ongoing',
              icon: Icons.directions_walk_rounded,
              color: Colors.green,
            ),
            _bookingGrid(
              context,
              ref,
              state.bookings
                  .where((b) => b.status == TourStatus.ongoing)
                  .toList(),
            ),
          ],
          if (state.bookings.any((b) => b.status == TourStatus.planned)) ...[
            _SliverSectionHeader(
              label: 'Upcoming',
              icon: Icons.calendar_month_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            _bookingGrid(
              context,
              ref,
              state.bookings
                  .where((b) => b.status == TourStatus.planned)
                  .toList(),
            ),
          ],

          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ],
    );
  }

  Widget _bookingGrid(
    BuildContext context,
    WidgetRef ref,
    List<BookingEntity> items,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 340,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => _BookingCard(
            booking: items[i],
            onCancel: () => _confirmCancel(context, ref, items[i]),
          ),
          childCount: items.length,
        ),
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    BookingEntity booking,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel reservation?'),
        content: Text(
            'Cancel your reservation for "${booking.tour.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Tour'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final auth = ref.read(authProvider).valueOrNull;
    if (auth is! AuthAuthenticated) return;

    try {
      await ref.read(bookingsDatasourceProvider).cancel(
            token: auth.token,
            bookingId: booking.id,
          );
      ref.invalidate(myToursProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reservation cancelled.')),
        );
      }
    } on BookingsException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not cancel. Please try again.')),
        );
      }
    }
  }
}

class _SliverSectionHeader extends StatelessWidget {
  const _SliverSectionHeader({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onCancel});

  final BookingEntity booking;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TourDetailPage(tourId: booking.tour.id, hideReserve: true),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
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
                  child: Image.network(
                    booking.tour.coverImageUrl ??
                        'https://picsum.photos/seed/${booking.tour.id}/600/360',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) =>
                        _PlaceholderImage(seed: booking.tour.id),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: _DateBadge(date: booking.scheduledDate),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: _StatusBadge(status: booking.status),
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
                      booking.tour.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Rp ${_fmt(booking.agreedPrice)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                        ),
                        if (booking.canCancel)
                          OutlinedButton(
                            onPressed: onCancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              minimumSize: const Size(64, 30),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Cancel',
                                style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final TourStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, bgColor) = switch (status) {
      TourStatus.ongoing => (
          'Ongoing',
          Colors.green.shade700,
          Colors.green.shade50
        ),
      TourStatus.planned => (
          'Scheduled',
          Colors.blue.shade700,
          Colors.blue.shade50
        ),
      TourStatus.completed => (
          'Completed',
          Colors.grey.shade700,
          Colors.grey.shade100
        ),
      TourStatus.cancelled => (
          'Cancelled',
          Colors.red.shade700,
          Colors.red.shade50
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('EEE').format(date).toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.black54,
              letterSpacing: 0.4,
              height: 1.3,
            ),
          ),
          Text(
            DateFormat('MMM').format(date).toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.black54,
              letterSpacing: 0.4,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            DateFormat('d').format(date),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  final String seed;
  const _PlaceholderImage({required this.seed});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Image.network(
      'https://picsum.photos/seed/$seed/400/240',
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => Container(
        color: cs.primaryContainer,
        child: Icon(Icons.forest_rounded, size: 36, color: cs.primary),
      ),
    );
  }
}

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.luggage_rounded,
                size: 48,
                color: colorScheme.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Trips Yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tours you book will appear here. Start exploring and discover new experiences!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => MainShell.jumpTo(context, 1),
              icon: const Icon(Icons.explore_rounded),
              label: const Text('Explore Tours'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 48, color: colorScheme.error.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
