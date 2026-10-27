# Registro de Decisiones de Arquitectura y Producto

Este documento centraliza las decisiones arquitectónicas y técnicas (ADRs) adoptadas para el desarrollo del MVP de Vía Justa, distinguiendo formalmente entre decisiones [Acordadas], [Propuestas] y [Pendientes].

---

## D1 · Soporte bilingüe en español e inglés desde el inicio
- **Fecha:** 19 de octubre de 2026
- **Estado:** [Acordado]
- **Efecto:** Todo texto presentado al usuario debe gestionarse mediante internacionalización; prohibido el texto estático en duro (*hardcoded*).
- **Justificación:** Los perfiles de usuarios (turistas extranjeros, migrantes y locales) demandan paridad bilingüe inmediata.

## D2 · Gestión de internacionalización con `easy_localization`
- **Fecha:** 19 de octubre de 2026
- **Estado:** [Acordado]
- **Efecto:** Archivos de traducción en `assets/translations/es.json` y `assets/translations/en.json` con claves idénticas y prueba automatizada de paridad terminal.

## D3 · Uso de Google Maps (`google_maps_flutter`) y Places
- **Fecha:** 19 de octubre de 2026
- **Estado:** [Acordado]
- **Efecto:** Requiere cuenta de Google Cloud Platform (GCP) con facturación, APIs habilitadas y clave de Android restringida por paquete y huella SHA-1.
- **Alternativa para avance:** Si las credenciales no están listas en la fase preliminar, se usará un mapa estático de muestra debidamente rotulado como DEMO.

## D4 · Backend en Supabase (PostgreSQL, PostGIS, Auth, Storage, Edge Functions)
- **Fecha:** 19 de octubre de 2026
- **Estado:** [Propuesto - Pendiente ratificación con compañero de backend]
- **Efecto:** Centraliza base de datos relacional y geoespacial, autenticación, almacenamiento multimedia de negocios y funciones sin servidor para el análisis con LLM.

## D5 · Gestión de estado con Riverpod y navegación declarativa con `go_router`
- **Fecha:** 19 de octubre de 2026
- **Estado:** [Acordado]
- **Efecto:** Estado desacoplado de la interfaz por funcionalidad; rutas centralizadas en `lib/core/router/app_router.dart`.
- **Regla:** Uso estricto de Riverpod 3 (`Notifier`, `Provider`, `FutureProvider`); prohibido el uso de `StateProvider` o `ChangeNotifierProvider`.

## D6 · Negocios sin pedidos internos
- **Fecha:** 19 de octubre de 2026
- **Estado:** [Acordado]
- **Efecto:** La app no procesa transacciones comerciales ni cobros dentro de la plataforma; el botón de pedido redirige a enlaces externos del propio comercio.

## D7 · Contacto por WhatsApp sin chat interno
- **Fecha:** 19 de octubre de 2026
- **Estado:** [Acordado]
- **Efecto:** El contacto entre usuarios y negocios se realiza mediante enlaces `wa.me` externos con mensaje prellenado en el idioma seleccionado.

## D8 · Arquitectura por capas ligeras y agente de código con archivo de reglas
- **Fecha:** 19 de octubre de 2026
- **Estado:** [Propuesto / Aplicado en código]
- **Efecto:** Estructuración estricta en capas `presentation/`, `domain/` y `data/`. Reglas operativas documentadas en `AGENTS.md`. Prohibida la lógica de negocio en las vistas.

## D9 · Gemini como proveedor de LLM para contratos
- **Fecha:** 19 de octubre de 2026
- **Estado:** [Acordado]
- **Efecto:** El análisis de cláusulas de contratos se delega al modelo Gemini mediante invocación segura desde una Edge Function. La API Key nunca reside en el cliente móvil.

## D10 · Un único repositorio, ramas cortas por tarea y PR con revisión
- **Fecha:** 19 de octubre de 2026
- **Estado:** [Acordado]
- **Efecto:** Rama `main` protegida; cada tarea abre una rama específica y se integra mediante Pull Request revisado por el otro integrante.

## D11 · Tercer perfil "Local / Residente" (`profile_type = resident`)
- **Fecha:** 25 de octubre de 2026
- **Estado:** [Propuesto - Falta confirmación con compañero de backend]
- **Qué cambia:** El onboarding ofrece tres perfiles: `visitor`, `settler` y `resident`. El valor `resident` debe aceptarse en el constraint o enum `profiles.profile_type` antes de cerrar la migración 0001 de base de datos.
- **Motivo:** El profesor solicitó que los usuarios puedan registrar negocios locales (restaurantes, bandas, etc.). Quien registra suele ser residente local y los perfiles de Visitante e Instalación no representan adecuadamente esa realidad.
- **Alternativa descartada:** Mantener únicamente dos perfiles y forzar a los dueños locales a encajar en Visitante o Instalación.
- **Notas:** Registrar un negocio no es un tipo de cuenta restringido: cualquier perfil podrá solicitar el registro desde la pestaña Negocios. El inicio temporal para `resident` en el primer avance se equiparará a `settler` con una marca `TODO(D11)`.
