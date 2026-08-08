import 'package:sistema_educativo/config/app_palette.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider_v2.dart';
import '../models/website_content.dart';
import '../services/website_service.dart';
import 'public_website_screen.dart';

class WebsiteEditorScreen extends StatefulWidget {
  const WebsiteEditorScreen({super.key});

  @override
  State<WebsiteEditorScreen> createState() => _WebsiteEditorScreenState();
}

class _WebsiteEditorScreenState extends State<WebsiteEditorScreen> {
  final _service = WebsiteService();
  WebsiteBundle? _bundle;
  WebsiteBundle? _publishedBundle;
  String _selectedPageId = 'home';
  String? _selectedBlockId;
  bool _editingSite = false;
  bool _editingFooter = false;
  bool _mobilePreview = false;
  bool _loading = true;
  bool _saving = false;
  String? _uploading;
  final Set<String> _sessionUploads = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bundle = await _service.getBundle();
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _publishedBundle = bundle;
        _selectedPageId = bundle.pages.first.id;
      });
    } catch (error) {
      if (mounted) {
        _message('No fue posible cargar el sitio: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    final publishedPaths =
        _publishedBundle?.managedAssetPaths ?? const <String>{};
    for (final path in _sessionUploads.difference(publishedPaths)) {
      unawaited(_service.deleteAsset(WebsiteAsset(storagePath: path)));
    }
    super.dispose();
  }

  WebsitePage get _page => _bundle!.pages.firstWhere(
    (page) => page.id == _selectedPageId,
    orElse: () => _bundle!.pages.first,
  );

  WebsiteBlock? get _block {
    final id = _selectedBlockId;
    if (id == null) return null;
    for (final block in _page.blocks) {
      if (block.id == id) return block;
    }
    return null;
  }

  bool _canEdit(BuildContext context) {
    final user = context.read<UserProviderV2>().user;
    final permissions =
        user?.permissions.map((item) => item.trim().toLowerCase()).toSet() ??
        const <String>{};
    return (user?.isSuperadmin ?? false) ||
        permissions.contains('sitio_web.editar');
  }

  void _replaceConfig(WebsiteSiteConfig config) {
    setState(
      () => _bundle = WebsiteBundle(config: config, pages: _bundle!.pages),
    );
  }

  void _replacePage(WebsitePage page) {
    final pages = [
      for (final item in _bundle!.pages)
        if (item.id == page.id) page else item,
    ];
    final navigation = [
      for (final item in _bundle!.config.navigation)
        if (item.id == page.id)
          item.copyWith(
            label: page.label,
            slug: page.slug,
            enabled: page.enabled && page.showInNavigation,
          )
        else
          item,
    ];
    setState(
      () => _bundle = WebsiteBundle(
        config: _bundle!.config.copyWith(navigation: navigation),
        pages: pages,
      ),
    );
  }

  void _replaceBlock(WebsiteBlock block) {
    _replacePage(
      _page.copyWith(
        blocks: [
          for (final item in _page.blocks)
            if (item.id == block.id) block else item,
        ],
      ),
    );
  }

  Future<void> _publish() async {
    final bundle = _bundle!;
    if (bundle.config.schoolName.trim().isEmpty) {
      _message('El nombre del colegio es obligatorio.', error: true);
      return;
    }
    final slugs = bundle.pages.map((page) => page.slug.trim()).toList();
    if (slugs.any((slug) => !_validSlug(slug)) ||
        slugs.toSet().length != slugs.length) {
      _message('Cada página debe tener una URL única y válida.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await _service.publishBundle(
        bundle,
        previous: _publishedBundle,
      );
      if (!mounted) return;
      setState(() => _publishedBundle = bundle);
      _sessionUploads.removeAll(bundle.managedAssetPaths);
      final cleanup = result.deletedAssets == 0
          ? ''
          : ' Se eliminaron ${result.deletedAssets} imágenes anteriores.';
      _message('Sitio publicado correctamente.$cleanup');
      if (result.cleanupWarnings.isNotEmpty) {
        _message(
          'El sitio se publicó, pero algunas imágenes no pudieron limpiarse.',
          error: true,
        );
      }
    } catch (error) {
      if (mounted) _message('No fue posible publicar: $error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadImage({
    WebsiteBlock? targetBlock,
    bool logo = false,
    bool footerLogo = false,
  }) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final lower = picked.name.toLowerCase();
    if (!lower.endsWith('.jpg') &&
        !lower.endsWith('.jpeg') &&
        !lower.endsWith('.jpe') &&
        !lower.endsWith('.jfif') &&
        !lower.endsWith('.png')) {
      _message('Solo se permiten imágenes JPG, JPEG, JFIF o PNG.', error: true);
      return;
    }
    final target = logo
        ? 'logo'
        : (footerLogo ? 'footer_logo' : targetBlock!.id);
    setState(() => _uploading = target);
    try {
      final asset = await _service.uploadImage(
        bytes: await picked.readAsBytes(),
        fileName: picked.name,
      );
      _sessionUploads.add(asset.storagePath);
      final previous = logo
          ? _bundle!.config.logo
          : (footerLogo ? _bundle!.config.footer.logo : targetBlock!.image);
      if (logo) {
        _replaceConfig(_bundle!.config.copyWith(logo: asset));
      } else if (footerLogo) {
        _replaceConfig(
          _bundle!.config.copyWith(
            footer: _bundle!.config.footer.copyWith(logo: asset),
          ),
        );
      } else {
        _replaceBlock(targetBlock!.copyWith(image: asset));
      }
      if (previous.isManaged && _sessionUploads.remove(previous.storagePath)) {
        await _service.deleteAsset(previous);
      }
    } catch (error) {
      if (mounted) {
        final detail = error.toString();
        final guidance =
            detail.contains('storage/unauthorized') ||
                detail.contains('La sesión expiró')
            ? ' Verifica que esta cuenta esté activa y tenga "sitio_web.editar"; luego cierra sesión, ingresa de nuevo y recarga la página.'
            : '';
        _message(
          'No fue posible subir la imagen: $detail$guidance',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  void _addBlock(String type) {
    final index = _page.blocks.length;
    final block = WebsiteBlock(
      id: 'block_${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      pageId: _page.id,
      title: switch (type) {
        'contactForm' => 'Contáctanos',
        'hero' => 'Título de portada',
        'divider' || 'spacer' || 'image' || 'socialLinks' || 'button' => '',
        _ => 'Nuevo contenido',
      },
      body: switch (type) {
        'contactForm' => 'Completa el formulario y nos comunicaremos contigo.',
        'text' ||
        'imageText' ||
        'hero' => 'Escribe aquí el contenido del bloque.',
        _ => '',
      },
      buttonLabel: type == 'button' ? 'Nuevo botón' : '',
      mobileOrder: index,
      showAccent: type == 'text' || type == 'imageText',
      textColor: type == 'hero' ? '#FFFFFF' : '#212121',
    );
    _replacePage(_page.copyWith(blocks: [..._page.blocks, block]));
    setState(() {
      _selectedBlockId = block.id;
      _editingSite = false;
      _editingFooter = false;
    });
  }

  void _deleteBlock(WebsiteBlock block) {
    if (block.image.isManaged &&
        _sessionUploads.remove(block.image.storagePath)) {
      unawaited(_service.deleteAsset(block.image));
    }
    _replacePage(
      _page.copyWith(
        blocks: _page.blocks.where((item) => item.id != block.id).toList(),
      ),
    );
    setState(() => _selectedBlockId = null);
  }

  void _reorderDesktop(int oldIndex, int newIndex) {
    final blocks = [..._page.blocks];
    final item = blocks.removeAt(oldIndex);
    blocks.insert(newIndex, item);
    _replacePage(_page.copyWith(blocks: blocks));
  }

  void _reorderPreview(int oldIndex, int newIndex) {
    final visible = _page.blocks
        .where(
          (block) =>
              block.enabled &&
              (_mobilePreview ? block.showOnMobile : block.showOnDesktop),
        )
        .toList();
    if (_mobilePreview) {
      visible.sort((a, b) => a.mobileOrder.compareTo(b.mobileOrder));
      final item = visible.removeAt(oldIndex);
      visible.insert(newIndex, item);
      final orders = {
        for (var i = 0; i < visible.length; i++) visible[i].id: i,
      };
      var hiddenOrder = visible.length;
      _replacePage(
        _page.copyWith(
          blocks: [
            for (final block in _page.blocks)
              block.copyWith(mobileOrder: orders[block.id] ?? hiddenOrder++),
          ],
        ),
      );
    } else {
      final item = visible.removeAt(oldIndex);
      visible.insert(newIndex, item);
      final orderedIds = visible.map((block) => block.id).iterator;
      orderedIds.moveNext();
      final reordered = <WebsiteBlock>[];
      for (final block in _page.blocks) {
        if (block.enabled && block.showOnDesktop) {
          final id = orderedIds.current;
          reordered.add(_page.blocks.firstWhere((item) => item.id == id));
          orderedIds.moveNext();
        } else {
          reordered.add(block);
        }
      }
      _replacePage(_page.copyWith(blocks: reordered));
    }
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppPalette.error : AppPalette.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const _EditorUnavailable();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1024) return const _EditorUnavailable();
        if (_loading || _bundle == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final canEdit = _canEdit(context);
        return Scaffold(
          backgroundColor: AppPalette.surfaceContainer,
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Volver al menu de administracion',
              onPressed: () => context.go('/admin_dashboard'),
              icon: const Icon(Icons.arrow_back),
            ),
            title: Text(
              canEdit ? 'Constructor del sitio web' : 'Vista del sitio web',
            ),
            actions: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.desktop_windows),
                    label: Text('Escritorio'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.smartphone),
                    label: Text('Móvil'),
                  ),
                ],
                selected: {_mobilePreview},
                onSelectionChanged: (value) =>
                    setState(() => _mobilePreview = value.first),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () =>
                    context.go(_page.id == 'home' ? '/' : '/${_page.slug}'),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir página'),
              ),
              if (canEdit)
                TextButton.icon(
                  onPressed: () => context.go('/website_messages'),
                  icon: const Icon(Icons.inbox_outlined),
                  label: const Text('Mensajes'),
                ),
              if (canEdit)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: FilledButton.icon(
                    onPressed: _saving || _uploading != null ? null : _publish,
                    icon: _saving
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.publish),
                    label: Text(_saving ? 'Publicando...' : 'Publicar'),
                  ),
                ),
            ],
          ),
          body: AbsorbPointer(
            absorbing: !canEdit,
            child: Row(
              children: [
                SizedBox(width: 270, child: _leftPanel()),
                const VerticalDivider(width: 1),
                Expanded(child: _preview()),
                const VerticalDivider(width: 1),
                SizedBox(width: 370, child: _propertiesPanel()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _leftPanel() => ColoredBox(
    color: AppPalette.surface,
    child: Column(
      children: [
        ListTile(
          selected: _editingSite,
          leading: const Icon(Icons.tune),
          title: const Text('Configuración global'),
          onTap: () => setState(() {
            _editingSite = true;
            _editingFooter = false;
            _selectedBlockId = null;
          }),
        ),
        ListTile(
          selected: _editingFooter,
          leading: const Icon(Icons.vertical_align_bottom_outlined),
          title: const Text('Pie de página'),
          onTap: () => setState(() {
            _editingSite = false;
            _editingFooter = true;
            _selectedBlockId = null;
          }),
        ),
        const Divider(),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'PÁGINAS',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppPalette.onSurface.withValues(alpha: .54),
              ),
            ),
          ),
        ),
        for (final page in _bundle!.pages)
          ListTile(
            dense: true,
            selected: !_editingSite && !_editingFooter && page.id == _page.id,
            leading: Icon(
              page.id == 'home'
                  ? Icons.home_outlined
                  : Icons.description_outlined,
            ),
            title: Text(page.label),
            subtitle: Text(page.id == 'home' ? '/' : '/${page.slug}'),
            trailing: Icon(
              page.enabled ? Icons.visibility : Icons.visibility_off,
              size: 18,
            ),
            onTap: () => setState(() {
              _selectedPageId = page.id;
              _selectedBlockId = null;
              _editingSite = false;
              _editingFooter = false;
            }),
          ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FilledButton.icon(
            onPressed: _showAddBlock,
            icon: const Icon(Icons.add),
            label: const Text('Agregar bloque'),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: true,
            itemCount: _page.blocks.length,
            onReorderItem: _reorderDesktop,
            itemBuilder: (context, index) {
              final block = _page.blocks[index];
              return ListTile(
                key: ValueKey(block.id),
                dense: true,
                selected: block.id == _selectedBlockId,
                leading: Icon(_blockIcon(block.type), size: 20),
                title: Text(_blockTypeLabel(block.type)),
                subtitle: Text(
                  block.title.isEmpty ? 'Sin título' : block.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => setState(() {
                  _selectedBlockId = block.id;
                  _editingSite = false;
                  _editingFooter = false;
                }),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _preview() {
    final width = _mobilePreview ? 390.0 : 1120.0;
    return LayoutBuilder(
      builder: (context, constraints) => ColoredBox(
        color: AppPalette.outline,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(18),
          child: SizedBox(
            width: width,
            height: constraints.maxHeight - 36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppPalette.surface,
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.onSurface.withValues(alpha: .26),
                    blurRadius: 18,
                  ),
                ],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: WebsitePreviewCanvas(
                  config: _bundle!.config,
                  page: _page,
                  previewMobile: _mobilePreview,
                  editorMode: true,
                  selectedBlockId: _selectedBlockId,
                  onBlockSelected: (id) => setState(() {
                    _selectedBlockId = id;
                    _editingSite = false;
                    _editingFooter = false;
                  }),
                  onReorder: _reorderPreview,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _propertiesPanel() => ColoredBox(
    color: AppPalette.surface,
    child: _editingSite
        ? _siteProperties()
        : (_editingFooter
              ? _footerProperties()
              : (_block == null
                    ? _pageProperties()
                    : _blockProperties(_block!))),
  );

  Widget _siteProperties() {
    final config = _bundle!.config;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _propertyTitle('Configuración global', Icons.tune),
        _text(
          'Nombre del colegio',
          config.schoolName,
          (value) => _replaceConfig(config.copyWith(schoolName: value)),
        ),
        _text(
          'Frase institucional',
          config.tagline,
          (value) => _replaceConfig(config.copyWith(tagline: value)),
        ),
        _text(
          'Color principal',
          config.primaryColor,
          (value) => _replaceConfig(config.copyWith(primaryColor: value)),
        ),
        _dropdown(
          'Tipografía general',
          config.fontFamily,
          const {
            'Roboto': 'Roboto',
            'Lato': 'Lato',
            'Montserrat': 'Montserrat',
            'Poppins': 'Poppins',
            'Playfair Display': 'Playfair Display',
          },
          (value) => _replaceConfig(config.copyWith(fontFamily: value)),
        ),
        _imageControl(
          'Logo',
          config.logo,
          _uploading == 'logo',
          () => _uploadImage(logo: true),
        ),
        const Divider(height: 32),
        _text(
          'Dirección',
          config.address,
          (value) => _replaceConfig(config.copyWith(address: value)),
        ),
        _text(
          'Teléfono',
          config.phone,
          (value) => _replaceConfig(config.copyWith(phone: value)),
        ),
        _text(
          'Correo',
          config.email,
          (value) => _replaceConfig(config.copyWith(email: value)),
        ),
        const Divider(height: 32),
        const Text(
          'Redes sociales',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < config.socialLinks.length; index++)
          _socialEditor(config, index),
      ],
    );
  }

  Widget _footerProperties() {
    final config = _bundle!.config;
    final footer = config.footer;
    void update(WebsiteFooterConfig value) {
      _replaceConfig(config.copyWith(footer: value));
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _propertyTitle('Pie de página', Icons.vertical_align_bottom_outlined),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar pie de página'),
          value: footer.enabled,
          onChanged: (value) => update(footer.copyWith(enabled: value)),
        ),
        _dropdown(
          'Distribución',
          footer.layout,
          const {'columns': 'Columnas', 'centered': 'Centrado'},
          (value) => update(footer.copyWith(layout: value)),
        ),
        _dropdown(
          'Alineación',
          footer.alignment,
          const {'left': 'Izquierda', 'center': 'Centro', 'right': 'Derecha'},
          (value) => update(footer.copyWith(alignment: value)),
        ),
        _dropdown(
          'Tipografía',
          footer.fontFamily,
          const {
            '': 'Usar tipografía general',
            'Roboto': 'Roboto',
            'Lato': 'Lato',
            'Montserrat': 'Montserrat',
            'Poppins': 'Poppins',
            'Playfair Display': 'Playfair Display',
          },
          (value) => update(footer.copyWith(fontFamily: value)),
        ),
        _text(
          'Título (vacío usa nombre del colegio)',
          footer.title,
          (value) => update(footer.copyWith(title: value)),
          lines: 2,
        ),
        _text(
          'Descripción (vacía usa frase institucional)',
          footer.description,
          (value) => update(footer.copyWith(description: value)),
          lines: 3,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar descripción'),
          value: footer.showDescription,
          onChanged: (value) => update(footer.copyWith(showDescription: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar logo'),
          value: footer.showLogo,
          onChanged: (value) => update(footer.copyWith(showLogo: value)),
        ),
        if (footer.showLogo) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Usar logo principal'),
            value: footer.useSiteLogo,
            onChanged: (value) => update(footer.copyWith(useSiteLogo: value)),
          ),
          if (!footer.useSiteLogo)
            _imageControl(
              'Logo del pie de página',
              footer.logo,
              _uploading == 'footer_logo',
              () => _uploadImage(footerLogo: true),
            ),
          _slider(
            'Tamaño del logo',
            footer.logoSize,
            32,
            180,
            (value) => update(footer.copyWith(logoSize: value)),
          ),
        ],
        const Divider(height: 32),
        _text(
          'Color de fondo',
          footer.backgroundColor,
          (value) => update(footer.copyWith(backgroundColor: value)),
        ),
        _text(
          'Color de texto',
          footer.textColor,
          (value) => update(footer.copyWith(textColor: value)),
        ),
        _text(
          'Color de texto secundario',
          footer.secondaryTextColor,
          (value) => update(footer.copyWith(secondaryTextColor: value)),
        ),
        _text(
          'Color de redes y acentos',
          footer.accentColor,
          (value) => update(footer.copyWith(accentColor: value)),
        ),
        _slider(
          'Tamaño del título',
          footer.titleSize,
          14,
          48,
          (value) => update(footer.copyWith(titleSize: value)),
        ),
        _slider(
          'Tamaño del texto',
          footer.bodySize,
          11,
          26,
          (value) => update(footer.copyWith(bodySize: value)),
        ),
        _slider(
          'Espaciado escritorio',
          footer.padding,
          8,
          100,
          (value) => update(footer.copyWith(padding: value)),
        ),
        _slider(
          'Espaciado móvil',
          footer.mobilePadding,
          8,
          64,
          (value) => update(footer.copyWith(mobilePadding: value)),
        ),
        _slider(
          'Ancho máximo',
          footer.maxWidth,
          720,
          1600,
          (value) => update(footer.copyWith(maxWidth: value)),
        ),
        const Divider(height: 32),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar datos de contacto'),
          value: footer.showContact,
          onChanged: (value) => update(footer.copyWith(showContact: value)),
        ),
        if (footer.showContact) ...[
          _text(
            'Título de contacto',
            footer.contactTitle,
            (value) => update(footer.copyWith(contactTitle: value)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Usar contacto de configuración global'),
            value: footer.useGlobalContact,
            onChanged: (value) =>
                update(footer.copyWith(useGlobalContact: value)),
          ),
          if (!footer.useGlobalContact) ...[
            _text(
              'Dirección del footer',
              footer.address,
              (value) => update(footer.copyWith(address: value)),
            ),
            _text(
              'Teléfono del footer',
              footer.phone,
              (value) => update(footer.copyWith(phone: value)),
            ),
            _text(
              'Correo del footer',
              footer.email,
              (value) => update(footer.copyWith(email: value)),
            ),
          ],
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar redes sociales'),
          value: footer.showSocialLinks,
          onChanged: (value) => update(footer.copyWith(showSocialLinks: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar enlaces de navegación'),
          value: footer.showNavigation,
          onChanged: (value) => update(footer.copyWith(showNavigation: value)),
        ),
        if (footer.showNavigation)
          _text(
            'Título de enlaces',
            footer.linksTitle,
            (value) => update(footer.copyWith(linksTitle: value)),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar copyright'),
          value: footer.showCopyright,
          onChanged: (value) => update(footer.copyWith(showCopyright: value)),
        ),
        if (footer.showCopyright)
          _text(
            'Copyright (vacío genera el año automáticamente)',
            footer.copyrightText,
            (value) => update(footer.copyWith(copyrightText: value)),
            lines: 2,
          ),
      ],
    );
  }

  Widget _socialEditor(WebsiteSiteConfig config, int index) {
    final social = config.socialLinks[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(_socialIcon(social.platform)),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              key: ValueKey('social_${social.platform}'),
              initialValue: social.url,
              decoration: InputDecoration(
                labelText: social.platform,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                final links = [...config.socialLinks];
                links[index] = social.copyWith(url: value);
                _replaceConfig(config.copyWith(socialLinks: links));
              },
            ),
          ),
          Switch(
            value: social.enabled,
            onChanged: (value) {
              final links = [...config.socialLinks];
              links[index] = social.copyWith(enabled: value);
              _replaceConfig(config.copyWith(socialLinks: links));
            },
          ),
        ],
      ),
    );
  }

  Widget _pageProperties() {
    final page = _page;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _propertyTitle('Página', Icons.description_outlined),
        _text(
          'Nombre',
          page.label,
          (value) => _replacePage(page.copyWith(label: value)),
        ),
        _text(
          'URL',
          page.slug,
          (value) => _replacePage(page.copyWith(slug: _slugify(value))),
          enabled: false,
          prefix: '/',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Página publicada'),
          value: page.enabled,
          onChanged: page.id == 'home'
              ? null
              : (value) => _replacePage(page.copyWith(enabled: value)),
        ),
        if (page.id != 'home')
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar en navegación'),
            value: page.showInNavigation,
            onChanged: (value) =>
                _replacePage(page.copyWith(showInNavigation: value)),
          ),
        const SizedBox(height: 16),
        const Text(
          'Selecciona un bloque en la vista previa o en la lista izquierda para editarlo.',
        ),
      ],
    );
  }

  Widget _blockProperties(WebsiteBlock block) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      Row(
        children: [
          Expanded(
            child: _propertyTitle(
              _blockTypeLabel(block.type),
              _blockIcon(block.type),
            ),
          ),
          IconButton(
            tooltip: 'Eliminar bloque',
            color: AppPalette.error,
            onPressed: () => _deleteBlock(block),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      if (!{
        'divider',
        'spacer',
        'image',
        'socialLinks',
        'button',
      }.contains(block.type)) ...[
        _text(
          'Título',
          block.title,
          (value) => _replaceBlock(block.copyWith(title: value)),
          lines: 2,
        ),
        _text(
          'Contenido',
          block.body,
          (value) => _replaceBlock(block.copyWith(body: value)),
          lines: 5,
        ),
      ],
      if ({'hero', 'image', 'imageText'}.contains(block.type))
        _imageControl(
          'Imagen',
          block.image,
          _uploading == block.id,
          () => _uploadImage(targetBlock: block),
        ),
      if ({'hero', 'imageText', 'button'}.contains(block.type)) ...[
        _text(
          'Texto del botón',
          block.buttonLabel,
          (value) => _replaceBlock(block.copyWith(buttonLabel: value)),
        ),
        _text(
          'Enlace del botón',
          block.buttonUrl,
          (value) => _replaceBlock(block.copyWith(buttonUrl: value)),
        ),
      ],
      const Divider(height: 30),
      _dropdown(
        'Alineación',
        block.textAlignment,
        const {'left': 'Izquierda', 'center': 'Centro', 'right': 'Derecha'},
        (value) => _replaceBlock(block.copyWith(textAlignment: value)),
      ),
      if ({'hero', 'imageText'}.contains(block.type)) ...[
        _dropdown(
          'Imagen en escritorio',
          block.imagePosition,
          const {
            'left': 'Izquierda',
            'right': 'Derecha',
            'top': 'Arriba',
            'background': 'Fondo',
          },
          (value) => _replaceBlock(block.copyWith(imagePosition: value)),
        ),
        _dropdown(
          'Imagen en móvil',
          block.mobileImagePosition,
          const {'top': 'Arriba', 'background': 'Fondo'},
          (value) => _replaceBlock(block.copyWith(mobileImagePosition: value)),
        ),
        _dropdown(
          'Ajuste de imagen',
          block.imageFit,
          const {'cover': 'Cubrir', 'contain': 'Contener'},
          (value) => _replaceBlock(block.copyWith(imageFit: value)),
        ),
      ],
      _dropdown(
        'Ancho',
        block.contentWidth,
        const {'wide': 'Amplio', 'normal': 'Normal', 'narrow': 'Estrecho'},
        (value) => _replaceBlock(block.copyWith(contentWidth: value)),
      ),
      _dropdown(
        'Tipografía',
        block.fontFamily,
        const {
          'Roboto': 'Roboto',
          'Lato': 'Lato',
          'Montserrat': 'Montserrat',
          'Poppins': 'Poppins',
          'Playfair Display': 'Playfair Display',
        },
        (value) => _replaceBlock(block.copyWith(fontFamily: value)),
      ),
      _text(
        'Color de fondo',
        block.backgroundColor,
        (value) => _replaceBlock(block.copyWith(backgroundColor: value)),
      ),
      _text(
        'Color de texto',
        block.textColor,
        (value) => _replaceBlock(block.copyWith(textColor: value)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Separador de acento'),
        value: block.showAccent,
        onChanged: (value) => _replaceBlock(block.copyWith(showAccent: value)),
      ),
      if (block.showAccent)
        _text(
          'Color del acento',
          block.accentColor,
          (value) => _replaceBlock(block.copyWith(accentColor: value)),
        ),
      _slider(
        'Título escritorio',
        block.titleSize,
        18,
        80,
        (value) => _replaceBlock(block.copyWith(titleSize: value)),
      ),
      _slider(
        'Título móvil',
        block.mobileTitleSize,
        16,
        58,
        (value) => _replaceBlock(block.copyWith(mobileTitleSize: value)),
      ),
      _slider(
        'Texto escritorio',
        block.bodySize,
        12,
        30,
        (value) => _replaceBlock(block.copyWith(bodySize: value)),
      ),
      _slider(
        'Texto móvil',
        block.mobileBodySize,
        12,
        26,
        (value) => _replaceBlock(block.copyWith(mobileBodySize: value)),
      ),
      _slider(
        'Espaciado escritorio',
        block.padding,
        0,
        100,
        (value) => _replaceBlock(block.copyWith(padding: value)),
      ),
      _slider(
        'Espaciado móvil',
        block.mobilePadding,
        0,
        64,
        (value) => _replaceBlock(block.copyWith(mobilePadding: value)),
      ),
      const Divider(height: 30),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Visible en escritorio'),
        value: block.showOnDesktop,
        onChanged: (value) =>
            _replaceBlock(block.copyWith(showOnDesktop: value)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Visible en móvil'),
        value: block.showOnMobile,
        onChanged: (value) =>
            _replaceBlock(block.copyWith(showOnMobile: value)),
      ),
    ],
  );

  Future<void> _showAddBlock() async {
    final type = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar bloque'),
        content: SizedBox(
          width: 480,
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            childAspectRatio: 2.8,
            children: [
              for (final type in const [
                'hero',
                'text',
                'image',
                'imageText',
                'button',
                'divider',
                'spacer',
                'contactForm',
                'socialLinks',
              ])
                ListTile(
                  leading: Icon(_blockIcon(type)),
                  title: Text(_blockTypeLabel(type)),
                  onTap: () => Navigator.pop(context, type),
                ),
            ],
          ),
        ),
      ),
    );
    if (type != null) _addBlock(type);
  }

  Widget _propertyTitle(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      children: [
        Icon(icon, color: AppPalette.error),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  Widget _text(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    int lines = 1,
    bool enabled = true,
    String? prefix,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: TextFormField(
      key: ValueKey('${_selectedPageId}_${_selectedBlockId}_${label}_$enabled'),
      initialValue: value,
      enabled: enabled,
      minLines: lines,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onChanged,
    ),
  );

  Widget _dropdown(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: DropdownButtonFormField<String>(
      key: ValueKey('${_selectedBlockId}_${label}_$value'),
      initialValue: options.containsKey(value) ? value : options.keys.first,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final option in options.entries)
          DropdownMenuItem(value: option.key, child: Text(option.value)),
      ],
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    ),
  );

  Widget _slider(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label: $value px'),
      Slider(
        value: value.clamp(min, max).toDouble(),
        min: min.toDouble(),
        max: max.toDouble(),
        divisions: max - min,
        onChanged: (newValue) => onChanged(newValue.round()),
      ),
    ],
  );

  Widget _imageControl(
    String label,
    WebsiteAsset asset,
    bool loading,
    VoidCallback onUpload,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: WebsiteImage(asset: asset, width: 76, height: 62),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        OutlinedButton.icon(
          onPressed: loading ? null : onUpload,
          icon: loading
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload),
          label: Text(loading ? 'Subiendo' : 'Cambiar'),
        ),
      ],
    ),
  );
}

