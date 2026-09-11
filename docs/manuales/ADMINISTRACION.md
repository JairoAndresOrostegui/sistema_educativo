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
La foto debe ser PNG o JPEG y pesar máximo 5 MiB. Si otra sesión modificó el
perfil o la opción que se estaba editando, el sistema exige recargar para evitar
sobrescribir información más reciente.
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

Para recuperar una cuenta estudiantil, abrir el menú del estudiante y elegir
**Generar clave temporal**. Confirmar que corresponde a la persona y sede
correctas, copiar la clave que se muestra una sola vez y entregarla de forma
privada. No enviarla en grupos ni anotarla en observaciones. Mientras esté
pendiente, el estudiante solo puede cambiarla; ningún módulo queda habilitado.
Si la clave se pierde o no fue copiada completa, se puede generar otra: la
anterior queda inválida inmediatamente. El sistema bloquea únicamente otro
restablecimiento que todavía esté ejecutándose. Cada generación y el cambio
posterior quedan auditados, pero las contraseñas nunca quedan en el log.

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

## Configuración académica: grupos y años lectivos

Administrar grupos por sede: Cuarto A y Cuarto B son grupos distintos, incluso
si comparten nivel. Revisar que estudiantes, docentes y horarios correspondan.
Un grupo con referencias no debe borrarse; usar desactivación cuando corresponda.
Para cambio de año: preparar período, revisar estructura y copia opcional de
horarios, resolver pendientes y activar. El anterior queda cerrado, no se borra.
No ocurre automáticamente el 1 de enero. Usuarios y sitio web no se reinician.

El acceso requiere `parametros.ver`; los cambios requieren `parametros.editar`.
Un administrador normal queda limitado a su institución y sede. Solo el
superadministrador cambia de sede. EPS y tipos de documento aparecen en
Catálogos administrativos: el administrador de sede los consulta y solo el
superadministrador agrega, renombra, ordena o desactiva opciones. El código
interno de una opción existente no cambia y no se eliminan opciones con historia.
La desactivación conserva formularios y usuarios históricos. Un cambio simultáneo
de catálogo o grupo se rechaza y debe repetirse después de recargar.
Roles y permisos se gestionan como matriz técnica versionada, no como texto libre.

Para retirar un grupo con historia, desactivarlo. La eliminación definitiva solo
está disponible para el superadministrador cuando el grupo ya está inactivo y el
análisis previo confirma que no tiene estudiantes, docente director, horarios,
matrículas, autorizaciones, canales ni archivos relacionados.

## Matrículas

Consultar bandejas, abrir solicitud, validar datos y grupo/sede, pedir corrección
si faltan datos o aprobar/rechazar con motivo. Revisar historial y PDF disponible.
Dos decisiones simultáneas no deben sobreescribirse: ante conflicto, recargar.
Familiar corrige la solicitud de su hijo, no crea duplicados para responder.
No cambiar nombres de grupos a mano ni mezclar solicitudes de otras sedes.

Si el formulario no logra cargar los grupos o catálogos, muestra un aviso con
**Reintentar** y bloquea el envío. No sustituye el año lectivo por el del reloj ni
inventa opciones de EPS. La matrícula pública consulta solo la proyección de la
institución publicada; nunca obtiene acceso a perfiles ni solicitudes existentes.

## Autorizaciones

Familiar solicita; administración revisa, aprueba o rechaza. Cuando se ejecuta
la salida, registrar observación y finalizar. Finalizada es inmutable para admin;
solo superadmin corrige con log. No confundir aprobado con salida efectuada.
Las funciones docentes para ausencias/citas futuras no se consideran habilitadas.
Los cambios avisan a los familiares activos vinculados con permiso de consulta.
Un hijo retirado o trasladado deja de exponer sus solicitudes al vínculo anterior.

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
Si aparece **Eliminación pendiente**, el documento no se puede descargar. Usa
**Reintentar eliminación** para terminar la operación; no vuelvas a publicarlo
ni cambies su cuota manualmente.
Usar **Ver descargas** para consultar acuses individuales; una solicitud de
descarga no equivale a lectura efectiva del contenido.
Las descargas exigen una sesión vigente y se validan en el servidor. El acceso
a un enlace antiguo no sustituye los permisos de la cuenta.

## Mensajería

Usar grupos para comunidad académica y particulares para asuntos individuales.
La membresía viene de matrícula/grupo/docencia/vínculos vigentes. Silenciar un
grupo lo convierte en anuncios, no elimina historia. Consultar acuses propios
cuando estén disponibles. No confundir FCM aceptado con lectura del mensaje.
Todo particular entre personal y estudiante es `supervised_student`: incluye al
menor y a todos sus familiares activos, con pendiente y hora de lectura propios.
Administración integra los canales colectivos de su sede, pero no puede abrir
particulares ajenos ni intervenir en ellos.
Solo superadmin abre Estado de notificaciones y reintenta fallos auditados.
Los avisos del viaje se operan en Rutas, no requieren crear un chat paralelo.
En un canal existente, el clip adjunta PDF, Word o Excel de hasta 25 MiB. El
archivo comparte cuota y retención con Archivos; no envíe datos por enlaces
externos para evadir el control. Cada descarga se registra por cuenta.

## Lista de asistencia

