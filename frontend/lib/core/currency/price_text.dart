import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'app_currency.dart';
import 'exchange_rates_provider.dart';

class PriceText extends ConsumerWidget {
  const PriceText({
    super.key,
    this.amountIdr,
    this.rangeEndIdr,
    this.style,
    this.prefix = '',
    this.fallback = 'Price TBD',
  });

  final double? amountIdr;
  final double? rangeEndIdr;
  final TextStyle? style;
  final String prefix;
  final String fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = amountIdr;
    if (amount == null) {
      return Text(fallback, style: style);
    }

    final authState = ref.watch(authProvider).valueOrNull;
    final preferred = authState is AuthAuthenticated
        ? authState.user.currency
        : AppCurrency.idr;
    final ratesAsync = ref.watch(exchangeRatesProvider);
    final rangeEnd = rangeEndIdr;

    return ratesAsync.when(
      data: (rates) {
        final start = rates.convert(amount, preferred);
        if (rangeEnd == null) {
          return Text('$prefix${format(start, preferred)}', style: style);
        }
        final end = rates.convert(rangeEnd, preferred);
        return Text(
          '$prefix${format(start, preferred)} – ${format(end, preferred)}',
          style: style,
        );
      },
      loading: () => Text('$prefix${_baseText(amount, rangeEnd)}', style: style),
      error: (_, __) => Text('$prefix${_baseText(amount, rangeEnd)}', style: style),
    );
  }

  String _baseText(double amount, double? rangeEnd) {
    if (rangeEnd == null) return format(amount, AppCurrency.idr);
    return '${format(amount, AppCurrency.idr)} – ${format(rangeEnd, AppCurrency.idr)}';
  }

  static String format(double amount, AppCurrency currency) {
    if (currency == AppCurrency.idr) {
      return 'Rp ${_grouped(amount.round(), '.')}';
    }

    const noDecimalCurrencies = {AppCurrency.jpy, AppCurrency.krw, AppCurrency.vnd};
    if (noDecimalCurrencies.contains(currency)) {
      return '${currency.code} ${_grouped(amount.round(), ',')}';
    }

    final fixed = amount.toStringAsFixed(2);
    final dotIndex = fixed.indexOf('.');
    final whole = int.parse(fixed.substring(0, dotIndex));
    return '${currency.code} ${_grouped(whole, ',')}${fixed.substring(dotIndex)}';
  }

  static String _grouped(int value, String separator) {
    return value.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}$separator',
        );
  }
}
