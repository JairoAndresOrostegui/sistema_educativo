import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/history/file_history_service.dart';
import '../../../utils/export/file_export_utils.dart';

class GestionDocumentosView extends StatefulWidget {
  const GestionDocumentosView({super.key});

  @override
  State<GestionDocumentosView> createState() => _GestionDocumentosViewState();
}

class _GestionDocumentosViewState extends State<GestionDocumentosView> {
  List<Map<String, dynamic>> _documentos = [];
  String _filtroGrado = '';
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final data = await DocumentHistoryService().obtenerHistorialDocumentos();
    setState(() {
      _documentos = data;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final registrosFiltrados = _documentos.where((e) {
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
              label: 'Total de documentos subidos',
              child: Text('Total registros: ${_documentos.length}'),
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
            if (kIsWeb && _documentos.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => DocumentHistoryUtils.exportarExcel(registrosFiltrados),
                    icon: const Icon(Icons.table_view),
                    label: const Text('Exportar Excel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => DocumentHistoryUtils.exportarPDF(registrosFiltrados),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Exportar PDF'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : registrosFiltrados.isEmpty
                      ? const Center(child: Text('No hay registros'))
                      : ListView.builder(
                          itemCount: registrosFiltrados.length,
                          itemBuilder: (_, i) {
                            final r = registrosFiltrados[i];
                            final fecha = r['fechaSubida'];
                            final fechaTexto = fecha != null
                                ? DateFormat('yyyy-MM-dd HH:mm:ss').format(fecha)
                                : '-';
                            return Semantics(
                              label: 'Registro de documento subido',
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: ListTile(
                                  title: Text('📄 ${r['nombre']}'),
                                  subtitle: Text(
                                    'Grado: ${r['grado']}\nSubido por: ${r['subidoPor']}\nFecha: $fechaTexto',
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
