// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/materia_model.dart';
import '../../../services/horario_service.dart';

class AdminHorarioScreen extends StatefulWidget {
  const AdminHorarioScreen({super.key});

  @override
  State<AdminHorarioScreen> createState() => _AdminHorarioScreenState();
}

class _AdminHorarioScreenState extends State<AdminHorarioScreen> {
  final _horarioService = HorarioService();
  final _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes'];
  String? gradoSeleccionado;
  Map<String, List<MateriaModel>> horario = {};
  List<QueryDocumentSnapshot> historial = [];
  bool cargando = false;

  Map<String, String> docentes = {}; // Cache para ID => Nombre completo

  @override
  void initState() {
    super.initState();
    _cargarGrados();
  }

  List<String> grados = [];

  Future<void> _cargarGrados() async {
    final snap = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('rol', isEqualTo: 'estudiante')
        .get();

    final g = snap.docs.map((d) => d['grado'] as String).toSet().toList()..sort();
    setState(() {
      grados = g;
    });
  }

  Future<void> _cargarDatos() async {
    if (gradoSeleccionado == null) return;
    setState(() => cargando = true);

    final h = await _horarioService.obtenerHorario(gradoSeleccionado!);

    final snap = await FirebaseFirestore.instance
        .collection('historial_horarios')
        .doc(gradoSeleccionado)
        .collection('cambios')
        .orderBy('fecha', descending: true)
        .get();

    // Cargar docentes (solo los que estén en el horario)
    final Set<String> idsDocentes = {};
    for (final lista in h.values) {
      for (final m in lista) {
        idsDocentes.add(m.docenteId);
      }
    }

    final docentesSnap = await FirebaseFirestore.instance
        .collection('usuarios')
        .where(FieldPath.documentId, whereIn: idsDocentes.toList())
        .get();

    docentes = {
      for (final d in docentesSnap.docs)
        d.id: '${d['nombres']} ${d['apellidos']}'
    };

    setState(() {
      horario = h;
      historial = snap.docs;
      cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isLargeScreenOrWeb = kIsWeb || MediaQuery.of(context).size.width > 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de horarios'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: gradoSeleccionado,
              decoration: const InputDecoration(labelText: 'Selecciona un grado'),
              items: grados.map((g) {
                return DropdownMenuItem(value: g, child: Text(g));
              }).toList(),
              onChanged: (value) {
                setState(() => gradoSeleccionado = value);
                _cargarDatos();
              },
            ),
            const SizedBox(height: 20),
            if (cargando)
              const Center(child: CircularProgressIndicator())
            else if (gradoSeleccionado != null)
              Expanded(
                child: isLargeScreenOrWeb
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _buildHorarioSection()),
                          const SizedBox(width: 16),
                          Expanded(flex: 1, child: _buildHistorialSection()),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: _buildHorarioSection()),
                          const SizedBox(height: 16),
                          Expanded(child: _buildHistorialSection()),
                        ],
                      ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildHorarioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Horario',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: _dias.map((dia) {
              final materias = [...(horario[dia] ?? [])]
                ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dia.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (materias.isEmpty)
                        const Text('Sin materias')
                      else
                        ...materias.map((m) => ListTile(
                              title: Text(m.materia),
                              subtitle: Text(
                                '${DateFormat('HH:mm').format(m.horaInicio.toDate())} - '
                                '${DateFormat('HH:mm').format(m.horaFin.toDate())}',
                              ),
                              trailing: Text(
                                docentes[m.docenteId] ?? 'Desconocido',
                                style: const TextStyle(fontSize: 12),
                              ),
                            )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorialSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Historial de cambios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 10),
        Expanded(
          child: historial.isEmpty
              ? const Text('Sin historial')
              : ListView.builder(
                  itemCount: historial.length,
                  itemBuilder: (ctx, i) {
                    final h = historial[i].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          h['accion'] == 'creado'
                              ? Icons.add
                              : h['accion'] == 'modificado'
                                  ? Icons.edit
                                  : Icons.delete,
                          color: h['accion'] == 'eliminado'
                              ? Colors.red
                              : h['accion'] == 'modificado'
                                  ? Colors.orange
                                  : Colors.green,
                        ),
                        title: Text(h['materia'] ?? ''),
                        subtitle: Text(
                          '${h['dia']?.toUpperCase() ?? ''} - ${h['accion']}'
                          '\n${DateFormat.yMd().add_Hm().format((h['fecha'] as Timestamp).toDate())}',
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
