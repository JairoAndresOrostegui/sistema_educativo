import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../config/theme_config.dart';

class PublicLogoWidget extends StatelessWidget {
  final double? heightFactor; // Fraction of screen height (0.2 = 20%)

  const PublicLogoWidget({super.key, this.heightFactor = 0.2});

  @override
  Widget build(BuildContext context) {
    final logoUrl = ThemeProvider.config?.logoUrl;

    if (logoUrl == null || logoUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final targetHeight = screenHeight * (heightFactor ?? 0.2);

    return Semantics(
      label: 'Logo del colegio',
      image: true,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: targetHeight,
            maxWidth: targetHeight * 2,
          ),
          child: SvgPicture.network(
            logoUrl,
            height: targetHeight,
            width: targetHeight * 2,
            fit: BoxFit.contain,
            placeholderBuilder:
                (context) => SizedBox(
                  height: targetHeight * 0.35,
                  width: targetHeight * 0.35,
                  child: const CircularProgressIndicator(),
                ),
            errorBuilder: (context, error, stackTrace) {
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}
