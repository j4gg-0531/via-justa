# VJ-16 · Formulario y publicación de negocios

Segundo bloque de la rama `codex/vj-16-publicacion-directa-negocios`.
Preparado para revisión antes del commit. No se ha aplicado una migración remota ni hecho push.

## Comportamiento

- Formulario de cuatro pasos: identidad; ubicación y contacto; oferta, horarios y fotos; revisión y consentimiento.
- Registro con sesión real y municipio piloto Valledupar (20001).
- Un enlace HTTPS para menú y pedidos, independiente del WhatsApp autorizado.
- Hasta cinco fotos JPEG/PNG/WebP, de hasta 5 MB cada una; selección desde galería y comprobación de decodificación.
- Hasta cinco platos o servicios destacados con precio en COP.
- Horario semanal con una franja por día; permite cerrar al día siguiente.
- Publicación automática mediante `submit_business` → fotos en Storage → `business_photos` → `publish_business`.
- El borrador permanece bloqueado durante un reintento y reutiliza `client_request_id` para evitar duplicados. Se puede cancelar la preparación para corregirlo.
- Una respuesta de una sesión anterior no modifica el formulario de la sesión actual.
- Al avanzar, la pantalla vuelve al inicio del siguiente paso para permitir revisar todo el contenido.

## Archivos creados

- `lib/features/businesses/domain/business_draft.dart`
- `lib/features/businesses/domain/business_registration_repository.dart`
- `lib/features/businesses/domain/business_validator.dart`
- `lib/features/businesses/data/device_business_photo_repository.dart`
- `lib/features/businesses/data/supabase_business_registration_repository.dart`
- `lib/features/businesses/presentation/state/register_business_provider.dart`
- `lib/features/businesses/presentation/pages/register_business_page.dart`
- `test/business_validator_test.dart`
- `test/business_registration_repository_test.dart`
- `test/register_business_provider_test.dart`
- `test/register_business_page_test.dart`
- Este informe.

## Archivos modificados

- `lib/core/router/app_router.dart`
- `lib/features/businesses/presentation/pages/businesses_page.dart`
- `lib/features/home/presentation/pages/home_page.dart`
- `assets/translations/es.json`
- `assets/translations/en.json`
- `test/businesses_page_test.dart`
- `test/home_profiles_test.dart`

No se eliminan archivos ni se añaden dependencias. Los archivos de plataformas regenerados por Flutter se restauraron sin cambios funcionales.

## Verificaciones ejecutadas

- `dart fix --apply --code=curly_braces_in_flow_control_structures`: corrigió 17 avisos en cuatro archivos nuevos.
- `dart format` sobre archivos editados: completado.
- `flutter analyze --no-pub`: última ejecución sin problemas.
- `flutter test --no-pub --reporter expanded`: última ejecución con **286 pruebas aprobadas**.
- Se ejecutaron también pruebas individuales de validaciones, provider, repositorio, navegación y formulario. Los fallos iniciales de navegación y arquitectura se corrigieron antes de la ejecución completa final.
- Pruebas de pantalla: cuatro pasos y publicación simulada en español e inglés, 360 dp y escala de texto 2.0.
- Pruebas del adaptador HTTP con servidor local de prueba: contrato de llamadas, orden de subida/publicación, sesión distinta, negocio ya publicado y errores del servidor. Estas pruebas no equivalen a una publicación real en Supabase.
- `rg -n 'normalizeForSearch|search[A-Z]\w*\(|\.where\(|\.sort\(|firstWhere|jsonDecode|rootBundle|Timer|Future\.delayed' lib --glob '**/presentation/**' --glob '!**/presentation/state/**'`: ninguna coincidencia (código de salida 1 de rg).
- `git diff --check`: sin errores de espacios.
- `flutter devices`: emulador Android `emulator-5554` disponible.
- `flutter run -d emulator-5554 -t .dart_tool/vj_business_preview.dart --no-pub`: compilación e instalación realizadas; vista de prueba observada mediante captura ADB. Se detuvo el proceso de seguimiento posteriormente.
- `flutter build apk --debug -t .dart_tool/vj_business_preview.dart --no-pub`: APK compilado tras los ajustes visuales.
- Capturas mediante `adb shell screencap` y `adb pull`, con escala del sistema 1.0 y 2.0. La vista temporal utiliza datos de prueba y no escribe en Supabase; permanece fuera de Git, en `.dart_tool/`.

Las pruebas antiguas imprimen avisos de traducción porque verifican claves sin inicializar localización. La prueba nueva del formulario sí carga los textos reales de ambos idiomas.

## Recorrido del código

- Abrir registro: `BusinessesPage` / `HomePage` → `AppRoutes.businessRegister` → `RegisterBusinessPage`.
- Validar y avanzar: `RegisterBusinessPage` → `RegisterBusinessNotifier.next/submit` → `validateBusinessStep` → `BusinessDraft`.
- Elegir ubicación: `RegisterBusinessPage` → selector de mapa existente → `RegisterBusinessNotifier.selectPoint` → `municipalityZonesProvider` → repositorio de zonas existente.
- Añadir foto: `RegisterBusinessPage` → `RegisterBusinessNotifier.addPhoto` → `BusinessPhotoRepository` → `DeviceBusinessPhotoRepository` → `businessImageExtension` y decodificador de imagen.
- Publicar: `RegisterBusinessPage` → `RegisterBusinessNotifier.submit` → `validateBusinessStep` → `BusinessRegistrationRepository` → `SupabaseBusinessRegistrationRepository` → RPC y Storage.
- Cancelar preparación: `RegisterBusinessPage` → `RegisterBusinessNotifier.discard` → `SupabaseBusinessRegistrationRepository.discard` → limpieza de archivos y registro pendiente propio; si ya está publicado, conserva el negocio y muestra éxito.
- Refrescar después de publicar: `RegisterBusinessNotifier` invalida `allBusinessesProvider` y `allPriceMapItemsProvider`.

## Límites y pendientes

- Requiere desplegar la migración del primer commit en el Supabase del entorno donde se pruebe. No se ha desplegado desde este bloque.
- Falta probar el recorrido completo con una cuenta real y subida real de fotos en ese entorno. Las verificaciones de este bloque son pruebas automatizadas y revisión visual con datos controlados.
- El borrador se conserva durante la estancia en el formulario, no tras cerrar por completo la aplicación.
- La integración final del directorio/mapa y la eliminación de negocios demo corresponden al tercer bloque de esta rama.
- La ficha del negocio, los enlaces de acción, las valoraciones y el aviso de precios por zona permanecen en las ramas posteriores acordadas.

Siguiente paso: revisión del usuario y confirmación explícita antes de crear el segundo commit.
