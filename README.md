# Sistema Educativo Rodolfo Llinás

Aplicación Flutter para la gestión multiinstitución y multisede de preescolar, primaria y bachillerato. Incluye autenticación por roles, usuarios, grupos académicos, matrículas, autorizaciones, horarios, archivos, mensajería, rutas, QR, auditoría y sitio web público.

## Documentación

- [Manual de usuario](docs/MANUAL_USUARIO.md): funciones, roles, reglas y flujos por módulo.
- [Guía de desarrollo](docs/GUIA_DESARROLLO.md): arquitectura, seguridad, datos, estilos, migraciones y despliegue.
- [Reglas permanentes](AGENTS.md): decisiones obligatorias para futuras sesiones y módulos.

## Decisiones centrales

- Administrador normal: solo su institución y sede.
- Superadministrador: único actor con alcance entre sedes.
- Grupos académicos independientes por sede mediante `groupId`; se permiten Cuarto A, Cuarto B, etc.
- Familiar: selector de hijo activo en todo módulo relacionado con estudiantes.
- Estudiante: correo ficticio sin verificación y sin acceso a Autorizaciones.
- Escrituras sensibles: Cloud Functions, validación backend y auditoría.
- Archivos: 300 MiB por institución, 25 MiB por documento y limpieza exclusiva del superadministrador después de 60 días.
- Tema: color y tipografía obtenidos de `website/config`; no se agregan colores de marca dentro de pantallas.
- El proyecto Firebase actual funciona como QA. Producción tendrá infraestructura separada.

## Preparación local

```powershell
flutter pub get
Set-Location functions
npm ci
Set-Location ..
flutter run -d chrome
```

La configuración Firebase de las plataformas está en `lib/config/firebase_options.dart`, Android y Web. No agregue credenciales privadas al repositorio.

## Calidad

```powershell
dart format lib test
flutter analyze
flutter test
Set-Location functions
npm run lint
npm run test:rules
npm run test:auth
npm run test:users
npm run test:enrollment
npm run test:authorization
npm run test:schedule
```

Las pruebas de Functions y reglas usan los emuladores definidos en `firebase.test.json`.

## Migración a grupos académicos

La migración es seca por defecto:

```powershell
Set-Location functions
node scripts/migrate_academic_groups.js
```

Para aplicarla, configure credenciales administrativas del proyecto QA, valide primero el resumen y ejecute:

```powershell
node scripts/migrate_academic_groups.js --apply
```

La migración crea una sección A para los niveles actuales de cada sede, cambia las referencias a `groupId/groupName`, reorganiza objetos de Archivos, recalcula cuota y elimina los parámetros antiguos de grado. Nuevas secciones se administran como grupos independientes.

## Despliegue QA

```powershell
flutter build web
firebase use default
firebase deploy --only firestore,storage,functions,hosting
```

Antes de desplegar confirme que `default` apunta al proyecto QA esperado y que todas las pruebas anteriores finalizaron correctamente.
