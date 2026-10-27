# Arquitectura del Sistema — Vía Justa MVP

## 1. Principios de Arquitectura

El proyecto adopta una arquitectura en capas limpias y ligeras (adaptación de Clean / Hexagonal Architecture para Flutter), con flujo de dependencias unidireccional hacia el dominio:

```text
       ┌────────────────────────┐
       │      Presentation      │  (Pages, Widgets, Riverpod Notifiers)
       └───────────┬────────────┘
                   │ depende de
                   ▼
       ┌────────────────────────┐
       │         Domain         │  (Entities, Value Objects, Pure Validators, Repository Interfaces)
       └───────────▲────────────┘
                   │ implementa
       ┌───────────┴────────────┐
       │          Data          │  (Repository Implementations, Local JSON, Supabase Adapters)
       └────────────────────────┘
```

### Reglas Innegociables de Dependencia
1. **Presentation -> Domain:** Las pantallas y widgets solo conocen entidades, casos de uso/funciones puras e interfaces de repositorios. NUNCA importan la capa `data/`.
2. **Domain es Dart puro:** No contiene dependencias de Flutter (`BuildContext`, `Widget`), ni de librerías externas de persistencia o red (`supabase_flutter`, `http`). Es 100% testeable con pruebas unitarias rápidas.
3. **Data -> Domain:** Las implementaciones concretas de acceso a datos implementan las interfaces del dominio y transforman estructuras de transporte (JSON, tablas SQL) a entidades de negocio.

---

## 2. Gestión de Estado con Riverpod 3

El estado de la aplicación se orquesta con **Riverpod 3** siguiendo convenciones estrictas:
- **`Notifier` / `NotifierProvider`:** Para estado mutable controlado y formularios (e.g. `LoginFormNotifier`, `ProfileTypeNotifier`).
- **`FutureProvider` / `FutureProvider.family`:** Para operaciones asíncronas de lectura de datos (e.g. `municipalitiesByDepartmentProvider`).
- **`Provider`:** Para inyección de dependencias (repositorios abstractos, combinadores de providers y configuración).
- **`.autoDispose`:** Obligatorio en pantallas y formularios efímeros para evitar fugas de memoria o persistencia accidental de estados previos.
- **Prohibición expresa:** No se utilizan `StateProvider`, `StateNotifierProvider` ni `ChangeNotifierProvider`.

---

## 3. Enrutamiento y Navegación con GoRouter

Todas las rutas del aplicativo se definen y administran de forma centralizada en [`lib/core/router/app_router.dart`](file:///C:/Users/JUAN/Antigravity%20IDE/via-justa/lib/core/router/app_router.dart):
- **`AppRoutes`:** Constantes de rutas y métodos auxiliares para paths parametrizados (`municipalityPath(code)`).
- **Estrategia de Navegación:**
  - `context.go`: Se reserva exclusivamente para cambios de raíz donde no debe existir retorno en el stack (e.g. desde splash al flujo inicial, o logout hacia `/welcome`).
  - `context.push`: Para navegación jerárquica o drill-down donde el usuario puede regresar libremente.
- **Transición a ShellRoute (VJ-03):** La barra inferior fija de 5 pestañas (`Inicio`, `Mapa`, `Escanear`, `Negocios`, `Perfil`) se implementará mediante una estructura `ShellRoute` en la tarea VJ-03.

---

## 4. Patrón Repositorio y Fuentes de Datos Intercambiables

Para cumplir con el principio de no acoplar la interfaz al backend:
1. La interfaz vive en `domain/` (ej. `MunicipalityRepository`).
2. La implementación inicial de demostración vive en `data/` (ej. `LocalMunicipalityRepository`).
3. El provider `municipalityRepositoryProvider` es el **único** punto de enlace.
4. Cuando se conecte Supabase en VJ-07/VJ-09, se sustituirá la instancia retornada por el provider por `SupabaseMunicipalityRepository` sin modificar una sola línea de código en las vistas.

---

## 5. Internacionalización y Textos

- Todo texto visible en interfaz se resuelve mediante `easy_localization` con el método `'clave'.tr()`.
- Estructura de claves jerárquica: `modulo.seccion.elemento` (ej. `municipality.pilot_available`).
- **Paridad estricta:** Toda clave debe existir en `assets/translations/es.json` y `assets/translations/en.json`.
- El test automatizado `test/translations_test.dart` garantiza la paridad total de claves entre ambos idiomas.
- Español (`es`) actúa como fallback general.
- Los nombres propios y datos geográficos oficiales (ej. "Valledupar", "Cesar") se tratan como datos y no se traducen.

---

## 6. Sistema de Diseño, Tokens y Accesibilidad

- **Tokens centralizados:**
  - Colores: [`lib/core/theme/app_colors.dart`](file:///C:/Users/JUAN/Antigravity%20IDE/via-justa/lib/core/theme/app_colors.dart). Los colores verde, ámbar y rojo están reservados exclusivamente para el semáforo de justicia.
  - Espaciados y Radios: [`lib/core/theme/app_spacing.dart`](file:///C:/Users/JUAN/Antigravity%20IDE/via-justa/lib/core/theme/app_spacing.dart) (incluye `AppRadius`).
  - Tema: [`lib/core/theme/app_theme.dart`](file:///C:/Users/JUAN/Antigravity%20IDE/via-justa/lib/core/theme/app_theme.dart).
- **Reglas de Accesibilidad y Responsividad:**
  - Blanco táctil mínimo de 48x48 dp.
  - Diseño adaptable sin desbordes a 360 dp de ancho y compatible con configuraciones de accesibilidad de escala de fuente aumentada.
  - Semántica explícita (`Semantics` / `Tooltip`) en elementos interactivos complejos.
  - El semáforo de precios nunca comunicará su estado únicamente por color: siempre combinará color, texto e icono.

---

## 7. Control de Higiene y Prevención de Lógica en Vistas

De acuerdo con la regla 5.2 de `AGENTS.md`, las vistas (`presentation/pages/` y `presentation/widgets/`) no pueden contener lógica de negocio, filtros, cálculos ni llamadas a repositorios.

**Expresión regular de auditoría:**
```regex
normalizeForSearch|search[A-Z]\w*\(|\.where\(|\.sort\(|firstWhere|jsonDecode|rootBundle|Timer|Future\.delayed
```
Ningún widget debe coincidir con este patrón, excepto excepciones temporales explícitamente documentadas (e.g. animación o timer transitorio de splash).
