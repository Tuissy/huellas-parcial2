import 'package:intl/intl.dart';

/// Formatos de fecha en español usados en toda la interfaz.
///
/// Requiere `initializeDateFormatting('es')` en `main()`.
abstract final class DateFormatter {
  static const String _locale = 'es';

  /// "martes, 17 de noviembre de 2026"
  static String longDate(DateTime date) =>
      DateFormat("EEEE, d 'de' MMMM 'de' y", _locale).format(date);

  /// "14:35"
  static String time(DateTime date) => DateFormat.Hm(_locale).format(date);

  /// "Hoy · 14:35", "Ayer · 09:10" o "15 nov 2026 · 18:00".
  static String relative(DateTime date, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final day = DateTime(date.year, date.month, date.day);
    final difference = today.difference(day).inDays;

    final String label;
    if (difference == 0) {
      label = 'Hoy';
    } else if (difference == 1) {
      label = 'Ayer';
    } else {
      label = DateFormat('d MMM y', _locale).format(date);
    }
    return '$label · ${time(date)}';
  }
}
