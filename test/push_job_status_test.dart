import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/models/messaging/push_job_status.dart';

void main() {
  test('interpreta un trabajo push válido', () {
    final job = PushJobStatus.fromMap({
      'id': 'job-1',
      'status': 'accepted',
      'institutionId': 'inst-1',
      'campusId': 'campus-1',
      'type': 'messaging',
      'total': 2,
      'accepted': 2,
      'createdAt': 1000,
    });
    expect(job.id, 'job-1');
    expect(job.status, 'accepted');
    expect(job.accepted, 2);
    expect(job.createdAt, DateTime.fromMillisecondsSinceEpoch(1000));
  });

  test('tolera contadores, fechas y estados históricos dañados', () {
    final job = PushJobStatus.fromMap({
      'id': 4,
      'status': 'inventado',
      'total': -3,
      'accepted': 'dos',
      'createdAt': 'ayer',
      'lastError': 500,
    });
    expect(job.id, isEmpty);
    expect(job.status, 'unknown');
    expect(job.type, 'desconocido');
    expect(job.total, 0);
    expect(job.accepted, 0);
    expect(job.createdAt, isNull);
    expect(job.lastError, isNull);
  });
}
