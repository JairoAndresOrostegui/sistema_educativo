import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sistema_educativo/modules/user/services/teacher_bulk_import_service.dart';
import 'package:sistema_educativo/providers/user_provider_v2.dart';

class TeacherBulkImportDialog extends StatefulWidget {
  const TeacherBulkImportDialog({super.key});

  @override
  State<TeacherBulkImportDialog> createState() => _TeacherBulkImportDialogState();
}

class _TeacherBulkImportDialogState extends State<TeacherBulkImportDialog> {
  final TeacherBulkImportService _service = TeacherBulkImportService();

  PlatformFile? _selectedFile;
  TeacherBulkImportResult? _result;
  bool _loading = false;
  bool _shouldRefresh = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const <String>['xlsx', 'xls'],
    );

    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      _selectedFile = result.files.first;
      _result = null;
    });
  }

  Future<void> _import() async {
    final file = _selectedFile;
    if (file?.bytes == null) {
      return;
    }

    final user = context.read<UserProviderV2>().user;
    if (user == null) {
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await _service.importTeachersFromBytes(
        bytes: file!.bytes!,
        usuarioLogueado: user,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
        _shouldRefresh = result.createdCount > 0;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _result = TeacherBulkImportResult(
          totalRows: 0,
          createdCount: 0,
          failures: <TeacherBulkImportFailure>[
            TeacherBulkImportFailure(
              rowNumber: 0,
              displayName: file!.name,
              reason: _cleanError(e),
            ),
          ],
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _cleanError(Object error) {
    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Importar docentes desde Excel',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(_shouldRefresh),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Usa un archivo .xlsx o .xls. El rol se crea como Docente, la contrasena inicial sera el documento y la institucion/sede se toman del administrador logueado.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: .15)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Columnas recomendadas',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text('Obligatorias: nombres, apellidos, documento, correo, grado'),
                    SizedBox(height: 4),
                    Text('Opcionales: tipo_documento, correo_institucional, estado'),
                    SizedBox(height: 8),
                    Text(
                      'Si solo tienes una columna de nombre completo, usa nombre_completo en lugar de nombres y apellidos.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Seleccionar archivo'),
                  ),
                  if (_selectedFile != null)
                    Text(
                      _selectedFile!.name,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ElevatedButton.icon(
                    onPressed:
                        _loading || _selectedFile?.bytes == null ? null : _import,
                    icon:
                        _loading
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.upload_file),
                    label: Text(_loading ? 'Importando...' : 'Importar docentes'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: _result == null ? _buildExampleTable() : _buildResultCard(),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(_shouldRefresh),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExampleTable() {
    const rows = <List<String>>[
      <String>[
        'nombres',
        'apellidos',
        'documento',
        'correo',
        'grado',
        'tipo_documento',
        'correo_institucional',
        'estado',
      ],
      <String>[
        'Ana Maria',
        'Perez Gomez',
        '12345678',
        'ana.perez@colegio.edu.co',
        '8A',
        'CC',
        'ana.perez@colegio.edu.co',
        'activo',
      ],
    ];

    return Table(
      border: TableBorder.all(color: Colors.black12),
      columnWidths: const <int, TableColumnWidth>{
        0: IntrinsicColumnWidth(),
        1: IntrinsicColumnWidth(),
        2: IntrinsicColumnWidth(),
        3: FlexColumnWidth(),
        4: IntrinsicColumnWidth(),
        5: IntrinsicColumnWidth(),
        6: FlexColumnWidth(),
        7: IntrinsicColumnWidth(),
      },
      children:
          rows.map((row) {
            final isHeader = row == rows.first;
            return TableRow(
              decoration: BoxDecoration(
                color: isHeader ? Colors.black.withValues(alpha: .04) : null,
              ),
              children:
                  row.map((cell) {
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        cell,
                        style: TextStyle(
                          fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    );
                  }).toList(),
            );
          }).toList(),
    );
  }

  Widget _buildResultCard() {
    final result = _result!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha: .16)),
          ),
          child: Text(
            'Filas procesadas: ${result.totalRows} | Creados: ${result.createdCount} | Fallidos: ${result.failedCount}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),
        if (result.failures.isEmpty)
          const Text('Importacion completada sin errores.')
        else
          ...result.failures.map(
            (failure) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: .14)),
              ),
              child: Text(
                failure.rowNumber > 0
                    ? 'Fila ${failure.rowNumber} - ${failure.displayName}: ${failure.reason}'
                    : '${failure.displayName}: ${failure.reason}',
              ),
            ),
          ),
      ],
    );
  }
}
