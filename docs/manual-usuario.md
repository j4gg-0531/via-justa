# Manual de Usuario — Vía Justa MVP

> **Versión:** 1.0 (Cierre `VJ-21`)  
> **Plataforma:** Android (API 24+ / Android 7.0 o superior)  
> **Idiomas soportados:** Español (`es`) e Inglés (`en`) con cambio en vivo  
> **Ciudad piloto activa:** Valledupar, Cesar (`20001`)

---

## 1. ¿Qué es Vía Justa?

**Vía Justa** es una aplicación móvil ciudadana diseñada para que visitantes, personas en proceso de instalación y residentes locales en ciudades colombianas puedan:
1. **Consultar precios justos por zona urbana** mediante una regla estadística transparente (mediana comunitaria de los últimos 60 días), nunca una caja negra.
2. **Aportar precios reales** observados en el terreno para fortalecer la referencia comunitaria.
3. **Analizar contratos de arrendamiento o servicios** mediante reconocimiento óptico de caracteres (OCR) en el dispositivo e inteligencia artificial orientativa, sin almacenar el documento en ningún servidor.
4. **Conocer la cultura, patrimonio, gastronomía y líneas de emergencia** verificadas de la ciudad piloto (**Valledupar**).
5. **Explorar y registrar comercios locales** verificados con contacto directo por llamada, WhatsApp o ruta en Google Maps.

---

## 2. Creación de Cuenta, Consentimiento y Selección de Perfil

### 2.1 Registro e Inicio de Sesión (`M01` / `M16`)
1. Al abrir la aplicación por primera vez verás la pantalla de bienvenida (**M01**). Puedes cambiar el idioma entre **Español (`ES`)** e **Inglés (`EN`)** desde la esquina superior.
2. Toca **Crear cuenta** para registrarte con tu nombre, correo electrónico y una contraseña segura (mínimo 8 caracteres).
3. **Consentimiento informado (Ley 1581 de 2012):** Para crear tu cuenta debes marcar la aceptación de los **Términos y Condiciones (`v1.0`)** y la **Política de Privacidad (`v1.0`)**. La aplicación registra la fecha y versión exacta de tu aceptación.
4. Si ya tienes cuenta, toca **Iniciar sesión** e ingresa tus credenciales.

### 2.2 Elección de Perfil (`M02`)
Durante el onboarding inicial (y en cualquier momento desde la pestaña **Perfil**), puedes elegir el perfil que mejor describa tu situación:
- **Visitante o Turista (`visitor`):** Prioriza transporte, gastronomía, eventos activos (como el Festival de la Leyenda Vallenata) y precios frecuentes para estadías cortas.
- **En proceso de instalación (`settler`):** Prioriza vivienda, revisión de contratos de arrendamiento, servicios básicos y orientación barrial por zonas.
- **Residente local (`resident`):** Facilita el reporte ágil de precios cotidianos y el registro de negocios locales en el directorio comunitario.

### 2.3 Selección de Departamento y Municipio (`M03`, `M13`, `M14`, `M15`)
1. Selecciona el departamento de **Cesar (`20`)** en el mapa de Colombia (**M03**).
2. En el selector de municipios (**M13**), puedes buscar cualquier municipio escribiendo con o sin tildes (p. ej. `Valledupar`, `Aguachica`, `Codazzi`).
3. **Municipio Piloto (`Valledupar - 20001`, `M14`):** Muestra la insignia **Piloto Activo**. Toca **Entrar a Valledupar** para habilitar las 5 pestañas principales.
4. **Municipio No Piloto (`M15`):** Si eliges un municipio que aún no tiene cobertura verificada, la aplicación te informará con transparencia que aún no existen muestras auditadas y te permitirá pulsar **Notificarme cuando esté disponible** para registrar tu interés ciudadano.

---

## 3. Semáforo de Precios por Zona (`M06`, `M07`, `M20`)

