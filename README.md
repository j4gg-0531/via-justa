# Vía Justa — App Móvil Android & Backend Supabase (MVP)

> Plataforma móvil Android para consulta de precios justos comunitarios por zona urbana, verificación orientativa de cláusulas de contratos con OCR local + IA, guía cultural verificada y directorio moderado de negocios locales.

---

## 1. Visión del Proyecto

**Vía Justa** es una aplicación diseñada para que ninguna persona (visitante/turista, persona en proceso de instalación o residente local) llegue o habite en una ciudad colombiana sin herramientas transparentes para contrastar precios frente a reportes comunitarios reales o comprender las cláusulas de un contrato de arrendamiento y servicios antes de firmar.

- **Ciudad Piloto Activa:** Valledupar, Cesar (`20001`), segmentada en 5 zonas urbanas (`Zona Norte`, `Zona Centro`, `Zona Sur`, `Zona Oriente`, `Zona Occidente`).
- **Enfoque técnico:** Android-first, arquitectura limpia de tres capas (`presentation` → `domain` ← `data`), soporte bilingüe en vivo (`es` / `en`) y seguridad de doble barrera (validación pura en cliente + RLS, `GRANT`s y triggers `SECURITY DEFINER` en PostgreSQL).
- **Núcleo de precios (Nunca IA):** Regla estadística verificable por zona del municipio (`public.calculate_price_verdict` en PostgreSQL: mediana `PERCENTILE_CONT(0.5)`, ventana móvil de 60 días, muestra mínima $N \ge 3$, umbrales `+15%` / `+40%`, alerta `<-40%` y contraste con eventos activos).
- **Núcleo de contratos (`RN-10` — Cero retención):** Captura con OCR 100% en el dispositivo mediante Google ML Kit (`VJ-13`) y análisis orientativo mediante la Edge Function `analyze_contract` con Gemini (`VJ-14`), cuota diaria atómica de 5 análisis por usuario (`public.consume_ai_daily_quota`), aislamiento contra *Prompt Injection* y cero almacenamiento del texto contractual.

---

## 2. Pila Tecnológica

| Capa | Tecnología |
|---|---|
| **Cliente Móvil (Android)** | Flutter `3.47.7` (canal `stable`), Dart `3.13.5`, JDK `17`, Android Gradle Plugin `9.1.0` |
| **Estado, Rutas e i18n** | `flutter_riverpod: ^3.4.3`, `go_router: ^18.1.1` (`StatefulShellRoute.indexedStack`), `easy_localization: ^3.0.8` |
| **OCR en Dispositivo** | `google_mlkit_text_recognition` (inferencia local sin subir imágenes al servidor) |
| **Base de Datos y Geoespacial** | Supabase PostgreSQL `17` + `PostGIS` + `unaccent` + `pgTAP` (`14` migraciones versionadas) |
| **Seguridad y Almacenamiento** | Supabase Auth (GoTrue JWT), Row Level Security (RLS) en las 16 tablas, Storage privado (`business-media`) con verificación de MIME real |
| **Cómputo Serverless e IA** | Supabase Edge Functions (Deno / TypeScript) + Google Gemini API (`responseSchema` JSON estructurado) |

---

## 3. Estructura del Proyecto

```text
via-justa/
├── android/                         # Configuración nativa Android, Gradle, ProGuard/R8
├── assets/
│   ├── data/                        # Catálogo local de respaldo (DIVIPOLA Cesar)
│   ├── images/                      # Activos visuales con licencia verificada
│   └── translations/                # Archivos es.json y en.json (paridad estricta 1:1)
├── lib/
│   ├── app/                         # Configuración raíz de MaterialApp.router
│   ├── core/                        # Infraestructura compartida (router, session, supabase, theme, widgets)
│   └── features/                    # Módulos por funcionalidad (presentation, domain, data)
│       ├── auth/                    # Bienvenida (M01), login, registro y consentimientos (M16 / VJ-08)
│       ├── businesses/              # Directorio, detalle y registro de negocios locales (M21/M09/M19)
│       ├── contracts/               # Captura OCR local (VJ-13) y análisis con Gemini (VJ-14)
│       ├── home/                    # Inicio dinámico según perfil (M04 / M05)
│       ├── map_colombia/            # Explorador departamental de Colombia (M03)
│       ├── municipality/            # Selector de municipios (M13) y detalle piloto/no piloto (M14/M15)
│       ├── onboarding/              # Selección de perfil inicial (M02: visitor, settler, resident)
│       ├── prices/                  # Semáforo por zonas (M06/M07/M20), mapa (M08) y aporte en 4 pasos (M10)
│       ├── profile/                 # Perfil, cambio de idioma en vivo, cierre y baja de cuenta (M17)
│       ├── scan/                    # Contenedor segmentado Precios vs. Contratos (M06)
│       └── splash/                  # Arranque con redirección reactiva por sesión (VJ-09a)
├── supabase/
│   ├── config.toml                  # Configuración del entorno Supabase CLI
│   ├── functions/
│   │   └── analyze_contract/        # Edge Function Deno + cliente Gemini + suite de pruebas
│   ├── migrations/                  # 14 migraciones SQL idempotentes (0001 a 20261108220000)
│   ├── seed/                        # 10 archivos de semillas verificadas (geografía, zonas, precios, cultura, comercios)
│   └── tests/                       # 9 suites de pruebas automatizadas pgTAP (RLS, semáforo, cuotas, seguridad)
├── docs/                            # Documentación técnica, operativa y de sustentación
│   ├── arquitectura.md              # Arquitectura de 3 capas, diagrama integral y decisiones de diseño
│   ├── contrato-datos-v1.md         # Contrato formal de tablas, RLS, RPCs y Edge Function
│   ├── decisiones.md                # Registro de decisiones arquitectónicas (ADRs D1–D15)
│   ├── fuentes-y-licencias.md       # Atribución institucional y licencias de contenido
│   ├── guia-demo.md                 # Guion de sustentación de 7 minutos + Plan B sin internet
│   ├── manual-usuario.md            # Manual de usuario completo (precios, contratos, negocios, cuenta)
│   ├── modelo-er.puml               # Diagrama Entidad-Relación v1.2 en PlantUML (16 tablas)
│   ├── release-android.md           # Protocolo de firma release Android, SHA-1/256, OAuth y rollback
│   ├── seguridad-privacidad.md      # Políticas RN-10, Ley 1581, matriz de amenazas y control de costos
│   ├── backend/
│   │   └── guia-respaldo-restauracion.md # Procedimiento de backup y restauración del backend
│   ├── implementacion/
│   │   ├── progreso-mvp.md          # Tablero VJ-00..VJ-21, estado de Gates G0-G6 y dictamen Go/No-Go
│   │   └── walkthrough-primer-avance.md  # Evidencia histórica del cierre del Primer Avance (VJ-06)
│   └── pruebas/
│       └── matriz-rf-casos.md       # Matriz de trazabilidad RF/RNF/RN -> pruebas SQL/Deno/Flutter
└── test/                            # Suite de pruebas automatizadas Flutter (unitarias, widgets y E2E)
```

