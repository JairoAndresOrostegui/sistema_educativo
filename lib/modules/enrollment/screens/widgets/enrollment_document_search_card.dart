import 'package:flutter/material.dart';
import 'package:sistema_educativo/config/app_palette.dart';

class EnrollmentDocumentSearchCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  final bool loading;
  final String? selectedDocument;

  const EnrollmentDocumentSearchCard({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.loading,
    required this.selectedDocument,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.primary.withValues(alpha: .03),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppPalette.primary.withValues(alpha: .15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Buscar estudiante',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppPalette.primary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Documento del estudiante',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: loading ? null : onSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar y prellenar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                    foregroundColor: AppPalette.surface,
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (selectedDocument != null && selectedDocument!.isNotEmpty)
                  Text(
                    'Documento seleccionado: $selectedDocument',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
