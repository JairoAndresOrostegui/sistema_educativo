import 'package:flutter/material.dart';
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
                    color: const Color.fromARGB(255, 31, 155, 212),
                  ),
              if (kIsWeb && enableHoverEdit)
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: onTap != null ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'Editar foto',
                          style: TextStyle(color: Colors.white, fontSize: 14),
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
