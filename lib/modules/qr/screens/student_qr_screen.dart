import 'package:sistema_educativo/config/app_palette.dart';
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
        title: Text('QR'),
        leading: BackToDashboardButton(),
        centerTitle: true,
        backgroundColor: AppPalette.surface,
        foregroundColor: AppPalette.primary,
      ),
      backgroundColor: AppPalette.surface,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: enabled
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 6),
                    Text(
                      user?.document ?? '',
                      style: TextStyle(
                        color: AppPalette.onSurface.withValues(alpha: .54),
                      ),
                    ),
                    SizedBox(height: 20),
                    QrImageView(
                      data: payload,
                      size: 240,
                      backgroundColor: AppPalette.surface,
                      errorStateBuilder: (context, error) {
                        return Text(
                          'No se pudo generar el QR.',
                          style: TextStyle(color: AppPalette.primary),
                        );
                      },
                    ),
                  ],
                )
              : Text(
                  'QR no disponible. Solicite al administrador.',
                  textAlign: TextAlign.center,
                ),
        ),
      ),
    );
  }
}
