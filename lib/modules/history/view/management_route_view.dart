import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/history/route_history_service.dart';
import '../../../utils/export/route_export_utils.dart';

class GestionRutasView extends StatefulWidget {
  const GestionRutasView({super.key});

  @override
  State<GestionRutasView> createState() => _GestionRutasViewState();
}

class _GestionRutasViewState extends State<GestionRutasView> {
  List<Map<String, dynamic>> _rutas = [];
  String _filtroNombre = '';
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final data = await AdminRouteLogService.obtenerHistorialRutasAdmin();
    setState(() {
      _rutas = data;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final registrosFiltrados =
        _rutas.where((e) {
          final nombre = e['nombreRuta']?.toLowerCase() ?? '';
          return nombre.contains(_filtroNombre.toLowerCase());
        }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: 'Total de registros de rutas',
              child: Text('Total registros: ${_rutas.length}'),
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
                      labelText: 'Buscar por nombre de ruta',
                    ),
                    onChanged: (v) => setState(() => _filtroNombre = v),
                  ),
                ),
                ElevatedButton(
                  onPressed: _cargar,
                  child: const Text('Filtrar'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (kIsWeb && _rutas.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        () => AdminRouteLogUtils.exportarExcel(
                          registrosFiltrados,
                        ),
                    icon: const Icon(Icons.table_view),
                    label: const Text('Exportar Excel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed:
                        () =>
                            AdminRouteLogUtils.exportarPDF(registrosFiltrados),
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
                                title: Text(
                                  '${r['nombreRuta']} - ${r['accion']}',
                                ),
                                subtitle: Text(
                                  'Por: ${r['nombreAdmin']}\nFecha: $fechaTexto',
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
