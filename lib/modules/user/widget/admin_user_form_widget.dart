import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sistema_educativo/models/user/user_model.dart';
import '../../auth/providers/user_provider.dart';
import '../../../services/auth/auth_service.dart';
import 'admin_user_form_body.dart';
import 'package:provider/provider.dart';
import '../../../services/profile/profile_service.dart';

class AdminUserFormWidget extends StatefulWidget {
  final UsuarioModel? usuario;
  final bool soloLectura;
  final void Function() onSuccess;

  const AdminUserFormWidget({
    super.key,
    this.usuario,
    this.soloLectura = false,
    required this.onSuccess,
  });

  @override
  State<AdminUserFormWidget> createState() => _AdminUserFormWidgetState();
}

class _AdminUserFormWidgetState extends State<AdminUserFormWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nombres;
  late TextEditingController apellidos;
  late TextEditingController correo;
  late TextEditingController correoInstitucional;
  late TextEditingController documento;
  late TextEditingController direccion;
  late TextEditingController telefonos;
  late TextEditingController fechaNacimiento;

  String rol = 'docente';
  String grado = 'Preescolar';
  String institucion = '';
  String sede = '';
  String? fotoUrl;
  List<String> funcionalidades = [];
  final todasFuncionalidades = [
    'documentos.ver',
    'documentos.crear',
    'documentos.editar',
    'documentos.eliminar',
    'historial_rutas.ver',
    'historial_rutas.crear',
    'historial_rutas.editar',
    'historial_rutas.eliminar',
    'horarios.ver',
    'horarios.crear',
    'horarios.editar',
    'horarios.eliminar',
    'rutas.ver',
    'rutas.crear',
    'rutas.editar',
    'rutas.eliminar',
    'usuarios.ver',
    'usuarios.crear',
    'usuarios.editar',
    'usuarios.eliminar',
  ];

  bool esSuperadminActual = false;
  Map<String, String?> errores = {};

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;

    nombres = TextEditingController(text: u?.nombres ?? '');
    apellidos = TextEditingController(text: u?.apellidos ?? '');
    correo = TextEditingController(text: u?.correoPersonal ?? '');
    correoInstitucional = TextEditingController(
      text: u?.correoInstitucional ?? '',
    );
    documento = TextEditingController(text: u?.documento ?? '');
    direccion = TextEditingController(text: u?.direccionResidencia ?? '');
    telefonos = TextEditingController(text: u?.telefonos.join(', ') ?? '');
    fechaNacimiento = TextEditingController(text: u?.fechaNacimiento ?? '');
    rol = u?.rol ?? 'docente';
    grado = u?.grado ?? 'Preescolar';
    institucion = u?.institucion ?? '';
    sede = u?.sede ?? '';
    fotoUrl = u?.fotoUrl;
    funcionalidades = List<String>.from(u?.funcionalidades ?? []);
    esSuperadminActual = u?.esSuperadmin ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final usuarioLogueado = context.read<UsuarioProvider>().usuario!;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:
              isMobile
                  ? double.infinity
                  : MediaQuery.of(context).size.width * 0.5,
        ),

        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdminUserFormBody(
                  usuario: widget.usuario,
                  soloLectura: widget.soloLectura,
                  esSuperadminActual: esSuperadminActual,
                  fotoUrl: fotoUrl,
                  nombres: nombres,
                  apellidos: apellidos,
                  correo: correo,
                  correoInstitucional: correoInstitucional,
                  documento: documento,
                  direccion: direccion,
                  telefonos: telefonos,
                  fechaNacimiento: fechaNacimiento,
                  rol: rol,
                  grado: grado,
                  institucion:
                      widget.usuario?.institucion ??
                      usuarioLogueado.institucion,
                  sede: widget.usuario?.sede ?? usuarioLogueado.sede,
                  funcionalidades: funcionalidades,
                  todasFuncionalidades: todasFuncionalidades,
                  setRol: (val) => setState(() => rol = val ?? rol),
                  setGrado: (val) => setState(() => grado = val ?? grado),
                  setInstitucion: (val) => setState(() => institucion = val),
                  setSede: (val) => setState(() => sede = val),
                  onFuncionalidadChanged: (funcionalidadCompleta, isChecked) {
                    setState(() {
                      if (isChecked == true) {
                        if (!funcionalidades.contains(funcionalidadCompleta)) {
                          funcionalidades.add(funcionalidadCompleta);
                        }
                      } else {
                        funcionalidades.remove(funcionalidadCompleta);
                      }
                    });
                  },
                  onPickPhoto: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (picked != null) {
                      final bytes = await picked.readAsBytes();
                      final uid = widget.usuario?.id ?? context.read<UsuarioProvider>().usuario!.id;

                      final nuevaUrl = await ProfileService().subirFotoPerfil(
                        bytes: bytes,
                        uid: uid,
                      );

                      setState(() {
                        fotoUrl = nuevaUrl;
                      });
                    }
                  },
                ),
                if (!widget.soloLectura)
                  Semantics(
                    label: 'Botón para guardar usuario',
                    enabled: true,
                    focusable: true,
                    button: true,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _guardarUsuario,
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nombres.dispose();
    apellidos.dispose();
    correo.dispose();
    correoInstitucional.dispose();
    documento.dispose();
    direccion.dispose();
    telefonos.dispose();
    fechaNacimiento.dispose();
    super.dispose();
  }

  void _guardarUsuario() async {
    errores.clear();

    if (nombres.text.trim().isEmpty) errores['nombres'] = 'Campo obligatorio';
    if (apellidos.text.trim().isEmpty)
      errores['apellidos'] = 'Campo obligatorio';
    if (correo.text.trim().isEmpty) errores['correo'] = 'Campo obligatorio';
    if (documento.text.trim().isEmpty)
      errores['documento'] = 'Campo obligatorio';
    if (correoInstitucional.text.trim().isEmpty)
      errores['correoInstitucional'] = 'Campo obligatorio';
    if (rol.trim().isEmpty) errores['rol'] = 'Campo obligatorio';
    if (grado.trim().isEmpty) errores['grado'] = 'Campo obligatorio';

    if (errores.isNotEmpty) {
      setState(() {}); // Actualizar vista con errores
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa todos los campos obligatorios'),
        ),
      );
      return;
    }

    final userProvider = context.read<UsuarioProvider>();
    final usuarioLogueado = userProvider.usuario!;
    final esNuevo = widget.usuario == null;
    String nuevoUid;

    if (esNuevo) {
      final nuevoUid = await UsuarioService().crearUsuarioDesdeAdmin(
        email: correo.text.trim(),
        password: documento.text.trim(),
        nombres: nombres.text.trim(),
        apellidos: apellidos.text.trim(),
        rol: rol,
        documento: documento.text.trim(),
      );

      final nuevoUsuario = UsuarioModel(
        id: nuevoUid,
        nombres: nombres.text.trim(),
        apellidos: apellidos.text.trim(),
        correoPersonal: correo.text.trim(),
        correoInstitucional: correoInstitucional.text.trim(),
        documento: documento.text.trim(),
        tipoDocumento: 'CC',
        direccionResidencia: direccion.text.trim(),
        telefonos: telefonos.text.split(',').map((e) => e.trim()).toList(),
        fechaNacimiento: fechaNacimiento.text.trim(),
        rol: rol,
        grado: grado,
        institucion:
            esSuperadminActual ? institucion : usuarioLogueado.institucion,
        sede: esSuperadminActual ? sede : usuarioLogueado.sede,
        funcionalidades: funcionalidades,
        esSuperadmin: false,
        fcmTokens: [],
        fotoUrl: fotoUrl ?? '',
        estado: 'activo',
      );

      await UsuarioService().guardarUsuario(nuevoUsuario);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario creado con éxito')),
        );
      }
      widget.onSuccess();
      return;
    } else {
      nuevoUid = widget.usuario!.id;
    }

    final nuevoUsuario = UsuarioModel(
      id: nuevoUid,
      nombres: nombres.text.trim(),
      apellidos: apellidos.text.trim(),
      correoPersonal: correo.text.trim(),
      correoInstitucional: correoInstitucional.text.trim(),
      documento: documento.text.trim(),
      tipoDocumento: 'CC',
      direccionResidencia: direccion.text.trim(),
      telefonos: telefonos.text.split(',').map((e) => e.trim()).toList(),
      fechaNacimiento: fechaNacimiento.text.trim(),
      rol: rol,
      grado: grado,
      institucion:
          esSuperadminActual ? institucion : usuarioLogueado.institucion,
      sede: esSuperadminActual ? sede : usuarioLogueado.sede,
      funcionalidades: funcionalidades,
      esSuperadmin: widget.usuario?.esSuperadmin ?? false,
      fcmTokens: widget.usuario?.fcmTokens ?? [],
      fotoUrl: fotoUrl ?? '',
      estado: widget.usuario?.estado ?? 'activo',
    );

    try {
      await UsuarioService().guardarUsuario(nuevoUsuario);
      await UsuarioService().registrarHistorialUsuario(
        usuario: nuevoUsuario,
        accion: esNuevo ? 'creado' : 'editado',
        realizadoPor: '${usuarioLogueado.nombres} ${usuarioLogueado.apellidos}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario guardado con éxito')),
        );
      }
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    }
  }
}
