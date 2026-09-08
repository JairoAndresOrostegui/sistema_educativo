# Manual de administración y superadministración

## Alcance y preparación

Ingresar con correo verificado. El administrador trabaja solo en su institución
y sede y con las acciones de su matriz. El superadministrador es el único que
puede operar entre sedes. Verificar el año activo antes de cualquier operación.
No compartir una cuenta administrativa con conductores, familias ni estudiantes.

Inicio permite entrar a módulos habilitados y activar notificaciones del equipo.
El contador de autorizaciones del superadministrador suma las sedes configuradas,
cada una en su año vigente. El administrador normal solo cuenta su propia sede.
La suma inicial espera la respuesta de todas las sedes para no mostrar un total parcial.
Perfil modifica datos personales permitidos, no el directorio de usuarios.
Un móvil nuevo reemplaza al móvil anterior; un navegador nuevo reemplaza al
navegador anterior. Son dos registros independientes.

## Usuarios

1. Abrir Usuarios, buscar por los datos disponibles y verificar sede.
2. Crear o editar seleccionando institución/sede dentro del alcance y grupo
   académico real, no escribiendo un grado libre.
3. Asignar el mínimo permiso necesario; comprobar vínculos familiares e hijo activo.
4. Guardar y revisar el resultado antes de crear otra cuenta por un error de red.

El estudiante usa documento para el acceso resuelto a correo ficticio, sin
verificación. Adultos usan correo real. No habilitar Autorizaciones a estudiantes;
familiares solo reciben autorizaciones.ver, nunca crear/editar/eliminar.
Auxiliar es una cuenta adulta para una ruta asignada, no un docente académico.

Inactivar impide acceso. Retirar lógicamente oculta al usuario al administrador
normal, conservándolo para superadmin. Si tiene registros institucionales,
preferir inactivación y consultar impacto. Solo superadmin elimina definitivamente:
revisar enlaces, confirmar responsabilidad, ejecutar cascada y comprobar historial.
Si falla, detenerse y revisar el estado reintentable; no borrar documentos a mano.

## Continuidad docente

Desde Usuarios: seleccionar saliente y reemplazo, revisar impacto y choques,
elegir temporal/definitivo y confirmar. El saliente pierde acceso; el reemplazo
recibe la carga vigente. Mensajes/archivos conservan autor original. En temporal,
Restaurar revierte responsabilidades que aún correspondan. No trasladar tokens ni QR.
El relevo de un auxiliar durante un viaje necesita todavía un flujo específico.

## Parámetros, grupos y años lectivos

Administrar grupos por sede: Cuarto A y Cuarto B son grupos distintos, incluso
si comparten nivel. Revisar que estudiantes, docentes y horarios correspondan.
Un grupo con referencias no debe borrarse; usar desactivación cuando corresponda.
Para cambio de año: preparar período, revisar estructura y copia opcional de
horarios, resolver pendientes y activar. El anterior queda cerrado, no se borra.
No ocurre automáticamente el 1 de enero. Usuarios y sitio web no se reinician.

## Matrículas

Consultar bandejas, abrir solicitud, validar datos y grupo/sede, pedir corrección
si faltan datos o aprobar/rechazar con motivo. Revisar historial y PDF disponible.
Dos decisiones simultáneas no deben sobreescribirse: ante conflicto, recargar.
Familiar corrige la solicitud de su hijo, no crea duplicados para responder.
No cambiar nombres de grupos a mano ni mezclar solicitudes de otras sedes.

## Autorizaciones

Familiar solicita; administración revisa, aprueba o rechaza. Cuando se ejecuta
la salida, registrar observación y finalizar. Finalizada es inmutable para admin;
solo superadmin corrige con log. No confundir aprobado con salida efectuada.
Las funciones docentes para ausencias/citas futuras no se consideran habilitadas.

## Horarios

Consultar por grupo o por docente con buscador. Crear clases con materia, docente,
día y horas. El backend valida cruces de docente/grupo; las clases contiguas sí
son válidas. Si otra persona editó, recargar antes de insistir. Un año cerrado
no admite cambios. La consulta por docente no amplía el alcance entre sedes.

## Archivos