class _EditorUnavailable extends StatelessWidget {
  const _EditorUnavailable();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Volver al menu de administracion',
        onPressed: () => context.go('/admin_dashboard'),
        icon: const Icon(Icons.arrow_back),
      ),
      title: const Text('Administrar sitio web'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: const Card(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.desktop_windows_outlined, size: 58),
                SizedBox(height: 16),
                Text(
                  'Editor disponible únicamente en web de escritorio',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  'Usa un computador o una tableta con una ventana de al menos 1024 px. La vista móvil puede configurarse desde el editor.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

String _blockTypeLabel(String type) => switch (type) {
  'hero' => 'Portada',
  'text' => 'Texto',
  'image' => 'Imagen',
  'imageText' => 'Imagen y texto',
  'button' => 'Botón',
  'divider' => 'Separador',
  'spacer' => 'Espacio',
  'contactForm' => 'Formulario de contacto',
  'socialLinks' => 'Redes sociales',
  _ => 'Bloque',
};

IconData _blockIcon(String type) => switch (type) {
  'hero' => Icons.web_asset,
  'text' => Icons.text_fields,
  'image' => Icons.image_outlined,
  'imageText' => Icons.view_week_outlined,
  'button' => Icons.smart_button_outlined,
  'divider' => Icons.horizontal_rule,
  'spacer' => Icons.space_bar,
  'contactForm' => Icons.contact_mail_outlined,
  'socialLinks' => Icons.share_outlined,
  _ => Icons.widgets_outlined,
};

IconData _socialIcon(String platform) => switch (platform) {
  'facebook' => Icons.facebook,
  'youtube' => Icons.play_circle_fill,
  'instagram' => Icons.camera_alt_outlined,
  'tiktok' => Icons.music_note,
  _ => Icons.link,
};

bool _validSlug(String value) =>
    RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(value);

String _slugify(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');
