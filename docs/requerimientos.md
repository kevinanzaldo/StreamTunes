# Análisis de Requerimientos de Kiwi (Entrevista 2) y Criterios Técnicos

Este documento consolida la auditoría, análisis de viabilidad, señales de alerta y propuesta técnica frente a los requerimientos planteados por Kiwi (banda indie under) en la segunda entrevista de relevamiento, integrando las correcciones y devoluciones técnicas de la cátedra evaluadora (Rúbrica EGI).

---

## 1. Requerimientos Razonables y Viables (Implementados en StreamTunes)

Son aquellos pedidos que aportan valor real a la experiencia del fan y de la banda, técnicamente factibles y alineados con la arquitectura de StreamTunes:

1. **Acceso y fidelización por código QR (Criterios A1 / F1):**
   - **Solución implementada:** En el panel de la banda se genera un código QR que codifica la URL directa `https://streamtunes-web.vercel.app/?band=<slug>`. Al escanearlo, el fan ingresa a la PWA sin fricción, se le inicia sesión anónima automáticamente y queda registrado como seguidor sin tener que completar formularios de registro ni dar su email.
   - **Limitación técnica honesta (offline en sótanos):** La generación del QR en el panel de la banda es 100% offline (librería Dart en cliente). Sin embargo, para que el fan pueda abrir la PWA en un sótano sin señal de internet, el dispositivo debe haber visitado previamente la app (quedando cacheada en Service Worker) o tenerla instalada en la pantalla de inicio. Si la app ya está cacheada pero no hay conexión con Supabase en ese instante, la acción de seguir se guarda en la cola local segura (`PendingFollowService` vía SharedPreferences) y se sincroniza automáticamente apenas el dispositivo recupera señal.

2. **Top 10 de Fans y Gamificación (Criterios A1 / C1 / E2):**
   - **Solución implementada:** Visible en el perfil de la banda. El ranking se calcula en el servidor Postgres mediante la RPC optimizada `band_top_fans(p_band, p_limit)` sumando eventos de reproducción (`play_events`).
   - **Privacidad y cumplimiento legal (Ley 25.326 / GDPR):** El fan solo aparece con su nombre y foto pública si activó expresamente el switch de consentimiento opt-in en "Mi cuenta" (`is_public_profile = true`). Los oyentes que no dan su consentimiento aparecen agregados como "Fan anónimo", protegiendo su identidad.

3. **Reproductor con letras sincronizadas LRC (Karaoke) y pantalla completa:**
   - **Solución implementada:** Parseo en cliente de formato estándar LRC (`[mm:ss.xx]`) con sincronización en tiempo real al segundo de reproducción y scroll automático al verso activo. Si el tema no incluye letra sincronizada, la sección se oculta de manera limpia.

4. **Interrupciones de audio y foco en Android (Criterio F2):**
   - **Solución implementada:** La app gestiona el foco de audio del sistema operativo mediante el paquete `audio_session`. Al ingresar o finalizar una llamada telefónica, o recibir notificaciones del sistema con foco exclusivo, la música se pausa automáticamente y se reanuda de inmediato al liberar el foco, sin requerir permisos invasivos de telefonía.

5. **Diseño responsivo adaptativo (Criterio B1):**
   - **Solución implementada:** La UI se adapta fluido entre móvil (<600 px, `NavigationBar` inferior y tarjetas apiladas) y pantallas grandes/escritorio (≥600 px y ≥800 px, `NavigationRail` lateral, disposición a dos columnas para agenda, galería y métricas).

6. **Estados vacíos cuidados (Criterio B1):**
   - **Solución implementada:** Componente reutilizable `EmptyStateView` en todas las pantallas (biblioteca sin playlists, bandas sin agenda, sin fotos o sin canciones, y moderación sin reportes pendientes), guiando siempre al usuario con acciones claras ("Crear mi primera playlist", "Subir mi primer tema", "Recargar").

---

## 2. Gestión de Riesgos de Infraestructura y Alcance Técnico

Análisis técnico de riesgos de viabilidad económica, legal, técnica y operativa, junto con las mitigaciones arquitectónicas implementadas para encuadrar el MVP dentro de límites sustentables:

### Riesgo 1: Streaming sin modelo de monetización directo
- **Riesgo:** El streaming de audio genera consumo continuo de ancho de banda y almacenamiento (egress traffic). En la nube no existe el ancho de banda gratuito infinito.
- **Impacto:** Si un tema se reproduce miles de veces, los costos de transferencia superarán rápidamente el presupuesto de una banda under independiente.
- **Mitigación implementada:** Establecer un modelo sustentable (fondo colectivo por donaciones voluntarias, topes de temas por banda y compresión eficiente en AAC/MP3 a 128-192 kbps).

### Riesgo 2: Capacidad de hosting y límites de Supabase Free
- **Riesgo:** El plan gratuito de Supabase (Free Tier) tiene restricciones estrictas:
  - Base de datos: máx. 500 MB.
  - Almacenamiento Storage: máx. 1 GB total.
  - Transferencia de Storage (egress): máx. 2 GB mensuales.
  - Conexiones concurrentes Realtime: 200 clientes en vivo.
  - Pausa por inactividad: si el proyecto pasa 7 días sin consultas, Supabase lo pausa automáticamente.
- **Impacto:** Un recital con alta concurrencia simultánea puede saturar el límite de Realtime (200), y la transferencia de 2 GB se agotaría rápidamente con streaming continuo.
- **Mitigación implementada:** Modo offline desacoplado con mocks (`USE_MOCK=true`) para pruebas y contingencias, con opción documentada de suscripción a Supabase Pro ($25 USD/mes) o hosting propio en VPS (Docker/Coolify).

### Riesgo 3: Comisiones de pasarelas de pago en donaciones
- **Riesgo:** No existen pasarelas de pago que procesen transacciones financieras sin cobrar comisión.
- **Impacto:** Mercado Pago cobra entre 3.19% y 6.39% + IVA según el plazo de acreditación; Stripe cobra 3.99% + 0.50 USD. Prometer que el monto transferido llega íntegro sin costos de procesamiento es financieramente inviable.
- **Mitigación implementada:** Comunicar con transparencia en la UI el desglose de tarifas de la pasarela y documentar que StreamTunes como plataforma comunitaria no retiene comisión propia.

### Riesgo 4: Política de devoluciones y contracargos en donaciones
- **Riesgo:** La ausencia de una política clara de reembolsos expone a contracargos bancarios (chargebacks), costos por disputa en procesadores de pago y eventuales reclamos.
- **Mitigación implementada:** Fijar en términos y condiciones que las donaciones son aportes voluntarios no reembolsables, o habilitar un flujo formal de contacto con soporte antes de procesar el pago.

### Riesgo 5: Subida de archivos WAV sin comprimir (~1 GB por disco)
- **Riesgo:** Supabase Storage Free limita el tamaño máximo por archivo a **50 MB**. Un WAV crudo de 1 GB no puede subirse directamente.
- **Impacto:** Saturaría el bucket con un solo disco y consumiría el cupo mensual en la primera descarga.
- **Mitigación implementada:** La app valida el límite de 50 MB en cliente (`kMaxAudioFileSizeBytes = 52.428.800 bytes`) y orienta al músico a subir archivos en formato MP3 o AAC/M4A a 320 kbps (que pesan menos de 15 MB por tema y conservan fidelidad óptima), reservando la transcodificación masiva en servidor para una etapa con infraestructura dedicada.

### Riesgo 6: Subidas en segundo plano en Web / PWA (Workmanager)
- **Riesgo:** La API nativa `Workmanager` de Android no existe en navegadores web. Si un usuario cierra la pestaña o bloquea el navegador mientras se sube un archivo grande, el hilo de JavaScript se suspende y la subida se cancela.
- **Mitigación implementada:** En web, `UploadViewModel` advierte de forma explícita al usuario: *"En la versión web, no cierres esta pestaña hasta que la subida termine"*. En Android nativo, se programa el worker en background con notificación de progreso en la barra de tareas.

### Riesgo 7: Comercio electrónico de merchandising dentro del reproductor
- **Riesgo:** Construir un e-commerce completo (gestión de stock, talles, carritos, logística de envíos y facturación) desvía el foco del MVP y requiere meses de desarrollo adicional.
- **Mitigación implementada:** Se incorporó un botón destacado de "Tienda oficial" en el perfil de la banda (`merch_url`), enlazando directamente a la tienda externa oficial de la banda (ej. Tiendanube, Mercado Libre o Bandcamp), resolviendo la necesidad de ventas sin riesgo técnico.

