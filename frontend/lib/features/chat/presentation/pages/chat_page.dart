import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/currency/price_text.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/itinerary_proposal.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/chat_provider.dart';
import '../widgets/itinerary_builder_sheet.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../tours/domain/entities/tour.dart';
import '../../../tours/presentation/providers/tours_provider.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../../bookings/presentation/providers/my_tours_provider.dart';
import '../../../bookings/presentation/providers/reservations_provider.dart';

class ChatPage extends ConsumerStatefulWidget {
  final ConversationEntity conversation;

  const ChatPage({super.key, required this.conversation});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isTyping = false;

  late final ChatRoomParams _roomParams = (
    conversationId: widget.conversation.id,
    initialBookingStatus: widget.conversation.bookingStatus,
  );

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleTyping() {
    final notifier = ref.read(chatRoomProvider(_roomParams).notifier);
    if (!_isTyping) {
      _isTyping = true;
      notifier.notifyTyping(true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
      notifier.notifyTyping(false);
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    _typingTimer?.cancel();
    _isTyping = false;
    ref.read(chatRoomProvider(_roomParams).notifier).sendMessage(text);
  }

  bool _hasReservation(WidgetRef ref, bool isGuide) {
    final tourId = widget.conversation.tour?.id;
    if (tourId == null) return false;

    if (isGuide) {
      final bookings = ref.watch(guideBookingsProvider).valueOrNull ?? const [];
      return bookings.any((b) =>
          b.tour.id == tourId &&
          b.traveller?.id == widget.conversation.user.id &&
          b.status != TourStatus.cancelled);
    }

    final bookings = ref.watch(myToursProvider).valueOrNull?.bookings ?? const [];
    return bookings.any((b) => b.tour.id == tourId);
  }

  Future<void> _openItineraryBuilder(Tour? tour) async {
    final proposal = await showModalBottomSheet<ItineraryProposal>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItineraryBuilderSheet(
        tourTitle: tour?.title ?? widget.conversation.tour?.title,
        initialActivities: tour?.activities,
      ),
    );
    if (proposal != null && mounted) {
      ref
          .read(chatRoomProvider(_roomParams).notifier)
          .sendItineraryProposal(proposal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chatState = ref.watch(chatRoomProvider(_roomParams));
    final authState = ref.watch(authProvider).value;

    final Tour? tour = widget.conversation.tour != null
        ? ref
            .watch(tourDetailProvider(widget.conversation.tour!.id))
            .valueOrNull
        : null;

    final currentUserId =
        authState is AuthAuthenticated ? authState.user.id : '';
    final isGuide = currentUserId == widget.conversation.guide.id;

    final otherPartyName = isGuide
        ? widget.conversation.user.name
        : widget.conversation.guide.name;

    final reserved = _hasReservation(ref, isGuide);

    ref.listen(chatRoomProvider(_roomParams), (_, next) {
      if (!next.isLoading) _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              otherPartyName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (widget.conversation.tour != null)
              Text(
                widget.conversation.tour!.title,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6)),
              ),
          ],
        ),
        actions: [
          _BookingStatusChip(
            status: reserved ? 'RESERVED' : chatState.bookingStatus,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatState.error != null
                    ? _ErrorView(error: chatState.error!)
                    : _MessagesList(
                        messages: chatState.messages,
                        currentUserId: currentUserId,
                        scrollController: _scrollController,
                        bookingStatus: chatState.bookingStatus,
                        isAccepting: chatState.isAccepting,
                        tour: tour,
                        otherPartyName: otherPartyName,
                        onAccept: isGuide
                            ? null
                            : () => ref
                                .read(chatRoomProvider(_roomParams).notifier)
                                .acceptProposal(),
                      ),
          ),
          if (chatState.isTyping)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '$otherPartyName is typing...',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          _MessageInputBar(
            controller: _textController,
            onChanged: (_) => _handleTyping(),
            onSend: _sendMessage,
            isSendingProposal: chatState.isSendingProposal,
            onBuildItinerary: isGuide ? () => _openItineraryBuilder(tour) : null,
          ),
        ],
      ),
    );
  }
}


class _MessagesList extends StatelessWidget {
  final List<MessageEntity> messages;
  final String currentUserId;
  final ScrollController scrollController;
  final String bookingStatus;
  final bool isAccepting;
  final VoidCallback? onAccept;
  final Tour? tour;
  final String otherPartyName;

