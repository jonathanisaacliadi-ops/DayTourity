import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/image_picker_platform.dart' as img_picker;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/entities/tour.dart';
import '../providers/tours_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/active_mode_provider.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../chat/presentation/pages/chat_page.dart';
import '../../../bookings/data/datasources/bookings_remote_datasource.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../../bookings/presentation/providers/reservations_provider.dart';
import '../../../bookings/presentation/providers/my_tours_provider.dart';
import 'create_tour_page.dart';

class TourDetailPage extends ConsumerWidget {
  const TourDetailPage({
    super.key,
    required this.tourId,
    this.heroTour,
    this.hideReserve = false,
  });

  final String tourId;
  final Tour? heroTour;

  final bool hideReserve;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tourAsync = ref.watch(tourDetailProvider(tourId));

    return tourAsync.when(
      loading: () =>
          _TourDetailScaffold(tour: heroTour, isLoading: true, hideReserve: hideReserve),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (tour) =>
          _TourDetailScaffold(tour: tour, isLoading: false, hideReserve: hideReserve),
    );
  }
}

class _TourDetailScaffold extends ConsumerStatefulWidget {
  const _TourDetailScaffold({
    this.tour,
    required this.isLoading,
    this.hideReserve = false,
  });
  final Tour? tour;
  final bool isLoading;
  final bool hideReserve;

  @override
  ConsumerState<_TourDetailScaffold> createState() =>
      _TourDetailScaffoldState();
}

class _TourDetailScaffoldState extends ConsumerState<_TourDetailScaffold> {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  bool _isUploadingPhoto = false;

  String get _currentUserId {
    final auth = ref.read(authProvider).value;
    return auth is AuthAuthenticated ? auth.user.id : '';
  }

  bool get _isOwner =>
      widget.tour != null &&
      widget.tour!.guide.id == _currentUserId &&
      ref.watch(activeModeProvider) == 'GUIDE';

  BookingEntity? _reservationFor(Tour tour) {
    final bookings =
        ref.watch(myToursProvider).valueOrNull?.bookings ?? const [];
    for (final b in bookings) {
      if (b.tour.id == tour.id) return b;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tour = widget.tour;
    final isLoading = widget.isLoading;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: cs.surface,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: tour == null
                  ? Container(color: cs.primaryContainer)
                  : _CoverGallery(tour: tour),
            ),
          ),

          SliverToBoxAdapter(
            child: isLoading || tour == null
                ? const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _TourBody(
                    tour: tour,
                    isOwner: _isOwner,
                    isUploadingPhoto: _isUploadingPhoto,
                    reservation: _reservationFor(tour),
                    onAddPhoto: () => _addPhoto(context),
                    onEditTour: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateTourPage(editingTour: tour),
                      ),
                    ),
                    onDeleteTour: () => _confirmDelete(context),
                    onDeletePhoto: (photoId) => _deletePhoto(context, photoId),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: (isLoading || tour == null || _isOwner)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _openChat(context, tour, _currentUserId),
                        icon: const Icon(Icons.chat_outlined),
                        label: const Text('Chat Guide'),
                      ),
                    ),
                    if (!widget.hideReserve) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: _reserveOrCancelButton(context, tour),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }


  Future<void> _openReservationSheet(BuildContext context, Tour tour) async {
    final reserved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReservationSheet(tour: tour),
    );
    if (reserved == true && mounted) {
      ref.invalidate(myToursProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tour reserved! Check it in My Trips.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  Widget _reserveOrCancelButton(BuildContext context, Tour tour) {
    final reservation = _reservationFor(tour);

    if (reservation == null) {
      return ElevatedButton.icon(
        onPressed: () => _openReservationSheet(context, tour),
        icon: const Icon(Icons.calendar_today_outlined),
        label: const Text('Reserve'),
      );
    }

    if (!reservation.canCancel) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.event_available_outlined),
        label: const Text('Reserved'),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _cancelReservation(context, reservation),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.redAccent,
        side: const BorderSide(color: Colors.redAccent),
      ),
      icon: const Icon(Icons.cancel_outlined),
      label: const Text('Cancel Reservation'),
    );
  }

  Future<void> _cancelReservation(
      BuildContext context, BookingEntity reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel reservation?'),
        content: const Text(
            'Cancel your reservation for this tour? This cannot be undone.'),
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
            bookingId: reservation.id,
          );
      ref.invalidate(myToursProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reservation cancelled.')),
        );
      }
    } on BookingsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not cancel. Please try again.')),
        );
      }
    }
  }

  Future<void> _openChat(
      BuildContext context, Tour tour, String userId) async {
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please log in to chat')));
      return;
    }
    try {
      final conv = await ref
          .read(conversationsProvider.notifier)
          .findOrCreate(tourId: tour.id, guideId: tour.guide.id);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatPage(conversation: conv)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open chat: $e')));
    }
  }

  Future<void> _addPhoto(BuildContext context) async {
    final file = await img_picker.pickImage();
    if (file == null || !mounted) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final token = await _storage.read(key: 'access_token') ?? '';
      final url = await ref.read(toursDatasourceProvider).uploadImage(
            token: token,
            file: file,
          );
      await ref.read(addPhotoProvider((tourId: widget.tour!.id, url: url)).future);
      ref.invalidate(tourDetailProvider(widget.tour!.id));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _deletePhoto(BuildContext context, String photoId) async {
    try {
      await ref.read(
          deletePhotoProvider((tourId: widget.tour!.id, photoId: photoId))
              .future);
      ref.invalidate(tourDetailProvider(widget.tour!.id));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove photo: $e')));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tour'),
        content: const Text(
            'Are you sure you want to delete this tour? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(deleteTourProvider(widget.tour!.id).future);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tour deleted successfully')));
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')));
    }
  }
}

