import 'itinerary_proposal.dart';

enum MessageType { text, itineraryProposal }

class MessageSender {
  final String id;
  final String name;
  const MessageSender({required this.id, required this.name});

  factory MessageSender.fromJson(Map<String, dynamic> json) =>
      MessageSender(id: json['id'] as String, name: json['name'] as String);
}

class MessageEntity {
  final String id;
  final String conversationId;
  final MessageSender sender;
  final String content;
  final MessageType type;
  final DateTime createdAt;
  final bool isRead;
  final ItineraryProposal? proposal;

  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.content,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.proposal,
  });

  MessageEntity copyWith({bool? isRead}) => MessageEntity(
        id: id,
        conversationId: conversationId,
        sender: sender,
        content: content,
        type: type,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
        proposal: proposal,
      );

  factory MessageEntity.fromJson(Map<String, dynamic> json) {
    final senderJson = json['sender'] as Map<String, dynamic>?;
    final sender = senderJson != null
        ? MessageSender.fromJson(senderJson)
        : MessageSender(
            id: json['senderId'] as String? ?? '',
            name: 'Unknown',
          );

    final type = (json['type'] as String?) == 'ITINERARY_PROPOSAL'
        ? MessageType.itineraryProposal
        : MessageType.text;

    final content = json['content'] as String;

    final proposal = type == MessageType.itineraryProposal
        ? ItineraryProposal.tryParse(content)
        : null;

    return MessageEntity(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String? ?? '',
      sender: sender,
      content: content,
      type: type,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      proposal: proposal,
    );
  }
}
