# Guía de Sustentación y Walkthrough del Primer Avance (VJ-06)

**Versión:** 1.0 · Cierre del Primer Avance (Semana 1)  
**Cobertura:** Tareas `VJ-00` a `VJ-06` (Mockups `M01`–`M08`, `M10`, `M13`–`M17`, `M20` y `M21`)  
**Prueba automatizada E2E:** `test/first_milestone_walkthrough_test.dart`

---

## 1. Guion de Sustentación en 7 Minutos (Sección 3.7 del Plan de Trabajo)

| Minuto | Qué se muestra en el teléfono / repositorio | Qué decir en voz alta (mensajes clave y honestidad de alcance) |
|---|---|---|
| **0:00 – 1:00** | Contexto del problema y pantalla de bienvenida (`M01` — `/welcome`) | *"Durante eventos de alta afluencia en Valledupar como el Festival Vallenato, mientras la tarifa mínima oficial de taxi urbano era de \$8.300 COP, se reportaron cobros de \$70.000 a \$100.000 COP a visitantes y migrantes. Vía Justa nace para que nadie llegue a una ciudad colombiana sin saber qué es un precio o un contrato justo."* |
| **1:00 – 2:00** | Onboarding de perfiles (`M02` — `/onboarding`): Visitante, Instalación y Residente | *"El núcleo de precios de Vía Justa es una regla estadística verificable —mediana comunitaria por zona del municipio en ventana de 60 días con mínimo $N \ge 3$ reportes—, nunca una caja negra de IA. La IA (Gemini en Edge Function) se reserva únicamente para explicar cláusulas de contratos en lenguaje claro."* |
| **2:00 – 3:15** | Mapa de departamentos (`M03` — `/departments`) → Cesar (`20`) → Buscador sin tildes (`M13` — `/department/20`) → Aguachica no piloto (`M15`) y Valledupar piloto (`M14`) | *"Este primer avance corre con datos de ejemplo locales (DEMO). Si el usuario busca sin tildes en los 25 municipios del Cesar y entra a un municipio aún no verificado como Aguachica, recibe un aviso honesto y puede registrar su interés ('Te avisaremos'). Al elegir Valledupar (municipio piloto), ingresa a la experiencia principal."* |
| **3:15 – 4:30** | Shell de 5 pestañas (`Inicio`, `Mapa`, `Escanear`, `Negocios`, `Perfil`) → `Escanear` (`M06`) → Selector de Zona (GPS / Mapa) → Resultado del Semáforo (`M07` y `M20`) → Aportar Precio en 4 pasos (`M10`) | *"Las medianas no son planas para todo el municipio: cambian según la zona de Valledupar (Norte, Centro, Sur, Oriente, Occidente). La app solicita permiso para detectar la zona por GPS o permite tocarla manualmente en el mapa. En el resultado probamos los 4 estados: Verde ($\le +15\%$), Ámbar ($+15.01\%$ a $+40\%$), Rojo ($> +40\%$) y Muestra Insuficiente ($N < 3$, sin color ni tope). Luego abrimos el wizard de 4 pasos para aportar un precio y en Perfil cambiamos el idioma en vivo entre Español e Inglés."* |
| **4:30 – 5:30** | Diagrama de arquitectura (`docs/arquitectura.md`, `docs/modelo-er.puml` y `docs/contrato-datos-v1.md`) | *"Toda la app sigue arquitectura en 3 capas estrictas (`presentation` → `domain` ← `data`). Las vistas no contienen `.where`, `.sort`, cálculos ni validaciones; todo vive en funciones puras de `domain/` probadas unitariamente y verificadas en CI."* |
| **5:30 – 6:30** | Tablero Maestro (`docs/implementacion/progreso-mvp.md`) y Pipeline CI (`.github/workflows/ci.yml`) | *"En Semana 2 conectamos Supabase Auth y mapa SVG real; en Semana 3 la función SQL del semáforo y Google Maps; en Semana 4 OCR + Gemini para contratos; en Semana 5 cultura de Valledupar y registro de negocios."* |
| **6:30 – 7:00** | Cierre y preguntas al profesor (`docs/decisiones.md`) | *"Validar con el profesor el alcance congelado del MVP y la incorporación opcional de tarifa oficial regulada como referencia junto a la mediana comunitaria."* |