### 3.1 ¿Cómo consultar un precio?
1. Ve a la pestaña **Escanear / Evaluar** en la barra inferior y asegúrate de estar en el modo **Precios**.
2. **Selecciona la categoría:**
   - *Carrera mínima de taxi* (`transport_taxi_minimal`)
   - *Almuerzo corriente / ejecutivo* (`food_executable_lunch`)
   - *Habitación sencilla de hotel por noche* (`lodging_budget_single`)
   - *Corte de cabello básico* (`service_haircut_basic`)
3. **Selecciona la zona de Valledupar:**
   - Puedes usar el botón **Detectar mi zona por GPS** (la app solicita permiso de ubicación en primer plano y resuelve la zona más cercana) o tocar directamente en el selector/mapa una de las 5 zonas:
     - **Zona Norte (`vup_norte`):** Novalito, San Joaquín, CC Guatapurí, Parque de la Leyenda.
     - **Zona Centro (`vup_centro`):** Plaza Alfonso López, Callejón de la Purrututú, Mercado Público.
     - **Zona Sur (`vup_sur`):** Terminal de Transportes, Los Fundadores, Casimiro Maestre.
     - **Zona Oriente (`vup_oriente`):** Balneario Hurtado, Río Guatapurí, Las Delicias.
     - **Zona Occidente (`vup_occidente`):** La Nevada, Bello Horizonte, Ciudadela 450 Años.
4. **Ingresa el monto en pesos colombianos (COP)** que te están cobrando (sin puntos ni centavos, p. ej. `10000`) y toca **Evaluar precio**.

### 3.2 ¿Cómo interpretar el resultado del semáforo?
El resultado combina siempre **color + ícono + etiqueta textual + cifras en COP** para garantizar accesibilidad:

| Estado | Significado estadístico | Recomendación |
|---|---|---|
| **Verde — Precio dentro de referencia (`green`)** | El cobro está hasta un **+15.0%** por encima de la mediana de la zona en los últimos 60 días. | El valor es acorde con lo reportado por la comunidad en esa zona. |
| **Amarillo — Precio por encima de la referencia (`yellow`)** | El cobro supera la mediana entre un **+15.01% y +40.0%**. | Solicita confirmación del servicio incluido o compara con el **Tope recomendado (+15%)** que muestra la tarjeta. |
| **Rojo — Precio muy superior a la referencia (`red`)** | El cobro supera en más de un **+40.01%** la mediana de la zona. | Se recomienda cotizar en otro establecimiento o acordar tarifa antes de tomar el servicio. |
| **Alerta de precio inusualmente bajo (`underpriced_alert`)** | El cobro es más de un **40% inferior** (`< -40.0%`) a la mediana zonal. | Aunque es económico, verifica las condiciones de seguridad, higiene o que no existan cobros ocultos adicionales. |
| **Gris — Muestra insuficiente (`insufficient`, `M20`)** | Existen **menos de 3 reportes válidos ($N < 3$)** en los últimos 60 días para esa categoría y zona. | Vía Justa **no inventa semáforos**: muestra un aviso neutro e invita a aportar el primer reporte ciudadano. |

> **Modo Evento Activo:** Si consultas un precio durante fechas de un evento masivo activo en Valledupar (como el *Festival de la Leyenda Vallenata*) y existen al menos 3 reportes durante el evento, la tarjeta mostrará tanto la **mediana habitual de 60 días** como la **mediana durante el evento** para que puedas contrastar el incremento estacional con total transparencia.

---

## 4. Aportar un Precio en 4 Pasos (`M10`)

Desde el mapa de precios (**M08**) o la pantalla de resultado del semáforo (**M07** / **M20**), toca **Aportar precio** para abrir el asistente de 4 pasos:

1. **Paso 1 — Categoría:** Elige el producto o servicio observado.
2. **Paso 2 — Monto en COP:** Ingresa el valor pagado u observado (entre `$500` y `$20.000.000 COP`).
3. **Paso 3 — Zona del municipio:** Elige la zona urbana de Valledupar donde ocurrió el cobro.
4. **Paso 4 — Referencia u observación (opcional) y envío:** Puedes añadir el nombre del lugar o una nota breve (p. ej. `"Tarifa diurna desde Terminal"`). No incluyas datos personales ni nombres de terceros.

