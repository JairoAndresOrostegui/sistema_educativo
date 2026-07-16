import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/website_content.dart';
import '../services/website_service.dart';

class PublicWebsiteScreen extends StatefulWidget {
  const PublicWebsiteScreen({super.key});

  @override
  State<PublicWebsiteScreen> createState() => _PublicWebsiteScreenState();
}

class _PublicWebsiteScreenState extends State<PublicWebsiteScreen> {
  final _topKey = GlobalKey();
  final _contactKey = GlobalKey();
  final Map<String, GlobalKey> _pageKeys = {
    for (final id in ['about', 'admissions', 'learning', 'news', 'parents'])
      id: GlobalKey(),
  };

  void _goTo(GlobalKey key) {
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WebsiteContent>(
      stream: WebsiteService().watch(),
      builder: (context, snapshot) {
        final content = snapshot.data ?? WebsiteContent.defaults;
        final color = _hexColor(content.primaryColor);
        for (final item in content.navigation) {
          _pageKeys.putIfAbsent(item.id, GlobalKey.new);
        }
        return Scaffold(
          backgroundColor: const Color(0xFFFAF8F5),
          body: SelectionArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(
                    key: _topKey,
                    content: content,
                    color: color,
                    onHome: () => _goTo(_topKey),
                    onNavigate: (id) => _goTo(_pageKeys[id]!),
                    onLogin: () => context.go('/login'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _Hero(content: content, color: color),
                ),
                SliverToBoxAdapter(
                  child: _Sections(
                    content: content,
                    color: color,
                    pageKeys: _pageKeys,
                  ),
                ),
                SliverToBoxAdapter(
                  key: _contactKey,
                  child: _Footer(content: content, color: color),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final WebsiteContent content;
  final Color color;
  final VoidCallback onHome;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogin;

  const _Header({
    super.key,
    required this.content,
    required this.color,
    required this.onHome,
    required this.onNavigate,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 850;
          final navigation =
              content.navigation.where((item) => item.enabled).toList();
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 18 : 48,
              vertical: 14,
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: onHome,
                  borderRadius: BorderRadius.circular(8),
                  child: _SiteImage(
                    url: content.logoUrl,
                    width: compact ? 48 : 62,
                    height: compact ? 48 : 62,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content.schoolName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: compact ? 16 : 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (!compact)
                        Text(
                          content.tagline,
                          style: const TextStyle(color: Colors.black54),
                        ),
                    ],
                  ),
                ),
                if (!compact) ...[
                  for (final item in navigation)
                    TextButton(
                      onPressed: () => onNavigate(item.id),
                      child: Text(item.label),
                    ),
                  const SizedBox(width: 10),
                ] else
                  PopupMenuButton<String>(
                    tooltip: 'Navegación',
                    icon: const Icon(Icons.menu),
                    onSelected: onNavigate,
                    itemBuilder:
                        (context) => [
                          for (final item in navigation)
                            PopupMenuItem(
                              value: item.id,
                              child: Text(item.label),
                            ),
                        ],
                  ),
                FilledButton.icon(
                  onPressed: onLogin,
                  style: FilledButton.styleFrom(backgroundColor: color),
                  icon: const Icon(Icons.login, size: 19),
                  label: Text(compact ? 'Ingresar' : 'Iniciar sesión'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final WebsiteContent content;
  final Color color;

  const _Hero({required this.content, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).width < 700 ? 610 : 590,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _SiteImage(url: content.heroImageUrl, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xDD230405),
                  Color(0x991C0505),
                  Color(0x22000000),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width < 700 ? 24 : 80,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        content.tagline.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      content.heroTitle,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize:
                            MediaQuery.sizeOf(context).width < 700 ? 39 : 62,
                        height: 1.04,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      content.heroBody,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sections extends StatelessWidget {
  final WebsiteContent content;
  final Color color;
  final Map<String, GlobalKey> pageKeys;

  const _Sections({
    required this.content,
    required this.color,
    required this.pageKeys,
  });

  @override
  Widget build(BuildContext context) {
    final navigation =
        content.navigation.where((item) => item.enabled).toList();
    return Column(
      children: [
        for (final item in navigation)
          _PageSection(
            key: pageKeys[item.id],
            navigation: item,
            sections:
                content.sections
                    .where(
                      (section) => section.enabled && section.pageId == item.id,
                    )
                    .toList(),
            color: color,
          ),
      ],
    );
  }
}

class _PageSection extends StatelessWidget {
  final WebsiteNavigationItem navigation;
  final List<WebsiteSection> sections;
  final Color color;

  const _PageSection({
    super.key,
    required this.navigation,
    required this.sections,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 68),
      child: Column(
        children: [
          Text(
            navigation.label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 12),
          Container(width: 62, height: 4, color: color),
          const SizedBox(height: 42),
          for (var index = 0; index < sections.length; index++) ...[
            _SectionCard(section: sections[index], color: color),
            if (index != sections.length - 1) const SizedBox(height: 38),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final WebsiteSection section;
  final Color color;

  const _SectionCard({required this.section, required this.color});

  Future<void> _openLink(BuildContext context) async {
    if (section.buttonUrl.startsWith('/')) {
      context.go(section.buttonUrl);
      return;
    }
    final uri = Uri.tryParse(section.buttonUrl);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final textAlign = _textAlign(section.textAlignment);
    final crossAxisAlignment = _crossAxisAlignment(section.textAlignment);
    final imageFit =
        section.imageFit == 'contain' ? BoxFit.contain : BoxFit.cover;
    final background = _hexColor(
      section.backgroundColor,
      fallback: const Color(0xFFFAF8F5),
    );
    final textColor = _hexColor(
      section.textColor,
      fallback: const Color(0xFF212121),
    );
    final maxWidth = switch (section.contentWidth) {
      'narrow' => 720.0,
      'normal' => 940.0,
      _ => 1180.0,
    };
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: _SiteImage(
        url: section.imageUrl,
        height: compact ? 280 : 390,
        width: double.infinity,
        fit: imageFit,
      ),
    );
    final copy = Padding(
      padding: EdgeInsets.all(compact ? 22 : 38),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Container(width: 58, height: 5, color: color),
          const SizedBox(height: 22),
          Text(
            section.title,
            textAlign: textAlign,
            style: TextStyle(
              fontSize: 34,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            section.body,
            textAlign: textAlign,
            style: TextStyle(
              fontSize: 17,
              height: 1.65,
              color: textColor.withValues(alpha: .9),
            ),
          ),
          if (section.buttonLabel.isNotEmpty &&
              section.buttonUrl.isNotEmpty) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _openLink(context),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    section.imagePosition == 'background' ? textColor : color,
              ),
              icon: const Icon(Icons.arrow_forward),
              label: Text(section.buttonLabel),
            ),
          ],
        ],
      ),
    );

    Widget layout;
    if (section.imagePosition == 'background') {
      layout = SizedBox(
        height: compact ? 480 : 520,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _SiteImage(url: section.imageUrl, fit: imageFit),
            const ColoredBox(color: Color(0x99000000)),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: copy,
              ),
            ),
          ],
        ),
      );
    } else if (compact || section.imagePosition == 'top') {
      layout = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [image, copy],
      );
    } else {
      final imageFirst = section.imagePosition != 'right';
      layout = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children:
            imageFirst
                ? [Expanded(child: image), Expanded(child: copy)]
                : [Expanded(child: copy), Expanded(child: image)],
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: layout,
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final WebsiteContent content;
  final Color color;

  const _Footer({required this.content, required this.color});

  @override
  Widget build(BuildContext context) {
    final contacts = <Widget>[
      if (content.address.isNotEmpty)
        _Contact(icon: Icons.location_on_outlined, text: content.address),
      if (content.phone.isNotEmpty)
        _Contact(icon: Icons.phone_outlined, text: content.phone),
      if (content.email.isNotEmpty)
        _Contact(icon: Icons.email_outlined, text: content.email),
    ];
    return ColoredBox(
      color: const Color(0xFF25090A),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 55),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Wrap(
              spacing: 60,
              runSpacing: 30,
              alignment: WrapAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 430,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content.schoolName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        content.tagline,
                        style: TextStyle(
                          color: color.withValues(alpha: .95),
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 430,
                  child:
                      contacts.isEmpty
                          ? const Text(
                            'Los datos de contacto se pueden agregar desde el editor del sitio.',
                            style: TextStyle(color: Colors.white70),
                          )
                          : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: contacts,
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Contact extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Contact({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(
      children: [
        Icon(icon, color: Colors.white70),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

class _SiteImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  const _SiteImage({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('asset:')) {
      return Image.asset(
        url.substring('asset:'.length),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: _error,
      );
    }
    if (url.startsWith('https://')) {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: _error,
      );
    }
    return _placeholder();
  }

  Widget _error(BuildContext context, Object error, StackTrace? stack) =>
      _placeholder();

  Widget _placeholder() => Container(
    width: width,
    height: height,
    color: const Color(0xFFE9E1DC),
    child: const Center(
      child: Icon(Icons.image_outlined, size: 54, color: Colors.black38),
    ),
  );
}

TextAlign _textAlign(String value) => switch (value) {
  'center' => TextAlign.center,
  'right' => TextAlign.right,
  _ => TextAlign.left,
};

CrossAxisAlignment _crossAxisAlignment(String value) => switch (value) {
  'center' => CrossAxisAlignment.center,
  'right' => CrossAxisAlignment.end,
  _ => CrossAxisAlignment.start,
};

Color _hexColor(String value, {Color fallback = const Color(0xFFB71C1C)}) {
  final clean = value.replaceAll('#', '').trim();
  final parsed = int.tryParse(clean, radix: 16);
  return parsed == null || clean.length != 6
      ? fallback
      : Color(0xFF000000 | parsed);
}
