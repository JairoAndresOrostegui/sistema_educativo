# Sistema Educativo - Guia de Usuario

Aplicacion para gestion escolar con acceso por roles:
- Administrador
- Docente
- Estudiante
- Familiar

Incluye modulos de matricula, rutas, horarios, documentos, autorizaciones, QR, perfil e historial administrativo.

## 1. Ingreso al sistema

1. Abra la aplicacion (web o app movil).
2. Ingrese sus credenciales segun el rol:
   - Administrador, Docente y Familiar: `correo institucional + contrasena`
   - Estudiante: `documento + contrasena`
3. Si olvido la contrasena, use la opcion `Olvidaste tu contrasena?` solo para cuentas con acceso por correo.
4. Al iniciar sesion, el sistema muestra el panel segun su rol.

Notas importantes:
- Si su cuenta no esta activa o no tiene permisos, no podra entrar a ciertos modulos.
- El menu puede cambiar segun permisos asignados por el administrador.
- En el caso de estudiantes, el sistema autentica internamente con Firebase Auth usando el correo institucional registrado, pero la pantalla de acceso permite entrar con documento.

## 2. Que ve cada rol

### Administrador
Menu posible:
- Perfil
- Gestion de usuarios
- Parametros
- Matriculas
- Gestion de rutas
- Horario escolar
- Documentos
- Historial administrativo
- Autorizaciones
- QR

### Docente
Menu posible:
- Perfil
- Ruta escolar
- Horario escolar
- Documentos
- Autorizaciones

### Estudiante / Familiar
Menu posible:
- Perfil
- Matricula (si esta habilitada y aplica)
- Mis rutas
- Horario escolar
- Documentos
- Autorizaciones
- QR (familiar habilitado)

## 3. Modulos y uso paso a paso

### 3.1 Perfil
Permite ver y actualizar datos basicos y foto de perfil.

Flujo:
1. Entre a `Perfil`.
2. Actualice la imagen o datos permitidos.
3. Guarde cambios.

### 3.2 Matriculas
Hay dos flujos principales:
- Flujo administrativo (aprobacion y gestion)
- Flujo de familia/estudiante (formulario de pre-matricula)

#### Flujo familia/estudiante
1. Abra `Matricula`.
2. Busque o escriba el documento del estudiante.
3. Complete el formulario por secciones.
4. Guarde la informacion.

Tambien existe flujo por enlace publico (`/enrollment_public`) para registro sin inicio de sesion.

Comportamiento:
- Si ya existe matricula activa del ano en curso, el formulario puede bloquearse.
- El sistema puede precargar datos por documento.
- Familiar puede seleccionar hijo cuando tiene varios vinculados.

#### Flujo administrador
1. Abra `Matriculas`.
2. Revise pestanas por estado:
   - Pendientes
   - Pre-matriculado
   - Matriculados
   - Rechazados
   - Retirados
3. Abra cada registro y elija accion:
   - Editar
   - Aprobar (pasa a `matriculado`)
   - Rechazar (solicita motivo)
   - Retirar (para registros ya matriculados)
4. Al aprobar, se puede generar PDF del registro.

Estados de matricula:
- `prematriculado`: registro inicial
- `pendiente_revision`: en validacion administrativa
- `matriculado`: aprobado
- `rechazado`: rechazado por revision
- `desmatriculado`: retirado

### 3.3 Gestion de usuarios (Administrador)
Permite crear, editar, consultar y eliminar usuarios.

Flujo recomendado:
1. Entre a `Gestion de usuarios`.
2. Cree o edite usuario con rol, grado y permisos.
3. Verifique que el estado quede activo.
4. Use eliminar solo cuando aplique (evitar borrar usuarios en uso).

Importacion masiva de docentes:
- Solo disponible para superadmin.
- Se realiza desde el icono de carga dentro de `Gestion de usuarios`.
- Permite importar docentes desde Excel.

Columnas recomendadas para Excel:
- Obligatorias: `nombres`, `apellidos`, `documento`, `correo`, `grado`
- Opcionales: `tipo_documento`, `correo_institucional`, `estado`
- Alternativa de nombre: `nombre_completo`

Notas de importacion:
- Los docentes se crean con rol `Docente`.
- La contrasena inicial queda igual al `documento`.
- Si `correo_institucional` no se envia, se usa el valor de `correo`.
- `tipo_documento` acepta abreviaturas como `CC` o el valor completo configurado en parametros.
- La institucion y la sede se toman del superadmin logueado que ejecuta la importacion.

### 3.4 Parametros (Administrador)
Permite configurar catalogos operativos del sistema.

Ejemplos de parametros:
- Tipos de documento
- Roles
- Permisos
- Variables de matricula (ejemplo: ano activo, habilitacion para familias)

Flujo:
1. Abra `Parametros`.
2. Filtre por clave si necesita.
3. Cree o edite valores.
4. Defina orden y estado activo/inactivo.

