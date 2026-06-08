import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'app_currency.dart';

class ExchangeRates {
  const ExchangeRates({required this.base, required this.rates});

  final String base;
  final Map<String, double> rates;

  factory ExchangeRates.fromJson(Map<String, dynamic> json) {
    final rawRates = json['rates'] as Map<String, dynamic>? ?? const {};
    return ExchangeRates(
      base: json['base'] as String? ?? 'IDR',
      rates: rawRates.map(
        (code, value) => MapEntry(code, (value as num).toDouble()),
      ),
    );
  }

  double convert(double amountInBase, AppCurrency to) {
    if (to.code == base) return amountInBase;
    final rate = rates[to.code];
    if (rate == null) return amountInBase;
    return amountInBase * rate;
  }
}

class ExchangeRatesRemoteDatasource {
  ExchangeRatesRemoteDatasource({http.Client? client})
      : client = client ?? http.Client();

  final http.Client client;

  String get _base => AppConfig.baseUrl;

  Future<ExchangeRates> getRates() async {
    final uri = Uri.parse('$_base/exchange-rates');
    final response = await client.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode >= 400) {
      throw Exception('Failed to fetch exchange rates');
    }

    return ExchangeRates.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

final _exchangeRatesDatasourceProvider = Provider<ExchangeRatesRemoteDatasource>(
  (_) => ExchangeRatesRemoteDatasource(),
);

final exchangeRatesProvider = FutureProvider<ExchangeRates>((ref) async {
  final datasource = ref.watch(_exchangeRatesDatasourceProvider);
  return datasource.getRates();
});
