import '../../../../core/config/app_config.dart';
import 'tour_activity.dart';

enum PriceCategory { budget, standard, premium, outlier }

class TourGuide {
  const TourGuide({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isVerified = false,
    this.ratingAvg,
    this.reviewCount = 0,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final bool isVerified;
  final double? ratingAvg;
  final int reviewCount;

  bool get hasRating => ratingAvg != null;

  factory TourGuide.fromJson(Map<String, dynamic> json) => TourGuide(
        id: json['id'] as String,
        name: json['name'] as String,
        avatarUrl: AppConfig.resolveImageUrl(json['avatarUrl'] as String?),
        isVerified: json['isVerified'] as bool? ?? false,
        ratingAvg: (json['ratingAvg'] as num?)?.toDouble(),
        reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      );
}

class TourPhoto {
  const TourPhoto({required this.id, required this.url, required this.order});
  final String id;
  final String url;
  final int order;

  factory TourPhoto.fromJson(Map<String, dynamic> json) => TourPhoto(
        id: json['id'] as String,
        url: AppConfig.resolveImageUrl(json['url'] as String?) ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
      );
}

class Tour {
  const Tour({
    required this.id,
    required this.title,
    required this.description,
    required this.city,
    this.coverImageUrl,
    this.basePrice = 0,
    required this.totalPrice,
    required this.priceCategory,
    required this.guide,
    required this.activities,
    required this.availableDates,
    required this.photos,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String city;
  final String? coverImageUrl;
  final double basePrice;
  final double totalPrice;
  final PriceCategory priceCategory;
  final TourGuide guide;
  final List<TourActivity> activities;
  final List<DateTime> availableDates;
  final List<TourPhoto> photos;
  final DateTime createdAt;

  factory Tour.fromJson(Map<String, dynamic> json) {
    return Tour(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      city: json['city'] as String,
      coverImageUrl: AppConfig.resolveImageUrl(json['coverImageUrl'] as String?),
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0,
      totalPrice: (json['totalPrice'] as num).toDouble(),
      priceCategory: _parseCategory(json['priceCategory'] as String?),
      guide: TourGuide.fromJson(json['guide'] as Map<String, dynamic>),
      activities: (json['activities'] as List<dynamic>)
          .map((a) => TourActivity.fromJson(a as Map<String, dynamic>))
          .toList(),
      availableDates: ((json['availableDates'] as List<dynamic>?) ?? [])
          .map((d) => DateTime.parse(d as String))
          .toList(),
      photos: ((json['photos'] as List<dynamic>?) ?? [])
          .map((p) => TourPhoto.fromJson(p as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static PriceCategory _parseCategory(String? value) {
    switch (value?.toUpperCase()) {
      case 'BUDGET':
        return PriceCategory.budget;
      case 'PREMIUM':
        return PriceCategory.premium;
      case 'OUTLIER':
        return PriceCategory.outlier;
      default:
        return PriceCategory.standard;
    }
  }

  DateTime? get nextAvailableDate {
    final now = DateTime.now();
    final upcoming = availableDates
        .where((d) => d.isAfter(now))
        .toList()
      ..sort((a, b) => a.compareTo(b));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  List<DateTime> get upcomingDates {
    final now = DateTime.now();
    return availableDates.where((d) => d.isAfter(now)).toList()
      ..sort((a, b) => a.compareTo(b));
  }

  double get minTotalPrice {
    final activitiesMin = activities.fold<double>(0, (sum, a) {
      if (a.pricingType == PricingType.fixed) return sum + (a.fixedPrice ?? 0);
      return sum + (a.minPrice ?? 0);
    });
    return basePrice + activitiesMin;
  }

  String get startingPriceDisplay {
    if (basePrice == 0 && activities.isEmpty) return 'Price TBD';
    return 'From Rp ${_fmt(minTotalPrice)}';
  }

  String get basePriceDisplay => 'Rp ${_fmt(basePrice)}';

  static String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
}
