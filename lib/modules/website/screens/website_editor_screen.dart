import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../config/app_palette.dart';
import '../../../providers/user_provider_v2.dart';
import '../models/website_content.dart';
import '../services/website_service.dart';
import 'public_website_screen.dart';

enum _EditorArea { header, footer, page }

class WebsiteEditorScreen extends StatefulWidget {
  const WebsiteEditorScreen({super.key});

  @override
  State<WebsiteEditorScreen> createState() => _WebsiteEditorScreenState();
}

class _WebsiteEditorScreenState extends State<WebsiteEditorScreen> {
  final _service = WebsiteService();
  WebsiteBundle? _bundle;
  WebsiteBundle? _publishedBundle;
  _EditorArea _area = _EditorArea.header;
  String _selectedPageId = 'home';
  String? _selectedId;
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

  @override
  void dispose() {
    final published = _publishedBundle?.managedAssetPaths ?? const <String>{};
    for (final path in _sessionUploads.difference(published)) {
      unawaited(_service.deleteAsset(WebsiteAsset(storagePath: path)));
    }
    super.dispose();
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

  WebsitePage get _page => _bundle!.pages.firstWhere(
    (page) => page.id == _selectedPageId,
    orElse: () => _bundle!.pages.first,
  );

  List<WebsiteRow> get _rows => switch (_area) {
    _EditorArea.header => _bundle!.config.header.rows,
    _EditorArea.footer => _bundle!.config.footer.rows,
    _EditorArea.page => _page.rows,
  };

  WebsiteRow? get _selectedRow {
    for (final row in _rows) {
      if (row.id == _selectedId) return row;
    }
    return null;
  }

  WebsiteColumn? get _selectedColumn {
    for (final row in _rows) {
      for (final column in row.columns) {
        if (column.id == _selectedId) return column;
      }
    }
    return null;
  }

  WebsiteComponent? get _selectedComponent {
    for (final row in _rows) {
      for (final column in row.columns) {
        for (final component in column.components) {
          if (component.id == _selectedId) return component;
        }
      }
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

  void _replaceConfig(WebsiteSiteConfig config) => setState(
    () => _bundle = WebsiteBundle(config: config, pages: _bundle!.pages),
  );

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
    setState(() {
      _bundle = WebsiteBundle(
        config: _bundle!.config.copyWith(navigation: navigation),
        pages: pages,
      );
    });
  }

  void _replaceRows(List<WebsiteRow> rows) {
    switch (_area) {
      case _EditorArea.header:
        _replaceConfig(
          _bundle!.config.copyWith(
            header: _bundle!.config.header.copyWith(rows: rows),
          ),
        );
      case _EditorArea.footer:
        _replaceConfig(
          _bundle!.config.copyWith(
            footer: _bundle!.config.footer.copyWith(rows: rows),
          ),
        );
      case _EditorArea.page:
        _replacePage(_page.copyWith(rows: rows));
    }
  }

  void _replaceRow(WebsiteRow value) => _replaceRows([
    for (final row in _rows)
      if (row.id == value.id) value else row,
  ]);

  void _replaceColumn(WebsiteColumn value) => _replaceRows([
    for (final row in _rows)
      row.copyWith(
        columns: [
          for (final column in row.columns)
            if (column.id == value.id) value else column,
        ],
      ),
  ]);

  void _replaceComponent(WebsiteComponent value) => _replaceRows([
    for (final row in _rows)
      row.copyWith(
        columns: [
          for (final column in row.columns)
            column.copyWith(
              components: [
                for (final component in column.components)
                  if (component.id == value.id) value else component,
              ],
            ),
        ],
      ),
  ]);

  Future<void> _publish() async {
    final bundle = _bundle!;
    if (bundle.config.schoolName.trim().isEmpty) {
      _message('El nombre del colegio es obligatorio.', error: true);
      return;
    }
    final slugs = bundle.pages.map((page) => page.slug.trim()).toList();
    if (slugs.any((slug) => !RegExp(r'^[a-z0-9-]+$').hasMatch(slug)) ||
        slugs.toSet().length != slugs.length) {
      _message(
        'Cada página debe tener una URL única, en minúscula y sin espacios.',
        error: true,
      );
      return;
    }
    if (_allComponents(bundle)
        .where((item) => item.type == 'video' && item.url.isNotEmpty)
        .any((item) => !_validVideo(item.url))) {
      _message(
        'Los videos deben usar un enlace HTTPS válido de YouTube o Vimeo.',
        error: true,
      );
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
      final abandonedUploads = [..._sessionUploads];
      _sessionUploads.clear();
      for (final path in abandonedUploads) {
        unawaited(_deleteDiscardedAsset(WebsiteAsset(storagePath: path)));
      }
      _message(
        result.deletedAssets == 0
            ? 'Sitio publicado correctamente.'
            : 'Sitio publicado. Se limpiaron ${result.deletedAssets} imágenes anteriores.',
      );
      if (result.cleanupWarnings.isNotEmpty) {
        _message(
          'El sitio se publicó, pero algunas imágenes requieren limpieza.',
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
    WebsiteComponent? component,
    int? itemIndex,
    bool logo = false,
  }) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final target = logo ? 'logo' : '${component!.id}_${itemIndex ?? 'main'}';
    setState(() => _uploading = target);
    try {
      final asset = await _service.uploadImage(
        bytes: await picked.readAsBytes(),
        fileName: picked.name,
      );
      _sessionUploads.add(asset.storagePath);
      WebsiteAsset previous;
      if (logo) {
        previous = _bundle!.config.logo;
        _replaceConfig(_bundle!.config.copyWith(logo: asset));
      } else if (itemIndex != null) {
        previous = component!.items[itemIndex].image;
        final items = [...component.items];
        items[itemIndex] = items[itemIndex].copyWith(image: asset);
        _replaceComponent(component.copyWith(items: items));
      } else {
        previous = component!.image;
        _replaceComponent(component.copyWith(image: asset));
      }
      if (previous.isManaged && _sessionUploads.remove(previous.storagePath)) {
        await _service.deleteAsset(previous);
      }
    } catch (error) {
      if (mounted) {
        _message('No fue posible subir la imagen: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  void _addRow() {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final row = WebsiteRow(
      id: 'row_$stamp',
      columns: [WebsiteColumn(id: 'column_$stamp')],
    );
    _replaceRows([..._rows, row]);
    setState(() => _selectedId = row.id);
  }

  Future<void> _addPage() async {
    final name = TextEditingController();
    final slug = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva página'),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre visible',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => slug.text = _slug(value),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: slug,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  prefixText: '/',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Crear página'),
          ),
        ],
      ),
    );
    if (accepted != true) {
      name.dispose();
      slug.dispose();
      return;
    }
    final label = name.text.trim();
    final path = _slug(slug.text);
    name.dispose();
    slug.dispose();
    if (label.isEmpty || path.isEmpty) {
      _message('Escribe un nombre y una URL válidos.', error: true);
      return;
    }
    if (_bundle!.pages.any((page) => page.slug == path)) {
      _message('Ya existe una página con esa URL.', error: true);
      return;
    }
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final id = 'page_$stamp';
    final page = WebsitePage(
      id: id,
      label: label,
      slug: path,
      sortOrder: _bundle!.pages.length,
      rows: [
        WebsiteRow(
          id: 'row_$stamp',
          columns: [
            WebsiteColumn(
              id: 'column_$stamp',
              components: [
                WebsiteComponent(
                  id: 'component_$stamp',
                  type: 'text',
                  title: label,
                  body: 'Escribe aquí el contenido de esta página.',
                ),
              ],
            ),
          ],
        ),
      ],
    );
    setState(() {
      _bundle = WebsiteBundle(
        config: _bundle!.config.copyWith(
          navigation: [
            ..._bundle!.config.navigation,
            WebsiteNavigationItem(id: id, label: label, slug: path),
          ],
        ),
        pages: [..._bundle!.pages, page],
      );
      _area = _EditorArea.page;
      _selectedPageId = id;
      _selectedId = null;
    });
  }

  Future<void> _deletePage() async {
    if (_page.id == 'home') return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar página'),
        content: Text(
          'Se eliminará “${_page.label}” y todo su contenido al publicar. '
          'Sus imágenes se limpiarán después de guardar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    final deletedId = _page.id;
    _discardComponents(
      _page.rows
          .expand((row) => row.columns)
          .expand((column) => column.components),
    );
    setState(() {
      final pages = _bundle!.pages
          .where((page) => page.id != deletedId)
          .toList();
      _bundle = WebsiteBundle(
        config: _bundle!.config.copyWith(
          navigation: _bundle!.config.navigation
              .where((item) => item.id != deletedId)
              .toList(),
        ),
        pages: pages,
      );
      _selectedPageId = pages.first.id;
      _selectedId = null;
    });
  }

  void _addColumn(WebsiteRow row) {
    if (row.columns.length >= 4) {
      _message('Una fila admite máximo cuatro columnas.', error: true);
      return;
    }
    final column = WebsiteColumn(
      id: 'column_${DateTime.now().microsecondsSinceEpoch}',
    );
    _replaceRow(row.copyWith(columns: [...row.columns, column]));
    setState(() => _selectedId = column.id);
  }

  Future<void> _addComponent(WebsiteColumn column) async {
    final type = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar componente'),
        content: SizedBox(
          width: 620,
          child: GridView.extent(
            shrinkWrap: true,
            maxCrossAxisExtent: 190,
            childAspectRatio: 1.7,
            children: [
              for (final type in _componentTypes)
                Card(
                  child: InkWell(
                    onTap: () => Navigator.pop(context, type),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_componentIcon(type)),
                          const SizedBox(height: 5),
                          Text(
                            _componentLabel(type),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (type == null) return;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final component = WebsiteComponent(
      id: 'component_$stamp',
      type: type,
      title: switch (type) {
        'contactForm' => 'Contáctanos',
        'accordion' => 'Preguntas frecuentes',
        'stats' => 'Nuestro colegio en cifras',
        'video' => 'Video institucional',
        'hero' => 'Título principal',
        'card' => 'Nueva tarjeta',
        _ => '',
      },
      body: type == 'text' || type == 'hero' || type == 'card'
          ? 'Escribe aquí el contenido.'
          : '',
      buttonLabel: type == 'button' ? 'Más información' : '',
      items: _usesItems(type)
          ? [
              WebsiteComponentItem(
                id: 'item_$stamp',
                title: type == 'stats' ? '100+' : 'Nuevo elemento',
                text: type == 'stats' ? 'Estudiantes' : 'Descripción',
              ),
            ]
          : const [],
    );
    _replaceColumn(
      column.copyWith(components: [...column.components, component]),
    );
    setState(() => _selectedId = component.id);
  }

  void _deleteSelected() {
    final id = _selectedId;
    if (id == null) return;
    final component = _selectedComponent;
    final column = _selectedColumn;
    final row = _selectedRow;
    _discardComponents(
      component != null
          ? [component]
          : column != null
          ? column.components
          : row != null
          ? row.columns.expand((item) => item.components)
          : const <WebsiteComponent>[],
    );
    _replaceRows([
      for (final row in _rows)
        if (row.id != id)
          row.copyWith(
            columns: [
              for (final column in row.columns)
                if (column.id != id)
                  column.copyWith(
                    components: column.components
                        .where((item) => item.id != id)
                        .toList(),
                  ),
            ],
          ),
    ]);
    setState(() => _selectedId = null);
  }

  void _discardComponents(Iterable<WebsiteComponent> components) {
    for (final component in components) {
      for (final asset in [
        component.image,
        ...component.items.map((item) => item.image),
      ]) {
        if (asset.isManaged && _sessionUploads.remove(asset.storagePath)) {
          unawaited(_deleteDiscardedAsset(asset));
        }
      }
    }
  }

  Future<void> _deleteDiscardedAsset(WebsiteAsset asset) async {
    try {
      await _service.deleteAsset(asset);
    } catch (_) {
      // Conserva la carga de la sesión para reintentar al cerrar el editor.
      _sessionUploads.add(asset.storagePath);
    }
  }

  void _moveRow(int oldIndex, int newIndex) {
    final rows = [..._rows];
    rows.insert(newIndex, rows.removeAt(oldIndex));
    _replaceRows(rows);
  }

  void _moveColumn(WebsiteRow row, int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= row.columns.length) return;
    final columns = [...row.columns];
    columns.insert(target, columns.removeAt(index));
    _replaceRow(row.copyWith(columns: columns));
  }

  void _moveComponent(WebsiteColumn column, int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= column.components.length) return;
    final components = [...column.components];
    components.insert(target, components.removeAt(index));
    _replaceColumn(column.copyWith(components: components));
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
        if (constraints.maxWidth < 1100) return const _EditorUnavailable();
        if (_loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (_bundle == null) {
          return Scaffold(
            body: Center(
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ),
          );
        }
        final canEdit = _canEdit(context);
        return Scaffold(
          backgroundColor: AppPalette.surfaceContainer,
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Volver al menú de administración',
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
                    icon: Icon(Icons.phone_android),
                    label: Text('Móvil'),
                  ),
                ],
                selected: {_mobilePreview},
                onSelectionChanged: (value) =>
                    setState(() => _mobilePreview = value.first),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: !canEdit || _saving ? null : _publish,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.publish),
                label: Text(_saving ? 'Publicando...' : 'Publicar'),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: AbsorbPointer(
            absorbing: !canEdit,
            child: Row(
              children: [
                SizedBox(width: 310, child: _leftPanel()),
                const VerticalDivider(width: 1),
                Expanded(child: _preview()),
                const VerticalDivider(width: 1),
                SizedBox(width: 390, child: _propertiesPanel()),
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
        _areaTile(_EditorArea.header, 'Header', Icons.vertical_align_top),
        _areaTile(_EditorArea.footer, 'Footer', Icons.vertical_align_bottom),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 5),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'CONTENIDO DE NAVEGACIÓN',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              IconButton(
                tooltip: 'Crear página',
                onPressed: _addPage,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
        for (final page in _bundle!.pages)
          ListTile(
            dense: true,
            selected: _area == _EditorArea.page && page.id == _selectedPageId,
            leading: Icon(
              page.id == 'home'
                  ? Icons.home_outlined
                  : Icons.description_outlined,
            ),
            title: Text(page.label),
            subtitle: Text('/${page.slug}'),
            onTap: () => setState(() {
              _area = _EditorArea.page;
              _selectedPageId = page.id;
              _selectedId = null;
            }),
          ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                'FILAS DE ${_areaLabel.toUpperCase()}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Agregar fila',
                onPressed: _addRow,
                icon: const Icon(Icons.add_box_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: _rows.length,
            onReorderItem: _moveRow,
            itemBuilder: (context, rowIndex) {
              final row = _rows[rowIndex];
              return ExpansionTile(
                key: ValueKey(row.id),
                leading: ReorderableDragStartListener(
                  index: rowIndex,
                  child: const Icon(Icons.drag_indicator),
                ),
                title: InkWell(
                  onTap: () => setState(() => _selectedId = row.id),
                  child: Text('Fila ${rowIndex + 1}'),
                ),
                trailing: IconButton(
                  tooltip: 'Agregar columna',
                  onPressed: () => _addColumn(row),
                  icon: const Icon(Icons.view_column_outlined),
                ),
                children: [
                  for (
                    var columnIndex = 0;
                    columnIndex < row.columns.length;
                    columnIndex++
                  )
                    ExpansionTile(
                      leading: const Icon(Icons.view_column_outlined, size: 20),
                      title: InkWell(
                        onTap: () => setState(
                          () => _selectedId = row.columns[columnIndex].id,
                        ),
                        child: Text('Columna ${columnIndex + 1}'),
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Opciones de columna',
                        onSelected: (value) {
                          if (value == 'add') {
                            _addComponent(row.columns[columnIndex]);
                          } else {
                            _moveColumn(
                              row,
                              columnIndex,
                              value == 'up' ? -1 : 1,
                            );
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'add',
                            child: Text('Agregar componente'),
                          ),
                          PopupMenuItem(
                            value: 'up',
                            child: Text('Mover a la izquierda'),
                          ),
                          PopupMenuItem(
                            value: 'down',
                            child: Text('Mover a la derecha'),
                          ),
                        ],
                      ),
                      children: [
                        for (
                          var componentIndex = 0;
                          componentIndex <
                              row.columns[columnIndex].components.length;
                          componentIndex++
                        )
                          ListTile(
                            dense: true,
                            selected:
                                row
                                    .columns[columnIndex]
                                    .components[componentIndex]
                                    .id ==
                                _selectedId,
                            leading: Icon(
                              _componentIcon(
                                row
                                    .columns[columnIndex]
                                    .components[componentIndex]
                                    .type,
                              ),
                              size: 19,
                            ),
                            title: Text(
                              _componentLabel(
                                row
                                    .columns[columnIndex]
                                    .components[componentIndex]
                                    .type,
                              ),
                            ),
                            trailing: PopupMenuButton<int>(
                              tooltip: 'Mover componente',
                              onSelected: (delta) => _moveComponent(
                                row.columns[columnIndex],
                                componentIndex,
                                delta,
                              ),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: -1,
                                  child: Text('Mover arriba'),
                                ),
                                PopupMenuItem(
                                  value: 1,
                                  child: Text('Mover abajo'),
                                ),
                              ],
                            ),
                            onTap: () => setState(
                              () => _selectedId = row
                                  .columns[columnIndex]
                                  .components[componentIndex]
                                  .id,
                            ),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _areaTile(_EditorArea area, String label, IconData icon) => ListTile(
    selected: _area == area,
    leading: Icon(icon),
    title: Text(label),
    onTap: () => setState(() {
      _area = area;
      _selectedId = null;
    }),
  );

  Widget _preview() => Center(
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: _mobilePreview ? 420 : double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black12)],
      ),
      clipBehavior: Clip.antiAlias,
      child: WebsitePreviewCanvas(
        config: _previewConfig,
        page: _previewPage,
        previewMobile: _mobilePreview,
        editorMode: true,
        selectedId: _selectedId,
        onSelected: (id) => setState(() => _selectedId = id),
      ),
    ),
  );

  WebsiteSiteConfig get _previewConfig => switch (_area) {
    _EditorArea.header => _bundle!.config.copyWith(
      footer: const WebsiteFooterConfig(enabled: false),
    ),
    _EditorArea.footer => _bundle!.config.copyWith(
      header: const WebsiteHeaderConfig(enabled: false),
    ),
    _EditorArea.page => _bundle!.config,
  };

  WebsitePage get _previewPage => switch (_area) {
    _EditorArea.header || _EditorArea.footer => const WebsitePage(
      id: 'preview',
      label: 'Vista previa',
      slug: 'preview',
      rows: [],
    ),
    _EditorArea.page => _page,
  };

  Widget _propertiesPanel() {
    final component = _selectedComponent;
    final column = _selectedColumn;
    final row = _selectedRow;
    if (component != null) return _componentProperties(component);
    if (column != null) return _columnProperties(column);
    if (row != null) return _rowProperties(row);
    return switch (_area) {
      _EditorArea.header => _headerProperties(),
      _EditorArea.footer => _footerProperties(),
      _EditorArea.page => _pageProperties(),
    };
  }

  Widget _headerProperties() {
    final config = _bundle!.config;
    return _propertyList([
      _title('Header', Icons.vertical_align_top),
      const Text('Identidad, navegación y estilo general del sitio.'),
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
      _imageControl(
        'Logo institucional',
        config.logo,
        () => _uploadImage(logo: true),
        'logo',
      ),
      _color(
        'Color principal',
        config.primaryColor,
        (value) => _replaceConfig(config.copyWith(primaryColor: value)),
      ),
      _dropdown(
        'Tipografía',
        config.fontFamily,
        const {
          'Montserrat': 'Montserrat',
          'Roboto': 'Roboto',
          'Lato': 'Lato',
          'Poppins': 'Poppins',
          'Playfair Display': 'Playfair Display',
        },
        (value) => _replaceConfig(config.copyWith(fontFamily: value)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Header visible'),
        value: config.header.enabled,
        onChanged: (value) => _replaceConfig(
          config.copyWith(header: config.header.copyWith(enabled: value)),
        ),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Header fijo al desplazarse'),
        value: config.header.sticky,
        onChanged: (value) => _replaceConfig(
          config.copyWith(header: config.header.copyWith(sticky: value)),
        ),
      ),
    ]);
  }

  Widget _footerProperties() {
    final config = _bundle!.config;
    return _propertyList([
      _title('Footer', Icons.vertical_align_bottom),
      const Text('Organiza sus filas y columnas desde el panel izquierdo.'),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Footer visible'),
        value: config.footer.enabled,
        onChanged: (value) => _replaceConfig(
          config.copyWith(footer: config.footer.copyWith(enabled: value)),
        ),
      ),
      const Divider(),
      _subtitle('Datos de contacto del Footer'),
      const Text('El componente “Datos de contacto” usa esta información.'),
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
      _text(
        'Texto legal / copyright',
        config.footer.copyrightText,
        (value) => _replaceConfig(
          config.copyWith(footer: config.footer.copyWith(copyrightText: value)),
        ),
        maxLines: 2,
      ),
      const Divider(),
      _subtitle('Redes sociales del Footer'),
      const Text(
        'Estos enlaces aparecen donde agregues el componente “Redes sociales”, '
        'normalmente dentro del Footer.',
      ),
      for (var i = 0; i < config.socialLinks.length; i++)
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_socialLabel(config.socialLinks[i].platform)),
                  value: config.socialLinks[i].enabled,
                  onChanged: (value) {
                    final links = [...config.socialLinks];
                    links[i] = links[i].copyWith(enabled: value);
                    _replaceConfig(config.copyWith(socialLinks: links));
                  },
                ),
                _text(
                  'Enlace de ${_socialLabel(config.socialLinks[i].platform)}',
                  config.socialLinks[i].url,
                  (value) {
                    final links = [...config.socialLinks];
                    links[i] = links[i].copyWith(url: value);
                    _replaceConfig(config.copyWith(socialLinks: links));
                  },
                ),
              ],
            ),
          ),
        ),
    ]);
  }

  Widget _pageProperties() => _propertyList([
    _title('Contenido: ${_page.label}', Icons.description_outlined),
    _text(
      'Nombre en el menú',
      _page.label,
      (value) => _replacePage(_page.copyWith(label: value)),
    ),
    _text(
      'URL',
      _page.slug,
      (value) => _replacePage(_page.copyWith(slug: _slug(value))),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Página publicada'),
      value: _page.enabled,
      onChanged: (value) => _replacePage(_page.copyWith(enabled: value)),
    ),
    if (_page.id != 'home')
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Mostrar en navegación'),
        value: _page.showInNavigation,
        onChanged: (value) =>
            _replacePage(_page.copyWith(showInNavigation: value)),
      ),
    const SizedBox(height: 12),
    FilledButton.icon(
      onPressed: _addRow,
      icon: const Icon(Icons.add),
      label: const Text('Agregar fila'),
    ),
    if (_page.id != 'home')
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: _deletePage,
        icon: const Icon(Icons.delete_outline),
        label: const Text('Eliminar página'),
      ),
  ]);

  Widget _rowProperties(WebsiteRow row) => _propertyList([
    _title('Fila', Icons.table_rows_outlined),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Visible'),
      value: row.enabled,
      onChanged: (value) => _replaceRow(row.copyWith(enabled: value)),
    ),
    _color(
      'Fondo',
      row.backgroundColor,
      (value) => _replaceRow(row.copyWith(backgroundColor: value)),
    ),
    _slider(
      'Espacio interior',
      row.padding,
      0,
      80,
      (value) => _replaceRow(row.copyWith(padding: value)),
    ),
    _slider(
      'Separación entre columnas',
      row.gap,
      0,
      60,
      (value) => _replaceRow(row.copyWith(gap: value)),
    ),
    _dropdown(
      'Ancho máximo',
      row.maxWidth.toString(),
      const {
        '960': 'Compacto (960 px)',
        '1120': 'Medio (1120 px)',
        '1280': 'Amplio (1280 px)',
        '1920': 'Pantalla completa',
      },
      (value) => _replaceRow(row.copyWith(maxWidth: int.parse(value))),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Apilar columnas en móvil'),
      subtitle: const Text('Recomendado para lectura cómoda.'),
      value: row.stackOnMobile,
      onChanged: (value) => _replaceRow(row.copyWith(stackOnMobile: value)),
    ),
    _deleteButton('Eliminar fila'),
  ]);

  Widget _columnProperties(WebsiteColumn column) => _propertyList([
    _title('Columna', Icons.view_column_outlined),
    _color(
      'Fondo',
      column.backgroundColor,
      (value) => _replaceColumn(column.copyWith(backgroundColor: value)),
    ),
    _slider(
      'Ancho relativo',
      column.span,
      1,
      4,
      (value) => _replaceColumn(column.copyWith(span: value)),
    ),
    _slider(
      'Espacio interior',
      column.padding,
      0,
      60,
      (value) => _replaceColumn(column.copyWith(padding: value)),
    ),
    FilledButton.icon(
      onPressed: () => _addComponent(column),
      icon: const Icon(Icons.add),
      label: const Text('Agregar componente'),
    ),
    _deleteButton('Eliminar columna'),
  ]);

  Widget _componentProperties(WebsiteComponent component) {
    final usesCopy = !{
      'image',
      'button',
      'gallery',
      'video',
      'divider',
      'spacer',
      'socialLinks',
      'navigation',
      'siteIdentity',
    }.contains(component.type);
    return _propertyList([
      _title(_componentLabel(component.type), _componentIcon(component.type)),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Visible'),
        value: component.enabled,
        onChanged: (value) =>
            _replaceComponent(component.copyWith(enabled: value)),
      ),
      _dropdown(
        'Ancho del componente',
        component.widthPercent.toString(),
        const {
          '100': 'Ancho completo (100 %)',
          '75': 'Tres cuartos (75 %)',
          '50': 'Mitad (50 %)',
          '33': 'Un tercio (33 %)',
          '25': 'Un cuarto (25 %)',
        },
        (value) => _replaceComponent(
          component.copyWith(widthPercent: int.parse(value)),
        ),
      ),
      _dropdown(
        'Posición del componente',
        component.componentAlignment,
        const {'left': 'Izquierda', 'center': 'Centro', 'right': 'Derecha'},
        (value) =>
            _replaceComponent(component.copyWith(componentAlignment: value)),
      ),
      if (usesCopy) ...[
        _text(
          'Título',
          component.title,
          (value) => _replaceComponent(component.copyWith(title: value)),
        ),
        _text(
          'Texto',
          component.body,
          (value) => _replaceComponent(component.copyWith(body: value)),
          maxLines: 5,
        ),
      ],
      if ({'hero', 'image', 'card'}.contains(component.type))
        _imageControl(
          'Imagen',
          component.image,
          () => _uploadImage(component: component),
          '${component.id}_main',
        ),
      if (component.type == 'video') ...[
        _text(
          'Enlace de YouTube o Vimeo',
          component.url,
          (value) => _replaceComponent(component.copyWith(url: value)),
        ),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Usa un enlace público HTTPS. El video se reproduce desde YouTube o Vimeo y no consume almacenamiento ni transferencia de Firebase.',
            ),
          ),
        ),
      ],
      if ({'button', 'card'}.contains(component.type)) ...[
        _text(
          'Texto del botón',
          component.buttonLabel,
          (value) => _replaceComponent(component.copyWith(buttonLabel: value)),
        ),
        _text(
          'Destino (URL o /ruta)',
          component.url,
          (value) => _replaceComponent(component.copyWith(url: value)),
        ),
      ],
      if (component.type == 'navigation')
        _text(
          'Botón de acceso (vacío para ocultar)',
          component.buttonLabel,
          (value) => _replaceComponent(component.copyWith(buttonLabel: value)),
        ),
      if (component.type == 'carousel') ...[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Avance automático'),
          value: component.autoplay,
          onChanged: (value) =>
              _replaceComponent(component.copyWith(autoplay: value)),
        ),
        _slider(
          'Segundos por imagen',
          component.intervalSeconds,
          2,
          15,
          (value) =>
              _replaceComponent(component.copyWith(intervalSeconds: value)),
        ),
      ],
      if (!{
        'image',
        'gallery',
        'video',
        'divider',
        'spacer',
      }.contains(component.type))
        _dropdown(
          'Alineación del contenido',
          component.alignment,
          const {'left': 'Izquierda', 'center': 'Centro', 'right': 'Derecha'},
          (value) => _replaceComponent(component.copyWith(alignment: value)),
        ),
      if (!{
        'image',
        'gallery',
        'video',
        'divider',
        'spacer',
        'navigation',
        'siteIdentity',
      }.contains(component.type)) ...[
        _color(
          'Color del texto',
          component.textColor,
          (value) => _replaceComponent(component.copyWith(textColor: value)),
        ),
        _color(
          'Color de acento',
          component.accentColor,
          (value) => _replaceComponent(component.copyWith(accentColor: value)),
        ),
      ],
      _color(
        'Fondo del componente',
        component.backgroundColor,
        (value) =>
            _replaceComponent(component.copyWith(backgroundColor: value)),
      ),
      if (!{'divider', 'spacer'}.contains(component.type)) ...[
        _slider(
          'Tamaño del título',
          component.titleSize,
          18,
          72,
          (value) => _replaceComponent(component.copyWith(titleSize: value)),
        ),
        _slider(
          'Tamaño del texto',
          component.bodySize,
          12,
          26,
          (value) => _replaceComponent(component.copyWith(bodySize: value)),
        ),
      ],
      _slider(
        component.type == 'spacer' ? 'Altura' : 'Espacio interior',
        component.padding,
        0,
        100,
        (value) => _replaceComponent(component.copyWith(padding: value)),
      ),
      if (_usesItems(component.type)) ...[
        const Divider(),
        _subtitle(_itemsLabel(component.type)),
        for (var i = 0; i < component.items.length; i++)
          _itemEditor(component, i),
        OutlinedButton.icon(
          onPressed: () => _addItem(component),
          icon: const Icon(Icons.add),
          label: const Text('Agregar elemento'),
        ),
      ],
      _deleteButton('Eliminar componente'),
    ]);
  }

  Widget _itemEditor(WebsiteComponent component, int index) {
    final item = component.items[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Elemento ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: () {
                    if (item.image.isManaged &&
                        _sessionUploads.remove(item.image.storagePath)) {
                      unawaited(_deleteDiscardedAsset(item.image));
                    }
                    final items = [...component.items]..removeAt(index);
                    _replaceComponent(component.copyWith(items: items));
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            _text(
              component.type == 'stats' ? 'Cifra' : 'Título',
              item.title,
              (value) =>
                  _replaceItem(component, index, item.copyWith(title: value)),
            ),
            _text(
              component.type == 'accordion' ? 'Respuesta' : 'Descripción',
              item.text,
              (value) =>
                  _replaceItem(component, index, item.copyWith(text: value)),
              maxLines: 3,
            ),
            if ({'carousel', 'gallery'}.contains(component.type))
              _imageControl(
                'Imagen',
                item.image,
                () => _uploadImage(component: component, itemIndex: index),
                '${component.id}_$index',
              ),
            if (component.type == 'carousel')
              _text(
                'Enlace opcional',
                item.url,
                (value) =>
                    _replaceItem(component, index, item.copyWith(url: value)),
              ),
          ],
        ),
      ),
    );
  }

  void _replaceItem(
    WebsiteComponent component,
    int index,
    WebsiteComponentItem item,
  ) {
    final items = [...component.items];
    items[index] = item;
    _replaceComponent(component.copyWith(items: items));
  }

  void _addItem(WebsiteComponent component) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    _replaceComponent(
      component.copyWith(
        items: [
          ...component.items,
          WebsiteComponentItem(
            id: 'item_$stamp',
            title: component.type == 'stats' ? '100+' : 'Nuevo elemento',
            text: component.type == 'stats' ? 'Descripción' : '',
          ),
        ],
      ),
    );
  }

  Widget _propertyList(List<Widget> children) => ColoredBox(
    color: AppPalette.surface,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) const SizedBox(height: 14),
        ],
      ],
    ),
  );

  Widget _title(String text, IconData icon) => Row(
    children: [
      Icon(icon),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      ),
    ],
  );
  Widget _subtitle(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  Widget _text(
    String label,
    String value,
    ValueChanged<String> changed, {
    int maxLines = 1,
  }) {
    return TextFormField(
      key: ValueKey('$label-${_selectedId ?? _area.name}'),
      initialValue: value,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: changed,
    );
  }

  Widget _dropdown(
    String label,
    String value,
    Map<String, String> values,
    ValueChanged<String> changed,
  ) => DropdownButtonFormField<String>(
    initialValue: values.containsKey(value) ? value : values.keys.first,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final entry in values.entries)
        DropdownMenuItem(value: entry.key, child: Text(entry.value)),
    ],
    onChanged: (value) {
      if (value != null) changed(value);
    },
  );

  Widget _slider(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> changed,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label: $value'),
      Slider(
        value: value.clamp(min, max).toDouble(),
        min: min.toDouble(),
        max: max.toDouble(),
        divisions: max - min,
        onChanged: (value) => changed(value.round()),
      ),
    ],
  );

  Widget _color(String label, String value, ValueChanged<String> changed) =>
      InkWell(
        onTap: () async {
          final result = await showDialog<String>(
            context: context,
            builder: (_) =>
                WebsiteColorPickerDialog(initial: value, title: label),
          );
          if (result != null) changed(result);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.palette_outlined),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 28,
                decoration: BoxDecoration(
                  color: websiteHexColor(value),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black26),
                ),
              ),
              const SizedBox(width: 12),
              Text(value.toUpperCase()),
            ],
          ),
        ),
      );

  Widget _imageControl(
    String label,
    WebsiteAsset asset,
    VoidCallback upload,
    String target,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (asset.url.isNotEmpty)
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: WebsiteImage(asset: asset, height: 125, fit: BoxFit.contain),
        ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _uploading == null ? upload : null,
        icon: _uploading == target
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload),
        label: Text(asset.url.isEmpty ? 'Elegir imagen' : 'Cambiar imagen'),
      ),
    ],
  );

  Widget _deleteButton(String label) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.error,
    ),
    onPressed: _deleteSelected,
    icon: const Icon(Icons.delete_outline),
    label: Text(label),
  );

  String get _areaLabel => switch (_area) {
    _EditorArea.header => 'Header',
    _EditorArea.footer => 'Footer',
    _EditorArea.page => _page.label,
  };
}

