enum PricePreference { budget, standard, premium }

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.pricePreference = PricePreference.standard,
  });

  final String id;
  final String email;
  final String name;
  final String role;
  final PricePreference pricePreference;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      pricePreference: _parsePreference(json['pricePreference'] as String?),
    );
  }

  static PricePreference _parsePreference(String? value) {
    switch (value?.toUpperCase()) {
      case 'BUDGET':
        return PricePreference.budget;
      case 'PREMIUM':
        return PricePreference.premium;
      default:
        return PricePreference.standard;
    }
  }

  AuthUser copyWith({PricePreference? pricePreference}) {
    return AuthUser(
      id: id,
      email: email,
      name: name,
      role: role,
      pricePreference: pricePreference ?? this.pricePreference,
    );
  }
}
