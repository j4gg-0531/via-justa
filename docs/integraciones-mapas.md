# Integración de Google Maps, Reportes de Precios y Negocios (`VJ-12`)

## 1. Arquitectura general

La pantalla del mapa municipal ([`PriceMapPage`](../lib/features/prices/presentation/pages/price_map_page.dart)) muestra sobre el mapa interactivo de **Google Maps (`google_maps_flutter`)** de la ciudad seleccionada (piloto **Valledupar `20001`**, centrada en `10.4742, -73.2436`):

1. **Cartografía base y POIs de Google Maps:** Calles, barrios, hospitales, clínicas, centros comerciales, parques y comercios de Valledupar con desplazamiento libre (`pan`), zoom, brújula y barra de herramientas.
2. **Ubicación GPS en tiempo real del usuario (`myLocationEnabled` + `geolocator`):** Solicita permiso de ubicación (`ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`) bajo demanda al pulsar el botón flotante de ubicación (`Icons.my_location`) y centra la cámara en la posición actual del ciudadano.
3. **Reportes ciudadanos de precios (`public.price_reports`):** Cada reporte elegible de los últimos 60 días se proyecta en el mapa con sus coordenadas redondeadas a 3 decimales ($\approx 110\text{ m}$ por privacidad `RN-08`) o en el centro de su zona (`public.municipality_zones`), coloreado según el veredicto estadístico:
   * **Verde (`fair`):** $\le +15\%$ respecto a la mediana zonal.
   * **Ámbar (`moderate`):** $> +15\%$ y $\le +40\%$.
   * **Rojo (`alert`):** $> +40\%$.
4. **Negocios y servicios registrados (`public.businesses`):** Todo negocio o servicio con `status = 'approved'` en `public.businesses` aparece automáticamente tanto en los marcadores del mapa como en las tarjetas inferiores (con acciones reales de **Ruta** hacia Google Maps Navigation y **Llamar** mediante `url_launcher`).

---

## 2. Configuración de la clave `MAPS_API_KEY` en Android (sin exponerla en Git)

El archivo [`android/app/build.gradle.kts`](../android/app/build.gradle.kts) lee automáticamente la clave desde `android/local.properties` (que está ignorado por Git) y la inyecta como `manifestPlaceholders["MAPS_API_KEY"]` en [`android/app/src/main/AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml).

Agrega la siguiente línea al final de tu archivo local `android/local.properties`:

```properties
MAPS_API_KEY=AIzaSyTuClaveDeGoogleMapsAqui
```

---

## 3. Cómo registrar un negocio en la Base de Datos para que aparezca en el Mapa

Cualquier registro en `public.businesses` con `status = 'approved'` y `municipality_code = '20001'` aparece inmediatamente en el mapa. Puedes insertarlo desde el **SQL Editor de Supabase** usando la función helper [`public.register_business_on_map`](../supabase/migrations/20261029160000_map_items_rpc_and_businesses_geo.sql):

```sql
select public.register_business_on_map(
  p_name := 'Centro Comercial Guatapurí Plaza',
  p_type := 'service', -- 'restaurant' | 'hotel' | 'service' | 'handicraft' | 'transport' | 'hospital' | 'consulate'
  p_description_es := 'Centro comercial, servicios bancarios y plazoleta de comidas en Zona Norte.',
  p_description_en := 'Shopping mall, banking services and food court in North Zone.',
  p_latitude := 10.4912,
  p_longitude := -73.2568,
  p_address := 'Carrera 9 con Calle 6N · Valledupar',
  p_phone := '6055730000',
  p_whatsapp := '576055730000',
  p_municipality_code := '20001',
  p_approve_immediately := true
);
```

Una vez ejecutado, basta con tocar el botón de capas (`Icons.layers_outlined`) o **"Ver todos"** en la pantalla del mapa para recargar los marcadores desde Supabase en vivo.
