# Fuentes de Datos, Marco Normativo y Licencias — Vía Justa MVP

Este documento certifica las fuentes oficiales de datos, licencias de propiedad intelectual y fundamentos jurídicos incorporados en la plataforma **Vía Justa**, contrastados contra fuentes primarias oficiales.

---

## 1. Fuentes Geográficas y División Político-Administrativa

### 1.1 Catálogo DIVIPOLA (Departamentos y Municipios)
- **Entidad emisora:** Departamento Administrativo Nacional de Estadística (DANE).
- **Recurso:** Codificación de la División Político-Administrativa de Colombia (DIVIPOLA).
- **Uso en el proyecto:**
  - Código departamental de Cesar: `'20'`.
  - Código municipal de Valledupar (Piloto): `'20001'`.
  - 25 municipios de Cesar catalogados en `assets/data/municipalities_cesar.json`.
- **Condiciones de uso:** Datos abiertos del Estado colombiano bajo los términos de la Ley 1712 de 2014. Uso libre para consulta y procesamiento con obligación de atribución al DANE.

### 1.2 Geometría y Cartografía (Mapa de Departamentos de Colombia — M03)
- **Fuente real:** **Simplemaps.com** (`tools/source/co.svg`, mapa vectorial de los 33 territorios de Colombia: 32 departamentos, incluido San Andrés y Providencia, más Bogotá, D.C.).
- **Licencia:** Uso comercial y personal gratuito (*Free for commercial use, attribution appreciated*), disponible en https://simplemaps.com/resources/svg-license.
- **Procesamiento en el repositorio:** El archivo fuente `tools/source/co.svg` se convierte mediante el script reproducible `tools/svg_to_geo_json.py` al recurso estático `assets/data/colombia_departments_geo.json` (`bounds` y `rings` indexados por código DANE de 2 dígitos).
- **Alcance y honestidad:** Se trata de un **mapa vectorial simplificado** para selección interactiva en móvil y **NO constituye cartografía oficial del DANE**. Se rotula con atribución explícita a Simplemaps.com en la interfaz (`map.sample_note`) y nunca se presenta como cartografía oficial. El Marco Geoestadístico Nacional (MGN) del DANE queda registrado como mejora futura.

---

## 2. Marco Normativo y Jurídico de Referencia

### 2.1 Arrendamiento de Vivienda Urbana en Colombia
- **Norma oficial:** **Ley 820 de 2003** (Congreso de la República de Colombia, Diario Oficial No. 45.244). Fuente oficial: Gestor Normativo de Función Pública.
- **Artículos clave incorporados en el análisis de contratos (Gemini Edge Function):**
  - **Artículo 8 (Obligaciones del arrendador):** Obligación de entregar el inmueble en buen estado de servicio, seguridad y sanidad, y mantener en él los servicios, cosas o usos conexos y adicionales convenidos.
  - **Artículo 9 (Obligaciones del arrendatario):** Pagar el precio del arrendamiento dentro del plazo estipulado y cuidar el inmueble y las cosas recibidas en arrendamiento.
  - **Artículo 16 (Prohibición de depósitos y garantías):** En los contratos de arrendamiento de vivienda urbana no se podrán exigir depósitos en dinero efectivo u otra clase de cauciones reales para garantizar el cumplimiento de las obligaciones. Toda estipulación en contrario es nula de pleno derecho.
  - **Artículo 18 (Límite del canon de arrendamiento):** El precio mensual del canon no podrá exceder el **uno por ciento (1%) del valor comercial** del inmueble o de la parte de él que se dé en arriendo. La estimación comercial no podrá exceder el equivalente a dos (2) veces el avalúo catastral vigente.
  - **Artículo 20 (Reajuste del canon de arrendamiento):** Cada doce (12) meses de ejecución del contrato bajo un mismo precio, el arrendador podrá incrementar el canon hasta en una proporción que no supere el **cien por ciento (100%) del incremento del Índice de Precios al Consumidor (IPC)** del año calendario inmediatamente anterior, siempre que el nuevo canon no supere el tope del 1% del valor comercial (Art. 18).
- **Advertencia Legal Obligatoria:** El análisis automatizado del modelo LLM se contrasta contra estos artículos con carácter exclusivamente orientativo y pedagógico. La aplicación no emite conceptos vinculantes ni sustituye el asesoramiento de un abogado o de las autoridades de inspección y vigilancia.

