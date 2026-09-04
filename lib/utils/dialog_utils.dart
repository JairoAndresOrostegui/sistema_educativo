import 'package:sistema_educativo/config/app_palette.dart';
import 'package:flutter/material.dart';

class DialogUtils {
  static Future<void> showInfo({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    return _show(
      context: context,
      title: title,
      message: message,
      icon: Icons.info_outline,
      color: AppPalette.info,
    );
  }

  static Future<void> showSuccess({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    return _show(
      context: context,
      title: title,
      message: message,
      icon: Icons.check_circle_outline,
      color: AppPalette.success,
    );
  }

  static Future<void> showError({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    return _show(
      context: context,
      title: title,
      message: message,
      icon: Icons.error_outline,
      color: AppPalette.primary,
    );
  }

  static Future<void> _show({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(icon, color: color),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }
}
