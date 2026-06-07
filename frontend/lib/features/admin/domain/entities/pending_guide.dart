class PendingGuide {
  const PendingGuide({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final DateTime? createdAt;

  factory PendingGuide.fromJson(Map<String, dynamic> json) {
    return PendingGuide(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}
