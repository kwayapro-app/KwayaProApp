import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _dayMonth = DateFormat('d MMM', 'en_US');
  static final DateFormat _fullDate = DateFormat('EEEE, d MMMM yyyy', 'en_US');
  static final DateFormat _time = DateFormat('HH:mm', 'en_US');

  static String dayMonth(DateTime date) => _dayMonth.format(date);
  static String fullDate(DateTime date) => _fullDate.format(date);
  static String time(DateTime date) => _time.format(date);

  static String relative(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Tomorrow';
    if (diff.inDays < 7) return '${diff.inDays} days';
    return _dayMonth.format(date);
  }
}
