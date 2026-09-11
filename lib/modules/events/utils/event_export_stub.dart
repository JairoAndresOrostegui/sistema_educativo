import '../models/event_models.dart';

class EventExportPlatform {
  static void export({
    required List<EventReportRow> rows,
    required DateTime from,
    required DateTime to,
  }) {
    throw UnsupportedError('La exportación está disponible en la versión web.');
  }
}
