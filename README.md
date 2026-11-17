# Huellas — Diario personal multimedia (Parcial 2)

Aplicación Flutter para llevar un diario personal en segundos: **dicta** lo que pasó en tu día,
añade **fotos** con la cámara o la galería y Huellas guarda automáticamente **dónde** estabas.
Todo se almacena localmente en **SQLite** y puede protegerse con **huella, rostro o PIN**.

📄 Reporte técnico (arquitectura, diagramas de clases y flujo de datos):
[`docs/Reporte_Tecnico_Huellas.pdf`](docs/Reporte_Tecnico_Huellas.pdf)

## Funcionalidades

| Requerimiento | Implementación |
|---|---|
| UI avanzada | `Scaffold`, `AppBar` y `Drawer` (con la sección actual resaltada) en todas las pantallas |
| Navegación | 8 **rutas con nombre** (`onGenerateRoute`) entre la lista, el detalle y el formulario |
| Animaciones | `Hero` de la foto de la lista al detalle y al visor; transiciones personalizadas |
| Persistencia | **SQLite** (`sqflite`) para entradas, rutas de fotos (JSON) y coordenadas; `SharedPreferences` para el tema y el bloqueo |
| Asincronía y errores | `FutureBuilder` con indicadores de carga, try-catch en todas las capas y errores tipados (`AppException`) |
| Gadget 1: multimedia | Cámara y galería (`image_picker`); las fotos se copian al almacenamiento privado de la app |
| Gadget 2: audio | Dictado por voz desde el micrófono (`speech_to_text`) con medidor de audio en vivo |
| Gadget 3: GPS y mapas | Posición al guardar (`geolocator`), mapa interactivo (`flutter_map` + OpenStreetMap) y botón a Google Maps |
| Extra (rúbrica) | Inicio de sesión biométrico (`local_auth`), búsqueda, mapa de recuerdos y tema oscuro |

Si el usuario niega un permiso, la app lo avisa; si el permiso quedó bloqueado, ofrece abrir los
ajustes. Si el GPS está apagado o no responde, se puede reintentar, activarlo o guardar sin
ubicación. Ningún fallo de hardware cierra la app.

## Arquitectura

Arquitectura limpia en cuatro capas; las dependencias apuntan siempre hacia el dominio:

```
lib/
├── main.dart, app.dart   arranque, manejo global de errores y MaterialApp
├── core/                 inyección de dependencias (AppScope), errores, tema, fechas
├── domain/               entidades, interfaces y casos de uso (Dart puro, sin Flutter)
├── data/                 SQLite, modelos y adaptadores de plugins (cámara, voz, GPS…)
└── presentation/         pantallas, controladores, rutas y widgets
```

La UI solo conoce interfaces del dominio (`DiaryRepository`, `MediaService`, `SpeechService`,
`LocationService`…). Las clases concretas se crean en un único lugar: `AppDependencies.create()`.

## Ejecutar

Requisitos: Flutter 3.44+ (Dart 3.12) y Android SDK 37 (minSdk 24).

```bash
flutter pub get
flutter run          # se recomienda un teléfono físico para cámara, voz y GPS
flutter test         # 19 pruebas: modelo, SQLite, casos de uso y navegación
```

Para probar el bloqueo biométrico en el emulador, primero registra un PIN y una huella en
*Ajustes → Seguridad* del dispositivo. El dictado y los mosaicos del mapa necesitan internet.

### Regenerar el reporte PDF

El reporte se escribe en `docs/reporte_tecnico.html` (diagramas en Mermaid). Para volver a
generar el PDF (requiere Google Chrome y conexión la primera vez):

```bash
python3 docs/build_pdf.py
```

## Permisos

| Plataforma | Permisos |
|---|---|
| Android | `CAMERA`, `RECORD_AUDIO`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `USE_BIOMETRIC`, `INTERNET` |
| iOS | `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSFaceIDUsageDescription` |
