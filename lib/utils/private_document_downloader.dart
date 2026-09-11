import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

/// Private documents never expose a persistent Firebase Storage download token.
/// The server validates the current user, scope, child and document on each GET.
class PrivateDocumentDownloader {
  const PrivateDocumentDownloader({
    this.client,
    this.tokenProvider,
    this.projectId,
  });

  final http.Client? client;
  final Future<String?> Function()? tokenProvider;
  final String? projectId;
  static const maxBytes = 25 * 1024 * 1024;

  Future<Uint8List> download({
    required String endpoint,
    required Map<String, String> parameters,
  }) async {
    final token = await (tokenProvider != null
        ? tokenProvider!()
        : FirebaseAuth.instance.currentUser?.getIdToken());
    if (token == null || token.isEmpty) {
      throw FirebaseAuthException(code: 'user-token-expired');
    }
    final resolvedProject = projectId ?? Firebase.app().options.projectId;
    final uri = Uri.https(
      'us-central1-$resolvedProject.cloudfunctions.net',
      '/$endpoint',
      parameters,
    );
    final transport = client ?? http.Client();
    try {
      final request = http.Request('GET', uri)
        ..followRedirects = false
        ..headers['Authorization'] = 'Bearer $token';
      final response = await transport
          .send(request)
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        throw StateError(switch (response.statusCode) {
          401 => 'Tu sesión venció. Inicia sesión nuevamente.',
          403 => 'Ya no tienes acceso a este documento.',
          404 => 'El documento ya no está disponible.',
          409 => 'El documento no está disponible en su estado actual.',
          413 => 'El documento supera el tamaño permitido de 25 MiB.',
          _ => 'No fue posible descargar el documento. Intenta nuevamente.',
        });
      }
      if ((response.contentLength ?? 0) > maxBytes) {
        throw StateError('El documento supera el tamaño permitido de 25 MiB.');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 60),
      )) {
        if (bytes.length + chunk.length > maxBytes) {
          throw StateError(
            'El documento supera el tamaño permitido de 25 MiB.',
          );
        }
        bytes.add(chunk);
      }
      if (bytes.isEmpty) {
        throw StateError('El documento está vacío o ya no está disponible.');
      }
      return bytes.takeBytes();
    } on http.ClientException {
      throw StateError(
        'No fue posible conectar. Revisa tu conexión e intenta nuevamente.',
      );
    } finally {
      if (client == null) transport.close();
    }
  }
}
