# Manual de usuario

## Acceso y perfiles

Administradores, docentes y familiares ingresan con correo. Los estudiantes ingresan con su documento; internamente el sistema resuelve su correo ficticio de Firebase y nunca les exige verificarlo. Una cuenta inactiva, retirada o eliminándose no puede iniciar sesión.

Cada persona consulta y edita únicamente los campos seguros de su propio perfil. La administración de otras personas se realiza en Usuarios, nunca desde Perfil.

## Roles

### Superadministrador

Puede cambiar de institución y sede, administrar usuarios y grupos, consultar bajas administrativas, ejecutar eliminaciones definitivas con impacto y confirmación, corregir autorizaciones finalizadas con auditoría y operar la limpieza global de Archivos.

### Administrador

Opera solo su sede y únicamente los módulos/acciones presentes en su matriz de permisos. Puede retirar lógicamente usuarios de su vista, pero no eliminarlos definitivamente. Si una persona tiene matrículas u otra información, el sistema recomienda inactivarla y muestra las relaciones afectadas.

### Docente

Opera los módulos asignados y su grupo académico. Los permisos especiales son explícitos y temporales según decisión administrativa. No obtiene acceso transversal por ser docente.

### Familiar

Selecciona uno de sus hijos vinculados y todo módulo muestra el contexto correspondiente. En Autorizaciones, `autorizaciones.ver` le permite consultar y presentar solicitudes; nunca recibe permisos crear, editar o eliminar en la matriz administrativa.

### Estudiante

Consulta exclusivamente los módulos habilitados para su propio grupo y perfil. No puede acceder a Autorizaciones.

## Usuarios

El formulario permite escoger institución, sede y grupo según alcance. Un administrador queda fijado a su sede; el superadministrador puede cambiarla. Estudiantes y docentes requieren grupo; familiares y administradores no.

Acciones principales:

- crear o editar con validación de documento y correos únicos;
- importar docentes desde Excel usando la columna `grupo`;
- activar o inactivar para permitir o impedir acceso;
- retirar lógicamente para ocultar al usuario a administradores normales;
- consultar impacto antes de retirar o eliminar;
- eliminar definitivamente solo como superadministrador, con frase de confirmación y log.

Si una cascada no puede completarse, la operación se detiene o compensa para evitar registros huérfanos.

## Grupos académicos

Cada grupo pertenece a una institución y sede. El nivel y la sección forman el nombre: `Cuarto` + `A` = `Cuarto A`. Es válido crear Cuarto A y Cuarto B en la misma sede, así como grupos con el mismo nombre en sedes diferentes. Horarios, usuarios, matrículas, autorizaciones, archivos y mensajes se relacionan por el identificador del grupo.

Un grupo con información institucional vinculada no se elimina. Primero se reasignan o conservan los registros; como alternativa se desactiva el grupo.

## Matrículas

La matrícula pública crea una prematrícula; el personal autorizado revisa y cambia su estado. Familiar selecciona el hijo correspondiente. Docentes solo consultan o intervienen cuando poseen el permiso y el grupo apropiado. Los administradores trabajan en su sede y el superadministrador puede cambiar de sede.

El sistema valida duplicidad por documento/año y conserva historial de cambios. El grupo aspirado se selecciona desde los grupos activos de la sede.

## Autorizaciones

Familiar selecciona un hijo, registra fechas, horario y motivo, y envía la solicitud usando su permiso de consulta. Administradores autorizados aprueban o rechazan. Cuando el estudiante sale, el administrador registra la observación final y marca `finalizada`.

Después de finalizar nadie puede editar. Solo el superadministrador puede corregir excepcionalmente y cada corrección deja historial. El estudiante nunca ve este módulo.

## Horarios

Administrador selecciona grupo de su sede y crea asignaturas con docente, día y franja. El sistema evita cruces del mismo docente o grupo. Docente consulta su horario y el de su grupo según permiso. Estudiante consulta el propio; familiar cambia de hijo y ve el horario y grupo elegidos.

## Archivos

Archivos distribuye publicaciones compuestas por un documento PDF, Word o Excel y un mensaje o enlace opcional.

