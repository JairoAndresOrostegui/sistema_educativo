class UsuarioModel {
  final String id;
  final String nombres;
  final String apellidos;
  final String documento;
  final String tipoDocumento;
  final String correoPersonal;
  final String correoInstitucional;
  final String? fotoUrl;
  final String? fechaNacimiento;
  final String? lugarNacimientoPais;
  final String? lugarNacimientoDepartamento;
  final String? lugarNacimientoMunicipio;
  final String? direccionResidencia;
  final String? lugarResidenciaPais;
  final String? lugarResidenciaDepartamento;
  final String? lugarResidenciaMunicipio;
  final String rol;
  final String? grado;
  final String institucion;
  final String sede;
  final bool esSuperadmin;
  final String estado;
  final List<String> telefonos;
  final List<String> funcionalidades;
  final List<String>? fcmTokens;

  UsuarioModel({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.documento,
    required this.tipoDocumento,
    required this.rol,
    required this.estado,
    required this.correoPersonal,
    required this.correoInstitucional,
    this.fotoUrl,
    this.fechaNacimiento,
    this.lugarNacimientoPais,
    this.lugarNacimientoDepartamento,
    this.lugarNacimientoMunicipio,
    this.direccionResidencia,
    this.lugarResidenciaPais,
    this.lugarResidenciaDepartamento,
    this.lugarResidenciaMunicipio,
    this.grado,
    required this.esSuperadmin,
    required this.institucion,
    required this.sede,
    required this.telefonos,
    required this.funcionalidades,
    this.fcmTokens,
  });

  factory UsuarioModel.fromFirestore(Map<String, dynamic> map, String id) {
    return UsuarioModel(
      id: id,
      nombres: map['nombres'] ?? '',
      apellidos: map['apellidos'] ?? '',
      documento: map['documento'] ?? '',
      tipoDocumento: map['tipoDocumento'] ?? '',
      rol: map['rol'] ?? '',
      estado: map['estado'] ?? 'activo',
      correoPersonal: map['correoPersonal'],
      correoInstitucional: map['correoInstitucional'],
      fotoUrl: map['fotoUrl'],
      fechaNacimiento: map['fechaNacimiento'],
      lugarNacimientoPais: map['lugarNacimientoPais'],
      lugarNacimientoDepartamento: map['lugarNacimientoDepartamento'],
      lugarNacimientoMunicipio: map['lugarNacimientoMunicipio'],
      direccionResidencia: map['direccionResidencia'],
      lugarResidenciaPais: map['lugarResidenciaPais'],
      lugarResidenciaDepartamento: map['lugarResidenciaDepartamento'],
      lugarResidenciaMunicipio: map['lugarResidenciaMunicipio'],
      grado: map['grado'],
      institucion: map['institucion'],
      sede: map['sede'],
      esSuperadmin: map['esSuperadmin'] ?? false,
      telefonos: List<String>.from(map['telefonos']),
      funcionalidades: List<String>.from(map['funcionalidades']),
      fcmTokens: List<String>.from(map['fcmTokens'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombres': nombres,
      'apellidos': apellidos,
      'documento': documento,
      'tipoDocumento': tipoDocumento,
      'correoPersonal': correoPersonal,
      'correoInstitucional': correoInstitucional,
      'fotoUrl': fotoUrl,
      'fechaNacimiento': fechaNacimiento,
      'lugarNacimientoPais': lugarNacimientoPais,
      'lugarNacimientoDepartamento': lugarNacimientoDepartamento,
      'lugarNacimientoMunicipio': lugarNacimientoMunicipio,
      'direccionResidencia': direccionResidencia,
      'lugarResidenciaPais': lugarResidenciaPais,
      'lugarResidenciaDepartamento': lugarResidenciaDepartamento,
      'lugarResidenciaMunicipio': lugarResidenciaMunicipio,
      'rol': rol,
      'grado': grado,
      'institucion': institucion,
      'sede': sede,
      'estado': estado,
      'esSuperadmin': esSuperadmin,
      'telefonos': telefonos,
      'funcionalidades': funcionalidades,
      'fcmTokens': fcmTokens,
    };
  }
}