  const _MessagesList({
    required this.messages,
    required this.currentUserId,
    required this.scrollController,
    required this.bookingStatus,
    required this.isAccepting,
    required this.otherPartyName,
    this.onAccept,
    this.tour,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final hasTourCard = tour != null;
    final hasEmptyHint = messages.isEmpty;
    final headerCount = hasTourCard ? 1 : 0;
    final emptyHintCount = hasEmptyHint ? 1 : 0;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: messages.length + headerCount + emptyHintCount,
      itemBuilder: (ctx, i) {
        if (hasTourCard && i == 0) {
          return _TourInquiryCard(tour: tour!);
        }

        final adjustedI = i - headerCount;
        if (hasEmptyHint && adjustedI == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 40,
                    color: cs.primary.withValues(alpha: 0.3)),
                const SizedBox(height: 10),
                Text(
                  'Send a message to start chatting\nwith $otherPartyName',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.45),
                      fontSize: 13),
                ),
              ],
            ),
          );
        }

        final msgI = adjustedI - emptyHintCount;
        final msg = messages[msgI];
        final isMine = msg.sender.id == currentUserId;
        if (msg.type == MessageType.itineraryProposal) {
          return _ItineraryProposalBubble(
            message: msg,
            isMine: isMine,
            bookingStatus: bookingStatus,
            isAccepting: isAccepting,
            onAccept: onAccept,
          );
        }
        return _MessageBubble(message: msg, isMine: isMine);
      },
    );
  }
}


class _TourInquiryCard extends StatelessWidget {
  final Tour tour;
  const _TourInquiryCard({required this.tour});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(14)),
            child: CachedNetworkImage(
              imageUrl: tour.coverImageUrl ??
                  'https://picsum.photos/seed/${tour.id}/600/360',
              height: 140,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (_, __) => Container(
                height: 140,
                color: cs.primaryContainer,
              ),
              errorWidget: (_, __, ___) => Container(
                height: 140,
                color: cs.primaryContainer,
                child: Icon(Icons.forest_rounded,
                    size: 48, color: cs.primary),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 11, color: cs.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Tour Inquiry',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: cs.primary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Text(tour.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 13, color: cs.primary),
                    const SizedBox(width: 3),
                    Text(tour.city,
                        style: TextStyle(
                            fontSize: 12, color: cs.primary)),
                  ],
                ),
                const SizedBox(height: 12),

                if (tour.activities.isNotEmpty) ...[
                  Text('Included Activities',
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.55))),
                  const SizedBox(height: 6),
                  ...tour.activities.take(4).map((act) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 14, color: cs.primary),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(act.name,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            PriceText(
                              amountIdr: act.priceAmountIdr,
                              rangeEndIdr: act.priceRangeEndIdr,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )),
                  if (tour.activities.length > 4)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '+${tour.activities.length - 4} more activities',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.45),
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  const Divider(height: 20),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Starting from',
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                cs.onSurface.withValues(alpha: 0.55))),
                    PriceText(
                      amountIdr: tour.totalPrice,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _ReadReceipt extends StatelessWidget {
  final bool isRead;
  const _ReadReceipt({required this.isRead});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (isRead) {
      return Icon(Icons.done_all_rounded, size: 14, color: Colors.blue.shade300);
    }
    return Icon(
      Icons.done_rounded,
      size: 14,
      color: cs.onSurface.withValues(alpha: 0.4),
    );
  }
}