class _CoverGallery extends StatefulWidget {
  const _CoverGallery({required this.tour});
  final Tour tour;

  @override
  State<_CoverGallery> createState() => _CoverGalleryState();
}

class _CoverGalleryState extends State<_CoverGallery> {
  final PageController _pageController = PageController();
  Timer? _autoPlayTimer;
  int _current = 0;

  List<String> get _allUrls {
    final urls = <String>[];
    if (widget.tour.coverImageUrl != null) {
      urls.add(widget.tour.coverImageUrl!);
    }
    for (final p in widget.tour.photos) {
      if (!urls.contains(p.url)) urls.add(p.url);
    }
    return urls;
  }

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant _CoverGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.tour.coverImageUrl != widget.tour.coverImageUrl ||
            oldWidget.tour.photos.length != widget.tour.photos.length;
    if (changed) _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (_allUrls.length <= 1) return;
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final count = _allUrls.length;
      if (count <= 1) return;
      final next = (_current + 1) % count;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final urls = _allUrls;

    if (urls.isEmpty) {
      urls.add(
          'https://picsum.photos/seed/${widget.tour.id}/900/600');
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: urls.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _openPhotoViewer(context, urls, i),
            child: CachedNetworkImage(
              imageUrl: urls[i],
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (_, __) => Container(color: cs.primaryContainer),
              errorWidget: (_, __, ___) => Image.network(
                'https://picsum.photos/seed/${widget.tour.id}_$i/900/600',
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  color: cs.primaryContainer,
                  child: Icon(Icons.forest_rounded,
                      size: 80, color: cs.primary),
                ),
              ),
            ),
          ),
        ),
        if (urls.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                urls.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _current == i ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _current == i
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        if (urls.length > 1)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_outlined,
                      size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${_current + 1}/${urls.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TourBody extends StatefulWidget {
  const _TourBody({
    required this.tour,
    required this.isOwner,
    required this.isUploadingPhoto,
    required this.onAddPhoto,
    required this.onEditTour,
    required this.onDeleteTour,
    required this.onDeletePhoto,
    this.reservation,
  });

  final Tour tour;
  final bool isOwner;
  final bool isUploadingPhoto;
  final VoidCallback onAddPhoto;
  final VoidCallback onEditTour;
  final VoidCallback onDeleteTour;
  final ValueChanged<String> onDeletePhoto;
  final BookingEntity? reservation;

  @override
  State<_TourBody> createState() => _TourBodyState();
}

class _TourBodyState extends State<_TourBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final tour  = widget.tour;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tour.title,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: cs.primaryContainer,
                  child: Text(tour.guide.name[0].toUpperCase(),
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold,
                          color: cs.primary)),
                ),
                const SizedBox(width: 8),
                Text('By ${tour.guide.name}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
                const Spacer(),
                Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  tour.guide.hasRating
                      ? tour.guide.ratingAvg!.toStringAsFixed(1)
                      : 'New',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ]),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Row(children: [
            Expanded(child: _InfoPill(
              label: 'Meeting point',
              value: tour.city,
              valueColor: cs.primary,
            )),
            const SizedBox(width: 10),
            _InfoPill(
              label: 'Activities',
              value: '${tour.activities.length}',
              icon: Icons.format_list_bulleted_rounded,
            ),
            const SizedBox(width: 10),
            _InfoPill(
              label: 'Dates',
              value: '${tour.upcomingDates.length}',
              icon: Icons.calendar_month_outlined,
            ),
          ]),
        ),

        if (widget.isOwner) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _OwnerActions(
              isUploading: widget.isUploadingPhoto,
              onAddPhoto: widget.onAddPhoto,
              onEditTour: widget.onEditTour,
              onDeleteTour: widget.onDeleteTour,
            ),
          ),
        ],

        if (widget.reservation != null &&
            widget.reservation!.status != TourStatus.cancelled) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _GuideContactCard(reservation: widget.reservation!),
          ),
        ],

        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabCtrl,
              labelColor: cs.onPrimary,
              unselectedLabelColor: cs.onSurface.withValues(alpha: 0.55),
              indicator: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Description'),
                Tab(text: 'Activities'),
                Tab(text: 'Dates'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _tabCtrl,
          builder: (context, _) {
            return IndexedStack(
              index: _tabCtrl.index,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tour.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.7,
                            color: cs.onSurface.withValues(alpha: 0.8))),
                      if (tour.photos.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Photo Gallery',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            if (widget.isOwner)
                              Text('Tap × to remove',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: cs.onSurface.withValues(alpha: 0.4))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 110,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: tour.photos.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) => _PhotoThumbnail(
                              photo: tour.photos[i],
                              canDelete: widget.isOwner,
                              onDelete: () => widget.onDeletePhoto(tour.photos[i].id),
                              onView: () => _openPhotoViewer(
                                context,
                                [for (final p in tour.photos) p.url],
                                i,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Price includes',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700,
                                  color: cs.primary)),
                      const SizedBox(height: 12),
                      if (tour.basePrice > 0)
                        _ActivityCard(
                          icon: Icons.tour_outlined,
                          title: 'Base tour price',
                          price: tour.basePriceDisplay,
                          cs: cs, theme: theme,
                        ),
                      if (tour.basePrice > 0) const SizedBox(height: 10),
                      ...tour.activities.map((act) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ActivityCard(
                          icon: Icons.check_circle_outline_rounded,
                          title: act.name,
                          subtitle: act.description,
                          price: act.priceDisplay,
                          cs: cs, theme: theme,
                        ),
                      )),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: cs.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Price',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            Text(tour.startingPriceDisplay,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: tour.upcomingDates.isEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('No upcoming dates set.',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(
                                      color: cs.onSurface.withValues(alpha: 0.5))),
                            const SizedBox(height: 6),
                            Text('Contact the guide to arrange a date.',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(
                                      color: cs.onSurface.withValues(alpha: 0.4))),
                          ],
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: tour.upcomingDates
                              .map((d) => _DateChip(date: d, cs: cs))
                              .toList(),
                        ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}