Elegir audiencia: todos, uno/varios grupos o estudiantes; añadir documento y
mensaje/enlace. Revisar destinatarios antes de publicar. Cuota institucional 1 GiB,
25 MiB por documento; formatos PDF, Word y Excel admitidos. La reserva de carga
puede ocupar cuota temporalmente. No dar por publicado un archivo sin confirmación.
Administración autorizada elimina manualmente; superadmin limpia por antigüedad
superior a 60 días. Docentes nunca borran ni ocultan. Si Storage falla, conservar
metadatos y reintentar por el sistema. No ajustar contadores manualmente.

## Mensajería

Usar grupos para comunidad académica y particulares para asuntos individuales.
La membresía viene de matrícula/grupo/docencia/vínculos vigentes. Silenciar un
grupo lo convierte en anuncios, no elimina historia. Consultar acuses propios
cuando estén disponibles. No confundir FCM aceptado con lectura del mensaje.
Solo superadmin abre Estado de notificaciones y reintenta fallos auditados.
Los avisos del viaje se operan en Rutas, no requieren crear un chat paralelo.

## Rutas: configurar, operar y supervisar

1. Registrar conductor en Herramientas: hoja de vida sin cuenta de acceso.
2. Crear ruta con estudiantes, responsable activo de sede, horarios y conductor.
3. Responsable prepara el recorrido de hoy. Revisar direcciones e incluidos.
4. Revisar solicitudes familiares de cambio; aprobar/rechazar con motivo antes
   del inicio. Aprobación modifica solo la parada de ese estudiante en ese recorrido.
5. Iniciar: se bloquean direcciones e incluidos, también para administración.
6. Operar manualmente o solicitar cálculo Google si está habilitado. En automático
   hay cálculo inicial; no hay recálculo cada cinco minutos ni después de recoger.
7. Marcar cada estudiante recogido o no recogido con motivo. Finalizar solo cuando
   no queden participantes pendientes. Consultar historial después.

Con ETA de 10 minutos o menos se abre la ventana GPS y se avisa. Paradas próximas
pueden abrirse simultáneamente. El mapa permanece ante demoras y se cierra al
recoger/no recoger o terminar. Un aviso manual de hasta 10 minutos también abre
la ventana; uno mayor programa la estimación sin abrirla inmediatamente.
Enviar aviso general comunica una novedad a participantes, incluso ya recogidos,
y conserva texto/actor/fecha en el historial. No es chat libre entre familias.

Google Maps automático continúa condicionado a habilitación de API y presupuesto;
si no está disponible, operar manualmente. Recálculo consume cuota y requiere
confirmación. No se garantiza llegada exacta. GPS sin señal no debe interpretarse
como vehículo detenido. No manejar el teléfono mientras se conduce.

Direcciones iguales se agrupan por texto normalizado; casas cercanas no se fusionan
automáticamente. Paradas explícitas, Places/pin, planificación futura e ida/regreso
en una misma plantilla aún requieren ampliación. No prometerlos a familias.

## QR, sitio web e historial

QR: buscar usuario/evento dentro de sede, obtener identificador, revocar/reemplazar
con confirmación si se expuso. No autoriza entregar estudiantes ni registrar
asistencia por sí solo. Eventos actuales solo tienen identidad.
Sitio web: editar Header, Footer y páginas con filas/columnas/componentes; comprobar
vista móvil y publicar. Usar enlaces YouTube/Vimeo para videos. Eliminar en borrador
no equivale a retirar recursos publicados; la limpieza ocurre al publicar.
Revisar formularios públicos desde su bandeja sin confundirlos con matrículas.
Historial: consultar actor, fecha, sede y acción; no editar ni borrar evidencias.

## Escenarios de soporte

- Módulo ausente: revisar permiso, rol, sede y estado, no otorgar superadmin.
- Niño en grupo equivocado: corregir vínculo académico, no manipular audiencia.
- Dos hermanos: verificar hijo seleccionado; avisos compartidos no comparten perfiles.
- Sin notificación: revisar permiso del equipo, último login y panel superadmin.
- Fallo después de guardar: comprobar historial antes de repetir.
- Año cerrado: no reabrir por conveniencia; seguir cambio de período aprobado.

Consultar también [referencia transversal](../MANUAL_USUARIO.md) y
[pendientes de publicación](TECNICO.md#google-play).