Recomendacion:
- Mantenga consistentes los valores de permisos antes de crear usuarios.

### 3.5 Horario escolar
Permite gestionar y consultar materias por grado.

Administrador:
1. Abra `Horario escolar`.
2. Seleccione grado.
3. Cree, edite o elimine materias.

Docente:
- Consulta su horario asignado.

Estudiante/Familiar:
- Consulta el horario del estudiante.
- Familiar puede cambiar estudiante activo cuando corresponde.

### 3.6 Rutas escolares
Permite planear y ejecutar rutas de transporte.

Administrador:
- Crea y administra rutas base.
- Asigna responsables y datos de ruta.

Docente/encargado de ruta:
1. Abra `Ruta escolar`.
2. Seleccione ruta asignada.
3. Inicie ruta del dia.
4. Marque estados de estudiantes (recogido, no recogido, etc.).
5. Envie avisos de llegada y tiempo estimado.
6. Finalice ruta.

Estudiante/Familiar:
- Consulta `Mi ruta de hoy` con estado y seguimiento.

### 3.7 Documentos
Permite publicar y consultar archivos por grado.

Administrador/Docente:
1. Abra `Documentos`.
2. Seleccione grado.
3. Cargue archivo (ejemplo: PDF, Word, Excel).
4. Elimine archivos cuando sea necesario.

Estudiante/Familiar:
1. Abra `Documentos`.
2. Busque por listado.
3. Descargue archivo.

### 3.8 Autorizaciones
Gestiona solicitudes y respuestas de autorizacion de estudiantes.

Flujo general:
1. Crear solicitud (segun rol y permisos).
2. Revisar y responder (aprobar/rechazar).
3. Estado actualizado para todos los actores.

Estados habituales:
- Pendiente
- Aprobada
- Rechazada
- Finalizada

### 3.9 QR
Permite mostrar o administrar codigo QR de usuario.

Administrador:
- Gestiona QR por usuario.

Familiar/estudiante habilitado:
- Visualiza su QR en el modulo correspondiente.

### 3.10 Historial administrativo (Web)
Modulo de auditoria para administracion.

Incluye consultas y exportes de historicos de:
- Rutas
- Usuarios
- Horarios
- Archivos
- Registros diarios y logs

Nota:
- Este modulo esta orientado a uso web administrativo.

## 4. Notificaciones

El sistema envia notificaciones push para eventos como:
- Novedades de autorizaciones
- Publicacion de documentos
- Eventos de ruta y avisos

Recomendaciones:
- Acepte permisos de notificacion en el dispositivo/navegador.
- Mantenga sesion iniciada en el dispositivo que usara para recibir alertas.

## 5. Buenas practicas de uso

- Cierre sesion al terminar, sobre todo en equipos compartidos.
- Verifique siempre grado, documento y rol antes de guardar.
- En matriculas, complete campos obligatorios antes de avanzar.
- Evite crear usuarios duplicados con el mismo documento/correo.

## 6. Solucion de problemas comunes

### No puedo iniciar sesion
- Si es estudiante, verifique documento y contrasena.
- Si es administrador, docente o familiar, verifique correo institucional y contrasena.
- Use recuperacion de contrasena solo en cuentas con acceso por correo.
- Valide con administracion que su cuenta este activa.

### No veo un modulo en el menu
- Su usuario no tiene ese permiso o rol.
- Solicite habilitacion al administrador.

### No me llegan notificaciones
- Revise permisos de notificacion del navegador o celular.
- Cierre sesion e inicie nuevamente para refrescar token.

### No puedo editar una matricula
- Puede estar en estado bloqueado para su rol.
- Si es administrador, revise estado y permisos de matricula.

## 7. Guia rapida de primer arranque (Administrador)

Orden sugerido para dejar operativo el sistema:
1. Crear/validar parametros base.
2. Crear usuarios administrativos y operativos.
3. Configurar grados, permisos y ano de matricula.
4. Cargar horarios iniciales.
5. Configurar rutas.
6. Validar flujo de documentos y autorizaciones.
7. Probar matricula con un usuario familiar.

## 8. Soporte interno

Si necesita ajustes funcionales (nuevos permisos, campos o reglas), registre el requerimiento con:
- Modulo afectado
- Rol afectado
- Pasos para reproducir
- Resultado esperado
- Evidencia (captura y fecha)

## 9. Pendientes funcionales

Pendiente urgente:
- Implementar flujo de cambio y reseteo de contrasena para estudiantes sin depender de correo. La autenticacion por documento ya esta activa, pero falta el mecanismo administrativo y/o autoservicio controlado para actualizar la clave cuando el estudiante la olvide o necesite cambiarla.

---

## Anexo tecnico corto (para despliegue local)

Requisitos:
- Flutter SDK compatible con `sdk: ^3.7.2`
- Proyecto Firebase configurado

Comandos:
```bash
flutter pub get
flutter run -d chrome
```

Tambien puede ejecutar en Android/iOS segun dispositivo disponible.