class _GuideContactCard extends StatelessWidget {
  const _GuideContactCard({required this.reservation});
  final BookingEntity reservation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final phone = reservation.guide?.phone;
    final hasPhone = phone != null && phone.trim().isNotEmpty;
    final revealed = reservation.isGuideContactRevealed;

    final String title;
    final String message;
    final IconData icon;
    if (revealed && hasPhone) {
      title = 'Guide contact';
      message = phone;
      icon = Icons.call_outlined;
    } else if (revealed) {
      title = 'Guide contact';
      message = "The guide hasn't added a contact number yet — use chat to reach out.";
      icon = Icons.call_outlined;
    } else {
      title = 'Contact unlocks soon';
      message = "The guide's contact number will be shown here 48 hours before the tour starts.";
      icon = Icons.lock_clock_outlined;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: revealed && hasPhone
            ? cs.primary.withValues(alpha: 0.06)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: revealed && hasPhone
              ? cs.primary.withValues(alpha: 0.2)
              : cs.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: revealed && hasPhone
                  ? cs.primaryContainer
                  : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 18,
                color: revealed && hasPhone
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.4)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(message,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface
                            .withValues(alpha: revealed && hasPhone ? 0.75 : 0.5))),
              ],
            ),
          ),
          if (revealed && hasPhone)
            IconButton(
              tooltip: 'Copy number',
              icon: Icon(Icons.copy_rounded, size: 18, color: cs.primary),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: phone));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone number copied')),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
  });
  final String label, value;
  final IconData? icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurface.withValues(alpha: 0.45))),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: valueColor ?? cs.primary),
              const SizedBox(width: 4),
            ],
            Flexible(child: Text(value,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: valueColor ?? cs.onSurface,
              ))),
          ]),
        ],
      ),
    );
  }
}


class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.icon,
    required this.title,
    required this.price,
    required this.cs,
    required this.theme,
    this.subtitle,
  });
  final IconData icon;
  final String title, price;
  final String? subtitle;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: cs.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            if (subtitle != null)
              Text(subtitle!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
          ],
        )),
        Text(price,
            style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
      ]),
    );
  }
}

