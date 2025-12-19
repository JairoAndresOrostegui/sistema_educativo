import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../models/route/student_route_model.dart';

String normAddress(String s) => s.trim().toLowerCase();

List<EstudianteRutaDiaria> sameAddressGroup(
  EstudianteRutaDiaria ref,
  List<EstudianteRutaDiaria> students,
) {
  final addr = normAddress(ref.direccion);
  if (addr.isEmpty) return [ref];
  return students
      .where((e) => e.activo && !e.recogido && !e.anulado)
      .where((e) => normAddress(e.direccion) == addr)
      .toList();
}

List<List<EstudianteRutaDiaria>> buildGroupsForUI(
  List<EstudianteRutaDiaria> students,
) {
  final map = <String, List<EstudianteRutaDiaria>>{};
  final sorted = [...students]
    ..sort((a, b) => (a.orden ?? 0).compareTo(b.orden ?? 0));
  for (final s in sorted) {
    final base = normAddress(s.direccion);
    final key = base.isEmpty ? '__addr_empty_${s.id}' : base;
    map.putIfAbsent(key, () => []).add(s);
  }
  return map.values.toList();
}

bool isGroupClosed(String addrNorm, List<EstudianteRutaDiaria> students) {
  for (final s in students) {
    if (normAddress(s.direccion) == addrNorm) {
      if (s.activo && !s.recogido && !s.anulado) return false;
    }
  }
  return true;
}

EstudianteRutaDiaria? firstPendingOutsideGroup(
  String addrNorm,
  List<EstudianteRutaDiaria> students,
) {
  final sorted = [...students]
    ..sort((a, b) => (a.orden ?? 0).compareTo(b.orden ?? 0));
  for (final s in sorted) {
    if (s.activo &&
        !s.recogido &&
        !s.anulado &&
        normAddress(s.direccion) != addrNorm) {
      return s;
    }
  }
  return null;
}

List<String> _extractTokens(Map<String, dynamic> data) {
  final out = <String>[];
  final t1 = data['fcmToken'];
  if (t1 is String && t1.trim().isNotEmpty) out.add(t1.trim());
  final tN = data['fcmTokens'];
  if (tN is List) {
    out.addAll(
      tN.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty),
    );
  }
  return out;
}

Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
  for (var i = 0; i < list.length; i += size) {
    yield list.sublist(i, i + size > list.length ? list.length : i + size);
  }
}

Future<List<String>> collectTokensForActors({
  required FirebaseFirestore db,
  required String institutionId,
  required String campusId,
  required List<String> studentIds,
}) async {
  final users = db.collection('users');
  final tokens = <String>{};

  for (final chunk in _chunks(studentIds, 10)) {
    final snap =
        await users
            .where(FieldPath.documentId, whereIn: chunk)
            .where('institution', isEqualTo: institutionId)
            .where('campus', isEqualTo: campusId)
            .get();
    for (final d in snap.docs) {
      tokens.addAll(_extractTokens(d.data()));
    }
  }

  for (final chunk in _chunks(studentIds, 10)) {
    final famSnap =
        await users
            .where('institution', isEqualTo: institutionId)
            .where('campus', isEqualTo: campusId)
            .where('role', isEqualTo: 'Familiar')
            .where('status', isEqualTo: 'activo')
            .where('studentIds', arrayContainsAny: chunk)
            .get();
    for (final d in famSnap.docs) {
      tokens.addAll(_extractTokens(d.data()));
    }
  }

  return tokens.toList();
}
