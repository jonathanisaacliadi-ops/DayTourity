import 'dart:convert';

class ItineraryActivity {
  const ItineraryActivity({
    required this.name,
    this.duration,
    this.price,
  });

  final String name;
  final String? duration;
  final double? price;

  factory ItineraryActivity.fromJson(Map<String, dynamic> json) =>
      ItineraryActivity(
        name: json['name'] as String,
        duration: json['duration'] as String?,
        price: (json['price'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (duration != null) 'duration': duration,
        if (price != null) 'price': price,
      };
}

class ItineraryProposal {
  const ItineraryProposal({
    this.title,
    this.date,
    this.note,
    this.activities = const [],
    this.totalPrice,
  });

  final String? title;
  final String? date;
  final String? note;
  final List<ItineraryActivity> activities;
  final double? totalPrice;

  double get calculatedTotal =>
      activities.fold(0, (sum, a) => sum + (a.price ?? 0));

  double get displayTotal => totalPrice ?? calculatedTotal;

  factory ItineraryProposal.fromJson(Map<String, dynamic> json) =>
      ItineraryProposal(
        title: json['title'] as String?,
        date: json['date'] as String?,
        note: json['note'] as String?,
        activities: (json['activities'] as List<dynamic>? ?? [])
            .map((e) => ItineraryActivity.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalPrice: (json['totalPrice'] as num?)?.toDouble(),
      );

  static ItineraryProposal? tryParse(String content) {
    try {
      return ItineraryProposal.fromJson(
          jsonDecode(content) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (date != null) 'date': date,
        if (note != null) 'note': note,
        'activities': activities.map((a) => a.toJson()).toList(),
        if (totalPrice != null) 'totalPrice': totalPrice,
      };

  String toJsonString() => jsonEncode(toJson());
}
