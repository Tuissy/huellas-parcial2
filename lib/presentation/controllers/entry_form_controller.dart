import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/entities/diary_entry.dart';
import '../../domain/entities/geo_location.dart';
import '../../domain/entities/mood.dart';
import '../../domain/services/location_service.dart';
import '../../domain/services/media_service.dart';
import '../../domain/services/speech_service.dart';
import '../../domain/usecases/save_diary_entry.dart';

/// Etapas del guardado, para informar al usuario qué está pasando.
enum FormStatus { editing, locating, saving }

/// Lógica del formulario de creación/edición (separada de la UI).
///
/// Coordina los tres "gadgets": cámara/galería, micrófono (dictado) y GPS.
/// Los errores de hardware se propagan como `AppException` para que la
/// pantalla decida cómo mostrarlos.
class EntryFormController extends ChangeNotifier {
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
       titleController = TextEditingController(text: initialEntry?.title),
       contentController = TextEditingController(text: initialEntry?.content),
       _mood = initialEntry?.mood ?? Mood.good,
       _images = List.of(initialEntry?.imagePaths ?? const []),
       _attachLocation = initialEntry?.hasLocation ?? true {
    titleController.addListener(_markDirty);
    contentController.addListener(_markDirty);
  }

  final MediaService _media;
  final SpeechService _speech;
  final LocationService _location;
  final SaveDiaryEntry _saveEntry;

  /// Entrada en edición, o `null` si se está creando una nueva.
  final DiaryEntry? initialEntry;

  final TextEditingController titleController;
  final TextEditingController contentController;

  final StreamController<String> _messages = StreamController.broadcast();

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
    if (!_attachLocation) return false;
    final existing = initialEntry?.location;
    return existing == null || _refreshLocation;
  }

  // ---------------------------------------------------------------- campos
  void setMood(Mood mood) {
    if (mood == _mood) return;
    _mood = mood;
    _markDirty();
  }

  void setAttachLocation(bool value) {
    _attachLocation = value;
    _markDirty();
  }

  void setRefreshLocation(bool value) {
    _refreshLocation = value;
    _markDirty();
  }

  // ------------------------------------------------------- cámara/galería
  /// Abre la cámara o la galería. Lanza `AppException` si falla.
  Future<void> addPhoto(PhotoSource source) async {
    if (!canAddImages) {
      _messages.add('Puedes adjuntar hasta ${SaveDiaryEntry.maxImages} fotos.');
      return;
    }
    if (_isListening) await stopDictation();
    final path = await _media.pickPhoto(source);
    if (path == null || _disposed) return; // El usuario canceló.
    _images.add(path);
    _markDirty();
  }

  /// Recupera fotos tomadas si Android destruyó la app con la cámara abierta.
  Future<void> recoverLostPhotos() async {
    final recovered = await _media.recoverLostPhotos();
    if (recovered.isEmpty || _disposed) return;
    for (final path in recovered) {
      if (canAddImages) _images.add(path);
    }
    _messages.add('Recuperamos la foto que estabas tomando.');
    _markDirty();
  }

  void removeImage(String path) {
    _images.remove(path);
    _markDirty();
  }

  // -------------------------------------------------------------- dictado
  Future<void> toggleDictation() =>
      _isListening ? stopDictation() : startDictation();

  /// Inicia el dictado. Lanza `AppException` si no hay permiso o motor.
  Future<void> startDictation() async {
    if (_isListening) return;
    _dictationBase = contentController.text.trimRight();
    _isListening = true;
    _soundLevel = 0;
    _notify();

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
    } catch (_) {
      _onDictationStopped();
      rethrow;
    }
  }

  Future<void> stopDictation() async {
    if (!_isListening) return;
    await _speech.stopListening();
    _onDictationStopped();
  }

  void _applyDictation(String recognized, bool isFinal) {
    if (_disposed || recognized.isEmpty) return;
    final separator = _dictationBase.isEmpty ? '' : ' ';
    final text = '$_dictationBase$separator$recognized';
    contentController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    // Cada frase final pasa a formar parte del texto base.
    if (isFinal) _dictationBase = text;
  }

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
    if (_isListening) await stopDictation();
    _setStatus(FormStatus.locating);
    try {
      return await _location.getCurrentLocation();
    } finally {
      _setStatus(FormStatus.editing);
    }
  }

  /// Ubicación que conservará la entrada si no se captura una nueva.
  GeoLocation? get existingLocation =>
      _attachLocation ? initialEntry?.location : null;

  /// Paso 2 del guardado: persistir la entrada. Lanza `AppException`.
  Future<DiaryEntry> save({GeoLocation? location}) async {
    if (_isListening) await stopDictation();
    _setStatus(FormStatus.saving);
    try {
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
      _dirty = false;
      return saved;
    } finally {
      _setStatus(FormStatus.editing);
    }
  }

  // ------------------------------------------------------------ utilidades
  void _markDirty() {
    _dirty = true;
    _notify();
  }

  void _setStatus(FormStatus status) {
    _status = status;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

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
