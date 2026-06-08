import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/green_page_header.dart';
import '../../../../core/currency/price_text.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../../bookings/presentation/providers/reservations_provider.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBookings = ref.watch(guideBookingsProvider);

    return Scaffold(
      body: Column(
        children: [
          GreenPageHeader(
            title: 'Reservations',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(guideBookingsProvider),
              ),
            ],
          ),
          Expanded(
            child: asyncBookings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(guideBookingsProvider),
              ),
              data: (bookings) {
                if (bookings.isEmpty) return const _EmptyView();
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(guideBookingsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: bookings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        _ReservationCard(booking: bookings[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.booking});
  final BookingEntity booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final travellerName = booking.traveller?.name ?? 'Traveller';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  travellerName.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                      color: cs.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(travellerName,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text('reserved your tour',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withOpacity(0.55))),
                  ],
                ),
              ),
              _StatusBadge(status: booking.status),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: cs.outlineVariant.withOpacity(0.4), height: 1),
          const SizedBox(height: 12),
          _InfoLine(icon: Icons.tour_outlined, text: booking.tour.title),
          const SizedBox(height: 6),
          _InfoLine(
            icon: Icons.calendar_today_rounded,
            text: DateFormat('EEE, dd MMM yyyy').format(booking.scheduledDate),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 15, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              PriceText(
                amountIdr: booking.agreedPrice,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
              ),
            ],
          ),
          if (booking.notes != null && booking.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            _InfoLine(icon: Icons.sticky_note_2_outlined, text: booking.notes!),
          ],
        ],
      ),
    );
  }

}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text, this.bold = false});
  final IconData icon;
  final String text;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 15, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                  color: bold ? cs.onSurface : cs.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final TourStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      TourStatus.ongoing => ('Ongoing', Colors.green.shade700, Colors.green.shade50),
      TourStatus.planned => ('Reserved', Colors.blue.shade700, Colors.blue.shade50),
      TourStatus.completed => ('Completed', Colors.grey.shade700, Colors.grey.shade100),
      TourStatus.cancelled => ('Cancelled', Colors.red.shade700, Colors.red.shade50),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                color: cs.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event_available_outlined,
                  size: 48, color: cs.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            Text('No reservations yet',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'When travellers reserve your tours, they\'ll show up here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: cs.error.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant)),
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
