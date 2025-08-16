import 'package:flutter/material.dart';

class DialogUtils {
  static Future<int?> askEstimatedMinutes(BuildContext context, String message) {
    final ctrl = TextEditingController();
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Builder(
          builder: (dialogContext) => AlertDialog(
            title: const Text('Estimación de tiempo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minutos estimados',
                    hintText: 'Ej. 7',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  final parsed = int.tryParse(ctrl.text);
                  if (parsed != null && parsed > 0) {
                    Navigator.pop(dialogContext, parsed);
                  } else {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Ingresa un número válido mayor a 0'),
                      ),
                    );
                  }
                },
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<bool?> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmButtonText = 'Sí',
    String cancelButtonText = 'No',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelButtonText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmButtonText),
          ),
        ],
      ),
    );
  }
}
