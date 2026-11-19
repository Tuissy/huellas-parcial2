// Utilidad de la capa core para mostrar fechas en español con el
// paquete intl, el estándar de Dart para formatear fechas.
import 'package:intl/intl.dart';

// Clase "abstract final" con métodos estáticos: no se puede crear un
// objeto de ella ni heredarla desde otro archivo; funciona como un
// grupo de funciones de ayuda.
/// Formatos de fecha en español usados en toda la interfaz.
///
/// Requiere `initializeDateFormatting('es')` en `main()`.
abstract final class DateFormatter {
  // Idioma usado en todos los formatos de este archivo.
  static const String _locale = 'es';

  // Fecha larga para el detalle de una entrada. El texto entre comillas
  // simples ('de') se copia tal cual en el resultado.
  /// "martes, 17 de noviembre de 2026"
  static String longDate(DateTime date) =>
      DateFormat("EEEE, d 'de' MMMM 'de' y", _locale).format(date);

  // Hora en formato de 24 horas: horas y minutos.
  /// "14:35"
  static String time(DateTime date) => DateFormat.Hm(_locale).format(date);

  // Fecha relativa para las tarjetas de la lista y del mapa. El
  // parámetro opcional now permite fijar el momento actual, útil en
  // pruebas.
  /// "Hoy · 14:35", "Ayer · 09:10" o "15 nov 2026 · 18:00".
  static String relative(DateTime date, {DateTime? now}) {
    // Se comparan solo los días, sin horas: se crean dos fechas a
    // medianoche y se calcula cuántos días hay de diferencia entre ellas.
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final day = DateTime(date.year, date.month, date.day);
    final difference = today.difference(day).inDays;

    // Se elige la etiqueta. label se declara final sin valor inicial y
    // Dart comprueba que cada rama del if le asigne uno.
    final String label;
    if (difference == 0) {
      label = 'Hoy';
    } else if (difference == 1) {
      label = 'Ayer';
    } else {
      label = DateFormat('d MMM y', _locale).format(date);
    }
    // Resultado: etiqueta, punto medio y la hora.
    return '$label · ${time(date)}';
  }
}
