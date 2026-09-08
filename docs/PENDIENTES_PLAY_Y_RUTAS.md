# Pendientes de publicación y Rutas — 5 de septiembre de 2026

## Play Console

La captura del propietario muestra registro de aplicaciones completo, pero
riesgo de cierre por inactividad con acción requerida antes del 19 de septiembre.
No confundir ese plazo con el 30 de septiembre del registro Android.
Cuenta personal de 2025: acceso público a producción sujeto a prueba cerrada
de 12 participantes durante 14 días continuos y posterior solicitud/revisión.

- Solicitar captura de «Ver detalles» del aviso y del rechazo previo.
- Verificar correo y teléfono de contacto y completar las acciones que indique
  Play Console. No dar por cerrado el aviso solo por cargar un AAB.
- El paquete visible en Console difiere de
  `co.edu.liceobilinguerodolfollinas.sistemaeducativo`, configurado localmente.
  Confirmar identificador exacto, certificado de subida y mayor versionCode
  usado antes de cambiar configuración Android/Firebase o volver a compilar.
- No publicar al público mientras falten pruebas de permisos, privacidad,
  datos de menores, acceso del revisor y funcionamiento real Android.
- Se recomienda una prueba interna estable antes del plazo, sin esperar a
  terminar todos los módulos; no subir sin resolver firma/paquete y rechazo.

Referencias:
- https://support.google.com/googleplay/android-developer/answer/11605267?hl=es
- https://support.google.com/googleplay/android-developer/answer/14151465?hl=es

## Endurecimiento durante la prueba cerrada

La primera versión cerrada usa el AAB de producción `1.0.0 (8)`. Publicar una
versión superior en la misma pista no sustituye la exigencia de mantener al menos
12 cuentas inscritas continuamente durante 14 días; conservar la lista y el enlace
de inscripción. Aprovechar ese período para publicar una versión 9 con:

- QR: validar sesión y tipos de todas las respuestas antes de dibujar o resolver.
- Mensajería y panel Push: estado vacío ante sesión ausente, respuestas defensivas
  y mensajes de dominio sin excepciones técnicas.
- Matrículas e Historial: tolerar fechas, listas y documentos heredados incompletos.
- Parámetros, Usuarios y Perfil: eliminar usos de sesión forzada y texto técnico
  en errores recuperables.
- Ejecutar pruebas de regresión, informe previo al lanzamiento y recorrido físico
  de cada perfil antes de promover a producción pública.

Los testers no tienen que abrir la aplicación todos los días para conservar la
inscripción, pero la solicitud de acceso pregunta por uso real, funciones probadas
y retroalimentación. Reclutar personas reales, preferiblemente más de 12, registrar
las pruebas y no simular testers mediante varias cuentas de una sola persona.

## Rutas -> Mensajería (propuesta, NO implementada)

Después de revisar Rutas, acordar con el propietario un canal por ruta, sede y
año, con familias/estudiantes del recorrido y responsables vigentes. Propuesta:
avisos generales de retraso, cambio de recorrido o cancelación; novedades
individuales solo al estudiante/familia correspondiente, nunca al grupo.
La ubicación en vivo permanece en Rutas, sin copiarla al chat ni publicar
direcciones. Definir quién puede escribir y qué eventos generan push para no
saturar dispositivos. Reutilizar cola y auditoría, sin crear otro motor de chat.