---

## 2. Rutas del Código por Funcionalidad (Guía de Defensa ante el Profesor)

> En la sustentación el profesor verifica que **no exista lógica de negocio en las vistas** y pregunta en qué archivo ocurre cada regla. Esta tabla resume la trazabilidad exacta de cada flujo implementado hasta `VJ-06`:

| Funcionalidad | Pantalla / Widget (`presentation/pages` o `widgets`) | Provider (`presentation/state`) | Función Pura / Regla (`domain`) | Repositorio / Fuente (`data` y `assets`) |
|---|---|---|---|---|
| **1. Validar login y registro** | `LoginPage` / `RegisterPage` | `loginFormProvider` / `registerFormProvider` | `validateEmail`, `validatePassword`, `validateName` (`auth_validators.dart`) | En memoria (`SessionController` DEMO; Supabase Auth en `VJ-08`) |
| **2. Seleccionar perfil de usuario** | `ProfileSelectionPage` / `ProfilePage` | `profileTypeProvider` (`ProfileTypeNotifier`) | `ProfileType` (`visitor`, `settler`, `resident`) | En memoria durante la sesión (`profile_type_provider.dart`) |
| **3. Buscar departamento en el mapa** | `MapPage` | `filteredDepartmentsProvider`, `selectedDepartmentProvider` | `searchDepartments` (`department_search.dart`) + `normalizeForSearch` | `colombiaDepartments` (`departments_data.dart`) |
| **4. Buscar municipio sin tildes ni mayúsculas** | `MunicipalitySelectorPage` | `filteredMunicipalitiesProvider` | `searchMunicipalities` (`municipality_search.dart`) + `normalizeForSearch` | `LocalMunicipalityRepository` → `assets/data/municipalities_cesar.json` |
| **5. Municipio piloto vs. fuera del piloto ("Notificarme")** | `MunicipalityPage` | `municipalityByCodeProvider`, `municipalityInterestProvider` | `Municipality.isPilot` (`municipality.dart`) | `LocalMunicipalityRepository` + `MunicipalityInterestNotifier` (memoria) |
| **6. Detectar zona del municipio (GPS o toque en mapa)** | `PriceScanPage` / `ContributePricePage` → `ZoneMapPickerCard` | `priceScanProvider` / `priceContributionProvider`, `municipalityZonesProvider` | `resolveNearestZoneByNormalizedPoint` (`municipality_zone.dart`) | `DemoPriceVerdictRepository` (`getZones`, `detectCurrentZoneByGps`) |
| **7. Evaluar precio en el motor estadístico del semáforo (`M06` → `M07`/`M20`)** | `PriceScanPage` → `PriceResultPage` → `PriceVerdictCard` | `priceScanProvider` (`PriceScanNotifier.submitEvaluation` / `evaluateScenario`) | `evaluatePriceSample`, `calculateMedianCop`, `parseCopAmount` (`price_verdict.dart`) | `DemoPriceVerdictRepository` (`demo_price_verdict_repository.dart`) |
| **8. Aportar un precio en 4 pasos (`M10`)** | `ContributePricePage` | `priceContributionProvider` (`PriceContributionNotifier`) | `isValidContributionCategory`, `validateContributionAmount`, `isValidContributionZone`, `sanitizeContributionNote` (`price_contribution.dart`) | `DemoPriceContributionRepository` (`demo_price_contribution_repository.dart`) |
| **9. Filtrar mapa local de precios, servicios y consulados (`M08`)** | `PriceMapPage` | `filteredPriceMapItemsProvider`, `priceMapCategoryProvider`, `priceMapSearchQueryProvider` | `filterPriceMapItems` (`price_map_filter.dart`) | `LocalPriceMapRepository` (`local_price_map_repository.dart`) |
| **10. Mostrar resumen educativo de contrato (`M06` pestaña Contratos)** | `ScanPage` → `DemoContractSummary` | `demoContractAnalysisProvider` | `ContractAnalysisDemo`, `ContractClauseIssue` (`contract_analysis_demo.dart`) | `DemoContractAnalysisRepository` (`demo_contract_analysis_repository.dart`) |
| **11. Filtrar directorio de negocios locales (`M21`)** | `BusinessesPage` | `filteredBusinessesProvider`, `businessCategoryProvider`, `businessSearchQueryProvider` | `filterBusinesses` (`business_filter.dart`) | `LocalBusinessRepository` (`local_business_repository.dart`) |
| **12. Cerrar sesión y limpiar estado DEMO** | `ProfilePage` | `sessionControllerProvider` (`SessionController.signOut`) | Reinicio de notifiers de sesión y limpieza de aportes en memoria | `SessionController` (`lib/core/session/session_providers.dart`) |

