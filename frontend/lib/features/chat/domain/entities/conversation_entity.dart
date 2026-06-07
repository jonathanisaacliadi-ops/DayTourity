import '../../../../core/config/app_config.dart';
import 'message_entity.dart';

class ConversationParticipant {
  final String id;
  final String name;
  const ConversationParticipant({required this.id, required this.name});

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) =>
      ConversationParticipant(
          id: json['id'] as String, name: json['name'] as String);
}

class ConversationTour {
  final String id;
  final String title;
  final String? coverImageUrl;
  const ConversationTour(
      {required this.id, required this.title, this.coverImageUrl});

  factory ConversationTour.fromJson(Map<String, dynamic> json) =>
      ConversationTour(
        id: json['id'] as String,
        title: json['title'] as String,
        coverImageUrl: AppConfig.resolveImageUrl(json['coverImageUrl'] as String?),
      );
}

class ConversationEntity {
  final String id;
  final String bookingStatus;
  final ConversationParticipant user;
  final ConversationParticipant guide;
  final ConversationTour? tour;
  final MessageEntity? lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ConversationEntity({
    required this.id,
    required this.bookingStatus,
    required this.user,
    required this.guide,
    this.tour,
    this.lastMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ConversationEntity.fromJson(Map<String, dynamic> json) {
    return ConversationEntity(
      id: json['id'] as String,
      bookingStatus: json['bookingStatus'] as String? ?? 'NEGOTIATING',
      user: ConversationParticipant.fromJson(
          json['user'] as Map<String, dynamic>),
      guide: ConversationParticipant.fromJson(
          json['guide'] as Map<String, dynamic>),
      tour: json['tour'] != null
          ? ConversationTour.fromJson(json['tour'] as Map<String, dynamic>)
          : null,
      lastMessage: json['lastMessage'] != null
          ? MessageEntity.fromJson(
              json['lastMessage'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
