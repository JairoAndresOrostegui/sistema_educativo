import 'package:flutter/material.dart';

import 'admin_photo_widget.dart';

class PhotoSection extends StatelessWidget {
  final String? fotoUrl;
  final VoidCallback onPickPhoto;
  final bool soloLectura;
  const PhotoSection({
    super.key,
    required this.fotoUrl,
    required this.onPickPhoto,
    required this.soloLectura,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ProfilePhotoWidget(
          imageUrl: fotoUrl,
          onTap: onPickPhoto,
          enableHoverEdit: !soloLectura,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
