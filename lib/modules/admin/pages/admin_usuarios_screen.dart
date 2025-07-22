import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AdminUsuariosScreen extends StatefulWidget {
  const AdminUsuariosScreen({super.key});

  @override
  State<AdminUsuariosScreen> createState() => _AdminUsuariosScreenState();
}

class _AdminUsuariosScreenState extends State<AdminUsuariosScreen> {
  List<DocumentSnapshot> usuarios = [];
  bool isLoading = true;
  final currentUid = FirebaseAuth.instance.currentUser!.uid;

  final TextEditingController _busquedaController = TextEditingController();
  String _textoBusqueda = '';

  final List<String> roles = ['admin', 'docente', 'estudiante'];
  final List<String> tipoDocumentoOpciones = [
    'Registro Civil',
    'Tarjeta de Identidad',
    'Cédula',
    'Pasaporte',
  ];
  final List<String> gradosColombia = [
    'No aplica',
    'Prejardín',
    'Jardín',
    'Transición',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
  ];
  final List<String> funcionalidadesDisponibles = ['usuarios', 'rutas'];
  final List<String> permisos = ['ver', 'crear', 'editar', 'eliminar'];

  bool esSuperadminActual = false;
  Map<String, List<String>> permisosUsuarioActual = {};

  @override
  void initState() {
    super.initState();
    _verificarSuperadmin();
    _cargarUsuarios();
    _busquedaController.addListener(() {
      setState(() {
        _textoBusqueda = _busquedaController.text.toLowerCase();
      });
    });
  }