**Reglas de protección comunitaria:**
- **Privacidad de ubicación:** Si adjuntas ubicación GPS, el servidor redondea automáticamente las coordenadas a ~110 metros antes de guardarlas para nunca registrar domicilios exactos.
- **Antispam y límites:** No se permite enviar el mismo reporte dos veces seguidas en menos de **15 minutos**, y cada cuenta puede registrar hasta **10 aportes reales por día**.

---

## 5. Escaneo y Análisis Orientativo de Contratos (`VJ-13` y `VJ-14`)

### 5.1 Captura del contrato y OCR en el dispositivo
1. En la pestaña **Escanear / Evaluar**, selecciona la pestaña superior **Contratos**.
2. Puedes elegir una de las **3 muestras sintéticas de prueba** (arrendamiento equilibrado, arrendamiento con cláusulas de precaución o contrato con cláusulas abusivas) o capturar tu propio documento mediante **Cámara**, **Imagen (JPG/PNG)** o **Archivo de texto (TXT)** de hasta 10 MB.
3. **Primer consentimiento (`RN-10` — OCR local):** Antes de abrir la cámara o galería, la app te informa que la lectura del texto se ejecuta 100% dentro de tu teléfono con ML Kit y que las imágenes temporales se borran inmediatamente de la caché.
4. Una vez extraído el texto, puedes revisarlo y editarlo manualmente en pantalla (máximo **15.000 caracteres**).

### 5.2 Análisis con Inteligencia Artificial (Gemini)
1. Al pulsar **Analizar contrato**, la aplicación solicita el **segundo consentimiento informado**, explicando que el texto plano se enviará de forma efímera al servicio de análisis para identificar cláusulas relevantes y que **no se guardará copia del contrato en la base de datos**.
2. Recibirás un informe orientativo con:
   - **Nivel general de alerta** (`Verde`, `Amarillo` o `Rojo` con ícono y texto).
   - **Puntos clave del contrato** (canon, plazos, obligaciones principales).
   - **Cláusulas observadas** con fragmento citado, explicación del riesgo, recomendación práctica y referencia normativa colombiana verificada (p. ej. *Ley 820 de 2003*).
   - **Aviso legal obligatorio:** El resultado es pedagógico y orientativo; no reemplaza la asesoría de un abogado titulado.

### 5.3 ¿Qué hacer si el OCR o el análisis falla?
- **Si la foto sale borrosa o el OCR no detecta texto (`INVALID_INPUT_EMPTY`):** Ubica el documento sobre una superficie iluminada, evita sombras o edita/pega directamente las cláusulas principales en el cuadro de texto.
- **Si el documento supera los 15.000 caracteres (`TEXT_TOO_LONG`):** Recorta encabezados repetidos o analiza por secciones las cláusulas de obligaciones, penalidades y terminación.
- **Si alcanzaste el límite diario (`AI_DAILY_LIMIT_EXCEEDED`):** Cada cuenta dispone de **5 análisis con IA por día** (reinicio a medianoche hora de Colombia `UTC-5`). Los errores de red o caídas temporales del servicio no descuentan tu cupo diario.

---

## 6. Vista Cultural de Valledupar (`M18` — `VJ-15`)

Desde la pantalla de inicio (**Inicio**) o el detalle del municipio piloto, accede a **Conoce Valledupar** para consultar información verificada y bilingüe (`es` / `en`) organizada en 6 secciones:
1. **Bienvenida (`welcome`):** Introducción a la Capital Mundial del Vallenato.
2. **Contexto Urbano (`context`):** Clima, movilidad y distribución de las 5 zonas urbanas.
3. **Cultura y Patrimonio (`culture`):** Patrimonio Cultural Inmaterial de la Humanidad (UNESCO) y el Festival de la Leyenda Vallenata.
4. **Lugares Emblemáticos (`places`):** Plaza Alfonso López, Río Guatapurí (Balneario Hurtado) y Centro Histórico.
5. **Gastronomía Tradicional (`gastronomy`):** Platos típicos locales y bebidas tradicionales.
6. **Emergencias y Líneas Oficiales (`emergency`):** Línea 123, Policía Nacional, Hospital Rosario Pumarejo de López y orientación al consumidor.

