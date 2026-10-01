import 'package:intl/intl.dart';

class ArabicDayHelper {
  static const List<({int weekday, String shortName, String fullName})> schoolDays = [
    (weekday: DateTime.sunday, shortName: 'الأحد', fullName: 'يوم الأحد'),
    (weekday: DateTime.monday, shortName: 'الاثنين', fullName: 'يوم الاثنين'),
    (weekday: DateTime.tuesday, shortName: 'الثلاثاء', fullName: 'يوم الثلاثاء'),
    (weekday: DateTime.wednesday, shortName: 'الأربعاء', fullName: 'يوم الأربعاء'),
    (weekday: DateTime.thursday, shortName: 'الخميس', fullName: 'يوم الخميس'),
    (weekday: DateTime.saturday, shortName: 'السبت', fullName: 'يوم السبت'),
    (weekday: DateTime.friday, shortName: 'الجمعة', fullName: 'يوم الجمعة'),
  ];

  static String dayNameFromWeekday(int weekday, {bool withPrefix = true}) {
    String name;
    switch (weekday) {
      case DateTime.sunday:
        name = 'الأحد';
        break;
      case DateTime.monday:
        name = 'الاثنين';
        break;
      case DateTime.tuesday:
        name = 'الثلاثاء';
        break;
      case DateTime.wednesday:
        name = 'الأربعاء';
        break;
      case DateTime.thursday:
        name = 'الخميس';
        break;
      case DateTime.friday:
        name = 'الجمعة';
        break;
      case DateTime.saturday:
        name = 'السبت';
        break;
      default:
        name = 'الأحد';
    }
    return withPrefix ? 'يوم $name' : name;
  }

  static String formatDay(DateTime date, {bool withPrefix = true}) {
    return dayNameFromWeekday(date.weekday, withPrefix: withPrefix);
  }

  /// Returns 'صباحي' if hour < 12, otherwise 'مسائي'
  static String formatShift(DateTime date) {
    return date.hour < 12 ? 'صباحي' : 'مسائي';
  }

  /// Formats Day + Date + Shift in Arabic, e.g.: "يوم الأحد • 2026-09-27 • صباحي"
  static String formatFullDayDateTime(DateTime date) {
    final dayStr = formatDay(date, withPrefix: true);
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final shiftStr = formatShift(date);
    return '$dayStr • $dateStr • $shiftStr';
  }

  /// Formats Day + Date in Arabic, e.g.: "يوم الأحد • 2026-09-27"
  static String formatDayAndDate(DateTime date) {
    final dayStr = formatDay(date, withPrefix: true);
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return '$dayStr • $dateStr';
  }

  /// Returns a DateTime set to [hour]:[minute] on the upcoming occurrence of [targetWeekday].
  static DateTime nextDateForWeekday(int targetWeekday, {int hour = 9, int minute = 0}) {
    final now = DateTime.now();
    int daysAhead = (targetWeekday - now.weekday) % 7;
    final targetDate = now.add(Duration(days: daysAhead));
    return DateTime(targetDate.year, targetDate.month, targetDate.day, hour, minute);
  }

  /// Ensures any numeric date in homework descriptions includes the Arabic day name alongside the date and time.
  static String formatDescriptionDatesToDayNames(String text) {
    final regex = RegExp(r'(\d{4}-\d{2}-\d{2})');
    return text.replaceAllMapped(regex, (match) {
      final datePart = match.group(1);
      if (datePart != null) {
        final startIdx = match.start;
        final preceding = startIdx > 0 ? text.substring(0, startIdx) : '';
        if (preceding.contains('يوم ')) {
          return datePart;
        }
        final parsed = DateTime.tryParse(datePart);
        if (parsed != null) {
          return '${formatDay(parsed, withPrefix: true)} • $datePart';
        }
      }
      return match.group(0) ?? '';
    });
  }
}
