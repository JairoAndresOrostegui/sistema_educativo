import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider_v2.dart';
import '../models/website_content.dart';
import '../services/website_service.dart';

class WebsiteEditorScreen extends StatefulWidget {
  const WebsiteEditorScreen({super.key});

  @override
  State<WebsiteEditorScreen> createState() => _WebsiteEditorScreenState();
}

class _WebsiteEditorScreenState extends State<WebsiteEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = WebsiteService();
  final _schoolName = TextEditingController();
  final _tagline = TextEditingController();
  final _heroTitle = TextEditingController();
  final _heroBody = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _primaryColor = TextEditingController();

  List<WebsiteSection> _sections = [];
  List<WebsiteNavigationItem> _navigation = [];
  String _heroImageUrl = '';
  String _logoUrl = '';
  bool _loading = true;
  bool _saving = false;
  String? _uploadingTarget;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final content = await _service.get();
      _schoolName.text = content.schoolName;
      _tagline.text = content.tagline;
      _heroTitle.text = content.heroTitle;
      _heroBody.text = content.heroBody;
      _phone.text = content.phone;
      _email.text = content.email;
      _address.text = content.address;
      _primaryColor.text = content.primaryColor;
      _heroImageUrl = content.heroImageUrl;
      _logoUrl = content.logoUrl;
      _sections = List.of(content.sections);
      _navigation = List.of(content.navigation);
    } catch (error) {
      if (mounted) {
        _message('No fue posible cargar el sitio: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await _service.save(
        WebsiteContent(
          schoolName: _schoolName.text,
          tagline: _tagline.text,
          heroTitle: _heroTitle.text,
          heroBody: _heroBody.text,
          heroImageUrl: _heroImageUrl,
          logoUrl: _logoUrl,
          phone: _phone.text,
          email: _email.text,
          address: _address.text,
          primaryColor: _primaryColor.text,
          navigation: _navigation,
          sections: _sections,
        ),
      );
      if (mounted) _message('El sitio web quedó actualizado.');
    } catch (error) {
      if (mounted) _message('No fue posible guardar: $error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage(String target, {int? sectionIndex}) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final lower = picked.name.toLowerCase();
    if (!lower.endsWith('.jpg') &&
        !lower.endsWith('.jpeg') &&
        !lower.endsWith('.png')) {
      _message('Solo se permiten imágenes JPG o PNG.', error: true);
      return;
    }
    setState(() => _uploadingTarget = target);
    try {
      final url = await _service.uploadImage(
        bytes: await picked.readAsBytes(),
        fileName: picked.name,
      );
      if (!mounted) return;
      setState(() {
        if (target == 'hero') {
          _heroImageUrl = url;
        } else if (target == 'logo') {
          _logoUrl = url;
        } else if (sectionIndex != null && sectionIndex < _sections.length) {
          _sections[sectionIndex] = _sections[sectionIndex].copyWith(
            imageUrl: url,
          );
        }
      });
    } catch (error) {
      if (mounted) {
        _message('No fue posible subir la imagen: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _uploadingTarget = null);
    }
  }

  void _addSection() {
    setState(() {
      _sections.add(
        WebsiteSection(
          id: 'section_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Nueva sección',
          body: 'Escribe aquí el contenido de esta sección.',
          pageId: _navigation.isEmpty ? 'about' : _navigation.first.id,
        ),
      );
    });
  }

  void _move(int index, int delta) {
    final destination = index + delta;
    if (destination < 0 || destination >= _sections.length) return;
    setState(() {
      final item = _sections.removeAt(index);
      _sections.insert(destination, item);
    });
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _schoolName,
      _tagline,
      _heroTitle,
      _heroBody,
      _phone,
      _email,
      _address,
      _primaryColor,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProviderV2>().user;
    final permissions =
        user?.permissions
            .map((permission) => permission.trim().toLowerCase())
            .toSet() ??
        const <String>{};
    final canEdit =
        (user?.isSuperadmin ?? false) ||
        permissions.contains('sitio_web.editar');
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          canEdit ? 'Editor del sitio web' : 'Sitio web (solo lectura)',
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Ver sitio'),
          ),
          const SizedBox(width: 8),
          if (canEdit)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton.icon(
                onPressed: _saving || _uploadingTarget != null ? null : _save,
                icon:
                    _saving
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.publish),
                label: Text(_saving ? 'Publicando...' : 'Publicar cambios'),
              ),
            ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : AbsorbPointer(
                absorbing: !canEdit,
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1050),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _panel(
                                title: 'Identidad y encabezado',
                                icon: Icons.school_outlined,
                                child: Column(
                                  children: [
                                    _requiredField(
                                      _schoolName,
                                      'Nombre del colegio',
                                    ),
                                    _requiredField(
                                      _tagline,
                                      'Frase institucional',
                                    ),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _requiredField(
                                            _primaryColor,
                                            'Color principal (ej. #B71C1C)',
                                            validator: _colorValidator,
                                          ),
                                        ),
                                        const SizedBox(width: 18),
                                        Expanded(
                                          child: _ImageControl(
                                            label: 'Logo',
                                            url: _logoUrl,
                                            loading: _uploadingTarget == 'logo',
                                            onPick: () => _pickImage('logo'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              _panel(
                                title: 'Portada principal',
                                icon: Icons.web_asset_outlined,
                                child: Column(
                                  children: [
                                    _requiredField(
                                      _heroTitle,
                                      'Título principal',
                                    ),
                                    _requiredField(
                                      _heroBody,
                                      'Texto de presentación',
                                      lines: 4,
                                    ),
                                    _ImageControl(
                                      label: 'Imagen de portada',
                                      url: _heroImageUrl,
                                      loading: _uploadingTarget == 'hero',
                                      onPick: () => _pickImage('hero'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              _panel(
                                title: 'Navegación principal',
                                icon: Icons.menu_open,
                                child: Column(
                                  children: [
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Configura los nombres y la visibilidad del menú. El orden corresponde al diseño aprobado de Wix.',
                                        style: TextStyle(color: Colors.black54),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    for (
                                      var index = 0;
                                      index < _navigation.length;
                                      index++
                                    )
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 15,
                                              child: Text('${index + 1}'),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: TextFormField(
                                                initialValue:
                                                    _navigation[index].label,
                                                decoration: InputDecoration(
                                                  labelText:
                                                      'Etiqueta (${_navigation[index].id})',
                                                  border:
                                                      const OutlineInputBorder(),
                                                ),
                                                validator: _requiredValidator,
                                                onChanged: (value) {
                                                  _navigation[index] =
                                                      _navigation[index]
                                                          .copyWith(
                                                            label: value,
                                                          );
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Switch(
                                              value: _navigation[index].enabled,
                                              onChanged:
                                                  (value) => setState(() {
                                                    _navigation[index] =
                                                        _navigation[index]
                                                            .copyWith(
                                                              enabled: value,
                                                            );
                                                  }),
                                            ),
                                            const Text('Visible'),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              _panel(
                                title: 'Secciones del sitio',
                                icon: Icons.view_agenda_outlined,
                                trailing: FilledButton.icon(
                                  onPressed: _addSection,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Agregar sección'),
                                ),
                                child: Column(
                                  children: [
                                    if (_sections.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.all(24),
                                        child: Text(
                                          'Aún no hay secciones publicadas.',
                                        ),
                                      ),
                                    for (
                                      var index = 0;
                                      index < _sections.length;
                                      index++
                                    )
                                      _sectionEditor(index),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              _panel(
                                title: 'Contacto',
                                icon: Icons.contact_mail_outlined,
                                child: Column(
                                  children: [
                                    _optionalField(_address, 'Dirección'),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _optionalField(
                                            _phone,
                                            'Teléfono',
                                          ),
                                        ),
                                        const SizedBox(width: 18),
                                        Expanded(
                                          child: _optionalField(
                                            _email,
                                            'Correo electrónico',
                                            keyboardType:
                                                TextInputType.emailAddress,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 36),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _sectionEditor(int index) {
    final section = _sections[index];
    final uploadTarget = 'section_${section.id}';
    return Card(
      key: ValueKey(section.id),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.drag_indicator, color: Colors.black45),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sección ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Switch(
                  value: section.enabled,
                  onChanged:
                      (value) => setState(() {
                        _sections[index] = section.copyWith(enabled: value);
                      }),
                ),
                const Text('Visible'),
                IconButton(
                  tooltip: 'Subir',
                  onPressed: index == 0 ? null : () => _move(index, -1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'Bajar',
                  onPressed:
                      index == _sections.length - 1
                          ? null
                          : () => _move(index, 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  color: Colors.red,
                  onPressed: () => setState(() => _sections.removeAt(index)),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue:
                  _navigation.any((item) => item.id == section.pageId)
                      ? section.pageId
                      : (_navigation.isEmpty ? null : _navigation.first.id),
              decoration: const InputDecoration(
                labelText: 'Página del menú',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final item in _navigation)
                  DropdownMenuItem(value: item.id, child: Text(item.label)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _sections[index] = _sections[index].copyWith(pageId: value);
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: section.title,
              decoration: const InputDecoration(labelText: 'Título'),
              validator: _requiredValidator,
              onChanged:
                  (value) =>
                      _sections[index] = _sections[index].copyWith(
                        title: value,
                      ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: section.body,
              minLines: 3,
              maxLines: 7,
              decoration: const InputDecoration(labelText: 'Contenido'),
              validator: _requiredValidator,
              onChanged:
                  (value) =>
                      _sections[index] = _sections[index].copyWith(body: value),
            ),
            const SizedBox(height: 16),
            _ImageControl(
              label: 'Imagen de la sección',
              url: section.imageUrl,
              loading: _uploadingTarget == uploadTarget,
              onPick: () => _pickImage(uploadTarget, sectionIndex: index),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _sectionDropdown(
                  label: 'Alineación del texto',
                  value: section.textAlignment,
                  options: const {
                    'left': 'Izquierda',
                    'center': 'Centro',
                    'right': 'Derecha',
                  },
                  onChanged:
                      (value) => setState(() {
                        _sections[index] = _sections[index].copyWith(
                          textAlignment: value,
                        );
                      }),
                ),
                _sectionDropdown(
                  label: 'Posición de la imagen',
                  value: section.imagePosition,
                  options: const {
                    'left': 'Izquierda',
                    'right': 'Derecha',
                    'top': 'Arriba',
                    'background': 'Fondo completo',
                  },
                  onChanged:
                      (value) => setState(() {
                        _sections[index] = _sections[index].copyWith(
                          imagePosition: value,
                        );
                      }),
                ),
                _sectionDropdown(
                  label: 'Ajuste de imagen',
                  value: section.imageFit,
                  options: const {'cover': 'Cubrir', 'contain': 'Contener'},
                  onChanged:
                      (value) => setState(() {
                        _sections[index] = _sections[index].copyWith(
                          imageFit: value,
                        );
                      }),
                ),
                _sectionDropdown(
                  label: 'Ancho del contenido',
                  value: section.contentWidth,
                  options: const {
                    'wide': 'Amplio',
                    'normal': 'Normal',
                    'narrow': 'Estrecho',
                  },
                  onChanged:
                      (value) => setState(() {
                        _sections[index] = _sections[index].copyWith(
                          contentWidth: value,
                        );
                      }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: section.backgroundColor,
                    decoration: const InputDecoration(
                      labelText: 'Color de fondo (#RRGGBB)',
                      border: OutlineInputBorder(),
                    ),
                    validator: _colorValidator,
                    onChanged:
                        (value) =>
                            _sections[index] = _sections[index].copyWith(
                              backgroundColor: value,
                            ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    initialValue: section.textColor,
                    decoration: const InputDecoration(
                      labelText: 'Color del texto (#RRGGBB)',
                      border: OutlineInputBorder(),
                    ),
                    validator: _colorValidator,
                    onChanged:
                        (value) =>
                            _sections[index] = _sections[index].copyWith(
                              textColor: value,
                            ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: section.buttonLabel,
                    decoration: const InputDecoration(
                      labelText: 'Texto del botón (opcional)',
                    ),
                    onChanged:
                        (value) =>
                            _sections[index] = _sections[index].copyWith(
                              buttonLabel: value,
                            ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: TextFormField(
                    initialValue: section.buttonUrl,
                    decoration: const InputDecoration(
                      labelText: 'URL del botón (https://...)',
                    ),
                    onChanged:
                        (value) =>
                            _sections[index] = _sections[index].copyWith(
                              buttonUrl: value,
                            ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionDropdown({
    required String label,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) => SizedBox(
    width: 225,
    child: DropdownButtonFormField<String>(
      initialValue: options.containsKey(value) ? value : options.keys.first,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final entry in options.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: (newValue) {
        if (newValue != null) onChanged(newValue);
      },
    ),
  );

  Widget _panel({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) => Card(
    elevation: 1,
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.red.shade700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const Divider(height: 28),
          child,
        ],
      ),
    ),
  );

  Widget _requiredField(
    TextEditingController controller,
    String label, {
    int lines = 1,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 2,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: validator ?? _requiredValidator,
    ),
  );

  Widget _optionalField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  String? _requiredValidator(String? value) =>
      value == null || value.trim().isEmpty
          ? 'Este campo es obligatorio.'
          : null;

  String? _colorValidator(String? value) {
    if (value == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value.trim())) {
      return 'Usa un color hexadecimal, por ejemplo #B71C1C.';
    }
    return null;
  }
}

class _ImageControl extends StatelessWidget {
  final String label;
  final String url;
  final bool loading;
  final VoidCallback onPick;

  const _ImageControl({
    required this.label,
    required this.url,
    required this.loading,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.black26),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Container(
          width: 72,
          height: 58,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
          child:
              url.startsWith('asset:')
                  ? Image.asset(url.substring(6), fit: BoxFit.cover)
                  : url.startsWith('https://')
                  ? Image.network(url, fit: BoxFit.cover)
                  : const Icon(Icons.image_outlined),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        OutlinedButton.icon(
          onPressed: loading ? null : onPick,
          icon:
              loading
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.upload),
          label: Text(loading ? 'Subiendo...' : 'Cambiar'),
        ),
      ],
    ),
  );
}