### 2.2 Protección de Datos Personales
- **Norma:** **Ley Estatutaria 1581 de 2012** y **Decreto 1377 de 2013**.
- **Aplicación en la Plataforma:**
  - Consentimiento previo, expreso e informado antes del registro.
  - Tabla inmutable `consents` con registro de fecha y versión del texto legal aceptado.
  - Derecho de supresión de datos (derecho al olvido) habilitado mediante eliminación de cuenta.
  - No retención de textos contractuales privados (RN-10).

---

## 3. Contenido Cultural y Fotografías de Valledupar (`VJ-15`)

### 3.1 Criterios de Selección de Multimedia y Restricción en Base de Datos
1. **Fotografías con licencia Creative Commons (CC BY, CC BY-SA o CC0 / Dominio Público):** Cada recurso gráfico incluido en `assets/images/` o servido desde Supabase Storage debe contar con su correspondiente registro de atribución, autor y enlace a la licencia en los campos `source_citation` e `image_license` de la tabla `public.city_content`.
2. **Garantía técnica (`city_content_image_license_required_check`):** La migración `20261030130000_city_content_and_events_rpc.sql` impone a nivel de PostgreSQL que ninguna fila en `public.city_content` pueda definir `image_path` si `image_license` es nulo o vacío.
3. **Fotografías Propias y de Comercios:** Tomadas directamente en trabajo de campo por los integrantes del equipo o aportadas voluntariamente por dueños de negocios bajo consentimiento explícito.
4. **Prohibición Expresa:** Queda terminantemente prohibido el uso de imágenes protegidas por derechos de autor comerciales o marcas registradas sin autorización explícita.

### 3.2 Ficha Auditable de Fuentes Culturales de Valledupar (`20001` — `09_city_content_valledupar.sql`)

| Slug (`slug`) | Sección (`section`) | Idiomas | Fuente Oficial Verificada (`source_citation`) | Enlace (`source_url`) |
|---|---|---|---|---|
| `valledupar_welcome` | `welcome` | `es`, `en` | Alcaldía de Valledupar — Reseña histórica e institucional del municipio (DIVIPOLA 20001) | `https://www.valledupar-cesar.gov.co` |
| `valledupar_context` | `context` | `es`, `en` | Instituto Geográfico Agustín Codazzi (IGAC) y DANE — Geografía del Cesar y Valledupar | `https://www.dane.gov.co` |
| `vallenato_unesco` | `culture` | `es`, `en` | UNESCO — Decisión 10.COM 10.a.3 (2015) y Red de Ciudades Creativas de la UNESCO (2019) | `https://ich.unesco.org/es/USL/la-musica-vallenata-tradicional-del-magdalena-grande-01095` |
| `plaza_alfonso_lopez_y_hurtado` | `places` | `es`, `en` | Ministerio de las Culturas, las Artes y los Saberes de Colombia — Patrimonio Urbano de Valledupar | `https://www.mincultura.gov.co` |
| `gastronomia_tradicional_cesar` | `gastronomy` | `es`, `en` | Ministerio de Cultura — Biblioteca Básica de Cocinas Tradicionales de Colombia (Región Caribe / Cesar) | `https://www.mincultura.gov.co` |
| `lineas_atencion_y_emergencia_vup` | `emergency` | `es`, `en` | Alcaldía de Valledupar / Defensoría del Pueblo Regional Cesar — Directorio de Atención Ciudadana | `https://www.defensoria.gov.co` |

---

## 4. Términos de Servicio de Terceros e Inteligencia Artificial

### 4.1 Google Maps Platform
- Conforme a las Políticas de Google Maps Platform, la aplicación almacena únicamente el identificador unívoco de lugar (`place_id`) y las coordenadas geográficas de latitud/longitud de los comercios.
- Queda prohibido el almacenamiento persistente en caché (*scraping* o *caching*) de nombres de lugares, fotos de Google Places, reseñas comerciales o detalles de negocios provistos por Google.

### 4.2 Google Gemini API (Políticas de Datos y Privacidad de IA)
- **Nivel Gratuito (Google AI Studio Free Tier):** Los términos de servicio de Google AI Studio para el nivel gratuito estipulan que los datos de entrada y salida pueden ser revisados por evaluadores humanos y utilizados para entrenar y mejorar productos de Google.
- **Principio de Protección en el MVP:**
  - Debido a las condiciones del nivel gratuito, en las fases de desarrollo, pruebas y demostración se utilizarán **exclusivamente contratos sintéticos de prueba** (sin nombres reales, cédulas, direcciones exactas ni firmas).
  - Queda prohibido el envío de contratos de arrendamiento reales de personas naturales a la Edge Function de Gemini hasta que se configure un proyecto bajo términos comerciales (Google Cloud Vertex AI o API de pago con facturación corporativa) que certifique la no retención ni uso de los datos del cliente para entrenamiento.