### Riesgo 8: Derechos de autor y licencias (SADAIC / AADI-CAPIF)
- **Riesgo:** Si las bandas suben covers, reversiones o temas con samples no autorizados, la plataforma es pasible de intimaciones legales por derechos de propiedad intelectual.
- **Mitigación implementada:** Módulo de moderación (`AdminModerationView`) y sistema de denuncias comunitarias de contenido (`ReportRepository`), con aprobación previa de bandas antes de su publicación general.

---

## 3. Puntos de Validación y Alineación Funcional

Puntos a consensuar en reuniones de seguimiento para alinear expectativas operativas:

1. **Concurrencia en eventos en vivo:** Dimensionar la capacidad simultánea esperada en recitales con escaneo de QR para estimar el ancho de banda y conexiones de Realtime necesarias.
2. **Esquema de comisiones en donaciones:** Consensuar si el fan debe visualizar el monto neto final que recibe la banda o si las deducciones de la pasarela se absorben operativamente.
3. **Formatos y calidad de masterización:** Ratificar el estándar de subida en MP3 y M4A de alta fidelidad (hasta 320 kbps) frente a WAV crudo para optimizar el plan de almacenamiento.
4. **Integración con canales de merchandising:** Relevar plataformas externas activas de cada banda (Tiendanube, Mercado Shops, Instagram) para configurar los enlaces directos en sus perfiles.
5. **Procedimiento ante donaciones erróneas:** Establecer un canal oficial de contacto por correo electrónico para gestionar solicitudes de aclaración o reclamos.

---

## 4. Anexo Técnico y Costos de Infraestructura

### 4.1 Correcciones Conceptuales de la Cátedra (Rúbrica EGI)

| Concepto Erróneo / Ilusión Técnica | Realidad Arquitectónica en StreamTunes |
| :--- | :--- |
| **"Hacer el cálculo del total de minutos de todos los oyentes con Isolate/compute"** | **Falso en Web y Arquitectura:** Los agregados globales de todos los oyentes viven en la base de datos centralizada. En StreamTunes se ejecutan mediante RPC en PostgreSQL (`band_aggregated_stats`). En Flutter Web, `compute` corre sobre el event loop principal del navegador y congelaría la interfaz. |
| **"Un Stream de Dart trae datos en vivo desde otros celulares"** | **Falso:** Un `StreamController` local solo emite en la memoria del dispositivo actual. Para que un fan vea la donación de otro fan en tiempo real se requiere Supabase Realtime (WebSockets sobre Postgres Change Data Capture). |
| **"Workmanager sube archivos en segundo plano en la PWA"** | **Falso:** Workmanager es un wrapper de Android Jetpack. En Web no existe ejecución tras cerrar la pestaña. Se implementó advertencia visual en cliente web y soporte nativo en Android. |
| **"El navegador detecta llamadas telefónicas entrantes"** | **Falso:** Los navegadores no exponen eventos de llamadas entrantes por seguridad. En Android se gestiona el foco de audio (`audio_session`), pausando y reanudando la música según el foco del sistema operativo. |

### 4.2 Tabla Comparativa de Costos de Infraestructura y Servicios

| Servicio / Proveedor | Nivel Gratuito (MVP / Pruebas) | Plan Recomendado para Producción | Costo Estimado |
| :--- | :--- | :--- | :--- |
| **Supabase** | DB 500 MB, Storage 1 GB, 200 conexiones Realtime concurrentes (se pausa a los 7 días de inactividad). | **Plan Pro:** DB 8 GB, Storage 100 GB, 500 conexiones concurrentes, backups diarios, sin pausas. | **\$25 USD/mes** |
| **Vercel (Hosting PWA)** | Hobby: 100 GB ancho de banda mensual, despliegue continuo SSL. | **Plan Pro:** 1 TB ancho de banda, analíticas en tiempo real y soporte de equipo. | **\$20 USD/mes** (o \$0 en Hobby para festivales chicos) |
| **Mercado Pago (Procesamiento)** | Sin costo de alta ni mantenimiento mensual. | Comisión por cobro acreditado en el momento: **6.39% + IVA**; en 14 días: **3.49% + IVA**. | Variable por transacción |
| **Stripe (Internacional)** | Sin costo fijo de mantenimiento. | Comisión: **3.99% + 0.50 USD** por pago internacional con tarjeta. | Variable por transacción |
| **Dominio Propio (DNS/SSL)** | Subdominio gratuito `*.vercel.app`. | Dominio `.com.ar` o `.musica.ar` (NIC Argentina). | **\$8.000 a \$15.000 ARS/año** |

