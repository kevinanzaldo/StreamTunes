# Plan de Desarrollo - StreamTunes MVP (Fase 2)

## 📌 Contexto del Proyecto para el Asistente de IA
**StreamTunes** es una aplicación multiplataforma (PWA enfocada en Web y Móvil) diseñada para bandas under. El objetivo es ofrecer un reproductor de música continuo, subida de material, sistema de donaciones directas en vivo y estadísticas, manteniendo el código escalable y la experiencia fluida.

### ⚠️ Reglas Arquitectónicas Estrictas (Obligatorias)
El código generado debe cumplir estrictamente con los siguientes estándares:
1. **Arquitectura en Capas:** Separación estricta en `models`, `repositories`, `services`, `view_models`, y `views`.
2. **Gestión de Estado:** Uso exclusivo de `ChangeNotifier` para estados (como el reproductor). Consumir en la vista mediante `ListenableBuilder`. **Prohibido el prop-drilling.**
3. **Asincronía y Rendimiento:** Uso de `Future`, `async/await`. Para cálculos pesados usar `Isolate.run`. Para eventos en tiempo real usar `Streams`.
4. **Código Limpio:** Cumplir con las reglas de `flutter analyze` y `dart format`. Nombres descriptivos (lowerCamelCase para variables/métodos, UpperCamelCase para clases). Funciones con una única responsabilidad.
5. **Multiplataforma:** No usar `Platform.isIOS` o similares directamente en la UI. Usar clases de Capacidades/Políticas.

---

## ✅ Checklist de Tareas y Prompts de Implementación

*Instrucciones de uso: Ejecutar los siguientes prompts de forma secuencial. No avanzar al siguiente bloque sin haber probado y validado (con `flutter test` y `flutter analyze`) que el bloque anterior funciona correctamente.*

### Bloque 1: Arquitectura Base y Navegación Adaptativa (Criterios C1, B1, B4)
**Estado:** [x] Completado
**Prompt para ejecutar:**
> "Actúa como un desarrollador experto en Flutter. Necesito inicializar el esqueleto del proyecto 'StreamTunes' utilizando estrictamente Arquitectura en Capas.
> Generame el layout responsivo principal (`MainNavigationShell`): usá `MediaQuery.sizeOf` o `LayoutBuilder` para definir un breakpoint en 600px. 
> Si la pantalla es menor a 600px, mostrá un `NavigationBar` inferior; si es mayor o igual a 600px, mostrá un `NavigationRail` lateral. Mantené el código limpio y evitá usar validaciones de plataforma (como `kIsWeb`) directamente en la vista."

### Bloque 2: Reproductor Global Ininterrumpido (Criterio B2)
**Estado:** [x] Completado
**Prompt para ejecutar:**
> "Implementá el reproductor de música global de StreamTunes. Creá un `ReproductorViewModel` en la capa correspondiente que extienda de `ChangeNotifier`. 
> El reproductor debe tener propiedades privadas para el estado de la canción y usar getters públicos. Asegurate de llamar a `notifyListeners()` solo dentro de los métodos que modifican el estado (`play`, `pause`, `cambiarTema`). 
> Instancialo en la raíz y consumilo en la barra inferior (crea un widget `PlayerBar`) usando `ListenableBuilder`. Evitá el prop drilling."

### Bloque 3: Capacidades del Dispositivo - Cámara (Criterios D1, F1)
**Estado:** [x] Completado
**Prompt para ejecutar:**
> "Vamos a implementar la pantalla de subida (`UploadView`) donde se pide una foto de portada. Implementá el patrón de Capabilities y Policies.
> Creá una clase `DispositivoCapacidades` con un getter asincrónico (o booleano) llamado `tieneCamara`. En el ViewModel correspondiente, evaluá este getter: si es true, la vista debe mostrar un botón que abra la cámara (usando `image_picker`); si es false (ej. web sin cámara), ocultá el botón y dejá solo la opción de galería. La lógica de plataforma debe quedar encapsulada, nunca en la UI."

### Bloque 4: Cálculo Pesado con Isolates (Criterio D3)
**Estado:** [x] Completado
**Prompt para ejecutar:**
> "En el perfil del artista (`ArtistDetailView`), necesito mostrar estadísticas. Vamos a procesar un arreglo simulado de 50.000 registros de reproducciones para calcular el total de minutos escuchados. 
> Para no generar *jank* ni congelar la UI, implementá esta función matemática pesada utilizando `Isolate.run`. El cálculo debe realizarse en un hilo paralelo y devolver el resultado al hilo principal de forma asincrónica. Manejá los posibles errores con try/catch en el ViewModel e impactalo en el estado."

### Bloque 5: Donaciones en Tiempo Real con Streams (Criterio D3)
**Estado:** [x] Completado
**Prompt para ejecutar:**
> "Necesito simular un sistema de donaciones en vivo. Creá un servicio `DonacionesService` que exponga un `Stream` utilizando un `StreamController<Donacion>.broadcast()`.
> Creá una función simulada que emita un evento de donación aleatorio cada 10 segundos. En el ViewModel del perfil del artista, escuchá este stream y actualizá el estado para mostrar una alerta en la UI sin recargar toda la pantalla. Es obligatorio cancelar la suscripción (`subscription.cancel()`) en el método `dispose()` para evitar fugas de memoria."

### Bloque 6: Subidas en Segundo Plano (Criterios E1, E2)
**Estado:** [x] Completado
**Prompt para ejecutar:**
> "Implementá la lógica para subir un álbum pesado en segundo plano utilizando el paquete `workmanager`. La tarea debe registrarse para ejecutarse solo cuando haya conexión a internet (`NetworkType.connected`).
> Dentro del `callbackDispatcher` (que debe ser una función top-level con la anotación `@pragma('vm:entry-point')`), simulá una espera de 5 segundos. Al finalizar, dispará una notificación local usando `flutter_local_notifications` avisando al músico que el disco se publicó con éxito."

### Bloque 7: Eventos del Sistema y Ciclo de Vida (Criterio E3)
**Estado:** [x] Completado
**Prompt para ejecutar:**
> "La app debe reaccionar a los eventos del sistema utilizando `WidgetsBindingObserver`.
> Implementalo en un widget de nivel superior. Sobrescribí `didHaveMemoryPressure()` para ejecutar un print simulando el borrado de la caché de imágenes. 
> Además, escuchá los cambios con `didChangeAppLifecycleState`: si la app pasa a estado `inactive` o `paused` (ej. entra una llamada), ejecutá el método `pause()` del `ReproductorViewModel` automáticamente."
