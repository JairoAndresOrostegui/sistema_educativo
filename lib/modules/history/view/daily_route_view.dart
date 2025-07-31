// Archivo: screens/admin_history/views/rutas_diarias_view.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../services/history/daily_route_history_service.dart';
import '../../../utils/export/daily_route_export_utils.dart';
import '../../../utils/format_utils.dart';

class RutasDiariasView extends StatefulWidget {
  const RutasDiariasView({super.key});

  @override
  State<RutasDiariasView> createState() => _RutasDiariasViewState();
}

class _RutasDiariasViewState extends State<RutasDiariasView> {
  String? _nombreRuta;
  String? _estadoSeleccionado;
  DateTime? _fechaSeleccionada;
  int _porPagina = 20;
  int _pagina = 0;
  List<Map<String, dynamic>> _rutas = [];
  int _totalFinalizadas = 0;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);

    final data = await RutaHistoryService().obtenerHistorialRutas(
      nombreRuta: _nombreRuta,
      estado: _estadoSeleccionado,
      fecha: _fechaSeleccionada,
      limite: _porPagina,
      pagina: _pagina,
    );

    final total = await RutaHistoryService().contarRutasFinalizadas();

    setState(() {
      _rutas = data;
      _totalFinalizadas = total;
      _cargando = false;
    });
  }

  void _siguientePagina() {
    setState(() => _pagina++);
    _cargar();
  }

  void _paginaAnterior() {
    if (_pagina > 0) {
      setState(() => _pagina--);
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Center(
        child: Text(
          'Esta funcionalidad solo está disponible en la versión web.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: 'Total de rutas finalizadas',
              child: Text('Total finalizadas: $_totalFinalizadas'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 200,
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la ruta',
                    ),
                    onChanged: (v) => _nombreRuta = v,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: _estadoSeleccionado,
                    items:
                        ['finalizada', 'activa', 'pendiente']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _estadoSeleccionado = v),
                    decoration: const InputDecoration(labelText: 'Estado'),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextFormField(
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Fecha'),
                    controller: TextEditingController(
                      text:
                          _fechaSeleccionada == null
                              ? ''
                              : DateFormat(
                                'yyyy-MM-dd',
                              ).format(_fechaSeleccionada!),
                    ),
                    onTap: () async {
                      final fecha = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (fecha != null) {
                        setState(() => _fechaSeleccionada = fecha);
                      }
                    },
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
                    onPressed: () => ExportUtils.exportarExcel(_rutas),
                    icon: const Icon(Icons.table_view),
                    label: const Text('Exportar Excel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => ExportUtils.exportarPDF(_rutas),
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
                      : ListView.builder(
                        itemCount: _rutas.length,
                        itemBuilder: (_, i) => _buildRutaItem(_rutas[i]),
                      ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<int>(
                  value: _porPagina,
                  items:
                      [10, 20, 50]
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text('Mostrar $e'),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (v) => setState(() {
                        _porPagina = v!;
                        _pagina = 0;
                        _cargar();
                      }),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _paginaAnterior,
                    ),
                    Text('Página ${_pagina + 1}'),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _siguientePagina,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRutaItem(Map<String, dynamic> ruta) {
    final estudiantes = List<Map<String, dynamic>>.from(
      ruta['estudiantes'] ?? [],
    );
    final fecha = (ruta['fecha'] as Timestamp).toDate();
    final inicioTs = ruta['horaInicio'];
    final finTs = ruta['horaFin'];
    final inicio = inicioTs is Timestamp ? inicioTs.toDate() : null;
    final fin = finTs is Timestamp ? finTs.toDate() : null;
    final duracion =
        (inicio != null && fin != null) ? fin.difference(inicio).inMinutes : 0;

    final estado = ruta['estado'] ?? '';

    return Semantics(
      label:
          'Ruta ${ruta['nombreRuta']} realizada el ${FormatUtils.formatoFechaHora(fecha)} por ${ruta['gestionadaPorNombre']} estado $estado',
      child: ExpansionTile(
        title: Text(ruta['nombreRuta'] ?? ''),
        subtitle: Text(
          'Por: ${ruta['gestionadaPorNombre']} • ${FormatUtils.formatoFechaHora(fecha)}\nEstado: $estado\nDuración: $duracion min',
        ),
        children:
            estudiantes.map((est) {
              final recogido = est['recogido'] == true ? 'Si' : 'No';
              final anulado = est['anulado'] == true ? 'Si' : 'No';
              final activo = est['activo'] == true ? 'Si' : 'No';
              final hora =
                  est['horaRecogida'] != null
                      ? FormatUtils.formatoHora(
                        (est['horaRecogida'] as Timestamp).toDate(),
                      )
                      : '-';
              final avisos = est['avisosEnviados'] ?? 0;

              return ListTile(
                title: Text(est['nombre']),
                subtitle: Text(
                  'Dirección: ${est['direccion'] ?? ''}\nHora: $hora\nAvisos enviados: $avisos',
                ),
                trailing: Text(
                  'Recogido: $recogido\nAnulado: $anulado\nEn ruta: $activo',
                  style: TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
      ),
    );
  }
}