class WebsiteColorPickerDialog extends StatefulWidget {
  final String initial;
  final String title;

  const WebsiteColorPickerDialog({
    super.key,
    required this.initial,
    required this.title,
  });

  @override
  State<WebsiteColorPickerDialog> createState() =>
      _WebsiteColorPickerDialogState();
}

class _WebsiteColorPickerDialogState extends State<WebsiteColorPickerDialog> {
  late String _selected = widget.initial;
  late final TextEditingController _custom = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 700,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: websiteHexColor(_selected),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                _selected.toUpperCase(),
                style: TextStyle(
                  color: _contrast(websiteHexColor(_selected)),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Elige visualmente',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 10,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _websitePalette.length,
              itemBuilder: (context, index) {
                final value = _websitePalette[index];
                return Tooltip(
                  message: value,
                  child: InkWell(
                    onTap: () => setState(() {
                      _selected = value;
                      _custom.text = value;
                    }),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: websiteHexColor(value),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: value == _selected
                              ? Colors.black
                              : Colors.black12,
                          width: value == _selected ? 3 : 1,
                        ),
                      ),
                      child: value == _selected
                          ? Icon(
                              Icons.check,
                              color: _contrast(websiteHexColor(value)),
                            )
                          : null,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Color personalizado (avanzado)'),
              children: [
                TextField(
                  controller: _custom,
                  decoration: const InputDecoration(
                    labelText: 'Código hexadecimal',
                    hintText: '#A63D40',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
                      setState(() => _selected = value.toUpperCase());
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _selected),
        child: const Text('Usar color'),
      ),
    ],
  );
}

class _EditorUnavailable extends StatelessWidget {
  const _EditorUnavailable();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.desktop_windows_outlined, size: 64),
            SizedBox(height: 16),
            Text(
              'El constructor visual está disponible en navegador de escritorio.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

const _componentTypes = [
  'hero',
  'text',
  'image',
  'button',
  'card',
  'carousel',
  'gallery',
  'video',
  'accordion',
  'stats',
  'contactForm',
  'contactInfo',
  'navigation',
  'siteIdentity',
  'socialLinks',
  'divider',
  'spacer',
];

bool _usesItems(String type) =>
    {'carousel', 'gallery', 'accordion', 'stats'}.contains(type);
String _itemsLabel(String type) => switch (type) {
  'carousel' => 'Diapositivas',
  'gallery' => 'Imágenes',
  'accordion' => 'Preguntas y respuestas',
  'stats' => 'Cifras',
  _ => 'Elementos',
};
String _componentLabel(String type) => switch (type) {
  'hero' => 'Portada destacada',
  'text' => 'Texto',
  'image' => 'Imagen',
  'button' => 'Botón',
  'card' => 'Tarjeta',
  'carousel' => 'Carrusel',
  'gallery' => 'Galería',
  'video' => 'Video',
  'accordion' => 'Preguntas desplegables',
  'stats' => 'Cifras destacadas',
  'contactForm' => 'Formulario de contacto',
  'contactInfo' => 'Datos de contacto',
  'navigation' => 'Menú de navegación',
  'siteIdentity' => 'Logo e identidad',
  'socialLinks' => 'Redes sociales',
  'divider' => 'Separador',
  'spacer' => 'Espacio',
  _ => 'Componente',
};
IconData _componentIcon(String type) => switch (type) {
  'hero' => Icons.view_carousel_outlined,
  'text' => Icons.text_fields,
  'image' => Icons.image_outlined,
  'button' => Icons.smart_button_outlined,
  'card' => Icons.crop_portrait,
  'carousel' => Icons.collections_outlined,
  'gallery' => Icons.grid_view,
  'video' => Icons.ondemand_video_outlined,
  'accordion' => Icons.expand_circle_down_outlined,
  'stats' => Icons.query_stats,
  'contactForm' => Icons.contact_mail_outlined,
  'contactInfo' => Icons.location_on_outlined,
  'navigation' => Icons.menu,
  'siteIdentity' => Icons.branding_watermark_outlined,
  'socialLinks' => Icons.share_outlined,
  'divider' => Icons.horizontal_rule,
  'spacer' => Icons.height,
  _ => Icons.widgets_outlined,
};

String _socialLabel(String platform) => switch (platform.toLowerCase()) {
  'facebook' => 'Facebook',
  'instagram' => 'Instagram',
  'youtube' => 'YouTube',
  'tiktok' => 'TikTok',
  'linkedin' => 'LinkedIn',
  _ => platform,
};

Iterable<WebsiteComponent> _allComponents(WebsiteBundle bundle) sync* {
  for (final row in [
    ...bundle.config.header.rows,
    ...bundle.config.footer.rows,
    for (final page in bundle.pages) ...page.rows,
  ]) {
    for (final column in row.columns) {
      yield* column.components;
    }
  }
}

bool _validVideo(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme != 'https') return false;
  final host = uri.host.toLowerCase();
  return host == 'youtube.com' ||
      host.endsWith('.youtube.com') ||
      host == 'youtu.be' ||
      host == 'vimeo.com' ||
      host.endsWith('.vimeo.com');
}

String _slug(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[áàäâ]'), 'a')
    .replaceAll(RegExp(r'[éèëê]'), 'e')
    .replaceAll(RegExp(r'[íìïî]'), 'i')
    .replaceAll(RegExp(r'[óòöô]'), 'o')
    .replaceAll(RegExp(r'[úùüû]'), 'u')
    .replaceAll('ñ', 'n')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

Color _contrast(Color color) =>
    color.computeLuminance() > .45 ? Colors.black : Colors.white;

const _websitePalette = [
  '#FFFFFF',
  '#F8F5F2',
  '#EFE7E2',
  '#E0D4CE',
  '#C9BAB4',
  '#A8958E',
  '#75625E',
  '#4D3A38',
  '#2B1718',
  '#171112',
  '#FFEBEE',
  '#FFCDD2',
  '#EF9A9A',
  '#E57373',
  '#C95B5E',
  '#A63D40',
  '#8E3033',
  '#732629',
  '#571C1F',
  '#3B1113',
  '#FFF3E0',
  '#FFE0B2',
  '#FFCC80',
  '#FFB74D',
  '#FB8C00',
  '#EF6C00',
  '#E65100',
  '#BF4B00',
  '#8D3600',
  '#5D2400',
  '#FFFDE7',
  '#FFF9C4',
  '#FFF59D',
  '#FFF176',
  '#FDD835',
  '#F9A825',
  '#C99000',
  '#9C6F00',
  '#705000',
  '#493400',
  '#E8F5E9',
  '#C8E6C9',
  '#A5D6A7',
  '#81C784',
  '#4CAF50',
  '#388E3C',
  '#2E7D32',
  '#226425',
  '#174719',
  '#0D2B0F',
  '#E0F2F1',
  '#B2DFDB',
  '#80CBC4',
  '#4DB6AC',
  '#009688',
  '#00897B',
  '#00796B',
  '#00695C',
  '#004D40',
  '#00362D',
  '#E3F2FD',
  '#BBDEFB',
  '#90CAF9',
  '#64B5F6',
  '#42A5F5',
  '#1E88E5',
  '#1565C0',
  '#0D47A1',
  '#093473',
  '#05234E',
  '#EDE7F6',
  '#D1C4E9',
  '#B39DDB',
  '#9575CD',
  '#7E57C2',
  '#5E35B1',
  '#4527A0',
  '#311B92',
  '#24146C',
  '#180D48',
  '#FCE4EC',
  '#F8BBD0',
  '#F48FB1',
  '#F06292',
  '#EC407A',
  '#D81B60',
  '#AD1457',
  '#880E4F',
  '#610A38',
  '#3D0623',
];
