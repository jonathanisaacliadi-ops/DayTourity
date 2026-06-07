import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../data/datasources/chat_remote_datasource.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/itinerary_proposal.dart';
import '../../domain/entities/message_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/active_mode_provider.dart';

final chatDatasourceProvider = Provider<ChatRemoteDatasource?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.when(
    data: (state) {
      if (state is AuthAuthenticated) {
        return ChatRemoteDatasource(token: state.token);
      }
      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});


final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<ConversationEntity>>(
  ConversationsNotifier.new,
);

class ConversationsNotifier extends AsyncNotifier<List<ConversationEntity>> {
  @override
  Future<List<ConversationEntity>> build() async {
    final ds = ref.watch(chatDatasourceProvider);
    if (ds == null) return [];

    final activeMode   = ref.watch(activeModeProvider);
    final authState    = ref.watch(authProvider).valueOrNull;
    final currentUserId =
        authState is AuthAuthenticated ? authState.user.id : '';

    final all = await ds.listConversations();

    if (activeMode == 'GUIDE') {
      return all.where((c) => c.guide.id == currentUserId).toList();
    } else {
      return all.where((c) => c.user.id == currentUserId).toList();
    }
  }

  Future<ConversationEntity> findOrCreate({
    required String tourId,
    required String guideId,
  }) async {
    final ds = ref.read(chatDatasourceProvider);
    if (ds == null) throw Exception('Not authenticated');
    final conv =
        await ds.findOrCreateConversation(tourId: tourId, guideId: guideId);
    ref.invalidateSelf();
    return conv;
  }
}


class ChatRoomState {
  const ChatRoomState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.isTyping = false,
    this.bookingStatus = 'NEGOTIATING',
    this.isSendingProposal = false,
    this.isAccepting = false,
  });

  final List<MessageEntity> messages;
  final bool isLoading;
  final String? error;
  final bool isTyping;
  final String bookingStatus;
  final bool isSendingProposal;
  final bool isAccepting;

  ChatRoomState copyWith({
    List<MessageEntity>? messages,
    bool? isLoading,
    String? error,
    bool? isTyping,
    String? bookingStatus,
    bool? isSendingProposal,
    bool? isAccepting,
  }) =>
      ChatRoomState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
        isTyping: isTyping ?? this.isTyping,
        bookingStatus: bookingStatus ?? this.bookingStatus,
        isSendingProposal: isSendingProposal ?? this.isSendingProposal,
        isAccepting: isAccepting ?? this.isAccepting,
      );
}

typedef ChatRoomParams = ({String conversationId, String initialBookingStatus});

final chatRoomProvider = StateNotifierProvider.family
    .autoDispose<ChatRoomNotifier, ChatRoomState, ChatRoomParams>(
  (ref, params) {
    final ds = ref.watch(chatDatasourceProvider);
    return ChatRoomNotifier(
      conversationId: params.conversationId,
      initialBookingStatus: params.initialBookingStatus,
      datasource: ds,
    );
  },
);

class ChatRoomNotifier extends StateNotifier<ChatRoomState> {
  final String conversationId;
  final ChatRemoteDatasource? datasource;
  io.Socket? _socket;

  ChatRoomNotifier({
    required this.conversationId,
    required String initialBookingStatus,
    required this.datasource,
  }) : super(ChatRoomState(
          isLoading: true,
          bookingStatus: initialBookingStatus,
        )) {
    _init();
  }

  Future<void> _init() async {
    if (datasource == null) {
      state = state.copyWith(isLoading: false, error: 'Not authenticated');
      return;
    }

    try {
      final messages = await datasource!.getMessages(conversationId);
      state = state.copyWith(messages: messages, isLoading: false);

      _socket = datasource!.connect();

      _socket!.on('connect', (_) {
        datasource!.joinRoom(conversationId);
        datasource!.markRead(conversationId);
      });

      _socket!.on('new_message', (data) {
        final msg = MessageEntity.fromJson(
            Map<String, dynamic>.from(data as Map));
        if (!mounted) return;
        state = state.copyWith(
          messages: [...state.messages, msg],
          isTyping: false,
          isSendingProposal: false,
        );
        datasource!.markRead(conversationId);
      });

      _socket!.on('messages_read', (_) {
        if (!mounted) return;
        final updated =
            state.messages.map((m) => m.copyWith(isRead: true)).toList();
        state = state.copyWith(messages: updated);
      });

      _socket!.on('status_changed', (data) {
        if (!mounted) return;
        final d = Map<String, dynamic>.from(data as Map);
        final status = d['status'] as String? ?? state.bookingStatus;
        state = state.copyWith(bookingStatus: status);
      });

      _socket!.on('typing', (data) {
        if (!mounted) return;
        final d = Map<String, dynamic>.from(data as Map);
        state = state.copyWith(isTyping: d['isTyping'] as bool? ?? false);
      });

      _socket!.on('error', (data) {
        if (!mounted) return;
        state = state.copyWith(
            error: data?.toString(), isSendingProposal: false);
      });
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }


  void sendMessage(String content, {String type = 'TEXT'}) {
    datasource?.sendMessage(
      conversationId: conversationId,
      content: content,
      type: type,
    );
  }

  void sendItineraryProposal(ItineraryProposal proposal) {
    if (datasource == null) return;
    state = state.copyWith(isSendingProposal: true);
    datasource!.sendItineraryProposal(
      conversationId: conversationId,
      proposal: proposal,
    );
  }

  Future<void> acceptProposal() async {
    if (datasource == null) return;
    state = state.copyWith(isAccepting: true);
    try {
      await datasource!.acceptProposal(conversationId);
      if (mounted) state = state.copyWith(bookingStatus: 'ACCEPTED', isAccepting: false);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString(), isAccepting: false);
    }
  }

  void notifyTyping(bool isTyping) {
    datasource?.sendTyping(conversationId, isTyping: isTyping);
  }

  @override
  void dispose() {
    datasource?.disconnect();
    super.dispose();
  }
}