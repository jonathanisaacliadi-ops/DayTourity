import '../../../../core/config/app_config.dart';

enum TourStatus { planned, ongoing, completed, cancelled }

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
 
TourStatus tourStatusFromString(String s) {
  return TourStatus.values.firstWhere(
    (e) => e.name.toUpperCase() == s.toUpperCase(),
    orElse: () => TourStatus.planned,
  );
}
 
class BookingTourSummary {
  const BookingTourSummary({
    required this.id,
    required this.title,
    required this.city,
    this.coverImageUrl,
  });
 
  final String id;
  final String title;
  final String city;
  final String? coverImageUrl;
 
  factory BookingTourSummary.fromJson(Map<String, dynamic> json) {
    return BookingTourSummary(
      id:            json['id'] as String,
      title:         json['title'] as String,
      city:          json['city'] as String,
      coverImageUrl: AppConfig.resolveImageUrl(json['coverImageUrl'] as String?),
    );
  }
}
 
class BookingGuideSummary {
  const BookingGuideSummary({required this.id, required this.name, this.phone});

  final String id;
  final String name;
  final String? phone;

  factory BookingGuideSummary.fromJson(Map<String, dynamic> json) {
    return BookingGuideSummary(
      id:    json['id'] as String,
      name:  json['name'] as String,
      phone: json['phone'] as String?,
    );
  }
}

class BookingTravellerSummary {
  const BookingTravellerSummary({required this.id, required this.name});

  final String id;
  final String name;

  factory BookingTravellerSummary.fromJson(Map<String, dynamic> json) {
    return BookingTravellerSummary(
      id:   json['id'] as String,
      name: json['name'] as String,
    );
  }
}
 
class BookingEntity {
  const BookingEntity({
    required this.id,
    required this.status,
    required this.scheduledDate,
    required this.agreedPrice,
    required this.tour,
    this.guide,
    this.traveller,
    this.notes,
    this.startedAt,
    this.completedAt,
  });

  final String id;
  final TourStatus status;
  final DateTime scheduledDate;
  final double agreedPrice;
  final BookingTourSummary tour;
  final BookingGuideSummary? guide;
  final BookingTravellerSummary? traveller;
  final String? notes;
  final DateTime? startedAt;
  final DateTime? completedAt;

  bool get canCancel =>
      status == TourStatus.planned &&
      scheduledDate.difference(DateTime.now()).inHours >= 72;

  bool get isGuideContactRevealed =>
      scheduledDate.difference(DateTime.now()).inHours <= 48;

  factory BookingEntity.fromJson(Map<String, dynamic> json) {
    return BookingEntity(
      id:            json['id'] as String,
      status:        tourStatusFromString(json['status'] as String),
      scheduledDate: DateTime.parse(json['scheduledDate'] as String),
      agreedPrice:   _toDouble(json['agreedPrice']),
      tour:          BookingTourSummary.fromJson(json['tour'] as Map<String, dynamic>),
      guide:         json['guide'] != null
          ? BookingGuideSummary.fromJson(json['guide'] as Map<String, dynamic>)
          : null,
      traveller:     json['traveller'] != null
          ? BookingTravellerSummary.fromJson(json['traveller'] as Map<String, dynamic>)
          : null,
      notes:         json['notes'] as String?,
      startedAt:     json['startedAt'] != null ? DateTime.parse(json['startedAt'] as String) : null,
      completedAt:   json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
    );
  }
}