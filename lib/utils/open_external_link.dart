import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openExternalLink(
  BuildContext context,
  Uri uri, {
  LaunchMode mode = LaunchMode.platformDefault,
  Future<bool> Function(Uri uri)? launcher,
}) async {
  try {
    if (!{'https', 'http', 'mailto', 'tel'}.contains(uri.scheme) ||
        !await (launcher?.call(uri) ?? launchUrl(uri, mode: mode))) {
      throw StateError(
        'No hay una aplicación disponible para abrir el enlace.',
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text(
          'No se pudo abrir el enlace. Comprueba que tengas una aplicación compatible.',
        ),
      ),
    );
  }
}
