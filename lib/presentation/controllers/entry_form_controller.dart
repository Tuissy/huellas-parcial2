// ARCHIVO: entry_form_controller.dart. Concepto: el controlador separa la
// lógica de la pantalla (responsabilidad única). EntryFormScreen solo dibuja;
// aquí vive el estado del formulario y la coordinación de cámara, micrófono
// y GPS. Extiende ChangeNotifier: el controlador avisa a la pantalla cada vez
// que cambia el estado y ella se redibuja.
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/entities/diary_entry.dart';
import '../../domain/entities/geo_location.dart';
import '../../domain/entities/mood.dart';
import '../../domain/services/location_service.dart';
import '../../domain/services/media_service.dart';
import '../../domain/services/speech_service.dart';
import '../../domain/usecases/save_diary_entry.dart';

// editing: el usuario está escribiendo. locating: esperando la posición del
// GPS. saving: guardando la entrada.
/// Etapas del guardado, para informar al usuario qué está pasando.
enum FormStatus { editing, locating, saving }

/// Lógica del formulario de creación/edición (separada de la UI).
///
/// Coordina los tres "gadgets": cámara/galería, micrófono (dictado) y GPS.
/// Los errores de hardware se propagan como `AppException` para que la
/// pantalla decida cómo mostrarlos.
class EntryFormController extends ChangeNotifier {
  // El constructor recibe los servicios por inyección de dependencias. Son
  // interfaces del dominio, no implementaciones concretas: el controlador no
  // conoce los paquetes de cámara, voz o GPS y se podría probar con servicios
  // falsos. initialEntry solo llega cuando se edita una entrada.
  EntryFormController({
    required MediaService mediaService,
    required SpeechService speechService,
    required LocationService locationService,
    required SaveDiaryEntry saveDiaryEntry,
    this.initialEntry,
  }) : _media = mediaService,
       _speech = speechService,
       _location = locationService,
       _saveEntry = saveDiaryEntry,
       // Si estamos editando, los campos empiezan con los datos de la entrada
       // original; si es nueva, empiezan vacíos, con el ánimo 'bien' y con la
       // ubicación activada. La lista de fotos es una copia (List.of) para no
       // modificar la entrada original.
       titleController = TextEditingController(text: initialEntry?.title),
       contentController = TextEditingController(text: initialEntry?.content),
       _mood = initialEntry?.mood ?? Mood.good,
       _images = List.of(initialEntry?.imagePaths ?? const []),
       _attachLocation = initialEntry?.hasLocation ?? true {
    // Escuchamos los dos campos de texto: al escribir, el formulario queda
    // marcado como 'con cambios sin guardar'.
    titleController.addListener(_markDirty);
    contentController.addListener(_markDirty);
  }

  // Servicios que usa el controlador (privados). _saveEntry es el caso de uso
  // SaveDiaryEntry, que valida y guarda la entrada.
  final MediaService _media;
  final SpeechService _speech;
  final LocationService _location;
  final SaveDiaryEntry _saveEntry;

  /// Entrada en edición, o `null` si se está creando una nueva.
  final DiaryEntry? initialEntry;

  // Controladores de los campos de título y contenido. Son públicos porque la
  // pantalla los conecta a sus TextFormField.
  final TextEditingController titleController;
  final TextEditingController contentController;

  // Canal de mensajes informativos hacia la pantalla, por ejemplo el límite de
  // fotos. Es broadcast: se puede escuchar más de una vez y no guarda eventos
  // si nadie está escuchando.
  final StreamController<String> _messages = StreamController.broadcast();

  // Estado interno: ánimo, fotos, si se adjunta la ubicación y si hay que
  // renovarla, la etapa del guardado, si el micrófono está escuchando y su
  // nivel de sonido. _dirty indica cambios sin guardar y _disposed evita avisar
  // a una pantalla ya cerrada.
  Mood _mood;
  final List<String> _images;
  bool _attachLocation;
  bool _refreshLocation = false;
  FormStatus _status = FormStatus.editing;
  bool _isListening = false;
  double _soundLevel = 0;
  bool _dirty = false;
  bool _disposed = false;

  /// Texto que había antes de empezar a dictar; el dictado se añade al final.
  String _dictationBase = '';

  // --------------------------------------------------------------- getters
  // Getters de solo lectura: la pantalla consulta el estado, pero solo puede
  // cambiarlo con los métodos del controlador. images devuelve una lista no
  // modificable para proteger la interna. canAddImages respeta el máximo de
  // fotos del caso de uso. isBusy es verdadero mientras se localiza o se
  // guarda, y la pantalla lo usa para desactivar botones.
  bool get isEditing => initialEntry != null;
  Mood get mood => _mood;
  List<String> get images => List.unmodifiable(_images);
  bool get canAddImages => _images.length < SaveDiaryEntry.maxImages;
  bool get attachLocation => _attachLocation;
  bool get refreshLocation => _refreshLocation;
  FormStatus get status => _status;
  bool get isBusy => _status != FormStatus.editing;
  bool get isListening => _isListening;
  double get soundLevel => _soundLevel;
  bool get hasUnsavedChanges => _dirty;

