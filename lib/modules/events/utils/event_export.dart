import '../models/event_models.dart';
import 'event_export_stub.dart' if (dart.library.html) 'event_export_web.dart';

void exportEventReport({
  required List<EventReportRow> rows,
  required DateTime from,
  required DateTime to,
}) {
  EventExportPlatform.export(rows: rows, from: from, to: to);
}
