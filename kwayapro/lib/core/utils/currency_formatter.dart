import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _ugx = NumberFormat.currency(
    symbol: 'UGX ',
    decimalDigits: 0,
    locale: 'en_UG',
  );

  static String format(int amount) => _ugx.format(amount);
  static String formatMonthly(int amount) => '${_ugx.format(amount)}/month';
}
