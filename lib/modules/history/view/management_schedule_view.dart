import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/history/schedule_history_service.dart';
import '../../../utils/export/schedule_export_utils.dart';

class GestionHorariosView extends StatefulWidget {
  const GestionHorariosView({super.key});

  @override
  State<GestionHorariosView> createState() => _GestionHorariosViewState();
}

class _GestionHorariosViewState extends State<GestionHorariosView> {
  List<Map<String, dynamic>> _horarios = [];
  String _filtroGrado = '';
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final data = await ScheduleHistoryService.obtenerHistorialHorarios();
    setState(() {
      _horarios = data;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final registrosFiltrados =
        _horarios.where((e) {
          final grado = e['grado']?.toLowerCase() ?? '';
          return grado.contains(_filtroGrado.toLowerCase());
        }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: 'Total de registros de horarios',
              child: Text('Total registros: ${_horarios.length}'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 250,
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Filtrar por grado',
                    ),
                    onChanged: (v) => setState(() => _filtroGrado = v),
                  ),
                ),
                ElevatedButton(
                  onPressed: _cargar,
                  child: const Text('Filtrar'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (kIsWeb && _horarios.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        () => ScheduleHistoryUtils.exportarExcel(
                          registrosFiltrados,
                        ),
                    icon: const Icon(Icons.table_view),
                    label: const Text('Exportar Excel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed:
                        () => ScheduleHistoryUtils.exportarPDF(
                          registrosFiltrados,
                        ),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Exportar PDF'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child:
                  _cargando
                      ? const Center(child: CircularProgressIndicator())
                      : registrosFiltrados.isEmpty
                      ? const Center(child: Text('No hay registros'))
                      : ListView.builder(
                        itemCount: registrosFiltrados.length,
                        itemBuilder: (_, i) {
                          final r = registrosFiltrados[i];
                          final fecha = r['fecha']?.toDate();
                          final fechaTexto =
                              fecha != null
                                  ? DateFormat(
                                    'yyyy-MM-dd HH:mm:ss',
                                  ).format(fecha)
                                  : '-';
                          return Semantics(
                            label: 'Registro de log',
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                title: Text('${r['grado']} - ${r['accion']}'),
                                subtitle: Text(
                                  'Materia: ${r['materia']}\nDía: ${r['dia']}\nUsuario: ${r['usuarioNombre']}\nFecha: $fechaTexto',
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