  Future<void> _verificarSuperadmin() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(currentUid)
            .get();
    final data = doc.data();
    if (data != null) {
      esSuperadminActual = data['esSuperadmin'] == true;
      final funcionalidades = Map<String, dynamic>.from(
        data['funcionalidades'] ?? {},
      );
      permisosUsuarioActual = funcionalidades.map(
        (k, v) => MapEntry(k, List<String>.from(v)),
      );
    }
  }

  bool _correoValido(String correo) {
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(correo);
  }

  void _mostrarAlertaValidacion(String mensaje) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Campos incompletos'),
            content: Text(mensaje),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
    );
  }

  Future<void> _cargarUsuarios() async {
    final query = await FirebaseFirestore.instance.collection('usuarios').get();
    setState(() {
      usuarios = query.docs;
      isLoading = false;
    });
  }

  Future<String?> _subirFoto(XFile file, String userId) async {
    final ref = FirebaseStorage.instance.ref().child(
      'fotos_perfil/$userId.jpg',
    );
    UploadTask uploadTask = ref.putData(await file.readAsBytes());
    final snapshot = await uploadTask.whenComplete(() {});
    return await snapshot.ref.getDownloadURL();
  }

  void _mostrarFormulario({DocumentSnapshot? usuario}) {
    final data = usuario?.data() as Map<String, dynamic>? ?? {};

    final nombres = TextEditingController(text: data['nombres'] ?? '');
    final apellidos = TextEditingController(text: data['apellidos'] ?? '');
    final correo = TextEditingController(text: data['correo'] ?? '');
    final correoInstitucional = TextEditingController(
      text: data['correoInstitucional'] ?? '',
    );
    final documento = TextEditingController(text: data['documento'] ?? '');
    String tipoDocumento = data['tipoDocumento'] ?? tipoDocumentoOpciones.first;
    final direccion = TextEditingController(text: data['direccion'] ?? '');
    final telefono1 = TextEditingController(text: data['telefono1'] ?? '');
    final telefono2 = TextEditingController(text: data['telefono2'] ?? '');
    final fechaNacimiento = TextEditingController(
      text: data['fechaNacimiento'] ?? '',
    );
    String rol = data['rol'] ?? 'docente';
    String grado = data['grado'] ?? gradosColombia.first;
    String? fotoUrl = data['fotoUrl'];

    Map<String, List<String>> funcionalidades = {};
    if (data['funcionalidades'] != null) {
      final rawMap = Map<String, dynamic>.from(data['funcionalidades']);
      for (var key in rawMap.keys) {
        funcionalidades[key] = List<String>.from(rawMap[key]);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
              title: Center(
                child: Text(
                  usuario == null ? 'Crear usuario' : 'Editar usuario',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
              content: Container(
                width:
                    MediaQuery.of(context).size.width < 600
                        ? MediaQuery.of(context).size.width *
                            0.95 // casi toda la pantalla en móvil
                        : MediaQuery.of(context).size.width *
                            0.5, // mitad en web
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height *
                      0.9, // evita desbordes en altura
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 45,
                              backgroundImage:
                                  (fotoUrl ?? '').isNotEmpty
                                      ? NetworkImage(fotoUrl!)
                                      : null,
                              child:
                                  fotoUrl == null
                                      ? const Icon(Icons.person, size: 45)
                                      : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () async {
                                  final picker = ImagePicker();
                                  final picked = await picker.pickImage(
                                    source: ImageSource.gallery,
                                  );
                                  if (picked != null) {
                                    final id =
                                        usuario?.id ??
                                        FirebaseAuth
                                            .instance
                                            .currentUser
                                            ?.uid ??
                                        '';
                                    final url = await _subirFoto(picked, id);
                                    if (url != null) {
                                      setModalState(() => fotoUrl = url);
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStyledField(nombres, 'Nombres'),
                      _buildStyledField(apellidos, 'Apellidos'),
                      _buildStyledField(correo, 'Correo personal'),
                      _buildStyledField(
                        correoInstitucional,
                        'Correo institucional (opcional)',
                      ),
                      _buildStyledField(documento, 'Documento'),
                      _buildDropdown(
                        tipoDocumento,
                        tipoDocumentoOpciones,
                        (value) => setModalState(() => tipoDocumento = value!),
                        'Tipo de documento',
                      ),
                      _buildStyledField(direccion, 'Dirección'),
                      _buildStyledField(telefono1, 'Teléfono 1'),
                      _buildStyledField(telefono2, 'Teléfono 2 (opcional)'),
                      TextField(
                        controller: fechaNacimiento,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Fecha de nacimiento',
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setModalState(
                              () =>
                                  fechaNacimiento.text = DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(picked),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDropdown(
                        rol,
                        roles,
                        (value) => setModalState(() => rol = value!),
                        'Rol',
                      ),
                      const SizedBox(height: 12),
                      _buildDropdown(
                        grado,
                        gradosColombia,
                        (value) => setModalState(() => grado = value!),
                        'Grado',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Funcionalidades y permisos',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...funcionalidadesDisponibles.map((func) {
                        funcionalidades.putIfAbsent(func, () => []);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              func,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Wrap(
                              spacing: 6,
                              children:
                                  permisos.map((perm) {
                                    final activo = funcionalidades[func]!
                                        .contains(perm);
                                    return FilterChip(
                                      label: Text(perm),
                                      selected: activo,
                                      onSelected: (sel) {
                                        setModalState(() {
                                          if (sel) {
                                            funcionalidades[func]!.add(perm);
                                          } else {
                                            funcionalidades[func]!.remove(perm);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                if (usuario != null)
                  TextButton(
                    onPressed: () async {
                      final confirmar = await showDialog<bool>(
                        context: context,
                        builder:
                            (ctx) => AlertDialog(
                              title: const Text('¿Restablecer contraseña?'),
                              content: Text(
                                '¿Enviar un correo de recuperación a "${correo.text}"?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    try {
                                      await FirebaseAuth.instance
                                          .sendPasswordResetEmail(
                                            email: correo.text.trim(),
                                          );
                                      if (context.mounted) {
                                        Navigator.pop(
                                          ctx,
                                          true,
                                        ); // cerrar el diálogo al enviar
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Correo de restablecimiento enviado correctamente',
                                            ),
                                          ),
                                        );
                                      }
                                    } on FirebaseAuthException catch (e) {
                                      if (context.mounted) {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error: ${e.message ?? 'No se pudo enviar el correo'}',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text('Enviar'),
                                ),
                              ],
                            ),
                      );

                      if (confirmar == true) {
                        try {
                          await FirebaseAuth.instance.sendPasswordResetEmail(
                            email: correo.text.trim(),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Correo de restablecimiento enviado',
                                ),
                              ),
                            );
                          }
                        } on FirebaseAuthException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Error: ${e.message ?? 'No se pudo enviar el correo'}',
                                ),
                              ),
                            );
                          }
                        }
                      }
                    },
                    child: const Text('Restablecer contraseña'),
                  ),
                ElevatedButton(
                  onPressed: () async {
                    if (nombres.text.isEmpty ||
                        apellidos.text.isEmpty ||
                        correo.text.isEmpty ||
                        documento.text.length < 6 ||
                        direccion.text.isEmpty ||
                        telefono1.text.isEmpty ||
                        fechaNacimiento.text.isEmpty ||
                        !_correoValido(correo.text.trim()) ||
                        (correoInstitucional.text.isNotEmpty &&
                            !_correoValido(correoInstitucional.text.trim()))) {
                      _mostrarAlertaValidacion(
                        'Por favor completa todos los campos obligatorios correctamente.',
                      );
                      return;
                    }
                    final nuevoDoc = {
                      'nombres': nombres.text,
                      'apellidos': apellidos.text,
                      'correo': correo.text,
                      'correoInstitucional': correoInstitucional.text,
                      'documento': documento.text,
                      'tipoDocumento': tipoDocumento,
                      'direccion': direccion.text,
                      'telefono1': telefono1.text,
                      'telefono2': telefono2.text,
                      'fechaNacimiento': fechaNacimiento.text,
                      'rol': rol,
                      'grado': grado,
                      'activo': true,
                      'funcionalidades': funcionalidades,
                      'esSuperadmin': false,
                      'fotoUrl': fotoUrl,
                    };

                    final ref = FirebaseFirestore.instance.collection(
                      'usuarios',
                    );

                    if (usuario == null) {
                      try {
                        final callable = FirebaseFunctions.instance
                            .httpsCallable('crearUsuarioDesdeAdmin');
                        final resultado = await callable.call({
                          'email': correo.text.trim(),
                          'password': documento.text.trim(),
                          'nombres': nombres.text,
                          'apellidos': apellidos.text,
                          'rol': rol,
                          'documento': documento.text,
                        });

                        final uid = resultado.data['uid'];
                        await ref.doc(uid).set(nuevoDoc);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al crear el usuario: $e'),
                          ),
                        );
                        return; // importante para que no continúe si hay error
                      }
                    } else {
                      await ref.doc(usuario.id).update(nuevoDoc);
                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser != null &&
                          currentUser.email == correo.text.trim()) {
                        await currentUser.verifyBeforeUpdateEmail(
                          correo.text.trim(),
                        );
                      }
                    }

                    if (context.mounted) {
                      Navigator.pop(ctx);
                      _cargarUsuarios();
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStyledField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String value,
    List<String> opciones,
    Function(String?) onChanged,
    String label,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        value: value,
        items:
            opciones
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Future<void> _eliminarUsuario(String id, bool esSuperadmin) async {
    if (esSuperadmin || id == currentUid) return;
    if (!esSuperadminActual &&
        !(permisosUsuarioActual['usuarios']?.contains('eliminar') ?? false))
      return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: const Text(
              '¿Seguro que deseas eliminar este usuario? También se eliminará de Firebase Auth.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (confirmar == true) {
      try {
        // 1. Eliminar de Firestore
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(id)
            .delete();

        // 2. Eliminar de Firebase Auth mediante Cloud Function
        final callable = FirebaseFunctions.instance.httpsCallable(
          'eliminarUsuarioAuth',
        );
        await callable.call({'uid': id});

        _cargarUsuarios(); // recargar lista
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar usuario: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Gestión de Usuarios"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        elevation: 1,
        leading: const BackButton(color: Colors.black),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormulario(),
        child: const Icon(Icons.add),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      controller: _busquedaController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar usuario...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: usuarios.length,
                      itemBuilder: (context, index) {
                        final user = usuarios[index];
                        final data = user.data() as Map<String, dynamic>;
                        final fullName =
                            '${data['nombres']} ${data['apellidos']}'
                                .toLowerCase();
                        final correo = data['correo']?.toLowerCase() ?? '';

                        if (_textoBusqueda.isNotEmpty &&
                            !fullName.contains(_textoBusqueda) &&
                            !correo.contains(_textoBusqueda)) {
                          return const SizedBox.shrink();
                        }

                        final esSuperadmin =
                            data.containsKey('esSuperadmin') &&
                            data['esSuperadmin'] == true;
                        final puedeEliminar =
                            (esSuperadminActual ||
                                (permisosUsuarioActual['usuarios']?.contains(
                                      'eliminar',
                                    ) ??
                                    false)) &&
                            user.id != currentUid;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          color: const Color(0xFFF5F5F5),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading:
                                data['fotoUrl'] != null
                                    ? CircleAvatar(
                                      backgroundImage: NetworkImage(
                                        data['fotoUrl'],
                                      ),
                                    )
                                    : const Icon(Icons.person),
                            title: Text(
                              '${data['nombres']} ${data['apellidos']}',
                            ),
                            subtitle: Text(data['correo'] ?? ''),
                            trailing:
                                isMobile
                                    ? null
                                    : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed:
                                              () => _mostrarFormulario(
                                                usuario: user,
                                              ),
                                        ),
                                        if (puedeEliminar)
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            onPressed:
                                                () => _eliminarUsuario(
                                                  user.id,
                                                  esSuperadmin,
                                                ),
                                          ),
                                      ],
                                    ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
