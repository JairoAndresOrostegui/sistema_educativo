import 'package:sistema_educativo/config/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/website_content.dart';
import '../services/website_service.dart';

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

  void _load() {
    _future = WebsiteService().getPublicPage(widget.slug);
  }

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
  final String? selectedBlockId;
  final ValueChanged<String>? onBlockSelected;
  final void Function(int oldIndex, int newIndex)? onReorder;

  const WebsitePreviewCanvas({
    super.key,
    required this.config,
    required this.page,
    required this.previewMobile,
    this.editorMode = false,
    this.selectedBlockId,
    this.onBlockSelected,
    this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = _orderedVisibleBlocks(page.blocks, previewMobile);
    final content = <Widget>[
      for (final block in blocks)
        _EditableBlockFrame(
          key: ValueKey(block.id),
          selected: selectedBlockId == block.id,
          editorMode: editorMode,
          onTap: () => onBlockSelected?.call(block.id),
          child: WebsiteBlockView(
            config: config,
            pageId: page.id,
            block: block,
            mobile: previewMobile,
            preview: editorMode,
          ),
        ),
    ];

    final header = WebsiteHeader(
      config: config,
      compact: previewMobile,
      preview: editorMode,
    );
    final footer = WebsiteFooter(
      config: config,
      compact: previewMobile,
      preview: editorMode,
    );
    if (!editorMode) {
      return Scaffold(
        backgroundColor: AppPalette.surface,
        body: SelectionArea(
          child: CustomScrollView(
            slivers: [
              SliverList.list(children: [header, ...content]),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  children: [const Spacer(), if (config.footer.enabled) footer],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppPalette.surface,
      body: SelectionArea(
        child: Column(
          children: [
            header,
            Expanded(
              child: ReorderableListView(
                buildDefaultDragHandles: true,
                onReorderItem: onReorder!,
                children: content,
              ),
            ),
            if (config.footer.enabled) footer,
          ],
        ),
      ),
    );
  }
}

class WebsiteHeader extends StatelessWidget {
  final WebsiteSiteConfig config;
  final bool compact;
  final bool preview;

  const WebsiteHeader({
    super.key,
    required this.config,
    required this.compact,
    this.preview = false,
  });

  void _go(BuildContext context, String path) {
    if (!preview) context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final primary = websiteHexColor(config.primaryColor);
    final navigation = config.navigation.where((item) => item.enabled).toList();
    return Material(
      elevation: 2,
      color: AppPalette.surface,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 42,
          vertical: 12,
        ),
        child: Row(
          children: [
            InkWell(
              onTap: () => _go(context, '/'),
              child: WebsiteImage(
                asset: config.logo,
                width: compact ? 45 : 58,
                height: compact ? 45 : 58,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.schoolName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: websiteTextStyle(
                      config.fontFamily,
                      fontSize: compact ? 14 : 19,
                      fontWeight: FontWeight.w800,
                      color: primary,
                    ),
                  ),
                  if (!compact)
                    Text(
                      config.tagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (compact)
              PopupMenuButton<String>(
                tooltip: 'Navegación',
                icon: const Icon(Icons.menu),
                onSelected: (slug) => _go(context, '/$slug'),
                itemBuilder: (context) => [
                  for (final item in navigation)
                    PopupMenuItem(
                      value: item.resolvedSlug,
                      child: Text(item.label),
                    ),
                ],
              )
            else
              for (final item in navigation)
                TextButton(
                  onPressed: () => _go(context, '/${item.resolvedSlug}'),
                  child: Text(item.label),
                ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _go(context, '/login'),
              style: FilledButton.styleFrom(backgroundColor: primary),
              icon: const Icon(Icons.login, size: 18),
              label: Text(compact ? 'Login' : 'Iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

class WebsiteBlockView extends StatelessWidget {
  final WebsiteSiteConfig config;
  final String pageId;
  final WebsiteBlock block;
  final bool mobile;
  final bool preview;

  const WebsiteBlockView({
    super.key,
    required this.config,
    required this.pageId,
    required this.block,
    required this.mobile,
    this.preview = false,
  });

  @override
  Widget build(BuildContext context) {
    final padding = (mobile ? block.mobilePadding : block.padding).toDouble();
    final background = websiteHexColor(
      block.backgroundColor,
      fallback: AppPalette.surface,
    );
    final maxWidth = switch (block.contentWidth) {
      'narrow' => 720.0,
      'normal' => 960.0,
      _ => 1280.0,
    };
    Widget child = switch (block.type) {
      'hero' => _hero(context),
      'text' => _copy(context),
      'image' => _image(height: mobile ? 290 : 520),
      'button' => _button(context),
      'divider' => _divider(),
      'spacer' => SizedBox(height: mobile ? 34 : 64),
      'contactForm' => WebsiteContactForm(
        pageId: pageId,
        block: block,
        preview: preview,
      ),
      'socialLinks' => WebsiteSocialLinks(
        links: config.socialLinks,
        color: websiteHexColor(block.textColor),
        preview: preview,
      ),
      _ => _imageText(context),
    };
    if (block.type == 'hero') return child;
    return ColoredBox(
      color: background,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final text = _copy(context, hero: true);
    return SizedBox(
      height: mobile ? 560 : 620,
      child: Stack(
        fit: StackFit.expand,
        children: [
          WebsiteImage(asset: block.image, fit: _fit),
          ColoredBox(color: AppPalette.onSurface.withValues(alpha: .52)),
          Align(
            alignment: _alignment,
            child: Padding(
              padding: EdgeInsets.all(
                (mobile ? block.mobilePadding : block.padding).toDouble(),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageText(BuildContext context) {
    final image = _image(height: mobile ? 280 : 410);
    final copy = _copy(context);
    final position = mobile ? block.mobileImagePosition : block.imagePosition;
    if (position == 'background') return _hero(context);
    if (mobile || position == 'top') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [image, const SizedBox(height: 22), copy],
      );
    }
    final imageFirst = position != 'right';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: imageFirst
          ? [
              Expanded(child: image),
              const SizedBox(width: 34),
              Expanded(child: copy),
            ]
          : [
              Expanded(child: copy),
              const SizedBox(width: 34),
              Expanded(child: image),
            ],
    );
  }

  Widget _copy(BuildContext context, {bool hero = false}) {
    final color = websiteHexColor(
      block.textColor,
      fallback: hero ? AppPalette.surface : AppPalette.onSurface,
    );
    final align = websiteTextAlign(block.textAlignment);
    final cross = websiteCrossAxisAlignment(block.textAlignment);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: cross,
      children: [
        if (block.showAccent) ...[
          Container(
            width: 58,
            height: 5,
            color: websiteHexColor(block.accentColor),
          ),
          const SizedBox(height: 18),
        ],
        if (block.title.isNotEmpty)
          Text(
            block.title,
            textAlign: align,
            style: websiteTextStyle(
              block.fontFamily,
              fontSize: (mobile ? block.mobileTitleSize : block.titleSize)
                  .toDouble(),
              height: 1.12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        if (block.body.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            block.body,
            textAlign: align,
            style: websiteTextStyle(
              block.fontFamily,
              fontSize: (mobile ? block.mobileBodySize : block.bodySize)
                  .toDouble(),
              height: 1.55,
              color: color.withValues(alpha: .92),
            ),
          ),
        ],
        if (block.buttonLabel.isNotEmpty && block.buttonUrl.isNotEmpty) ...[
          const SizedBox(height: 22),
          FilledButton(
            onPressed: preview
                ? null
                : () => openWebsiteLink(context, block.buttonUrl),
            style: FilledButton.styleFrom(
              backgroundColor: websiteHexColor(block.accentColor),
            ),
            child: Text(block.buttonLabel),
          ),
        ],
      ],
    );
  }

  Widget _image({required double height}) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: WebsiteImage(
      asset: block.image,
      width: double.infinity,
      height: height,
      fit: _fit,
    ),
  );

  Widget _button(BuildContext context) => Align(
    alignment: _alignment,
    child: FilledButton(
      onPressed: preview || block.buttonUrl.isEmpty
          ? null
          : () => openWebsiteLink(context, block.buttonUrl),
      style: FilledButton.styleFrom(
        backgroundColor: websiteHexColor(block.accentColor),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      ),
      child: Text(block.buttonLabel.isEmpty ? 'Botón' : block.buttonLabel),
    ),
  );

  Widget _divider() => Align(
    alignment: _alignment,
    child: Container(
      width: block.contentWidth == 'wide' ? double.infinity : 180,
      height: 4,
      color: websiteHexColor(block.accentColor),
    ),
  );

  BoxFit get _fit =>
      block.imageFit == 'contain' ? BoxFit.contain : BoxFit.cover;

  Alignment get _alignment => switch (block.textAlignment) {
    'center' => Alignment.center,
    'right' => Alignment.centerRight,
    _ => Alignment.centerLeft,
  };
}

class WebsiteContactForm extends StatefulWidget {
  final String pageId;
  final WebsiteBlock block;
  final bool preview;

  const WebsiteContactForm({
    super.key,
    required this.pageId,
    required this.block,
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
        blockId: widget.block.id,
        name: _name.text,
        email: _email.text,
        phone: _phone.text,
        message: _message.text,
        website: _website.text,
      );
      if (!mounted) return;
      _key.currentState?.reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu mensaje fue enviado correctamente.')),
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
      crossAxisAlignment: websiteCrossAxisAlignment(widget.block.textAlignment),
      children: [
        if (widget.block.title.isNotEmpty)
          Text(
            widget.block.title,
            style: websiteTextStyle(
              widget.block.fontFamily,
              fontSize: widget.block.titleSize.toDouble(),
              fontWeight: FontWeight.w800,
              color: websiteHexColor(widget.block.textColor),
            ),
          ),
        if (widget.block.body.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(widget.block.body),
        ],
        const SizedBox(height: 22),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _field(_name, 'Nombre', required: true),
            _field(_email, 'Correo', required: true),
            _field(_phone, 'Teléfono'),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _message,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Mensaje',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value == null || value.trim().length < 5
              ? 'Escribe un mensaje.'
              : null,
        ),
        Offstage(offstage: true, child: TextFormField(controller: _website)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: widget.preview || _sending ? null : _submit,
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: const Text('Enviar mensaje'),
        ),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) => SizedBox(
    width: 300,
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? 'Campo obligatorio.'
                : null
          : null,
    ),
  );
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
    spacing: 10,
    children: [
      for (final link in links.where(
        (item) => item.enabled && item.url.isNotEmpty,
      ))
        IconButton.filledTonal(
          tooltip: link.platform,
          color: color,
          onPressed: preview ? null : () => openWebsiteLink(context, link.url),
          icon: Icon(_socialIcon(link.platform)),
        ),
    ],
  );
}

class WebsiteFooter extends StatelessWidget {
  final WebsiteSiteConfig config;
  final bool compact;
  final bool preview;

  const WebsiteFooter({
    super.key,
    required this.config,
    required this.compact,
    this.preview = false,
  });

  @override
  Widget build(BuildContext context) {
    final footer = config.footer;
    final textColor = websiteHexColor(
      footer.textColor,
      fallback: AppPalette.surface,
    );
    final secondaryColor = websiteHexColor(
      footer.secondaryTextColor,
      fallback: AppPalette.onPrimary.withValues(alpha: .70),
    );
    final accentColor = websiteHexColor(footer.accentColor);
    final font = footer.fontFamily.isEmpty
        ? config.fontFamily
        : footer.fontFamily;
    final alignment = switch (footer.alignment) {
      'center' => CrossAxisAlignment.center,
      'right' => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.start,
    };
    final textAlign = switch (footer.alignment) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      _ => TextAlign.left,
    };
    final address = footer.useGlobalContact ? config.address : footer.address;
    final phone = footer.useGlobalContact ? config.phone : footer.phone;
    final email = footer.useGlobalContact ? config.email : footer.email;
    final logo = footer.useSiteLogo ? config.logo : footer.logo;
    final title = footer.title.isEmpty ? config.schoolName : footer.title;
    final description = footer.description.isEmpty
        ? config.tagline
        : footer.description;
    final navigation = config.navigation.where((item) => item.enabled).toList();

    Widget identity = SizedBox(
      width: compact ? double.infinity : 390,
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (footer.showLogo && logo.url.isNotEmpty) ...[
            WebsiteImage(
              asset: logo,
              width: footer.logoSize.toDouble(),
              height: footer.logoSize.toDouble(),
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 14),
          ],
          if (title.isNotEmpty)
            Text(
              title,
              textAlign: textAlign,
              style: websiteTextStyle(
                font,
                color: textColor,
                fontSize: footer.titleSize.toDouble(),
                fontWeight: FontWeight.w800,
              ),
            ),
          if (footer.showDescription && description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: textAlign,
              style: websiteTextStyle(
                font,
                color: secondaryColor,
                fontSize: footer.bodySize.toDouble(),
              ),
            ),
          ],
          if (footer.showSocialLinks) ...[
            const SizedBox(height: 16),
            WebsiteSocialLinks(
              links: config.socialLinks,
              color: accentColor,
              preview: preview,
            ),
          ],
        ],
      ),
    );

    Widget contact = SizedBox(
      width: compact ? double.infinity : 310,
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (footer.contactTitle.isNotEmpty)
            _heading(footer.contactTitle, font, textColor, textAlign),
          if (address.isNotEmpty)
            _contact(Icons.location_on_outlined, address, textColor, font),
          if (phone.isNotEmpty)
            _contact(Icons.phone_outlined, phone, textColor, font),
          if (email.isNotEmpty)
            _contact(Icons.email_outlined, email, textColor, font),
        ],
      ),
    );

    Widget links = SizedBox(
      width: compact ? double.infinity : 230,
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (footer.linksTitle.isNotEmpty)
            _heading(footer.linksTitle, font, textColor, textAlign),
          for (final item in navigation)
            TextButton(
              onPressed: preview
                  ? null
                  : () => context.go('/${item.resolvedSlug}'),
              style: TextButton.styleFrom(
                foregroundColor: textColor,
                padding: const EdgeInsets.symmetric(vertical: 5),
              ),
              child: Text(item.label, textAlign: textAlign),
            ),
        ],
      ),
    );

    final sections = <Widget>[
      identity,
      if (footer.showContact) contact,
      if (footer.showNavigation) links,
    ];
    final content = footer.layout == 'centered'
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < sections.length; i++) ...[
                sections[i],
                if (i < sections.length - 1) const SizedBox(height: 28),
              ],
            ],
          )
        : Wrap(
            spacing: 50,
            runSpacing: 28,
            alignment: WrapAlignment.spaceBetween,
            children: sections,
          );

    final copyright = footer.copyrightText.isEmpty
        ? '© ${DateTime.now().year} ${config.schoolName}'
        : footer.copyrightText;
    return ColoredBox(
      color: websiteHexColor(
        footer.backgroundColor,
        fallback: AppPalette.primary,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: footer.maxWidth.toDouble()),
          child: Padding(
            padding: EdgeInsets.all(
              (compact ? footer.mobilePadding : footer.padding).toDouble(),
            ),
            child: Column(
              children: [
                content,
                if (footer.showCopyright && copyright.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Divider(color: secondaryColor.withValues(alpha: 0.35)),
                  const SizedBox(height: 10),
                  Align(
                    alignment: switch (footer.alignment) {
                      'center' => Alignment.center,
                      'right' => Alignment.centerRight,
                      _ => Alignment.centerLeft,
                    },
                    child: Text(
                      copyright,
                      textAlign: textAlign,
                      style: websiteTextStyle(
                        font,
                        color: secondaryColor,
                        fontSize: footer.bodySize.toDouble(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(String text, String font, Color color, TextAlign textAlign) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          textAlign: textAlign,
          style: websiteTextStyle(
            font,
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _contact(IconData icon, String text, Color color, String font) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                style: websiteTextStyle(font, color: color, fontSize: 15),
              ),
            ),
          ],
        ),
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
        asset.url.substring('asset:'.length),
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
    return _placeholder();
  }

  Widget _error(BuildContext context, Object error, StackTrace? stack) =>
      _placeholder();

  Widget _placeholder() => Container(
    width: width,
    height: height,
    color: AppPalette.surfaceContainer,
    child: Center(
      child: Icon(
        Icons.image_outlined,
        size: 48,
        color: AppPalette.onSurface.withValues(alpha: .38),
      ),
    ),
  );
}

class _EditableBlockFrame extends StatelessWidget {
  final Widget child;
  final bool editorMode;
  final bool selected;
  final VoidCallback onTap;

  const _EditableBlockFrame({
    super.key,
    required this.child,
    required this.editorMode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!editorMode) return child;
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppPalette.info : AppPalette.transparent,
            width: selected ? 3 : 1,
          ),
        ),
        child: Stack(
          children: [
            child,
            if (selected)
              const Positioned(
                top: 6,
                left: 6,
                child: Chip(
                  avatar: Icon(Icons.drag_indicator, size: 17),
                  label: Text('Arrastra para ordenar'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

List<WebsiteBlock> _orderedVisibleBlocks(
  List<WebsiteBlock> blocks,
  bool mobile,
) {
  final visible = blocks
      .where(
        (block) =>
            block.enabled &&
            (mobile ? block.showOnMobile : block.showOnDesktop),
      )
      .toList();
  if (mobile) visible.sort((a, b) => a.mobileOrder.compareTo(b.mobileOrder));
  return visible;
}

Future<void> openWebsiteLink(BuildContext context, String value) async {
  if (value.startsWith('/')) {
    context.go(value);
    return;
  }
  final uri = Uri.tryParse(value);
  if (uri != null &&
      (uri.scheme == 'https' ||
          uri.scheme == 'http' ||
          uri.scheme == 'mailto')) {
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
  final selected = supported.contains(family) ? family : 'Montserrat';
  return GoogleFonts.getFont(
    selected,
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