- Personal con `archivos.crear` publica un documento de hasta 25 MiB.
- La barra de carga muestra el avance del archivo.
- La tarjeta de almacenamiento muestra consumo frente al límite institucional de 1 GiB.
- El administrador elige entre todos los estudiantes, uno o más grupos, o uno o más estudiantes mediante buscador.
- El docente elige uno o más de los grupos donde dicta clase o estudiantes activos de esos grupos. No puede enviar a toda la sede.
- Cada publicación muestra audiencia, remitente y fecha/hora de envío.
- Estudiante, docente y familiar solo consultan las publicaciones donde fueron incluidos; el familiar usa el hijo activo para filtrar la información.
- Estudiantes y familiares reciben notificación. Si publica un administrador, también la reciben los docentes que dictan en los grupos involucrados.
- Solo administradores con permiso y el superadministrador seleccionan y eliminan documentos dentro de su alcance.
- El docente nunca puede borrar ni ocultar una publicación, incluso si se alterara su matriz de permisos.
- El superadministrador puede eliminar cualquier selección y ejecutar la limpieza de todos los documentos con más de 60 días.
- Toda carga, descarga o eliminación relevante queda registrada.

La eliminación retira primero el objeto de Storage y después ajusta registros y cuota. Un fallo no debe dejar metadatos huérfanos.

## Mensajería y notificaciones

Los contactos y envíos grupales usan el grupo académico exacto: Cuarto A no incluye Cuarto B. Un familiar conversa en el contexto del hijo seleccionado. Las notificaciones se resuelven por usuarios, roles, grupo e hijos vinculados; no por direcciones de correo ficticias.

## Sitio web

El constructor del sitio público está dividido en tres áreas independientes:

- **Header:** identidad institucional, logo, navegación, datos de contacto, redes, color principal y tipografía.
- **Footer:** filas propias, información institucional, contacto, enlaces, redes y texto legal.
- **Contenido de navegación:** una composición distinta para Inicio y para cada página publicada.

Cada área se organiza en filas. Una fila admite entre una y cuatro columnas, con ancho relativo, fondo, separación, espacio interior y comportamiento adaptable a celular. Dentro de cada columna se agregan componentes: portada, texto, imagen, botón, tarjeta, carrusel, galería, video, preguntas desplegables, cifras, formulario, contacto, navegación, identidad, redes, separador o espacio. El ancho y la posición del componente se configuran por separado de la alineación de su texto: por ejemplo, un bloque puede ocupar el 50 %, estar centrado en la columna y conservar el texto alineado a la izquierda.

Las imágenes se eligen desde el equipo y se guardan en Storage. Los videos se administran mediante enlaces HTTPS de YouTube o Vimeo; se reproducen incrustados en la web y no ocupan Storage ni consumen la transferencia de Firebase. No se permite pegar HTML o `iframe` arbitrario.

El selector de color muestra una paleta visual amplia y deja el hexadecimal como opción avanzada. El color principal y la tipografía también alimentan el tema de los módulos internos; los fondos y estilos propios de filas, columnas y componentes solo afectan el sitio público. Antes de publicar se puede alternar la vista previa entre escritorio y móvil. Solo usuarios con `sitio_web.editar` o el superadministrador pueden modificar y publicar.

Los carruseles publicados pueden recorrerse con las flechas, los indicadores inferiores o el gesto de arrastre. En pantallas estrechas, la bandeja de mensajes muestra primero el listado y abre el detalle en una vista independiente con botón para regresar; así ninguna acción ni texto queda oculto.

Eliminar una fila, columna, componente, elemento o página modifica primero el borrador. Al publicar se retiran sus referencias del documento de Firestore y se eliminan de Storage las imágenes que ya no utiliza ninguna parte del sitio. Si Storage falla, las rutas quedan en `pendingAssetCleanup` y se reintentan en la siguiente publicación; no se considera una limpieza terminada silenciosamente.

## Historial y auditoría

Los módulos sensibles generan registros con actor, sede, acción, fecha y contexto. Los historiales no se pueden falsificar desde el cliente. La visibilidad respeta sede; el superadministrador puede consultar transversalmente cuando corresponde.

## Rutas, QR y módulos en evolución

Rutas gestiona recorridos y estados diarios, sujeto a permisos y sede. QR identifica al estudiante cuando está habilitado. Los permisos de ubicación y el flujo Android deben volver a validarse antes de publicar en Play Store. Toda ampliación futura debe mantener selección de hijo, grupos por sede, seguridad backend, auditoría y tema central.