Cada tarjeta incluye su **fuente institucional verificable** (Alcaldía de Valledupar, Ministerio de Cultura, UNESCO, DANE).

---

## 7. Directorio de Negocios Locales y Registro en 4 Pasos (`M21`, `M09`, `M19`)

### 7.1 Explorar el catálogo y contactar un comercio (`M21` y `M09`)
1. Abre la pestaña **Negocios** en la barra inferior.
2. Filtra por categoría (*Restaurantes*, *Hoteles*, *Transporte*, *Servicios*, *Artesanías*) o busca por nombre, sector o plato destacado (el buscador ignora tildes y mayúsculas).
3. Toca cualquier negocio para abrir su **ficha de detalle (`M09`)** con:
   - Fotografías verificadas, descripción en tu idioma, dirección, zona y horario de atención.
   - Lista de hasta **5 platos o servicios destacados** con su precio en COP.
   - Botones de acción externa segura: **Llamar**, **Escribir por WhatsApp** (con mensaje contextual prellenado), **Cómo llegar en Google Maps** y **Ver carta / pedido externo** (con aviso antes de salir de la app).

### 7.2 Registrar un negocio propio en 4 pasos (`M19`)
Cualquier usuario autenticado puede postular su comercio local tocando **Registrar negocio**:
- **Paso 1 — Datos básicos:** Tipo de comercio, nombre comercial y descripción.
- **Paso 2 — Ubicación y horarios:** Dirección física en Valledupar, punto en el mapa y horarios de atención por día.
- **Paso 3 — Contacto y menú destacado:** Teléfono fijo/móvil y/o WhatsApp (con consentimiento explícito para botón `wa.me`), enlace externo HTTPS opcional y hasta 5 platos o servicios con su precio en COP.
- **Paso 4 — Fotografías y consentimiento de publicación:** Hasta 5 fotografías reales en formato JPG, PNG o WebP (máx. 5 MB por foto) y aceptación de publicación.

### 7.3 Estados de moderación de tu negocio
- **En revisión (`pending`):** Estado inicial de todo negocio nuevo o recién editado. Solo tú y los administradores pueden verlo mientras se verifica que la información sea real y respetuosa.
- **Aprobado (`approved`):** El negocio aparece públicamente en el catálogo y en el mapa de Valledupar.
- **Rechazado (`rejected`):** Si falta información verificable, verás el motivo detallado en **Mis negocios**; al corregir y guardar los datos, el comercio vuelve automáticamente a estado **En revisión (`pending`)**.

---

## 8. Idioma, Cierre de Sesión y Eliminación de Cuenta (`M17` — `RF-06`)

En la pestaña **Perfil** puedes:
- **Cambiar el idioma en vivo:** Alterna entre **Español (`es`)** e **Inglés (`en`)**; la preferencia se aplica de inmediato y se guarda en tu perfil.
- **Cambiar perfil o municipio activo:** Ajusta tu modo (*Visitante*, *Instalación* o *Residente*) o explora otro municipio.
- **Cerrar sesión:** Limpia tu sesión local de forma segura.
- **Eliminar mi cuenta (Habeas Data — Ley 1581 de 2012):** Si decides darte de baja definitiva, la opción **Eliminar cuenta** ejecuta el protocolo de supresión en 5 fases: borra tu perfil, tus consentimientos, tu historial de cuota de IA y tus negocios registrados, y **anonimiza por completo** cualquier reporte de precio previo (eliminando notas, nombres de lugar y coordenadas GPS), conservando únicamente el valor numérico anónimo para no distorsionar la estadística comunitaria.
