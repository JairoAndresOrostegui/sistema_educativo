// ADMIN RUTAS CON ESTILOS APLICADOS
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class AdminRutasScreen extends StatefulWidget {
  const AdminRutasScreen({super.key});

  @override
  State<AdminRutasScreen> createState() => _AdminRutasScreenState();
}

class _AdminRutasScreenState extends State<AdminRutasScreen> {
  List<DocumentSnapshot> rutas = [];
  bool isLoading = true;
  final _busquedaController = TextEditingController();
  String _textoBusqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarRutas();
    _busquedaController.addListener(() {
      setState(() {
        _textoBusqueda = _busquedaController.text.toLowerCase();
      });
    });
  }

  Future<void> _cargarRutas() async {
    final query = await FirebaseFirestore.instance.collection('rutas').get();
    setState(() {
      rutas = query.docs;
      isLoading = false;
    });
  }

  Future<void> _mostrarFormulario({DocumentSnapshot? ruta}) async {
    final data = ruta?.data() as Map<String, dynamic>? ?? {};
    final nombre = TextEditingController(text: data['nombre'] ?? '');
    final direccionInicio = TextEditingController(
      text: data['direccionInicio'] ?? '',
    );
    DateTime? fechaInicio =
        data['fechaInicio'] != null
            ? (data['fechaInicio'] as Timestamp).toDate()
            : null;
    DateTime? fechaFin =
        data['fechaFin'] != null
            ? (data['fechaFin'] as Timestamp).toDate()
            : null;
    TimeOfDay? horaInicio =
        data['horaInicio'] != null
            ? TimeOfDay.fromDateTime((data['horaInicio'] as Timestamp).toDate())
            : null;
    TimeOfDay? horaFin =
        data['horaFin'] != null
            ? TimeOfDay.fromDateTime((data['horaFin'] as Timestamp).toDate())
            : null;
    List<Map<String, dynamic>> estudiantesOrdenados = [];
    String? gestionador = data['gestionador'];

    final users = await FirebaseFirestore.instance.collection('usuarios').get();
    final estudiantes =
        users.docs.where((u) => u['rol'] == 'estudiante').toList();
    final gestores =
        users.docs
            .where((u) => u['rol'] == 'admin' || u['rol'] == 'docente')
            .toList();

    if (data['estudiantes'] != null) {
      for (var id in List<String>.from(data['estudiantes'])) {
        final est = estudiantes.firstWhereOrNull((e) => e.id == id);
        if (est != null) {
          estudiantesOrdenados.add({
            'id': est.id,
            'nombre': '${est['nombres']} ${est['apellidos']}',
          });
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final gestionadorSeleccionado =
                gestionador != null
                    ? gestores.firstWhereOrNull((u) => u.id == gestionador)
                    : null;

            return AlertDialog(
              backgroundColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
              title: Center(
                child: Text(
                  ruta == null ? 'Crear ruta' : 'Editar ruta',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                height: MediaQuery.of(context).size.height * 0.85,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildField(nombre, 'Nombre de la ruta'),
                      _buildField(direccionInicio, 'Dirección de inicio'),
                      _buildFecha(
                        setModalState,
                        'Fecha inicio',
                        fechaInicio,
                        (val) => fechaInicio = val,
                      ),
                      _buildFecha(
                        setModalState,
                        'Fecha fin',
                        fechaFin,
                        (val) => fechaFin = val,
                      ),
                      _buildHora(
                        setModalState,
                        'Hora inicio',
                        horaInicio,
                        (val) => horaInicio = val,
                      ),
                      _buildHora(
                        setModalState,
                        'Hora fin',
                        horaFin,
                        (val) => horaFin = val,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Estudiantes asignados (orden de recogida)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TypeAheadFormField<DocumentSnapshot>(
                        textFieldConfiguration: const TextFieldConfiguration(
                          decoration: InputDecoration(
                            labelText: 'Buscar estudiante',
                          ),
                        ),
                        suggestionsCallback: (pattern) {
                          final texto = pattern.toLowerCase();
                          return estudiantes.where((e) {
                            final nombreCompleto =
                                '${e['nombres']} ${e['apellidos']}'
                                    .toLowerCase();
                            return nombreCompleto.contains(texto) &&
                                !estudiantesOrdenados.any(
                                  (eo) => eo['id'] == e.id,
                                );
                          }).toList();
                        },
                        itemBuilder: (context, DocumentSnapshot suggestion) {
                          return ListTile(
                            title: Text(
                              '${suggestion['nombres']} ${suggestion['apellidos']}',
                            ),
                          );
                        },
                        onSuggestionSelected: (DocumentSnapshot seleccionado) {
                          setModalState(() {
                            estudiantesOrdenados.add({
                              'id': seleccionado.id,
                              'nombre':
                                  '${seleccionado['nombres']} ${seleccionado['apellidos']}',
                            });
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 200,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F9F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ReorderableListView(
                          onReorder: (oldIndex, newIndex) {
                            setModalState(() {
                              if (newIndex > oldIndex) newIndex--;
                              final item = estudiantesOrdenados.removeAt(
                                oldIndex,
                              );
                              estudiantesOrdenados.insert(newIndex, item);
                            });
                          },
                          children:
                              estudiantesOrdenados.map((e) {
                                return ListTile(
                                  key: ValueKey(e['id']),
                                  title: Text(e['nombre']),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                    onPressed:
                                        () => setModalState(
                                          () =>
                                              estudiantesOrdenados.removeWhere(
                                                (el) => el['id'] == e['id'],
                                              ),
                                        ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Gestionador asignado',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TypeAheadFormField<DocumentSnapshot>(
                        textFieldConfiguration: TextFieldConfiguration(
                          decoration: const InputDecoration(
                            labelText: 'Buscar gestionador',
                          ),
                          controller: TextEditingController(
                            text:
                                gestionadorSeleccionado != null
                                    ? '${gestionadorSeleccionado['nombres']} ${gestionadorSeleccionado['apellidos']}'
                                    : '',
                          ),
                        ),
                        suggestionsCallback: (pattern) {
                          final texto = pattern.toLowerCase();
                          return gestores.where((u) {
                            final nombreCompleto =
                                '${u['nombres']} ${u['apellidos']}'
                                    .toLowerCase();
                            return nombreCompleto.contains(texto);
                          }).toList();
                        },
                        itemBuilder: (context, DocumentSnapshot suggestion) {
                          return ListTile(
                            title: Text(
                              '${suggestion['nombres']} ${suggestion['apellidos']}',
                            ),
                          );
                        },
                        onSuggestionSelected: (DocumentSnapshot seleccionado) {
                          setModalState(() => gestionador = seleccionado.id);
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          final ref = FirebaseFirestore.instance.collection(
                            'rutas',
                          );
                          final doc = {
                            'nombre': nombre.text,
                            'direccionInicio': direccionInicio.text,
                            'fechaInicio':
                                fechaInicio != null
                                    ? Timestamp.fromDate(fechaInicio!)
                                    : null,
                            'fechaFin':
                                fechaFin != null
                                    ? Timestamp.fromDate(fechaFin!)
                                    : null,
                            'horaInicio':
                                horaInicio != null
                                    ? Timestamp.fromDate(
                                      DateTime(
                                        2000,
                                        1,
                                        1,
                                        horaInicio!.hour,
                                        horaInicio!.minute,
                                      ),
                                    )
                                    : null,
                            'horaFin':
                                horaFin != null
                                    ? Timestamp.fromDate(
                                      DateTime(
                                        2000,
                                        1,
                                        1,
                                        horaFin!.hour,
                                        horaFin!.minute,
                                      ),
                                    )
                                    : null,
                            'estudiantes':
                                estudiantesOrdenados
                                    .map((e) => e['id'])
                                    .toList(),
                            'gestionador': gestionador,
                          };
                          if (ruta == null) {
                            await ref.add(doc);
                          } else {
                            await ref.doc(ruta.id).update(doc);
                          }
                          if (mounted) {
                            Navigator.pop(ctx);
                            _cargarRutas();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Guardar'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildFecha(
    StateSetter setModalState,
    String label,
    DateTime? fecha,
    Function(DateTime) onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$label: ${fecha != null ? DateFormat('yyyy-MM-dd').format(fecha) : 'No seleccionada'}',
          ),
        ),
        IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () async {
            final f = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (f != null) setModalState(() => onChanged(f));
          },
        ),
      ],
    );
  }

  Widget _buildHora(
    StateSetter setModalState,
    String label,
    TimeOfDay? hora,
    Function(TimeOfDay) onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$label: ${hora != null ? hora.format(context) : 'No seleccionada'}',
          ),
        ),
        IconButton(
          icon: const Icon(Icons.access_time),
          onPressed: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (t != null) setModalState(() => onChanged(t));
          },
        ),
      ],
    );
  }

  void _eliminarRuta(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: const Text(
              '¿Deseas eliminar esta ruta? Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
    if (confirmar == true) {
      await FirebaseFirestore.instance.collection('rutas').doc(id).delete();
      _cargarRutas();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Gestión de Rutas'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        elevation: 1,
        leading: const BackButton(color: Colors.black),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormulario(),
        child: const Icon(Icons.add),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      controller: _busquedaController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar ruta...',
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: rutas.length,
                      itemBuilder: (context, index) {
                        final ruta = rutas[index];
                        final data = ruta.data() as Map<String, dynamic>;
                        final nombreRuta = data['nombre']?.toLowerCase() ?? '';
                        if (_textoBusqueda.isNotEmpty &&
                            !nombreRuta.contains(_textoBusqueda)) {
                          return const SizedBox.shrink();
                        }
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          color: const Color(0xFFF5F5F5),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.route),
                            title: Text(data['nombre'] ?? ''),
                            subtitle: Text(
                              'Desde: ${data['direccionInicio'] ?? 'sin dirección'}',
                            ),
                            trailing:
                                isMobile
                                    ? null
                                    : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed:
                                              () => _mostrarFormulario(
                                                ruta: ruta,
                                              ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed:
                                              () => _eliminarRuta(ruta.id),
                                        ),
                                      ],
                                    ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
