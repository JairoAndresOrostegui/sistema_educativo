import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WebsiteVideoEmbed extends StatelessWidget {
  final String url;
  final bool preview;

  const WebsiteVideoEmbed({super.key, required this.url, this.preview = false});

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: FilledButton.icon(
          onPressed: preview ? null : () => launchUrl(Uri.parse(url)),
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Ver video'),
        ),
      ),
    ),
  );
}
