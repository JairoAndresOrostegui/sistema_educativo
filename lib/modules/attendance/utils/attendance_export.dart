import '../models/attendance_models.dart';
import 'attendance_export_stub.dart'
    if (dart.library.html) 'attendance_export_web.dart';

void exportAttendanceReport(AttendanceReport report) {
  AttendanceExportPlatform.export(report);
}