  /// Mensajes informativos no bloqueantes (p. ej. "No se detectó voz").
  Stream<String> get messages => _messages.stream;

  /// `true` si al guardar hay que pedir una posición nueva al GPS.
  bool get needsGpsCapture {
    // Si el usuario no quiere ubicación, no se usa el GPS. Si la entrada no
    // tiene ubicación guardada (por ejemplo, una nueva), hay que pedirla. Si
    // ya tenía, solo se pide otra cuando el usuario marcó 'Actualizar a mi
    // ubicación actual'.
    if (!_attachLocation) return false;
    final existing = initialEntry?.location;
    return existing == null || _refreshLocation;
  }

  // ---------------------------------------------------------------- campos
  /// Cambia el estado de ánimo (lo llama el MoodSelector). Si es el mismo, no
  /// hace nada.
  void setMood(Mood mood) {
    if (mood == _mood) return;
    _mood = mood;
    _markDirty();
  }

  /// Interruptor 'adjuntar ubicación' del formulario.
  void setAttachLocation(bool value) {
    _attachLocation = value;
    _markDirty();
  }

  /// Casilla 'Actualizar a mi ubicación actual'. La pantalla solo la muestra
  /// si la entrada ya tenía ubicación.
  void setRefreshLocation(bool value) {
    _refreshLocation = value;
    _markDirty();
  }

  // ------------------------------------------------------- cámara/galería
  /// Abre la cámara o la galería. Lanza `AppException` si falla.
  Future<void> addPhoto(PhotoSource source) async {
    // Si ya se llegó al máximo de fotos, avisamos con un mensaje y no abrimos
    // la cámara.
    if (!canAddImages) {
      _messages.add('Puedes adjuntar hasta ${SaveDiaryEntry.maxImages} fotos.');
      return;
    }
    // Si el micrófono está activo lo detenemos antes, para no dejarlo
    // escuchando mientras se usa la cámara o la galería.
    if (_isListening) await stopDictation();
    // Pedimos la foto al servicio (cámara o galería, según source). Devuelve
    // la ruta del archivo o null si el usuario canceló. También revisamos
    // _disposed por si la pantalla se cerró mientras tanto.
    final path = await _media.pickPhoto(source);
    if (path == null || _disposed) return; // El usuario canceló.
    // Agregamos la foto y marcamos cambios, lo que redibuja la pantalla.
    _images.add(path);
    _markDirty();
  }

  /// Recupera fotos tomadas si Android destruyó la app con la cámara abierta.
  Future<void> recoverLostPhotos() async {
    // La pantalla llama a este método al abrirse. Agregamos las fotos
    // recuperadas sin pasar el límite y avisamos al usuario.
    final recovered = await _media.recoverLostPhotos();
    if (recovered.isEmpty || _disposed) return;
    for (final path in recovered) {
      if (canAddImages) _images.add(path);
    }
    _messages.add('Recuperamos la foto que estabas tomando.');
    _markDirty();
  }

  /// Quita una foto de la entrada y redibuja la pantalla.
  void removeImage(String path) {
    _images.remove(path);
    _markDirty();
  }

  // -------------------------------------------------------------- dictado
  /// Un solo botón para el micrófono: si está escuchando lo detiene y si no,
  /// lo inicia.
  Future<void> toggleDictation() =>
      _isListening ? stopDictation() : startDictation();

  /// Inicia el dictado. Lanza `AppException` si no hay permiso o motor.
  Future<void> startDictation() async {
    // Si ya estaba escuchando, no hacemos nada. Guardamos el texto que ya
    // había para añadir lo dictado al final, sin borrarlo.
    if (_isListening) return;
    _dictationBase = contentController.text.trimRight();
    // Marcamos que estamos escuchando y avisamos a la pantalla para que el
    // botón cambie de inmediato.
    _isListening = true;
    _soundLevel = 0;
    _notify();

    // Iniciamos el reconocimiento de voz con cuatro callbacks. onResult recibe
    // el texto reconocido. onSoundLevel recibe el volumen (de 0 a 1) y alimenta
    // el medidor de volumen del dictado. onStopped se llama cuando la escucha
    // termina sola. onError entrega errores no graves como mensaje.
    try {
      await _speech.startListening(
        onResult: _applyDictation,
        onSoundLevel: (level) {
          _soundLevel = level;
          _notify();
        },
        onStopped: _onDictationStopped,
        onError: (message) {
          if (!_messages.isClosed) _messages.add(message);
        },
      );
      // Si no se pudo iniciar (sin permiso o sin motor de voz), volvemos al
      // estado normal y relanzamos el error para que la pantalla lo muestre con
      // AppFeedback.
    } catch (_) {
      _onDictationStopped();
      rethrow;
    }
  }

