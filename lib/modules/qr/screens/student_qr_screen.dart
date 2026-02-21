import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../providers/user_provider_v2.dart';
import '../../../utils/navigation_utils.dart';

class StudentQrScreen extends StatelessWidget {
  const StudentQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<UserProviderV2>().user;
    final payload = user?.qrPayload ?? '';
    final enabled = user?.qrEnabled == true && payload.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR'),
        leading: const BackToDashboardButton(),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: enabled
              ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user?.document ?? '',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  QrImageView(
                    data: payload,
                    size: 240,
                    backgroundColor: Colors.white,
                    errorStateBuilder: (_, __) {
                      return const Text(
                        'No se pudo generar el QR.',
                        style: TextStyle(color: Colors.redAccent),
                      );
                    },
                  ),
                ],
              )
              : const Text(
                'QR no disponible. Solicite al administrador.',
                textAlign: TextAlign.center,
              ),
        ),
      ),
    );
  }
}
