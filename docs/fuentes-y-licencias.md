# Fuentes de Datos, Marco Normativo y Licencias — Vía Justa MVP

Este documento certifica las fuentes oficiales de datos, licencias de propiedad intelectual y fundamentos jurídicos incorporados en la plataforma **Vía Justa**.

---

## 1. Fuentes Geográficas y División Político-Administrativa

### 1.1 Catálogo DIVIPOLA (Departamentos y Municipios)
- **Entidad emisora:** Departamento Administrativo Nacional de Estadística (DANE).
- **Recurso:** Codificación de la División Político-Administrativa de Colombia (DIVIPOLA).
- **Uso en el proyecto:**
  - Código departamental de Cesar: `20`.
  - Código municipal de Valledupar (Piloto): `20001`.
  - 25 municipios de Cesar catalogados en `assets/data/municipalities_cesar.json`.
- **Licencia:** Datos Abiertos del Gobierno de Colombia (Ley 1712 de 2014 de Transparencia y Acceso a la Información Pública). Uso libre con fines académicos y de servicio ciudadano con debida citación.

### 1.2 Geometría y Cartografía
- **Fase de Avance (Actual):** Trazos vectoriales provisorios (`Path` con formas elípticas de demostración en `map_page.dart`) para ilustrar la interacción táctil. No pretenden reflejar fidelidad geográfica.
- **Fase Real (Semana 2 / VJ-09):** Geometría vectorial simplificada a partir del Marco Geoestadístico Nacional (MGN) del DANE procesada mediante Mapshaper para optimizar el peso del archivo SVG/Path en el dispositivo móvil.

---

## 2. Marco Normativo y Jurídico de Referencia

### 2.1 Arrendamiento de Vivienda Urbana
- **Norma:** **Ley 820 de 2003** ("Por la cual se expide el régimen de arrendamiento de vivienda urbana y se dictan otras disposiciones").
- **Aplicación en el Motor de Contratos (Gemini Edge Function):**
  - **Artículo 8:** Obligaciones del arrendador (conservar el inmueble en buen estado y realizar reparaciones necesarias).
  - **Artículo 9:** Obligaciones del arrendatario (cuidado del inmueble y pago oportuno).
  - **Artículo 16:** Prohibición expresa de exigencia de depósitos en dinero o garantías adicionales en contratos de vivienda urbana.
  - **Artículo 18:** Reglas de incremento anual del canon de arrendamiento atadas a la meta de inflación del Banco de la República (IPC).
- **Advertencia Legal:** El análisis del modelo LLM se contrasta contra estos artículos con carácter exclusivamente orientativo y pedagógico.

### 2.2 Protección de Datos Personales
- **Norma:** **Ley Estatutaria 1581 de 2012** y **Decreto Reglamentario 1377 de 2013**.
- **Aplicación en la Plataforma:**
  - Consentimiento previo, expreso e informado antes del registro.
  - Tabla inmutable `consents` con registro de fecha y versión del texto legal aceptado.
  - Derecho de supresión de datos (derecho al olvido) habilitado mediante eliminación de cuenta.
  - No retención de textos contractuales privados (RN-10).

---

## 3. Contenido Cultural y Fotografías de Valledupar

### 3.1 Criterios de Selección de Multimedia
1. **Fotografías con licencia Creative Commons (CC BY, CC BY-SA o CC0 / Dominio Público):** Cada recurso gráfico incluido en `assets/images/` o servido desde Supabase Storage debe contar con su correspondiente registro de atribución, autor y enlace a la licencia en el campo `source_citation` de la tabla `city_content`.
2. **Fotografías Propias:** Tomadas directamente en trabajo de campo por los integrantes del equipo.
3. **Prohibición Expresa:** Queda terminantemente prohibido el uso de imágenes protegidas por derechos de autor comerciales o marcas registradas sin autorización explícita.

---

## 4. Términos de Servicio de Terceros

### 4.1 Google Maps Platform
- Conforme a las Políticas de Google Maps Platform, la aplicación almacena únicamente el identificador unívoco de lugar (`place_id`) y las coordenadas geográficas de latitud/longitud de los comercios.
- Queda prohibido el almacenamiento persistente en caché (*scraping* o *caching*) de nombres de lugares, fotos de Google Places, reseñas comerciales o detalles de negocios provistos por Google.

### 4.2 Google Gemini API
- Las llamadas de inferencia de IA se ejecutan a través de la Edge Function con el nivel gratuito / comercial aplicable de Google AI Studio / Vertex AI, respetando las políticas de uso aceptable y privacidad (no entrenamiento con datos privados bajo términos comerciales).
