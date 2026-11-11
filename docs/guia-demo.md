# Guion de Sustentación Final (7 Minutos) y Plan B — Vía Justa MVP

> **Documento:** `docs/guia-demo.md` (Cierre `VJ-21`)  
> **Duración objetivo:** 7 minutos exactos (sustentación en vivo) + ronda de preguntas  
> **Ciudad piloto:** Valledupar, Cesar (`20001`)  
> **Alcance:** Recorrido de extremo a extremo con backend Supabase (`vjehsjqmwibmiqmxlsou`) y contingencia **Plan B sin internet** claramente rotulada como `DEMO`.

---

## 1. Preparación Previa (5 minutos antes de pasar al frente)

1. **Dispositivo Android físico** conectado por USB o proyectado con `scrcpy`, con batería $> 50\%$, modo **No molestar** activo y brillo al 80%.
2. **Verificación rápida de conectividad y backend:**
   - Conexión Wi-Fi o datos móviles activa (y hotspot móvil listo como respaldo).
   - Proyecto Supabase `via-justa` (`vjehsjqmwibmiqmxlsou`) activo con las 14 migraciones aplicadas y semillas cargadas.
3. **Insumos listos en el teléfono:**
   - Cuenta de prueba verificada (o correo listo para registro en vivo).
   - Una imagen impresa o en galería de un **contrato de arrendamiento de vivienda urbana** para la captura con cámara/galería y OCR local con ML Kit.
   - Pestaña de terminal lista con resultados de pruebas (`flutter test`, `supabase test db`, `deno test`) por si el jurado solicita evidencia de pruebas automatizadas.

---

## 2. Cronograma Minuto a Minuto (7:00 Minutos — Flujo Principal con Datos Reales)

### Minuto `0:00 – 1:00` | Problema, Propuesta de Valor, Auth Real y Selección de Valledupar
- **Qué decir:**
  > *"Quien llega a una ciudad como turista o a instalarse enfrenta dos asimetrías críticas: desconocer cuánto cuesta realmente un servicio según el sector de la ciudad y firmar contratos de arriendo con cláusulas lesivas. Vía Justa resuelve ambos problemas con una arquitectura Android en 3 capas estrictas y backend en Supabase PostgreSQL/PostGIS."*
- **Qué mostrar en pantalla:**
  1. Pantalla de bienvenida (`M01`) y login/registro con **Supabase Auth** (`M16`), mostrando la aceptación auditable de Términos y Política de Privacidad (`public.consents`, Ley 1581).
  2. Selección de perfil en `M02` (**Visitante**, **Instalación** o **Residente** — `D11` ratificada en base de datos).
  3. Mapa departamental (`M03` → Cesar `20`) y selector de los 25 municipios (`M13`) con búsqueda sin tildes:
     - Tocar brevemente un municipio no piloto (ej. *Aguachica*, `M15`) para evidenciar transparencia: no se inventan datos y permite registrar interés (`public.interest_registrations`).
     - Entrar al municipio piloto **Valledupar (`20001`, `M14`)**.

---

### Minuto `1:00 – 2:30` | Semáforo Estadístico de Precios por Zona (Nunca IA)
- **Qué decir:**
  > *"Nuestra primera regla innegociable es que el semáforo de precios jamás lo decide un modelo de IA: se calcula en PostgreSQL mediante la función `calculate_price_verdict` usando la mediana (`percentile_cont(0.5)`) de los últimos 60 días segmentada por las 5 zonas urbanas de Valledupar, con muestra mínima $N \ge 3$."*
- **Qué mostrar en pantalla:**
  1. En la pestaña **Escanear → Precios** (`M06`), usar el selector de zona por GPS o mapa interactivo para elegir **Zona Centro (`vup_centro`)** y la categoría **Carrera mínima de taxi**.
  2. **Caso Verde (`green`, $\le +15\%$):** Evaluar `$9.000 COP` → mostrar tarjeta `M07` con triple canal de accesibilidad (color verde + ícono + etiqueta textual), mediana zonal y tope recomendado (`+15%`).
  3. **Caso Rojo (`red`, $> +40\%$):** Evaluar `$18.000 COP` → mostrar alerta roja, porcentaje exacto de desviación y recomendación de cotizar antes de tomar el servicio.
  4. **Caso Muestra Insuficiente (`insufficient`, $N < 3$, `M20`):** Cambiar a una combinación sin 3 muestras recientes para demostrar que cuando $N < 3$ el sistema responde en gris neutro sin inventar colores.

---

