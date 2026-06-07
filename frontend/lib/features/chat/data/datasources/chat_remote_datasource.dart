import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../../core/config/app_config.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/itinerary_proposal.dart';
import '../../domain/entities/message_entity.dart';

class ChatRemoteDatasource {
  final String token;
  io.Socket? _socket;

  ChatRemoteDatasource({required this.token});

  Future<ConversationEntity> findOrCreateConversation({
    required String tourId,
    required String guideId,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/conversations');
    final res = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'tourId': tourId, 'guideId': guideId}),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to open conversation: ${res.body}');
    }
    return ConversationEntity.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<ConversationEntity>> listConversations() async {
    final uri = Uri.parse('${AppConfig.baseUrl}/conversations');
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode != 200) {
      throw Exception('Failed to load conversations: ${res.body}');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => ConversationEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MessageEntity>> getMessages(String conversationId) async {
    final uri =
        Uri.parse('${AppConfig.baseUrl}/conversations/$conversationId/messages');
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode != 200) {
      throw Exception('Failed to load messages: ${res.body}');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => MessageEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  io.Socket connect() {
    final wsUrl = AppConfig.socketUrl;
    _socket = io.io(
      '$wsUrl/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    _socket!.connect();
    debugPrint('[Socket] Connecting to $wsUrl/chat');
    return _socket!;
  }

  void joinRoom(String conversationId) {
    _socket?.emit('join_room', {'conversationId': conversationId});
  }

  void sendMessage({
    required String conversationId,
    required String content,
    String type = 'TEXT',
  }) {
    _socket?.emit('send_message', {
      'conversationId': conversationId,
      'content': content,
      'type': type,
    });
  }

  void sendItineraryProposal({
    required String conversationId,
    required ItineraryProposal proposal,
  }) {
    _socket?.emit('send_itinerary', {
      'conversationId': conversationId,
      'proposal': proposal.toJson(),
    });
  }

  Future<void> acceptProposal(String conversationId) async {
    final uri =
        Uri.parse('${AppConfig.baseUrl}/conversations/$conversationId/accept');
    final res = await http.patch(uri, headers: _headers());
    if (res.statusCode != 200) {
      throw Exception('Failed to accept proposal: ${res.body}');
    }
  }


  void markRead(String conversationId) {
    _socket?.emit('mark_read', {'conversationId': conversationId});
  }

  void sendTyping(String conversationId, {required bool isTyping}) {
    _socket?.emit('typing', {
      'conversationId': conversationId,
      'isTyping': isTyping,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
}
