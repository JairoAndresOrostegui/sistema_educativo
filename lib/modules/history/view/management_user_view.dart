import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/history/user_history_service.dart';
import '../../../utils/export/user_export_utils.dart';

class GestionUsuariosView extends StatefulWidget {
  const GestionUsuariosView({super.key});

  @override
  State<GestionUsuariosView> createState() => _GestionUsuariosViewState();
}

class _GestionUsuariosViewState extends State<GestionUsuariosView> {
  List<Map<String, dynamic>> _usuarios = [];
  String _filtroNombre = '';
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final data = await UserHistoryService().obtenerHistorial();
    setState(() {
      _usuarios = data;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final registrosFiltrados =
        _usuarios.where((e) {
          final nombre = e['nombres']?.toLowerCase() ?? '';
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
              label: 'Total de registros de usuario',
              child: Text('Total registros: ${_usuarios.length}'),
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
                      labelText: 'Buscar por nombre',
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
            if (kIsWeb && _usuarios.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        () =>
                            UserHistoryUtils.exportarExcel(registrosFiltrados),
                    icon: const Icon(Icons.table_view),
                    label: const Text('Exportar Excel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed:
                        () => UserHistoryUtils.exportarPDF(registrosFiltrados),
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
                          final fecha = r['fecha'];
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
                                  '${r['nombres']} ${r['apellidos']} - ${r['accion']}',
                                ),
                                subtitle: Text(
                                  'Rol: ${r['rol']}\nRealizado por: ${r['realizadoPor']}\nFecha: $fechaTexto',
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
