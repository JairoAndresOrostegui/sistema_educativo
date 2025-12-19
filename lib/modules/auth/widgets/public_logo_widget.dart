import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

import '../../../config/theme_config.dart';

class PublicLogoWidget extends StatelessWidget {
  final double? heightFactor; // Fraction of screen height (0.2 = 20%)

  const PublicLogoWidget({super.key, this.heightFactor = 0.2});

  Future<bool> _probeLogo(String url) async {
    try {
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

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
          child: FutureBuilder<bool>(
            future: _probeLogo(logoUrl),
            builder: (context, snapshot) {
              final ok = snapshot.data == true;

              if (ok) {
                return SvgPicture.network(
                  logoUrl,
                  height: targetHeight,
                  width: targetHeight * 2,
                  fit: BoxFit.contain,
                  placeholderBuilder: (context) =>
                      const CircularProgressIndicator(),
                );
              }

              // Fallback to local asset to avoid crashing if remote logo fails
              return Image.asset(
                'assets/logo.jpg',
                height: targetHeight,
                fit: BoxFit.contain,
              );
            },
          ),
        ),
      ),
    );
  }
}