### Minuto `2:30 – 3:30` | Aporte Ciudadano de Precio en 4 Pasos y Privacidad Geoespacial
- **Qué decir:**
  > *"Para nutrir la mediana comunitaria sin permitir abusos ni rastrear domicilios, el aporte ciudadano pasa por un wizard de 4 pasos y por el trigger `enforce_price_report_submission_rules` en PostgreSQL."*
- **Qué mostrar en pantalla:**
  1. Tocar **Aportar precio** (`M10`):
     - **Paso 1:** Seleccionar *Almuerzo corriente / ejecutivo*.
     - **Paso 2:** Ingresar `$15.000 COP` (validado entre `$500` y `$20.000.000 COP`).
     - **Paso 3:** Elegir **Zona Norte (`vup_norte`)**.
     - **Paso 4:** Agregar nota `"Observado en zona comercial"` y confirmar.
  2. Destacar ante el jurado las 3 defensas activas en base de datos:
     - **Redondeo de coordenadas GPS a 3 decimales ($\approx 110\text{ m}$)** en servidor para proteger la privacidad.
     - **Bloqueo de duplicados en 15 minutos** (`[PRICE_DUPLICATE_REPORT]`) y **límite de 10 reportes cada 24h** (`[PRICE_RATE_LIMITED]`) serializados con `pg_advisory_xact_lock`.

---

### Minuto `3:30 – 5:00` | Captura de Contrato con OCR Local (ML Kit) + Análisis con Gemini (`RN-10`)
- **Qué decir:**
  > *"En contratos aplicamos privacidad por diseño (`RN-10`): el reconocimiento óptico (OCR) ocurre 100% en el dispositivo con Google ML Kit, borrando el archivo temporal en un bloque `finally`. Luego, previo segundo consentimiento, la Edge Function `analyze_contract` consulta Gemini con esquema JSON estricto, defensa contra Prompt Injection y cero persistencia del texto del contrato."*
- **Qué mostrar en pantalla:**
  1. Cambiar al segmento **Contratos** en `M06`.
  2. Mostrar el **primer consentimiento de OCR local**, capturar imagen de contrato (o cargar muestra sintética con cláusula lesiva) y evidenciar el texto extraído editable en memoria (límite 15.000 caracteres).
  3. Pulsar **Analizar contrato**, aceptar el **segundo consentimiento informado** y mostrar el resultado estructurado (`ContractAnalysisResultView`):
     - Semáforo global del contrato (`Amarillo` o `Rojo`).
     - Puntos clave del acuerdo.
     - Cláusula riesgosa citada literalmente con su recomendación y referencia verificada a la **Ley 820 de 2003** (filtrada por lista blanca en servidor para impedir leyes alucinadas).
     - Disclaimer jurídico visible y control de cuota atómica de **5 análisis diarios por usuario** (`consume_ai_daily_quota` con reembolso automático si el proveedor falla).

---

### Minuto `5:00 – 6:15` | Vista Cultural de Valledupar + Directorio, Registro y Moderación de Negocios
- **Qué decir:**
  > *"Vía Justa también integra al visitante y al comerciante local: ofrece una guía cultural verificada de Valledupar con fuentes oficiales y un directorio de negocios donde cualquier comercio nuevo entra en estado `pending` hasta ser moderado."*
- **Qué mostrar en pantalla:**
  1. **Vista cultural de Valledupar (`M18` — `VJ-15`):** Mostrar las tarjetas de patrimonio vallenato (UNESCO), lugares emblemáticos, gastronomía y líneas de emergencia con su cita de fuente oficial y soporte bilingüe `es`/`en`.
  2. **Directorio y Ficha de Detalle (`M21` y `M09` — `VJ-17`):**
     - Buscar un comercio en la pestaña **Negocios** (búsqueda insensible a tildes con `unaccent`).
     - Abrir la ficha de detalle con sus platos destacados en COP y botones de acción externa (**Llamar**, **WhatsApp** con mensaje RFC 3986 codificado y **Cómo llegar en Google Maps**).
  3. **Registro en 4 pasos y Moderación (`M19` — `VJ-16`):**
     - Mostrar el wizard de 4 pasos y explicar que `submit_business` fuerza `status = 'pending'`, que el bucket `business-media` es privado con validación de MIME real y que ningún usuario puede autoaprobar su propio negocio (`[MODERATION_SELF_REVIEW]`).

---

### Minuto `6:15 – 7:00` | Cambio de Idioma en Vivo (`ES`/`EN`), Habeas Data (`RF-06`) y Cierre
- **Qué decir:**
  > *"Finalmente, toda la aplicación y los catálogos del backend operan en Español e Inglés en tiempo real, y cumplimos el derecho de supresión de la Ley 1581 mediante un protocolo transaccional de 5 fases."*
