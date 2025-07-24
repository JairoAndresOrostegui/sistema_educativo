import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/materia_model.dart';
import '../utils/firebase_utils.dart'; // Usa tu función de enviarNotificacionRuta

class HorarioService {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  Future<String?> obtenerGradoDelUsuario() async {
    final snap = await _db.collection('usuarios').doc(_uid).get();
    return snap.data()?['grado'];
  }

  Future<Map<String, List<MateriaModel>>> obtenerHorario(String grado) async {
    final snap = await _db.collection('horarios').doc(grado).get();
    if (!snap.exists) return {};
    final data = snap.data()!;
    final materias = <String, List<MateriaModel>>{};
    for (final dia in data['materias']?.keys ?? []) {
      materias[dia] = List<Map<String, dynamic>>.from(data['materias'][dia])
          .map((e) => MateriaModel.fromMap(e))
          .toList();
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
        data['materias'][dia] ?? []);
    materiasDia.add(materia.toMap());

    data['materias'][dia] = materiasDia;
    data['ultimaModificacion'] = FieldValue.serverTimestamp();
    data['modificadoPor'] = _uid;

    await ref.set(data);

    await _registrarHistorial(grado, dia, materia, 'creado');
    await _notificarEstudiantes(grado, '📅 Nueva materia agregada al horario', materia.materia);
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

    if (data == null || data['materias'] == null || data['materias'][dia] == null) {
      throw Exception('No se encontró el horario del día $dia para el grado $grado');
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
    await _registrarHistorial(grado, dia, nuevaMateria, 'modificado');
    await _notificarEstudiantes(grado, '📝 Materia modificada en el horario', nuevaMateria.materia);
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
      grado,
      dia,
      MateriaModel.fromMap(materiaEliminada),
      'eliminado',
    );
    await _notificarEstudiantes(grado, '❌ Materia eliminada del horario', materiaEliminada['materia']);
  }

  Future<void> _registrarHistorial(
    String grado,
    String dia,
    MateriaModel materia,
    String accion,
  ) async {
    await _db
        .collection('historial_horarios')
        .doc(grado)
        .collection('cambios')
        .add({
      'docenteId': _uid,
      'fecha': Timestamp.now(),
      'accion': accion,
      'dia': dia,
      ...materia.toMap(),
    });
  }

  Future<void> _notificarEstudiantes(
    String grado,
    String titulo,
    String cuerpo,
  ) async {
    final snap = await _db
        .collection('usuarios')
        .where('grado', isEqualTo: grado)
        .where('activo', isEqualTo: true)
        .get();

    final tokens = snap.docs
        .map((d) => d.data()['fcmToken'])
        .whereType<String>()
        .toList();

    if (tokens.isNotEmpty) {
      await enviarNotificacionRuta(
        tokens: tokens,
        titulo: titulo,
        cuerpo: cuerpo,
      );
    }
  }
}
