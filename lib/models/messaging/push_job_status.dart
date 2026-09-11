class PushJobStatus {
  static const knownStatuses = {
    'pending',
    'sending',
    'retry',
    'failed',
    'partial',
    'accepted',
    'skipped',
  };

  final String id;
  final String status;
  final String institutionId;
  final String campusId;
  final String type;
  final int total;
  final int accepted;
  final int rejected;
  final int skipped;
  final int pending;
  final int attempts;
  final String? lastError;
  final DateTime? createdAt;

  const PushJobStatus({
    required this.id,
    required this.status,
    required this.institutionId,
    required this.campusId,
    required this.type,
    required this.total,
    required this.accepted,
    required this.rejected,
    required this.skipped,
    required this.pending,
    required this.attempts,
    required this.lastError,
    required this.createdAt,
  });

  factory PushJobStatus.fromMap(Map<dynamic, dynamic> map) {
    final rawStatus = _text(map['status']);
    final millis = map['createdAt'] is num
        ? (map['createdAt'] as num).toInt()
        : null;
    return PushJobStatus(
      id: _text(map['id']),
      status: knownStatuses.contains(rawStatus) ? rawStatus : 'unknown',
      institutionId: _text(map['institutionId']),
      campusId: _text(map['campusId']),
      type: _text(map['type'], fallback: 'desconocido'),
      total: _count(map['total']),
      accepted: _count(map['accepted']),
      rejected: _count(map['rejected']),
      skipped: _count(map['skipped']),
      pending: _count(map['pending']),
      attempts: _count(map['attempts']),
      lastError: _text(map['lastError']).isEmpty
          ? null
          : _text(map['lastError']),
      createdAt: millis == null || millis < 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }

  static int _count(dynamic value) {
    final count = value is num ? value.toInt() : 0;
    return count < 0 ? 0 : count;
  }

  static String _text(dynamic value, {String fallback = ''}) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? fallback : text;
  }
}