- **Qué mostrar en pantalla:**
  1. Ir a la pestaña **Perfil (`M17`)** y conmutar el idioma de **Español (`ES`)** a **Inglés (`EN`)** en vivo, mostrando la paridad inmediata de textos y etiquetas.
  2. Mostrar la opción de **Cierre de sesión / Eliminación de cuenta (`delete_my_account`)**, explicando que antes de borrar `auth.users` el servidor limpia notas, nombres de lugar y coordenadas GPS de los reportes de precios para proteger la privacidad sin destruir la mediana estadística.

---

## 3. Plan B de Contingencia (Sustentación Sin Internet o Caída de Red)

Si durante la presentación en el aula falla el Wi-Fi institucional, la señal celular o un servicio externo, **no se improvisa ni se oculta**: Vía Justa cuenta con un **Modo DEMO Offline** arquitectónicamente desacoplado mediante repositorios en memoria y activos locales verificados.

### Cómo activar y presentar el Plan B en menos de 15 segundos
1. **Declaración transparente al jurado:**
   > *"Dado que la red del recinto presenta intermitencia, activamos el flujo de respaldo offline de Vía Justa. Como pueden observar en los banners superiores `[DEMO]`, la aplicación utiliza exactamente las mismas reglas puras de dominio (`evaluatePriceSample`, validadores de 4 pasos y OCR local en el dispositivo) sobre el conjunto de datos semilla de Valledupar."*
2. **Qué sigue funcionando al 100% sin internet:**
   - **Recorrido completo de navegación (`M01` → `M21`):** Onboarding de los 3 perfiles, mapa de departamentos, buscador de los 25 municipios del Cesar (`assets/data/municipalities_cesar.json`) y distinción Piloto vs. No Piloto.
   - **Semáforo de precios por las 5 zonas de Valledupar (`DemoPriceVerdictRepository`):** Ejecuta la misma fórmula de mediana, umbrales `15%`/`40%`, alerta `<-40%` y estado insuficiente $N < 3$.
   - **Wizard de 4 pasos para aportar precio (`DemoPriceContributionRepository`):** Valida cada paso en `domain/` y registra el aporte en la sesión de demostración.
   - **OCR Local de Contratos con ML Kit (`VJ-13`) + 3 Contratos Sintéticos (`DemoContractAnalysisGateway`):** El OCR de cámara/imagen con ML Kit **no requiere internet** porque el modelo latino corre en el procesador del teléfono; a continuación, el gateway de demostración permite exhibir los 3 dictámenes (`Verde`, `Amarillo` y `Rojo`) rotulados como `[DEMO]`.
   - **Directorio de negocios y cambio de idioma `ES`/`EN` en vivo.**
3. **Evidencia técnica complementaria en laptop (sin depender del Wi-Fi):**
   - Mostrar las migraciones SQL en [`supabase/migrations/`](../supabase/migrations/), la matriz de trazabilidad en [`docs/pruebas/matriz-rf-casos.md`](pruebas/matriz-rf-casos.md) y la suite de 9 archivos pgTAP en [`supabase/tests/`](../supabase/tests/).

---

## 4. Preguntas Frecuentes del Jurado (Q&A Rápido)

1. **¿Por qué usan la mediana por zona y no el promedio municipal o IA para los precios?**
   - Porque un promedio simple se distorsiona fácilmente con un solo cobro abusivo (*outlier*), y una cifra única para toda la ciudad mezclaría sectores turísticos o comerciales (Zona Norte / Hurtado) con sectores populares. La mediana (`PERCENTILE_CONT(0.5)`) por zona con ventana de 60 días y mínimo $N \ge 3$ es auditable, determinista y resistente a valores extremos.
2. **¿Cómo garantizan que el texto de un contrato privado no quede guardado ni expuesto?**
   - Por diseño (`RN-10`): no existe ninguna tabla ni bucket en PostgreSQL para almacenar contratos. El OCR ocurre en el teléfono, el archivo temporal se elimina en un bloque `finally`, y la Edge Function `analyze_contract` procesa el texto en memoria RAM y solo incrementa el contador numérico `(user_id, day, count)` en `public.ai_usage`.
3. **¿Cómo evitan que un usuario malintencionado infle precios, suba archivos falsos o apruebe su propio negocio?**
   - Mediante validación de doble barrera (`domain/` en Flutter + triggers `SECURITY DEFINER` y RLS en PostgreSQL): `submit_price_report` aplica bloqueo transaccional (`pg_advisory_xact_lock`), enfriamiento de 15 min contra duplicados y tope de 10 reportes/día; el bucket privado `business-media` verifica el MIME real en `storage.objects.metadata`; y tanto `moderate_business` como `moderate_price_report` bloquean la automoderación con `[MODERATION_SELF_REVIEW]`.