  /// Detiene el dictado a pedido del usuario y actualiza el estado.
  Future<void> stopDictation() async {
    if (!_isListening) return;
    await _speech.stopListening();
    _onDictationStopped();
  }

  /// Escribe en el campo de contenido el texto base más lo que se va
  /// reconociendo. Recibe resultados parciales y finales.
  void _applyDictation(String recognized, bool isFinal) {
    // Ignoramos resultados vacíos o que llegan con la pantalla ya cerrada.
    if (_disposed || recognized.isEmpty) return;
    // Ponemos un espacio solo si ya había texto antes.
    final separator = _dictationBase.isEmpty ? '' : ' ';
    final text = '$_dictationBase$separator$recognized';
    // Reemplazamos el valor del campo y dejamos el cursor al final del texto.
    contentController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    // Cada frase final pasa a formar parte del texto base.
    if (isFinal) _dictationBase = text;
  }

  /// Vuelve al estado 'sin escuchar'. La primera condición evita avisar dos
  /// veces, porque se puede llamar desde stopDictation y también desde el
  /// callback onStopped.
  void _onDictationStopped() {
    if (!_isListening) return;
    _isListening = false;
    _soundLevel = 0;
    _notify();
  }

  // -------------------------------------------------------------- guardado
  /// Paso 1 del guardado: obtener la posición GPS (con estado "locating"
  /// para que la UI muestre retroalimentación). Lanza `AppException`.
  Future<GeoLocation> captureLocation() async {
    // Paramos el dictado, cambiamos el estado a 'locating' y pedimos la
    // posición. El bloque finally devuelve el estado a 'editing' aunque el GPS
    // falle, así la pantalla nunca se queda bloqueada.
    if (_isListening) await stopDictation();
    _setStatus(FormStatus.locating);
    try {
      return await _location.getCurrentLocation();
    } finally {
      _setStatus(FormStatus.editing);
    }
  }

  // Si el usuario desactivó la ubicación devuelve null y la entrada se guarda
  // sin ella.
  /// Ubicación que conservará la entrada si no se captura una nueva.
  GeoLocation? get existingLocation =>
      _attachLocation ? initialEntry?.location : null;

  /// Paso 2 del guardado: persistir la entrada. Lanza `AppException`.
  Future<DiaryEntry> save({GeoLocation? location}) async {
    // Igual que antes: paramos el dictado y pasamos al estado 'saving'.
    if (_isListening) await stopDictation();
    _setStatus(FormStatus.saving);
    try {
      // Armamos un borrador (DiaryEntryDraft) con los datos del formulario y se
      // lo pasamos al caso de uso SaveDiaryEntry, que valida y guarda. Si
      // original es null se crea una entrada nueva; si no, se actualiza la
      // existente. Pasamos una copia de la lista de fotos.
      final saved = await _saveEntry(
        DiaryEntryDraft(
          original: initialEntry,
          title: titleController.text,
          content: contentController.text,
          mood: _mood,
          imagePaths: List.of(_images),
          location: location,
        ),
      );
      // Si se guardó bien, ya no quedan cambios pendientes.
      _dirty = false;
      return saved;
    } finally {
      // Pase lo que pase, volvemos al estado de edición (bloque finally).
      _setStatus(FormStatus.editing);
    }
  }

  // ------------------------------------------------------------ utilidades
  /// Marca que hay cambios sin guardar y avisa a la pantalla. La pantalla lo
  /// usa para preguntar antes de salir sin guardar.
  void _markDirty() {
    _dirty = true;
    _notify();
  }

  /// Cambia la etapa del guardado y redibuja la pantalla.
  void _setStatus(FormStatus status) {
    _status = status;
    _notify();
  }

  /// notifyListeners protegido: si el controlador ya fue desechado no avisa,
  /// porque eso provocaría un error. Puede pasar con callbacks del micrófono
  /// que llegan tarde.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // Libera los recursos al cerrar la pantalla: cancela el dictado si seguía
  // activo (unawaited: no esperamos a que termine), cierra el canal de mensajes
  // y desecha los controladores de texto.
  @override
  void dispose() {
    _disposed = true;
    if (_isListening) unawaited(_speech.cancel());
    _messages.close();
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }
}