---

## 4. Puesta en Marcha Reproducible en Windows

### 4.1 Requisitos Previos
1. **Flutter SDK:** `3.47.7` (canal `stable`, con **Dart `3.13.5`** incluido).
2. **Java & Android SDK:** JDK `17`, Android SDK Command-line Tools y `adb`.
3. **Supabase CLI:** `>= 2.100.0` (requiere Docker Desktop para ejecución local con `supabase start`, o vínculo directo al proyecto remoto con `supabase link`).
4. **Deno (opcional para pruebas locales de Edge Functions):** `>= 1.45`.

### 4.2 Clonar e Instalar Dependencias
```powershell
git clone https://github.com/j4gg-0531/via-justa.git
cd via-justa
flutter pub get
```

### 4.3 Ejecución en Modo DEMO (Sin Credenciales de Red)
Si ejecutas la aplicación sin banderas `--dart-define`, el bootstrap activa automáticamente los repositorios de demostración rotulados con `[DEMO]`:
```powershell
flutter run -d <device-id>
```

### 4.4 Ejecución Conectada a Supabase (Sin Secretos en el Repositorio)
Las credenciales públicas se inyectan exclusivamente en tiempo de compilación mediante `--dart-define` (nunca uses `service_role` ni `GEMINI_API_KEY` en el cliente móvil):
```powershell
flutter run -d <device-id> `
  --dart-define=SUPABASE_URL=https://vjehsjqmwibmiqmxlsou.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<TU_SUPABASE_ANON_KEY> `
  --dart-define=GOOGLE_MAPS_API_KEY=<TU_GOOGLE_MAPS_API_KEY_RESTRINGIDA>
```

Para compilar el APK de entrega en modo `--release`, sigue paso a paso el protocolo en [`docs/release-android.md`](docs/release-android.md).

---

## 5. Comandos de Base de Datos y Pruebas Automatizadas

### 5.1 Pruebas Estáticas y Suite Flutter
```powershell
flutter analyze
flutter test
```

### 5.2 Verificación de Higiene Arquitectónica (Regla 5.2)
Ningún archivo de vista (`lib/**/presentation/pages` o `widgets`) puede contener lógica de negocio, búsquedas, ordenamientos, JSON o timers:
```powershell
Get-ChildItem -Path "lib" -Recurse -Include *.dart | Where-Object { $_.FullName -match "\\presentation\\" -and $_.FullName -notmatch "\\presentation\\state\\" } | Select-String -Pattern 'normalizeForSearch|search[A-Z]\w*\(|\.where\(|\.sort\(|firstWhere|jsonDecode|rootBundle|Timer|Future\.delayed' -CaseSensitive
```

### 5.3 Migraciones, Semillas y Suite pgTAP (Supabase)
```powershell
# Verificar estado de las 14 migraciones frente a Supabase Cloud
supabase migration list

# Reiniciar base local (migraciones + semillas) y correr las 9 suites pgTAP (168 aserciones)
supabase db reset
supabase test db

# Ejecutar pruebas unitarias y de contrato HTTP de la Edge Function analyze_contract
deno test supabase/functions/analyze_contract/contract_analyzer_test.ts
```

---

## 6. Documentación Clave del Repositorio

- **Arquitectura y Modelo de Datos:** [`docs/arquitectura.md`](docs/arquitectura.md) | [`docs/contrato-datos-v1.md`](docs/contrato-datos-v1.md) | [`docs/modelo-er.puml`](docs/modelo-er.puml)
- **Seguridad, Privacidad y Backups:** [`docs/seguridad-privacidad.md`](docs/seguridad-privacidad.md) | [`docs/backend/guia-respaldo-restauracion.md`](docs/backend/guia-respaldo-restauracion.md)
- **Pruebas y Trazabilidad:** [`docs/pruebas/matriz-rf-casos.md`](docs/pruebas/matriz-rf-casos.md)
- **Entrega Android, Manual y Sustentación:** [`docs/release-android.md`](docs/release-android.md) | [`docs/manual-usuario.md`](docs/manual-usuario.md) | [`docs/guia-demo.md`](docs/guia-demo.md)
- **Estado del MVP y Dictamen Go/No-Go:** [`docs/implementacion/progreso-mvp.md`](docs/implementacion/progreso-mvp.md)
