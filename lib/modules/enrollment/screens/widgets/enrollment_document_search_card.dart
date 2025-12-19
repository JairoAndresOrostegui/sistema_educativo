import 'package:flutter/material.dart';

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
      color: Colors.redAccent.withValues(alpha: .03),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.redAccent.withValues(alpha: .15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Buscar estudiante',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.redAccent,
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
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: loading ? null : onSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar y prellenar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (selectedDocument != null && selectedDocument!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      'Documento seleccionado: $selectedDocument',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