Administración puede abrir listas por grupo, asignatura y fecha dentro de su sede.
Debe completar los cuatro estados posibles y cerrar la lista solo después de
revisarla. Una lista cerrada es visible al estudiante y sus familiares vinculados.
Si necesita corrección, entra de nuevo, modifica el registro y pulsa **Guardar
corrección**; el sistema incrementa la revisión, conserva el cambio en historial y
envía otro aviso. Un administrador normal no puede operar otra sede. El traslado
docente mueve únicamente sesiones abiertas; nunca cambia la autoría histórica.
El icono de reporte permite elegir rango y grupo; la vista resume estados y en
web exporta todos los resultados a Excel.

Las fechas deben existir y pertenecer al año activo. Un año cerrado queda de
solo consulta, incluso para correcciones administrativas. El cierre comprueba
las marcas reales de toda la lista, no solo el contador mostrado. Si falla una
consulta, aparece un mensaje de error y **Actualizar** permite reintentar; no
se interpreta el fallo como ausencia de datos.

## Eventos

Abre **Eventos**, crea el borrador y define lugar, fechas, audiencia de toda la
sede, grupos completos o estudiantes específicos, responsables,
confirmación, autorización familiar, cupo y enlace opcional. Revisa el borrador y
pulsa **Publicar**; en ese momento se actualizan los estudiantes vigentes de la
audiencia y se envía el aviso. Un evento publicado puede cancelarse antes de iniciar
o finalizarse después del inicio. Los finalizados/cancelados pueden archivarse;
no se borran para conservar evidencia.

Desde **Asistencia** marca de forma explícita Presente o Ausente para cada alumno.
El botón permanece deshabilitado mientras falte una marca. Si otro responsable
guardó primero, recarga para no sobrescribirlo. El icono **Reporte de eventos**
consulta un rango completo, muestra estado, destinatarios y confirmados y, desde
la versión web, permite exportar todos esos resultados a Excel. Trasladar un
docente reasigna sus eventos futuros y una reversión temporal los devuelve si
siguen vigentes.

Cada evento publicado genera un único recordatorio automático dentro de las 24
horas anteriores a su inicio. Cancelarlo antes de esa ventana evita el aviso.

La publicación vuelve a comprobar que los responsables y destinatarios sigan
activos. Las cancelaciones de eventos ya publicados permanecen visibles para
sus destinatarios; cancelar un borrador no lo hace público. No se permite
modificar eventos de años cerrados. Si la lista de asistencia supera 400
alumnos, se guarda por bloques; ante un fallo se recargan las marcas confirmadas
y deben completarse las restantes antes de considerar terminada la operación.
Los reportes detienen explícitamente consultas demasiado grandes; reducir el
rango o seleccionar un grupo evita recibir un informe incompleto.

## Rutas: configurar, operar y supervisar

1. Registrar conductor en Herramientas: hoja de vida sin cuenta de acceso.
2. Crear ruta con estudiantes, responsable activo de sede, horarios y conductor.
   Un estudiante no puede quedar en dos rutas activas del mismo año y sede.
   Si otra persona modificó la ruta, recargar antes de guardar. Una ruta con
   recorridos conserva su historial; una baja permitida es lógica.
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
Al cerrar el año lectivo también se revoca el mapa de sus recorridos, incluso
para administración. El historial autorizado conserva sus registros, no GPS vivo.
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
asistencia por sí solo. **Leer con cámara** solicita permiso, acepta solamente
identificadores `LLQ1` y valida su vigencia en el servidor; si no hay cámara o
permiso, usar **Validar manualmente**. El QR del evento solo identifica y no cambia
la confirmación ni la asistencia del módulo Eventos.
Sitio web: editar Header, Footer y páginas con filas/columnas/componentes; comprobar
vista móvil y publicar. Usar enlaces YouTube/Vimeo para videos. Eliminar en borrador
no equivale a retirar recursos publicados; la limpieza ocurre al publicar.
Revisar formularios públicos desde su bandeja sin confundirlos con matrículas.
Historial: consultar actor, fecha, sede y acción; no editar ni borrar evidencias.

La bandeja del sitio web está aislada por institución y sede. Si el constructor
informa que otra persona publicó primero, recargar y reaplicar conscientemente
solo los cambios necesarios.
Los filtros recorren todo el rango seleccionado, no solo la primera pantalla.
Los botones de exportación descargan la página o los registros visibles que
indica su etiqueta; avanzar o cargar más antes de exportar si se necesitan otros.

QR: emitir identificadores solo para personas activas de la sede. Revocar invalida
el código anterior; una credencial revocada permanece visible para administración
y puede reemplazarse. Si otra sesión la modificó primero, recargar. Validar un QR
solo confirma la identidad vigente: no registra asistencia ni autoriza entregas.
Cada lectura correcta deja auditoría del administrador, fecha, origen y plataforma.

## Escenarios de soporte

- Módulo ausente: revisar permiso, rol, sede y estado, no otorgar superadmin.
- Niño en grupo equivocado: corregir vínculo académico, no manipular audiencia.
- Dos hermanos: verificar hijo seleccionado; avisos compartidos no comparten perfiles.
- Sin notificación: revisar permiso del equipo, último login y panel superadmin.
- Fallo después de guardar: comprobar historial antes de repetir.
- Año cerrado: no reabrir por conveniencia; seguir cambio de período aprobado.

Consultar también [referencia transversal](../MANUAL_USUARIO.md) y
[pendientes de publicación](TECNICO.md#google-play).