class _MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMine ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.sender.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
              ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: message.content,
                    style: TextStyle(
                      color: isMine ? cs.onPrimary : cs.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('HH:mm')
                                .format(message.createdAt.toLocal()),
                            style: TextStyle(
                              fontSize: 10,
                              color: (isMine ? cs.onPrimary : cs.onSurface)
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          if (isMine) ...[
                            const SizedBox(width: 4),
                            _ReadReceipt(isRead: message.isRead),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _ItineraryProposalBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMine;
  final String bookingStatus;
  final bool isAccepting;
  final VoidCallback? onAccept;

  const _ItineraryProposalBubble({
    required this.message,
    required this.isMine,
    required this.bookingStatus,
    required this.isAccepting,
    this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final proposal = message.proposal;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.88),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.primary, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Icon(Icons.route_outlined,
                      color: cs.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          proposal?.title ?? 'Custom Itinerary Proposal',
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (proposal?.date != null)
                          Text(
                            proposal!.date!,
                            style: TextStyle(
                              color:
                                  cs.primary.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('HH:mm')
                            .format(message.createdAt.toLocal()),
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(height: 2),
                        _ReadReceipt(isRead: message.isRead),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (proposal != null &&
                      proposal.activities.isNotEmpty) ...[
                    Text('Activities',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color:
                                cs.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 8),
                    ...proposal.activities.asMap().entries.map((e) {
                      final idx = e.key;
                      final act = e.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor:
                                  cs.primaryContainer,
                              child: Text(
                                '${idx + 1}',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: cs.primary,
                                    fontWeight:
                                        FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(act.name,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight.w600)),
                                  if (act.duration != null ||
                                      act.price != null)
                                    Row(
                                      children: [
                                        if (act.duration != null)
                                          Text(act.duration!,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: cs.onSurface
                                                      .withValues(alpha: 0.6))),
                                        if (act.duration != null &&
                                            act.price != null)
                                          Text(' · ',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: cs.onSurface
                                                      .withValues(alpha: 0.6))),
                                        if (act.price != null)
                                          PriceText(
                                            amountIdr: act.price,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: cs.onSurface
                                                    .withValues(alpha: 0.6)),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (proposal.displayTotal > 0) ...[
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total',
                              style: theme.textTheme.titleSmall),
                          PriceText(
                            amountIdr: proposal.displayTotal,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ] else
                    Text(
                      message.content,
                      style: TextStyle(
                          color: cs.onSurface, fontSize: 13),
                    ),

                  if (proposal?.note != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.notes_outlined,
                              size: 16,
                              color: cs.onSurface
                                  .withValues(alpha: 0.5)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              proposal!.note!,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface
                                      .withValues(alpha: 0.8),
                                  fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _ProposalActionArea(
              isMine: isMine,
              bookingStatus: bookingStatus,
              isAccepting: isAccepting,
              onAccept: onAccept,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProposalActionArea extends StatelessWidget {
  final bool isMine;
  final String bookingStatus;
  final bool isAccepting;
  final VoidCallback? onAccept;

  const _ProposalActionArea({
    required this.isMine,
    required this.bookingStatus,
    required this.isAccepting,
    this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (bookingStatus == 'ACCEPTED' || bookingStatus == 'PAID') {
      final (icon, label, color) = bookingStatus == 'PAID'
          ? (Icons.payments_rounded, 'Paid', Colors.teal)
          : (Icons.check_circle_rounded, 'Accepted', Colors.green);
      return Padding(
        padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ],
        ),
      );
    }

    final canAccept = !isMine && bookingStatus == 'PROPOSED';
    if (!canAccept) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
      child: FilledButton.icon(
        icon: isAccepting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.check_circle_outline, size: 18),
        label: Text(isAccepting ? 'Confirming…' : 'Accept & Confirm'),
        onPressed: isAccepting ? null : onAccept,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final bool isSendingProposal;

  final VoidCallback? onBuildItinerary;

  const _MessageInputBar({
    required this.controller,
    required this.onChanged,
    required this.onSend,
    required this.isSendingProposal,
    this.onBuildItinerary,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 8),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
            top: BorderSide(color: cs.outline.withValues(alpha: 0.2))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (onBuildItinerary != null)
              isSendingProposal
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Build Itinerary',
                      icon: Icon(Icons.route_outlined, color: cs.primary),
                      onPressed: onBuildItinerary,
                    ),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                onSubmitted: (_) => onSend(),
                textInputAction: TextInputAction.send,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.send_rounded),
              onPressed: onSend,
              style: IconButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingStatusChip extends StatelessWidget {
  final String status;
  const _BookingStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      'RESERVED'    => ('Reserved', Colors.teal),
      'NEGOTIATING' => ('Negotiating', Colors.orange),
      'PROPOSED'    => ('Proposed', Colors.blue),
      'ACCEPTED'    => ('Accepted', Colors.green),
      'PAID'        => ('Paid', Colors.teal),
      _             => (status, cs.primary),
    };
    return Chip(
      label: Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color, width: 1),
      labelStyle: TextStyle(color: color),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EmptyChat extends StatelessWidget {
  final String otherPartyName;
  const _EmptyChat({required this.otherPartyName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 64, color: cs.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Start chatting with $otherPartyName',
            style:
                TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
