import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_palette.dart';
import '../models/website_content.dart';
import '../services/website_service.dart';
import '../widgets/website_video_embed.dart';

class PublicWebsiteScreen extends StatefulWidget {
  final String slug;

  const PublicWebsiteScreen({super.key, this.slug = 'home'});

  @override
  State<PublicWebsiteScreen> createState() => _PublicWebsiteScreenState();
}

class _PublicWebsiteScreenState extends State<PublicWebsiteScreen> {
  late Future<({WebsiteSiteConfig config, WebsitePage page})?> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PublicWebsiteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug) _load();
  }

  void _load() => _future = WebsiteService().getPublicPage(widget.slug);

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<({WebsiteSiteConfig config, WebsitePage page})?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final data = snapshot.data;
          if (snapshot.hasError || data == null) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.web_asset_off_outlined, size: 58),
                    const SizedBox(height: 14),
                    const Text('Esta página no está disponible.'),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Ir al inicio'),
                    ),
                  ],
                ),
              ),
            );
          }
          return WebsitePreviewCanvas(
            config: data.config,
            page: data.page,
            previewMobile: MediaQuery.sizeOf(context).width < 760,
          );
        },
      );
}

class WebsitePreviewCanvas extends StatelessWidget {
  final WebsiteSiteConfig config;
  final WebsitePage page;
  final bool previewMobile;
  final bool editorMode;
  final String? selectedId;
  final ValueChanged<String>? onSelected;

  const WebsitePreviewCanvas({
    super.key,
    required this.config,
    required this.page,
    required this.previewMobile,
    this.editorMode = false,
    this.selectedId,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final header = config.header.enabled
        ? WebsiteLayout(
            rows: config.header.rows,
            config: config,
            pageId: page.id,
            mobile: previewMobile,
            preview: editorMode,
            selectedId: selectedId,
            onSelected: onSelected,
          )
        : const SizedBox.shrink();
    final content = WebsiteLayout(
      rows: page.rows,
      config: config,
      pageId: page.id,
      mobile: previewMobile,
      preview: editorMode,
      selectedId: selectedId,
      onSelected: onSelected,
    );
    final footer = config.footer.enabled
        ? WebsiteFooter(
            config: config,
            compact: previewMobile,
            preview: editorMode,
            selectedId: selectedId,
            onSelected: onSelected,
          )
        : const SizedBox.shrink();
    final scrollingContent = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [content, footer],
      ),
    );
    return Scaffold(
      backgroundColor: websiteHexColor('#FFFFFF'),
      body: SelectionArea(
        child: config.header.enabled && config.header.sticky
            ? Column(
                children: [
                  header,
                  Expanded(child: scrollingContent),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [header, content, footer],
                ),
              ),
      ),
    );
  }
}

class WebsiteLayout extends StatelessWidget {
  final List<WebsiteRow> rows;
  final WebsiteSiteConfig config;
  final String pageId;
  final bool mobile;
  final bool preview;
  final String? selectedId;
  final ValueChanged<String>? onSelected;

