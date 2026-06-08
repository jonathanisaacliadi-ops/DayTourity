enum PricingType { fixed, range }

class TourActivity {
  const TourActivity({
    required this.id,
    required this.name,
    this.description,
    required this.pricingType,
    this.fixedPrice,
    this.minPrice,
    this.maxPrice,
    required this.order,
  });

  final String id;
  final String name;
  final String? description;
  final PricingType pricingType;
  final double? fixedPrice;
  final double? minPrice;
  final double? maxPrice;
  final int order;

  factory TourActivity.fromJson(Map<String, dynamic> json) {
    return TourActivity(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      pricingType: (json['pricingType'] as String).toUpperCase() == 'RANGE'
          ? PricingType.range
          : PricingType.fixed,
      fixedPrice: (json['fixedPrice'] as num?)?.toDouble(),
      minPrice: (json['minPrice'] as num?)?.toDouble(),
      maxPrice: (json['maxPrice'] as num?)?.toDouble(),
      order: json['order'] as int? ?? 0,
    );
  }

  double? get priceAmountIdr {
    if (pricingType == PricingType.fixed) return fixedPrice;
    return minPrice;
  }

  double? get priceRangeEndIdr {
    if (pricingType == PricingType.range) return maxPrice;
    return null;
  }

  bool get hasPrice => priceAmountIdr != null;
}
