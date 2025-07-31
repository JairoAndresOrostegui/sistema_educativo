import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/schedule/subject_model.dart';

class HorarioService {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  final List<String> _dias = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
  ];

  Future<Map<String, List<MateriaModel>>> obtenerHorario(String grado) async {
    final snap = await _db.collection('horarios').doc(grado).get();
    if (!snap.exists) return {};
    final data = snap.data()!;
    final materias = <String, List<MateriaModel>>{};
    for (final dia in data['materias']?.keys ?? []) {
      materias[dia] =
          List<Map<String, dynamic>>.from(
            data['materias'][dia],
          ).map((e) => MateriaModel.fromMap(e)).toList();
    }
    return materias;
  }

  Future<void> guardarMateria({
    required String grado,
    required String dia,
    required MateriaModel materia,
  }) async {
    final ref = _db.collection('horarios').doc(grado);
    final doc = await ref.get();
    final data = doc.data() ?? {'materias': {}};

    final materiasDia = List<Map<String, dynamic>>.from(
      data['materias'][dia] ?? [],
    );
    materiasDia.add(materia.toMap());

    data['materias'][dia] = materiasDia;
    data['ultimaModificacion'] = FieldValue.serverTimestamp();
    data['modificadoPor'] = _uid;

    await ref.set(data);

    await _registrarHistorial(
      accion: 'crear',
      grado: grado,
      dia: dia,
      materia: materia.materia,
    );

    await _notificarEstudiantes(
      grado,
      '📅 Nueva materia agregada al horario',
      materia.materia,
    );
  }

  Future<void> editarMateria({
    required String grado,
    required String dia,
    required int index,
    required MateriaModel nuevaMateria,
  }) async {
    final ref = _db.collection('horarios').doc(grado);
    final doc = await ref.get();
    final data = doc.data();

    if (data == null ||
        data['materias'] == null ||
        data['materias'][dia] == null) {
      throw Exception(
        'No se encontró el horario del día $dia para el grado $grado',
      );
    }

    final materiasDia = List<Map<String, dynamic>>.from(data['materias'][dia]);

    if (index >= materiasDia.length) {
      throw Exception('Índice fuera de rango');
    }

    materiasDia[index] = nuevaMateria.toMap();
    data['materias'][dia] = materiasDia;
    data['ultimaModificacion'] = FieldValue.serverTimestamp();
    data['modificadoPor'] = _uid;

    await ref.set(data);

    await _registrarHistorial(
      accion: 'editar',
      grado: grado,
      dia: dia,
      materia: nuevaMateria.materia,
    );

    await _notificarEstudiantes(
      grado,
      '📝 Materia modificada en el horario',
      nuevaMateria.materia,
    );
  }

  Future<void> eliminarMateria({
    required String grado,
    required String dia,
    required int index,
  }) async {
    final ref = _db.collection('horarios').doc(grado);
    final doc = await ref.get();
    final data = doc.data()!;
    final materiasDia = List<Map<String, dynamic>>.from(data['materias'][dia]);
    final materiaEliminada = materiasDia.removeAt(index);
    data['materias'][dia] = materiasDia;

    await ref.set(data);

    await _registrarHistorial(
      accion: 'eliminar',
      grado: grado,
      dia: dia,
      materia: materiaEliminada['materia'],
    );

    await _notificarEstudiantes(
      grado,
      '❌ Materia eliminada del horario',
      materiaEliminada['materia'],
    );
  }

  Future<void> _registrarHistorial({
    required String accion,
    required String grado,
    required String dia,
    required String materia,
  }) async {
    final userDoc = await _db.collection('usuarios').doc(_uid).get();
    final nombres = userDoc['nombres'] ?? '';
    final apellidos = userDoc['apellidos'] ?? '';
    final nombreCompleto = '$nombres $apellidos';

    await _db.collection('historial_horarios').add({
      'accion': accion,
      'materia': materia,
      'grado': grado,
      'dia': dia,
      'fecha': FieldValue.serverTimestamp(),
      'usuarioId': _uid,
      'usuarioNombre': nombreCompleto,
    });
  }

  Future<void> _notificarEstudiantes(
    String grado,
    String titulo,
    String cuerpo,
  ) async {
    final tokensSnap =
        await _db
            .collection('usuarios')
            .where('rol', isEqualTo: 'estudiante')
            .where('grado', isEqualTo: grado)
            .get();

    final tokens =
        tokensSnap.docs
            .map((doc) => List<String>.from(doc['fcmTokens'] ?? []))
            .expand((e) => e)
            .toList();

    if (tokens.isEmpty) return;

    await _db.collection('notificaciones').add({
      'tokens': tokens,
      'titulo': titulo,
      'cuerpo': cuerpo,
      'fecha': FieldValue.serverTimestamp(),
    });
  }

  Future<List<DocumentSnapshot>> obtenerDocentesActivos() async {
    final snap =
        await _db
            .collection('usuarios')
            .where('rol', isEqualTo: 'docente')
            .where('estado', isEqualTo: 'activo')
            .get();
    return snap.docs;
  }

  Future<DocumentSnapshot?> obtenerDocentePorId(String docenteId) async {
    final doc = await _db.collection('usuarios').doc(docenteId).get();
    return doc.exists ? doc : null;
  }

  Future<List<String>> obtenerGradosConHorario() async {
    final snapshot = await _db.collection('horarios').get();
    final grados = snapshot.docs.map((doc) => doc.id).toList();
    grados.sort();
    return grados;
  }

  Future<Map<String, List<MateriaModel>>> obtenerHorarioDocente(
  String uidDocente,
) async {

  final snapshot = await _db.collection('horarios').get();
  final Map<String, List<MateriaModel>> horario = {};

  for (final gradoDoc in snapshot.docs) {
    final data = gradoDoc.data();
    final materiasMap = data['materias'] as Map<String, dynamic>?;

    if (materiasMap == null) continue;

    for (final dia in _dias) {
      final materiasDia = List<Map<String, dynamic>>.from(
        materiasMap[dia] ?? [],
      );

      for (final mat in materiasDia) {
        if (mat['docenteId'] == uidDocente) {
          final model = MateriaModel.fromMap(mat);
          horario.putIfAbsent(dia, () => []).add(model);
        }
      }
    }
  }

  return horario;
}

}