  const WebsiteLayout({
    super.key,
    required this.rows,
    required this.config,
    required this.pageId,
    required this.mobile,
    this.preview = false,
    this.selectedId,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final entry
          in rows.where((item) => item.enabled).toList().asMap().entries)
        _selectable(
          entry.value.id,
          ColoredBox(
            color: websiteHexColor(entry.value.backgroundColor),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: entry.value.maxWidth.toDouble(),
                ),
                child: Padding(
                  padding: EdgeInsets.all(entry.value.padding.toDouble()),
                  child: _row(entry.value),
                ),
              ),
            ),
          ),
          label: 'Fila ${entry.key + 1}',
          outlined: true,
          labelOnRight: false,
        ),
    ],
  );

  Widget _row(WebsiteRow row) {
    final columns = row.columns;
    if (mobile && row.stackOnMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < columns.length; i++) ...[
            _column(columns[i], i),
            if (i < columns.length - 1) SizedBox(height: row.gap.toDouble()),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < columns.length; i++) ...[
          Expanded(flex: columns[i].span, child: _column(columns[i], i)),
          if (i < columns.length - 1) SizedBox(width: row.gap.toDouble()),
        ],
      ],
    );
  }

  Widget _column(WebsiteColumn column, int columnIndex) => _selectable(
    column.id,
    ColoredBox(
      color: websiteHexColor(column.backgroundColor),
      child: Padding(
        padding: EdgeInsets.all(column.padding.toDouble()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < column.components.length; i++) ...[
              if (column.components[i].enabled)
                _selectable(
                  column.components[i].id,
                  WebsiteComponentView(
                    config: config,
                    pageId: pageId,
                    component: column.components[i],
                    mobile: mobile,
                    preview: preview,
                  ),
                  outlined: false,
                ),
              if (i < column.components.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    ),
    label: 'Columna ${columnIndex + 1}',
    outlined: true,
    labelOnRight: true,
  );

  Widget _selectable(
    String id,
    Widget child, {
    String? label,
    required bool outlined,
    bool labelOnRight = false,
  }) {
    if (!preview) return child;
    final selected = id == selectedId;
    final color = selected
        ? AppPalette.info
        : AppPalette.error.withValues(alpha: .82);
    return InkWell(
      onTap: () => onSelected?.call(id),
      child: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: selected || outlined ? color : Colors.transparent,
                width: selected ? 3 : (outlined ? 1.5 : 1),
              ),
            ),
            child: child,
          ),
          if (label != null && (outlined || selected))
            Positioned(
              top: 0,
              left: labelOnRight ? null : 0,
              right: labelOnRight ? 0 : null,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  color: color,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class WebsiteComponentView extends StatelessWidget {
  final WebsiteSiteConfig config;
  final String pageId;
  final WebsiteComponent component;
  final bool mobile;
  final bool preview;

  const WebsiteComponentView({
    super.key,
    required this.config,
    required this.pageId,
    required this.component,
    required this.mobile,
    this.preview = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = switch (component.type) {
      'hero' => _hero(context),
      'image' => _image(),
      'button' => _button(context),
      'card' => _card(context),
      'carousel' => WebsiteCarousel(
        component: component,
        config: config,
        preview: preview,
      ),
      'gallery' => _gallery(),
      'video' => WebsiteVideoEmbed(url: component.url, preview: preview),
      'accordion' => _accordion(),
      'stats' => _stats(),
      'divider' => Divider(
        thickness: 3,
        color: websiteHexColor(component.accentColor),
      ),
      'spacer' => SizedBox(height: component.padding.toDouble()),
      'socialLinks' => WebsiteSocialLinks(
        links: config.socialLinks,
        color: websiteHexColor(component.textColor),
        preview: preview,
      ),
      'contactInfo' => _contactInfo(),
      'navigation' => _navigation(context),
      'siteIdentity' => _identity(),
      'contactForm' => WebsiteContactForm(
        pageId: pageId,
        component: component,
        preview: preview,
      ),
      _ => _copy(),
    };
    if (component.type == 'hero') return child;
    return ColoredBox(
      color: websiteHexColor(component.backgroundColor),
      child: Padding(
        padding: EdgeInsets.all(component.padding.toDouble()),
        child: child,
      ),
    );
  }

  Widget _hero(BuildContext context) => SizedBox(
    height: mobile ? 470 : 600,
    child: Stack(
      fit: StackFit.expand,
      children: [
        WebsiteImage(asset: component.image, fit: _fit),
        ColoredBox(color: Colors.black.withValues(alpha: .48)),
        Align(
          alignment: _alignment,
          child: Padding(
            padding: EdgeInsets.all(component.padding.toDouble()),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: _copy(),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _copy() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: websiteCrossAxisAlignment(component.alignment),
    children: [
      if (component.title.isNotEmpty)
        Text(
          component.title,
          textAlign: websiteTextAlign(component.alignment),
          style: websiteTextStyle(
            config.fontFamily,
            color: websiteHexColor(component.textColor),
            fontSize:
                (mobile
                        ? component.titleSize.clamp(20, 42)
                        : component.titleSize)
                    .toDouble(),
            fontWeight: FontWeight.w800,
            height: 1.12,
          ),
        ),
      if (component.body.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
          component.body,
          textAlign: websiteTextAlign(component.alignment),
          style: websiteTextStyle(
            config.fontFamily,
            color: websiteHexColor(component.textColor),
            fontSize: component.bodySize.toDouble(),
            height: 1.55,
          ),
        ),
      ],
    ],
  );

  Widget _image() => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: WebsiteImage(
      asset: component.image,
      height: mobile ? 260 : 400,
      fit: _fit,
    ),
  );

  Widget _button(BuildContext context) => Align(
    alignment: _alignment,
    child: FilledButton(
      onPressed: component.url.isEmpty
          ? null
          : () {
              if (!preview) openWebsiteLink(context, component.url);
            },
      style: FilledButton.styleFrom(
        backgroundColor: websiteHexColor(component.accentColor),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      ),
      child: Text(
        component.buttonLabel.isEmpty
            ? 'Más información'
            : component.buttonLabel,
      ),
    ),
  );

  Widget _card(BuildContext context) => Card(
    elevation: 2,
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (component.image.url.isNotEmpty)
          WebsiteImage(asset: component.image, height: 220, fit: _fit),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: websiteCrossAxisAlignment(component.alignment),
            children: [
              _copy(),
              if (component.url.isNotEmpty) ...[
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () {
                    if (!preview) openWebsiteLink(context, component.url);
                  },
                  child: Text(
                    component.buttonLabel.isEmpty
                        ? 'Conocer más'
                        : component.buttonLabel,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _gallery() => LayoutBuilder(
    builder: (context, constraints) {
      final width = mobile
          ? constraints.maxWidth
          : (constraints.maxWidth - 24) / 3;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final item in component.items)
            SizedBox(
              width: width,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: WebsiteImage(asset: item.image, fit: BoxFit.cover),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _accordion() => Column(
    children: [
      if (component.title.isNotEmpty) _copy(),
      for (final item in component.items)
        ExpansionTile(
          iconColor: websiteHexColor(component.accentColor),
          collapsedIconColor: websiteHexColor(component.accentColor),
          title: Text(
            item.title,
            style: TextStyle(color: websiteHexColor(component.textColor)),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item.text,
                  style: TextStyle(color: websiteHexColor(component.textColor)),
                ),
              ),
            ),
          ],
        ),
    ],
  );

  Widget _stats() => Wrap(
    spacing: 28,
    runSpacing: 20,
    alignment: WrapAlignment.center,
    children: [
      for (final item in component.items)
        SizedBox(
          width: 180,
          child: Column(
            children: [
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: websiteTextStyle(
                  config.fontFamily,
                  color: websiteHexColor(component.accentColor),
                  fontSize: component.titleSize.toDouble(),
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                item.text,
                textAlign: TextAlign.center,
                style: TextStyle(color: websiteHexColor(component.textColor)),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _contactInfo() => Column(
    crossAxisAlignment: websiteCrossAxisAlignment(component.alignment),
    children: [
      if (component.title.isNotEmpty) _copy(),
      if (config.address.isNotEmpty)
        _contact(Icons.location_on_outlined, config.address),
      if (config.phone.isNotEmpty) _contact(Icons.phone_outlined, config.phone),
      if (config.email.isNotEmpty) _contact(Icons.email_outlined, config.email),
    ],
  );

  Widget _contact(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: websiteHexColor(component.accentColor)),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            value,
            style: TextStyle(color: websiteHexColor(component.textColor)),
          ),
        ),
      ],
    ),
  );

  Widget _navigation(BuildContext context) => Column(
    crossAxisAlignment: websiteCrossAxisAlignment(component.alignment),
    children: [
      if (component.title.isNotEmpty) ...[_copy(), const SizedBox(height: 10)],
      Wrap(
        alignment: switch (component.alignment) {
          'center' => WrapAlignment.center,
          'right' => WrapAlignment.end,
          _ => WrapAlignment.start,
        },
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final item in config.navigation.where((item) => item.enabled))
            TextButton(
              onPressed: () {
                if (!preview) context.go('/${item.slug}');
              },
              style: TextButton.styleFrom(
                foregroundColor: websiteHexColor(component.textColor),
              ),
              child: Text(item.label),
            ),
          if (component.id == 'site_navigation' ||
              component.buttonLabel.isNotEmpty)
            FilledButton.tonalIcon(
              onPressed: () {
                if (!preview) context.go('/login');
              },
              icon: const Icon(Icons.login, size: 18),
              label: Text(
                component.buttonLabel.isEmpty
                    ? 'Ingresar'
                    : component.buttonLabel,
              ),
            ),
        ],
      ),
    ],
  );

  Widget _identity() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (config.logo.url.isNotEmpty)
        WebsiteImage(
          asset: config.logo,
          width: 58,
          height: 58,
          fit: BoxFit.contain,
        ),
      if (config.logo.url.isNotEmpty) const SizedBox(width: 12),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              config.schoolName,
              style: websiteTextStyle(
                config.fontFamily,
                color: websiteHexColor(component.textColor),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            if (config.tagline.isNotEmpty)
              Text(
                config.tagline,
                style: TextStyle(color: websiteHexColor(component.textColor)),
              ),
          ],
        ),
      ),
    ],
  );

  BoxFit get _fit =>
      component.imageFit == 'contain' ? BoxFit.contain : BoxFit.cover;
  Alignment get _alignment => switch (component.alignment) {
    'center' => Alignment.center,
    'right' => Alignment.centerRight,
    _ => Alignment.centerLeft,
  };
}

class WebsiteCarousel extends StatefulWidget {
  final WebsiteComponent component;
  final WebsiteSiteConfig config;
  final bool preview;

  const WebsiteCarousel({
    super.key,
    required this.component,
    required this.config,
    required this.preview,
  });

  @override
  State<WebsiteCarousel> createState() => _WebsiteCarouselState();
}

class _WebsiteCarouselState extends State<WebsiteCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    if (!widget.component.autoplay || widget.component.items.length < 2) return;
    _timer = Timer.periodic(
      Duration(seconds: widget.component.intervalSeconds),
      (_) {
        if (!mounted || !_controller.hasClients) return;
        final next = (_index + 1) % widget.component.items.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.component.items.isEmpty) {
      return const AspectRatio(
        aspectRatio: 16 / 7,
        child: Center(child: Text('Agrega imágenes al carrusel')),
      );
    }
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 7,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.component.items.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) {
              final item = widget.component.items[index];
              final slide = Stack(
                fit: StackFit.expand,
                children: [
                  WebsiteImage(asset: item.image, fit: BoxFit.cover),
                  if (item.title.isNotEmpty || item.text.isNotEmpty)
                    ColoredBox(color: Colors.black.withValues(alpha: .35)),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              color: websiteHexColor(
                                widget.component.textColor,
                                fallback: Colors.white,
                              ),
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (item.text.isNotEmpty)
                            Text(
                              item.text,
                              style: TextStyle(
                                color: websiteHexColor(
                                  widget.component.textColor,
                                  fallback: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
              if (item.url.isEmpty) return slide;
              return InkWell(
                onTap: widget.preview
                    ? null
                    : () => openWebsiteLink(context, item.url),
                child: slide,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.component.items.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: CircleAvatar(
                  radius: i == _index ? 5 : 3,
                  backgroundColor: i == _index
                      ? websiteHexColor(widget.component.accentColor)
                      : Colors.grey,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class WebsiteContactForm extends StatefulWidget {
  final String pageId;
  final WebsiteComponent component;
  final bool preview;

  const WebsiteContactForm({
    super.key,
    required this.pageId,
    required this.component,
    required this.preview,
  });

  @override
  State<WebsiteContactForm> createState() => _WebsiteContactFormState();
}

class _WebsiteContactFormState extends State<WebsiteContactForm> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _message = TextEditingController();
  final _website = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    for (final controller in [_name, _email, _phone, _message, _website]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.preview || !(_key.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    try {
      await WebsiteService().submitContactForm(
        pageId: widget.pageId,
        blockId: widget.component.id,
        name: _name.text,
        email: _email.text,
        phone: _phone.text,
        message: _message.text,
        website: _website.text,
      );
      if (!mounted) return;
      _key.currentState?.reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mensaje enviado correctamente.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No fue posible enviar el mensaje.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _key,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.component.title.isNotEmpty)
          Text(
            widget.component.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: websiteHexColor(widget.component.textColor),
              fontWeight: FontWeight.w800,
            ),
          ),
        if (widget.component.body.isNotEmpty)
          Text(
            widget.component.body,
            style: TextStyle(
              color: websiteHexColor(widget.component.textColor),
            ),
          ),
        const SizedBox(height: 18),
        TextFormField(
          controller: _name,
          style: TextStyle(color: websiteHexColor(widget.component.textColor)),
          decoration: _decoration('Nombre'),
          validator: _required,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _email,
          style: TextStyle(color: websiteHexColor(widget.component.textColor)),
          decoration: _decoration('Correo'),
          validator: _required,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phone,
          style: TextStyle(color: websiteHexColor(widget.component.textColor)),
          decoration: _decoration('Teléfono'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _message,
          maxLines: 5,
          style: TextStyle(color: websiteHexColor(widget.component.textColor)),
          decoration: _decoration('Mensaje'),
          validator: _required,
        ),
        Offstage(offstage: true, child: TextFormField(controller: _website)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _sending
              ? null
              : () {
                  if (!widget.preview) _submit();
                },
          child: Text(_sending ? 'Enviando...' : 'Enviar mensaje'),
        ),
      ],
    ),
  );

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Campo obligatorio.' : null;

  InputDecoration _decoration(String label) {
    final color = websiteHexColor(widget.component.textColor);
    final accent = websiteHexColor(widget.component.accentColor);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: color.withValues(alpha: .78)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: color.withValues(alpha: .55)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(borderSide: BorderSide(color: accent)),
    );
  }
}

class WebsiteSocialLinks extends StatelessWidget {
  final List<WebsiteSocialLink> links;
  final Color color;
  final bool preview;

  const WebsiteSocialLinks({
    super.key,
    required this.links,
    required this.color,
    this.preview = false,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      for (final link in links.where(
        (item) => item.enabled && item.url.isNotEmpty,
      ))
        IconButton.filledTonal(
          tooltip: link.platform,
          color: color,
          onPressed: () {
            if (!preview) openWebsiteLink(context, link.url);
          },
          icon: Icon(_socialIcon(link.platform)),
        ),
    ],
  );
}

class WebsiteFooter extends StatelessWidget {
  final WebsiteSiteConfig config;
  final bool compact;
  final bool preview;
  final String? selectedId;
  final ValueChanged<String>? onSelected;

  const WebsiteFooter({
    super.key,
    required this.config,
    required this.compact,
    this.preview = false,
    this.selectedId,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      WebsiteLayout(
        rows: config.footer.rows,
        config: config,
        pageId: 'footer',
        mobile: compact,
        preview: preview,
        selectedId: selectedId,
        onSelected: onSelected,
      ),
      ColoredBox(
        color: websiteHexColor(
          config.footer.rows.isEmpty
              ? '#2B1718'
              : config.footer.rows.last.backgroundColor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            config.footer.copyrightText.isEmpty
                ? '© ${DateTime.now().year} ${config.schoolName}'
                : config.footer.copyrightText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: websiteContrastColor(
                config.footer.rows.isEmpty
                    ? '#2B1718'
                    : config.footer.rows.last.backgroundColor,
              ).withValues(alpha: .76),
            ),
          ),
        ),
      ),
    ],
  );
}

class WebsiteImage extends StatelessWidget {
  final WebsiteAsset asset;
  final double? width;
  final double? height;
  final BoxFit fit;

  const WebsiteImage({
    super.key,
    required this.asset,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (asset.url.startsWith('asset:')) {
      return Image.asset(
        asset.url.substring(6),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: _error,
      );
    }
    if (asset.url.startsWith('https://')) {
      return Image.network(
        asset.url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: _error,
      );
    }
    return _placeholder(context);
  }

  Widget _error(BuildContext context, Object error, StackTrace? stack) =>
      _placeholder(context);
  Widget _placeholder(BuildContext context) => Container(
    width: width,
    height: height,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Center(child: Icon(Icons.image_outlined, size: 44)),
  );
}

Future<void> openWebsiteLink(BuildContext context, String value) async {
  if (value.startsWith('/')) {
    context.go(value);
    return;
  }
  final uri = Uri.tryParse(value);
  if (uri != null && {'https', 'http', 'mailto', 'tel'}.contains(uri.scheme)) {
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }
}

TextStyle websiteTextStyle(
  String family, {
  double? fontSize,
  double? height,
  FontWeight? fontWeight,
  Color? color,
}) {
  const supported = {
    'Roboto',
    'Lato',
    'Montserrat',
    'Poppins',
    'Playfair Display',
  };
  return GoogleFonts.getFont(
    supported.contains(family) ? family : 'Montserrat',
    fontSize: fontSize,
    height: height,
    fontWeight: fontWeight,
    color: color,
  );
}

Color websiteHexColor(String value, {Color? fallback}) {
  final clean = value.replaceAll('#', '').trim();
  final parsed = int.tryParse(clean, radix: 16);
  return parsed == null || clean.length != 6
      ? fallback ?? AppPalette.primary
      : Color(0xFF000000 | parsed);
}

Color websiteContrastColor(String background) =>
    websiteHexColor(background).computeLuminance() > .45
    ? Colors.black
    : Colors.white;

TextAlign websiteTextAlign(String value) => switch (value) {
  'center' => TextAlign.center,
  'right' => TextAlign.right,
  _ => TextAlign.left,
};

CrossAxisAlignment websiteCrossAxisAlignment(String value) => switch (value) {
  'center' => CrossAxisAlignment.center,
  'right' => CrossAxisAlignment.end,
  _ => CrossAxisAlignment.start,
};

IconData _socialIcon(String value) => switch (value.toLowerCase()) {
  'facebook' => Icons.facebook,
  'youtube' => Icons.play_circle_fill,
  'instagram' => Icons.camera_alt_outlined,
  'tiktok' => Icons.music_note,
  'linkedin' => Icons.business,
  _ => Icons.link,
};