class _OwnerActions extends StatelessWidget {
  const _OwnerActions({
    required this.isUploading,
    required this.onAddPhoto,
    required this.onEditTour,
    required this.onDeleteTour,
  });

  final bool isUploading;
  final VoidCallback onAddPhoto;
  final VoidCallback onEditTour;
  final VoidCallback onDeleteTour;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isUploading ? null : onAddPhoto,
                icon: isUploading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined, size: 20),
                label: Text(isUploading ? 'Uploading…' : 'Add Photo'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEditTour,
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: const Text('Edit Tour'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onDeleteTour,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            label: const Text('Delete Tour'),
          ),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date, required this.cs});
  final DateTime date;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 14, color: cs.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            DateFormat('EEE, dd MMM yyyy').format(date),
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({
    required this.photo,
    required this.canDelete,
    required this.onDelete,
    required this.onView,
  });

  final TourPhoto photo;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onView,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: photo.url,
              width: 110,
              height: 110,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(color: cs.surfaceContainerHighest),
              errorWidget: (_, __, ___) => Image.network(
                'https://picsum.photos/seed/${photo.id}/220/220',
                width: 110,
                height: 110,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: cs.primaryContainer,
                  child: Icon(Icons.forest_rounded, color: cs.primary),
                ),
              ),
            ),
          ),
        ),
        if (canDelete)
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

void _openPhotoViewer(
    BuildContext context, List<String> urls, int initialIndex) {
  if (urls.isEmpty) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PhotoViewerPage(urls: urls, initialIndex: initialIndex),
    ),
  );
}

class _PhotoViewerPage extends StatefulWidget {
  const _PhotoViewerPage({required this.urls, required this.initialIndex});
  final List<String> urls;
  final int initialIndex;

  @override
  State<_PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<_PhotoViewerPage> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const ColoredBox(color: Colors.black),
            ),
          ),
          PageView.builder(
            controller: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.urls[i],
                  fit: BoxFit.contain,
                  width: double.infinity,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (_, __, ___) => Image.network(
                    'https://picsum.photos/seed/viewer_${widget.urls[i].hashCode.abs()}/1200/800',
                    fit: BoxFit.contain,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.image_not_supported_outlined,
                          color: Colors.white38, size: 64),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: topInset + 4,
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (widget.urls.length > 1)
            Positioned(
              top: topInset + 12,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_index + 1} / ${widget.urls.length}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReservationSheet extends ConsumerStatefulWidget {
  const _ReservationSheet({required this.tour});
  final Tour tour;

  @override
  ConsumerState<_ReservationSheet> createState() => _ReservationSheetState();
}

class _ReservationSheetState extends ConsumerState<_ReservationSheet> {
  DateTime? _selectedDate;
  final _notesCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final dates = widget.tour.upcomingDates;
    if (dates.isNotEmpty) _selectedDate = dates.first;
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFallbackDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _confirm() async {
    if (_selectedDate == null) {
      setState(() => _error = 'Please choose a date.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = ref.read(authProvider).valueOrNull;
    if (auth is! AuthAuthenticated) {
      setState(() {
        _error = 'Please log in to reserve.';
        _loading = false;
      });
      return;
    }

    try {
      await ref.read(bookingsDatasourceProvider).reserve(
            token: auth.token,
            tourId: widget.tour.id,
            scheduledDate: _selectedDate!.toIso8601String(),
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } on BookingsException catch (e) {
      if (mounted) setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dates = widget.tour.upcomingDates;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Reserve this tour',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(widget.tour.title,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 18),
          Text('Select a date', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (dates.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dates.map((d) {
                final selected =
                    _selectedDate != null && _sameDay(_selectedDate!, d);
                return ChoiceChip(
                  label: Text(DateFormat('EEE, dd MMM').format(d)),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedDate = d),
                  selectedColor: cs.primaryContainer,
                );
              }).toList(),
            )
          else
            OutlinedButton.icon(
              onPressed: _pickFallbackDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(_selectedDate == null
                  ? 'Pick a date'
                  : DateFormat('EEE, dd MMM yyyy').format(_selectedDate!)),
            ),
          const SizedBox(height: 18),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
                labelText: 'Notes for the guide (optional)'),
            maxLines: 2,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: theme.textTheme.titleMedium),
                Text(
                  'Rp ${_fmt(widget.tour.totalPrice)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: cs.primary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _confirm,
              child: _loading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm Reservation'),
            ),
          ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
}
