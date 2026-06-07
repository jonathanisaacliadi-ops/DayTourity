import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/green_page_header.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/chat_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'chat_page.dart';

class ConversationsPage extends ConsumerWidget {
  const ConversationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs           = Theme.of(context).colorScheme;
    final asyncConvs   = ref.watch(conversationsProvider);
    final authState    = ref.watch(authProvider).valueOrNull;
    final currentUserId =
        authState is AuthAuthenticated ? authState.user.id : '';

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: GreenPageHeader(title: 'Messages'),
          ),
          SliverFillRemaining(
            child: asyncConvs.when(
              loading: () => const _LoadingState(),
              error:   (e, _) => _ErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(conversationsProvider)),
              data: (convs) => convs.isEmpty
                  ? const _EmptyState()
                  : _ConversationList(
                      convs: convs, currentUserId: currentUserId,
                      onRefresh: () async =>
                          ref.invalidate(conversationsProvider)),
            ),
          ),
        ],
      ),
    );
  }
}


class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.convs,
    required this.currentUserId,
    required this.onRefresh,
  });
  final List<ConversationEntity> convs;
  final String currentUserId;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: convs.length,
          itemBuilder: (_, i) => _ConvTile(
              conv: convs[i], currentUserId: currentUserId),
        ),
      );
}


class _ConvTile extends StatefulWidget {
  const _ConvTile({required this.conv, required this.currentUserId});
  final ConversationEntity conv;
  final String currentUserId;

  @override
  State<_ConvTile> createState() => _ConvTileState();
}

class _ConvTileState extends State<_ConvTile> {
  bool _hovered = false;

  ConversationParticipant get _other => widget.conv.guide.id == widget.currentUserId
      ? widget.conv.user
      : widget.conv.guide;

  bool get _hasUnread {
    final last = widget.conv.lastMessage;
    return last != null &&
        !last.isRead &&
        last.sender.id != widget.currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final theme  = Theme.of(context);
    final other  = _other;
    final lastMsg = widget.conv.lastMessage;
    final initials = other.name.trim().split(RegExp(r'\s+')).map((w) => w.isEmpty ? '' : w[0]).take(2).join().toUpperCase();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => ChatPage(conversation: widget.conv))),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hovered ? cs.primary.withValues(alpha: 0.04) : cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hasUnread
                  ? cs.primary.withValues(alpha: 0.35)
                  : cs.outline.withValues(alpha: 0.4),
              width: _hasUnread ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.09 : 0.05),
                blurRadius: _hovered ? 14 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(children: [
            Stack(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: cs.primaryContainer,
                child: Text(initials,
                  style: TextStyle(color: cs.primary,
                      fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              if (_hasUnread)
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 13, height: 13,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 2),
                    ),
                  ),
                ),
            ]),
            const SizedBox(width: 14),

            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(other.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: _hasUnread ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 15, color: cs.onSurface,
                    ))),
                  if (lastMsg != null)
                    Text(_formatTime(lastMsg.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: _hasUnread
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: 0.4),
                        fontWeight: _hasUnread ? FontWeight.w700 : FontWeight.w400,
                      )),
                ]),
                if (widget.conv.tour != null) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.map_outlined, size: 12, color: cs.primary),
                    const SizedBox(width: 4),
                    Expanded(child: Text(widget.conv.tour!.title,
                      style: TextStyle(fontSize: 12, color: cs.primary, height: 1.3),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ],
                const SizedBox(height: 3),
                if (lastMsg != null)
                  _LastMsgRow(msg: lastMsg,
                      isOwn: lastMsg.sender.id == widget.currentUserId,
                      hasUnread: _hasUnread)
                else
                  Text('No messages yet',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.35),
                        fontStyle: FontStyle.italic)),
              ],
            )),

            const SizedBox(width: 8),
            _StatusPill(status: widget.conv.bookingStatus),
          ]),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now   = DateTime.now();
    final local = dt.toLocal();
    if (now.difference(local).inDays < 1 && now.day == local.day) {
      return DateFormat('HH:mm').format(local);
    }
    return DateFormat('MMM d').format(local);
  }
}

class _LastMsgRow extends StatelessWidget {
  const _LastMsgRow({required this.msg, required this.isOwn, required this.hasUnread});
  final MessageEntity msg;
  final bool isOwn, hasUnread;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isItinerary = msg.type == MessageType.itineraryProposal;
    final text = isItinerary
        ? (isOwn ? 'You sent an itinerary' : 'Sent an itinerary')
        : (isOwn ? 'You: ${msg.content}' : msg.content);

    return Row(children: [
      if (isOwn) ...[
        Icon(
          msg.isRead ? Icons.done_all_rounded : Icons.done_rounded,
          size: 13,
          color: msg.isRead ? Colors.blue.shade300 : cs.onSurface.withValues(alpha: 0.35),
        ),
        const SizedBox(width: 3),
      ],
      Expanded(child: Text(text,
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: hasUnread && !isOwn ? FontWeight.w600 : FontWeight.w400,
          color: hasUnread && !isOwn
              ? cs.onSurface
              : cs.onSurface.withValues(alpha: 0.5),
          fontStyle: isItinerary ? FontStyle.italic : FontStyle.normal,
        ))),
    ]);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isNeg = status.contains('CANCEL') || status.contains('REJECT');
    final isPos = status.contains('COMPLET') || status.contains('ONGOING');
    final Color fg, bg;
    if (isPos)       { fg = Colors.green.shade700; bg = Colors.green.shade50; }
    else if (isNeg)  { fg = cs.error;              bg = cs.errorContainer; }
    else             { fg = cs.primary;             bg = cs.primaryContainer; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        status.replaceAll('_', ' ').toLowerCase().split(' ')
            .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' '),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 80,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
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
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
          child: Icon(Icons.forum_outlined, size: 38, color: cs.primary.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 20),
        Text('No conversations yet',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text("Start a chat from a tour's detail page",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.45))),
      ]),
    ));
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message; final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_outlined, size: 48, color: cs.error.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ]),
    ));
  }
}