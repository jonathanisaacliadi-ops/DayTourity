enum AppCurrency {
  usd('USD', 'US'),
  eur('EUR', 'Eropa'),
  cny('CNY', 'Cina'),
  krw('KRW', 'Korea'),
  jpy('JPY', 'Jepang'),
  thb('THB', 'Thailand'),
  sgd('SGD', 'Singapur'),
  myr('MYR', 'Malaysia'),
  vnd('VND', 'Vietnam'),
  idr('IDR', 'Indonesia'),
  aud('AUD', 'Australia'),
  nzd('NZD', 'Selandia Baru'),
  inr('INR', 'India'),
  php('PHP', 'Filipina');

  const AppCurrency(this.code, this.countryLabel);

  final String code;
  final String countryLabel;

  String get displayName => '$code - $countryLabel';

  static AppCurrency fromCode(String? code) {
    return AppCurrency.values.firstWhere(
      (currency) => currency.code == code?.toUpperCase(),
      orElse: () => AppCurrency.idr,
    );
  }
}
