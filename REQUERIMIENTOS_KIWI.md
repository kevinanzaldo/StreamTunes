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

## 2. Señales de Alerta e Invenciones que Hay que Frenar

Puntos críticos planteados por el cliente que conllevan inviabilidad económica, legal, técnica u operativa si no se encuadran dentro de límites realistas:

### Alerta 1: Música gratis ilimitada sin publicidad ni modelo de monetización
- **Riesgo:** El streaming de audio genera consumo continuo de ancho de banda y almacenamiento (egress traffic). En la nube no existe el ancho de banda gratuito infinito.
- **Impacto:** Si un tema se reproduce miles de veces, los costos de transferencia superarán rápidamente el presupuesto de una banda under independiente.
- **Acción:** Establecer un modelo sustentable (fondo colectivo por donaciones voluntarias, topes de temas por banda y compresión eficiente en AAC/MP3 a 128-192 kbps).

### Alerta 2: Hosting "lo dejamos andando nosotros" y límites de Supabase Free
- **Riesgo:** El plan gratuito de Supabase (Free Tier) tiene restricciones estrictas:
  - Base de datos: máx. 500 MB.
  - Almacenamiento Storage: máx. 1 GB total.
  - Transferencia de Storage (egress): máx. 2 GB mensuales.
  - Conexiones concurrentes Realtime: 200 clientes en vivo.
  - Pausa por inactividad: si el proyecto pasa 7 días sin consultas, Supabase lo pausa automáticamente.
- **Impacto:** Un recital con 300 fans conectados simultáneamente saturará el límite de Realtime (200), y la transferencia de 2 GB se agotará con pocas horas de streaming.
- **Acción:** Definir quién es el titular de la tarjeta de crédito para la suscripción a Supabase Pro ($25 USD/mes) o un hosting autoalojado en VPS (Docker/Coolify).

### Alerta 3: Donaciones "sin comisión" y muro público tipo Twitch
- **Riesgo:** No existen pasarelas de pago que procesen transacciones financieras sin cobrar comisión.
- **Impacto:** Mercado Pago cobra entre 3.19% y 6.39% + IVA según el plazo de acreditación; Stripe cobra 3.99% + 0.50 USD. Prometer que "el dinero llega 100% directo sin comisión" es financieramente imposible.
- **Acción:** Comunicar con transparencia en la UI el desglose de tarifas de la pasarela y documentar que StreamTunes como plataforma comunitaria no retiene comisión propia.

### Alerta 4: Devolución de donaciones: "eso se soluciona después"
- **Riesgo:** Desentenderse de la política de reembolsos expone a contracargos bancarios (chargebacks), costos por disputa ($15 USD en procesadores internacionales), congelamiento de cuentas y reclamos en Defensa del Consumidor.
- **Acción:** Fijar en términos y condiciones que las donaciones son aportes voluntarios no reembolsables, o habilitar un flujo formal de contacto con soporte antes de procesar el pago.

### Alerta 5: Subida de discos completos en WAV sin comprimir de ~1 GB
- **Riesgo:** Supabase Storage Free limita el tamaño máximo por archivo a **50 MB**. Un WAV crudo de 1 GB no puede subirse directamente.
- **Impacto:** Saturaría el bucket con un solo disco y consumiría el cupo mensual en la primera descarga.
- **Acción:** La app valida el límite de 50 MB en cliente (`kMaxAudioFileSizeBytes = 52.428.800 bytes`) y orienta al músico a subir archivos en formato MP3 o AAC/M4A a 320 kbps (que pesan menos de 15 MB por tema y conservan fidelidad óptima), reservando la transcodificación masiva en servidor para una etapa con infraestructura dedicada.

### Alerta 6: Subidas en segundo plano en Web / PWA (Workmanager)
- **Riesgo:** La API nativa `Workmanager` de Android no existe en navegadores web. Si un usuario cierra la pestaña o bloquea el navegador mientras se sube un archivo grande, el hilo de JavaScript se suspende y la subida se cancela.
- **Acción:** En web, `UploadViewModel` advierte de forma explícita al usuario: *"En la versión web, no cierres esta pestaña hasta que la subida termine"*. En Android nativo, se programa el worker en background con notificación de progreso en la barra de tareas.

### Alerta 7: Tienda de merchandising "urgente" dentro del reproductor
- **Riesgo:** Construir un e-commerce completo (gestión de stock, talles de remeras, carritos, envíos por correo, cálculo de fletes y facturación) desvía el foco del MVP y requiere meses de desarrollo adicional.
- **Acción:** Se incorporó un botón destacado de "Tienda oficial" en el perfil de la banda (`merch_url`), enlazando directamente a la tienda externa oficial de la banda (ej. Tiendanube, Mercado Libre o Bandcamp), resolviendo la necesidad de ventas sin riesgo técnico.

### Alerta 8: Derechos de autor y licencias (SADAIC / AADI-CAPIF)
- **Riesgo:** Si las bandas suben covers, reversiones o temas con samples no autorizados, la plataforma es pasible de intimaciones legales por derechos de propiedad intelectual.
- **Acción:** Módulo de moderación (`AdminModerationView`) y sistema de denuncias ciudadanas de contenido (`ReportRepository`), con aprobación previa de bandas antes de su publicación general.

---

## 3. Repreguntas Abiertas para la Próxima Reunión con Kiwi

Preguntas formuladas en tono constructivo y en español rioplatense (voseo) para alinear expectativas sin tecnicismos agresivos:

1. *"Para el recital de marzo, ¿cuánta gente calculan que va a escanear el QR al mismo tiempo? Así dejamos dimensionado el servidor para que no se quede colgado si entran todos juntos."*
2. *"Con el tema de las donaciones, las tarjetas y billeteras (como Mercado Pago) descuentan una pequeña comisión operativa por cada cobro. ¿Quieren que el fan vea el monto neto exacto que les llega a ustedes o prefieren absorber la tarifa?"*
3. *"Sobre la calidad de audio: los discos en WAV pesan cerca de 1 GB y gastan los datos móviles de los fans en dos temas. ¿Les parece bien que la app acepte MP3 y M4A en alta definición (320 kbps), que suena idéntico en celulares y auriculares y carga al instante?"*
4. *"Para el merch de remeras y vinilos, en vez de obligarlos a cargar inventario y configurar envíos dentro de la app, dejamos un botón directo a su tienda o link de contacto. ¿Tienen ya algún link armado (Tiendanube, Instagram o Mercado Shops) para vincular?"*
5. *"Si alguien dona por error en medio del recital y pide anularlo al día siguiente, ¿cómo prefieren manejarlo? ¿Definimos un mail de contacto de la banda o una aclaración de que las donaciones son finales?"*

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