---

## 3. Declaración Honesta de Estado (Criterio 3.7 y 3.8 del Plan)

| Módulo / Funcionalidad | Estado en el Cierre del Primer Avance (`VJ-06`) | Cuándo se conecta al Backend / Servicios Reales |
|---|---|---|
| **Autenticación, Onboarding y Perfiles (`M01`, `M02`, `M16`, `M17`)** | **Implementado (interfaz con datos de ejemplo DEMO en memoria)** | **Semana 2 (`VJ-08`)**: Supabase Auth real (correo y Google) + tabla `public.profiles` y `public.consents`. |
| **Mapa de Colombia y Selector de Municipios (`M03`, `M13`, `M14`, `M15`)** | **Implementado (óvalos provisionales + 25 municipios de Cesar en JSON local)** | **Semana 2 (`VJ-09`)**: Geometría SVG oficial DANE + tabla `public.municipalities` e `public.interest_registrations`. |
| **Motor de Semáforo de Precios por Zona (`M06`, `M07`, `M20`)** | **Implementado (motor estadístico puro en Dart + muestras DEMO por zona de Valledupar)** | **Semana 3 (`VJ-10` y `VJ-11`)**: RPC PostgreSQL `public.evaluate_price_verdict` como única fuente de verdad. |
| **Aportar Precio en 4 Pasos (`M10`)** | **Implementado (wizard de 4 pasos con validación en `domain/` y guardado DEMO en sesión)** | **Semana 3 (`VJ-11`)**: Inserción autenticada en `public.price_reports` con límite diario e índice PostGIS. |
| **Mapa Local de Precios y Servicios (`M08`)** | **Implementado (lienzo urbano interactivo DEMO con filtros y pines accesibles)** | **Semana 3 (`VJ-12`)**: SDK `google_maps_flutter` con consulta acotada por viewport. |
| **Análisis de Contratos (`M06` pestaña Contratos)** | **Implementado (demostración educativa rotulada sin captura ni envío de documentos)** | **Semana 4 (`VJ-13` y `VJ-14`)**: Cámara/archivos + ML Kit OCR local + Edge Function con Gemini (`RN-10`). |
| **Directorio y Registro de Negocios (`M21`, `M09`, `M19`)** | **Implementado catálogo DEMO (`M21`); detalle (`M09`) y registro (`M19`) planificados** | **Semana 5 (`VJ-16` y `VJ-17`)**: Formulario en 4 pasos, moderación `pending`/`approved` y enlaces WhatsApp (`wa.me`). |
| **Vista Cultural de Valledupar (`M18`)** | **Planificado** | **Semana 5 (`VJ-15`)**: Contenido cultural bilingüe `es`/`en` con fuentes citadas desde `public.city_content`. |
| **Trámites (`M11`), Documentos (`M12`) y Conversor (`M16`)** | **Rotulados como "Próximamente" / Fase 2 (no se simula almacenamiento ni cifrado)** | Bolsa *"si hay tiempo"* o Fase 2. |

---

## 4. Comandos Rápidos para Demostración en Vivo

```powershell
# 1. Ejecutar análisis estático y suite completa de pruebas antes de presentar
flutter analyze
flutter test

# 2. Ejecutar únicamente la prueba E2E del recorrido del Primer Avance
flutter test test/first_milestone_walkthrough_test.dart

# 3. Correr la app en un teléfono Android real o emulador
flutter run -d <device-id> --no-pub
```
