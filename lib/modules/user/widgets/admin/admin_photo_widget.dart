import 'package:flutter/material.dart';
import 'package:sistema_educativo/config/app_palette.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ProfilePhotoWidget extends StatelessWidget {
  final String? imageUrl;
  final VoidCallback? onTap;
  final bool enableHoverEdit;

  final double radius;
  final double iconSize;

  const ProfilePhotoWidget({
    super.key,
    required this.imageUrl,
    this.onTap,
    this.enableHoverEdit = true,
    this.radius = 60,
    this.iconSize = 120,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: kIsWeb ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Semantics(
        label: 'Foto de perfil. Toca para cambiar la imagen.',
        image: true,
        enabled: true,
        focusable: true,
        child: GestureDetector(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              imageUrl != null && imageUrl!.isNotEmpty
                  ? CircleAvatar(
                      radius: radius,
                      backgroundImage: NetworkImage(imageUrl!),
                    )
                  : Icon(
                      Icons.account_circle,
                      size: iconSize,
                      color: AppPalette.info,
                    ),
              if (kIsWeb && enableHoverEdit)
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: onTap != null ? 1.0 : 0.0,
                    duration: Duration(milliseconds: 200),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppPalette.onSurface.withAlpha(100),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          'Editar foto',
                          style: TextStyle(
                            color: AppPalette.surface,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
