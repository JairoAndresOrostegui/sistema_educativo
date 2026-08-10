import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

class WebsiteVideoEmbed extends StatefulWidget {
  final String url;
  final bool preview;

  const WebsiteVideoEmbed({super.key, required this.url, this.preview = false});

  @override
  State<WebsiteVideoEmbed> createState() => _WebsiteVideoEmbedState();
}

class _WebsiteVideoEmbedState extends State<WebsiteVideoEmbed> {
  late final String _viewType;
  String? _embedUrl;

  @override
  void initState() {
    super.initState();
    _embedUrl = _toEmbedUrl(widget.url);
    _viewType = 'website-video-${identityHashCode(this)}';
    if (_embedUrl != null) {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
        final frame = html.IFrameElement()
          ..src = _embedUrl!
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow =
              'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
          ..allowFullscreen = true;
        return frame;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: _embedUrl == null
        ? ColoredBox(
            color: Theme.of(context).colorScheme.errorContainer,
            child: const Center(child: Text('Enlace de video no compatible')),
          )
        : IgnorePointer(
            ignoring: widget.preview,
            child: HtmlElementView(viewType: _viewType),
          ),
  );
}

String? _toEmbedUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme != 'https') return null;
  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
    return 'https://www.youtube-nocookie.com/embed/${uri.pathSegments.first}';
  }
  if (host == 'youtube.com' || host == 'm.youtube.com') {
    final id =
        uri.queryParameters['v'] ??
        (uri.pathSegments.contains('shorts') && uri.pathSegments.length > 1
            ? uri.pathSegments[1]
            : null);
    if (id != null && id.isNotEmpty) {
      return 'https://www.youtube-nocookie.com/embed/$id';
    }
  }
  if (host == 'vimeo.com' && uri.pathSegments.isNotEmpty) {
    final id = uri.pathSegments.last;
    if (RegExp(r'^\d+$').hasMatch(id)) {
      return 'https://player.vimeo.com/video/$id';
    }
  }
  return null;
}
