import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/errors/app_exception.dart';
import '../../domain/services/permission_service.dart';
import '../../domain/services/speech_service.dart';

/// Dictado por voz con el paquete speech_to_text.
///
/// El plugin abre el micrófono, captura el audio y lo envía al motor de
/// reconocimiento del sistema (SpeechRecognizer en Android y
/// SFSpeechRecognizer en iOS), que devuelve el texto transcrito.
///
/// El motor de Android reconoce **una frase por sesión**: al terminar la
/// frase deja de escuchar, pero el plugin no lo informa hasta que pasa la
/// pausa configurada y, además, ignora cualquier texto posterior. Para
/// dictar sin cortes, un dictado se arma con varias sesiones: en cuanto una
/// frase termina (o el motor deja de reportar volumen) se cierra la sesión y
/// se abre otra de inmediato. El dictado solo termina cuando el usuario lo
/// detiene, tras [_pauseAfterSpeech] de silencio, tras
/// [_maxWordlessSessions] sesiones seguidas sin entender nada, tras
/// [_maxMutedSessions] sesiones seguidas sin audio o al llegar a
/// [_maxDictation].
class SpeechToTextService implements SpeechService {
  // Implementa la interfaz SpeechService del dominio (inversión de
  // dependencias). Recibe el servicio de permisos y, para las pruebas, se
  // le pueden inyectar el objeto SpeechToText y los tiempos de espera.
  SpeechToTextService(
    this._permissions, {
    stt.SpeechToText? speech,
    this.restartDelay = const Duration(milliseconds: 400),
    this.sessionEndGrace = const Duration(seconds: 3),
    this.deafAfter = const Duration(milliseconds: 1500),
  }) : _speech = speech ?? stt.SpeechToText();

  /// Tiempo para empezar a hablar después de tocar el micrófono. Es más
  /// largo que la pausa normal porque el motor tarda en detectar la voz.
  static const Duration _waitForFirstWords = Duration(seconds: 10);

  /// Silencio que cierra el dictado una vez que ya se dijo algo.
  static const Duration _pauseAfterSpeech = Duration(seconds: 5);

  /// Duración máxima de un dictado, sumando todas sus sesiones.
  static const Duration _maxDictation = Duration(minutes: 5);

  /// Sesiones seguidas en las que el motor oyó sonido pero no entendió
  /// ninguna palabra (ruido, murmullo); al llegar aquí el dictado termina.
  static const int _maxWordlessSessions = 3;

  /// Sesiones seguidas en las que el micrófono no entregó audio (el volumen
  /// nunca cambió). Pasa sobre todo en el emulador, que a veces no logra
  /// abrir el micrófono de la computadora; se reintenta hasta este número.
  static const int _maxMutedSessions = 4;

  /// Variantes de español en orden de preferencia: México primero y luego
  /// el español latinoamericano, más parecido al acento local que es-ES.
  static const List<String> _preferredLocales = ['es_mx', 'es_us', 'es_419'];

  /// Errores que, si ya se dictó algo, solo indican que la persona terminó
  /// de hablar o que el motor no aceptó reabrir el micrófono.
  static const Set<String> _quietAfterSpeech = {
    'error_no_match',
    'error_speech_timeout',
    'error_client',
    'error_busy',
    'error_recognizer_busy',
  };

  final PermissionService _permissions;
  final stt.SpeechToText _speech;

  /// Pausa antes de reabrir el micrófono para que el motor lo libere.
  final Duration restartDelay;

  /// Si el motor no confirma el fin de una sesión, se da por terminada.
  final Duration sessionEndGrace;

  /// Si el motor deja de reportar el volumen durante este tiempo, ya no
  /// está escuchando (Android lo hace al terminar cada frase).
  final Duration deafAfter;

  // El motor se inicializa una sola vez; _localeId es el idioma elegido.
  bool _initialized = false;
  String? _localeId;

  // ---------------------------------------------------- estado del dictado
  bool _active = false; // el usuario no lo ha detenido
  DateTime _startedAt = DateTime.now();
  bool _heardSpeech = false; // hubo palabras en alguna sesión
  bool _messageShown = false; // ya se mostró un aviso en este dictado
  int _wordlessSessions = 0; // sesiones seguidas con sonido y sin palabras
  int _mutedSessions = 0; // sesiones seguidas sin audio

  // ------------------------------------------------------ sesión actual
  bool _wordsInSession = false;
  bool _engineWentDeaf = false; // el motor dejó de escuchar por su cuenta
  bool _sessionFailed = false;
  bool _sessionClosed = false;
  String _pendingPartial = ''; // último texto parcial sin confirmar
  DateTime? _lastLevelAt;
  double? _firstLevel; // primer volumen de la sesión
  bool _audioInSession = false; // el volumen cambió: llegó audio real
  Timer? _endFallback;
  Timer? _deafWatch;

  // Callbacks del dictado activo.
  SpeechResultCallback? _onResult;
  void Function(double level)? _onSoundLevel;
  void Function()? _onStopped;
  void Function(String message)? _onError;

  // Rango de niveles observados para normalizar el volumen a 0..1
  // (cada plataforma reporta escalas distintas).
  double _minLevel = 0;
  double _maxLevel = 1;

  /// Indica si hay un dictado en curso, aunque esté entre dos sesiones.
  @override
  bool get isListening => _active;

  /// Empieza un dictado nuevo: pide permisos, guarda los callbacks de la
  /// pantalla, reinicia los contadores y abre la primera sesión.
  @override
  Future<void> startListening({
    required SpeechResultCallback onResult,
    void Function(double level)? onSoundLevel,
    void Function()? onStopped,
    void Function(String message)? onError,
  }) async {
    await _ensureReady();

    // Se guardan los callbacks y se reinicia el estado del dictado.
    _onResult = onResult;
    _onSoundLevel = onSoundLevel;
    _onStopped = onStopped;
    _onError = onError;
    _minLevel = 0;
    _maxLevel = 1;
    _heardSpeech = false;
    _messageShown = false;
    _wordlessSessions = 0;
    _mutedSessions = 0;
    _startedAt = DateTime.now();
    _active = true;

    // try-catch: si el motor no logra abrir la primera sesión, se termina el
    // dictado y se lanza una AppException con mensaje en español.
    try {
      await _listenSession();
    } catch (error) {
      developer.log('No se pudo iniciar el dictado', error: error);
      _finish();
      throw HardwareUnavailableException(
        DeviceFeature.microphone,
        'No se pudo iniciar el dictado. Intenta de nuevo.',
        error,
      );
    }
  }

  /// El usuario detiene el dictado: se marca inactivo, se cancelan los
  /// temporizadores y se pide al motor que entregue el texto final.
  @override
  Future<void> stopListening() async {
    _active = false;
    _cancelTimers();
    await _speech.stop();
  }

  /// Cancela el dictado y borra los callbacks: ya no se avisa nada a la
  /// pantalla.
  @override
  Future<void> cancel() async {
    _active = false;
    _cancelTimers();
    _onResult = null;
    _onSoundLevel = null;
    _onStopped = null;
    _onError = null;
    await _speech.cancel();
  }

  /// Abre una sesión del motor. La primera espera más a que empiece la voz;
  /// las siguientes (reanudaciones) solo toleran una pausa corta.
  Future<void> _listenSession() async {
    // Se reinicia el estado de la sesión nueva.
    _wordsInSession = false;
    _engineWentDeaf = false;
    _sessionFailed = false;
    _sessionClosed = false;
    _pendingPartial = '';
    _lastLevelAt = null;
    _firstLevel = null;
    _audioInSession = false;
    // Tiempo que le queda al dictado completo (el máximo es 5 minutos).
    final remaining = _maxDictation - DateTime.now().difference(_startedAt);

    // Se abre el micrófono con resultados parciales (el texto aparece
    // mientras se habla), puntuación automática y modo dictado.
    await _speech.listen(
      onResult: _handleResult,
      onSoundLevelChange: _handleSoundLevel,
      listenOptions: stt.SpeechListenOptions(
        localeId: _localeId,
        listenFor: remaining,
        pauseFor: _heardSpeech ? _pauseAfterSpeech : _waitForFirstWords,
        partialResults: true,
        // Un error ya cierra la sesión en Android; si el plugin además
        // cancelara, podría cortar la sesión siguiente del dictado.
        cancelOnError: false,
        autoPunctuation: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
    // Se empieza a vigilar si el motor deja de escuchar por su cuenta.
    _watchForDeafEngine();
  }

  /// Recibe cada texto reconocido (parcial o final) y lo pasa a la pantalla.
  void _handleResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords;
    if (words.isNotEmpty) {
      // Ya hay voz: desde aquí basta una pausa corta para terminar.
      if (!_heardSpeech) _shortenPause();
      _heardSpeech = true;
      _wordsInSession = true;
    }
    // Se guarda el texto parcial por si la sesión se cierra sin confirmarlo.
    _pendingPartial = result.finalResult ? '' : words;
    _onResult?.call(words, result.finalResult);

    // Tras una frase final el motor ya no escucha y el plugin ignoraría lo
    // que llegue después: se cierra la sesión para abrir otra enseguida.
    if (result.finalResult && _active && !_sessionClosed) {
      _closeSessionEarly();
    }
  }

  /// Recibe el volumen del micrófono. Sirve para animar el indicador y
  /// para saber si llega audio real (el volumen cambia respecto al primero).
  void _handleSoundLevel(double level) {
    _lastLevelAt = DateTime.now();
    final first = _firstLevel ??= level;
    if ((level - first).abs() > 0.01) _audioInSession = true;
    _onSoundLevel?.call(_normalize(level));
  }

  /// Vigila que el motor siga reportando volumen. Si deja de hacerlo, la
  /// frase terminó sin texto y el micrófono quedó cerrado.
  void _watchForDeafEngine() {
    _deafWatch?.cancel();
    _deafWatch = Timer.periodic(deafAfter ~/ 3, (_) {
      final last = _lastLevelAt;
      // Solo se vigila si el motor ya reportó volumen en esta sesión.
      if (!_active || _sessionClosed || last == null) return;
      if (DateTime.now().difference(last) < deafAfter) return;
      developer.log('El motor dejó de escuchar; se cierra la sesión');
      _engineWentDeaf = true;
      _closeSessionEarly();
    });
  }

  /// Cierra la sesión actual sin terminar el dictado.
  void _closeSessionEarly() {
    _deafWatch?.cancel();
    if (_speech.isListening) {
      // El cierre llega luego como estado "done".
      unawaited(_speech.stop());
    } else {
      _onSessionClosed();
    }
  }

  /// Cambia la pausa larga inicial por la corta una vez que ya hay voz.
  void _shortenPause() {
    // El plugin lanza una excepción si la sesión ya se cerró.
    if (!_speech.isListening) return;
    try {
      _speech.changePauseFor(_pauseAfterSpeech);
    } on stt.ListenNotStartedException {
      // La sesión terminó justo ahora; no hay pausa que cambiar.
    }
  }

  /// Recibe los cambios de estado del motor (escuchando, no escuchando,
  /// terminado) y decide cuándo la sesión se da por cerrada.
  void _handleStatus(String status) {
    developer.log('Estado del dictado: $status');
    if (status == stt.SpeechToText.listeningStatus) return;
    if (!_active) {
      // El usuario lo detuvo o hubo un error: el dictado ya terminó.
      _notifyStopped();
      return;
    }
    if (status == stt.SpeechToText.doneStatus) {
      _onSessionClosed();
    } else if (status == stt.SpeechToText.notListeningStatus) {
      // "done" llega cuando el motor entrega el texto final; si no llega,
      // la sesión se da por terminada de todos modos.
      _endFallback?.cancel();
      _endFallback = Timer(sessionEndGrace, _onSessionClosed);
    }
  }

  /// Decide si el dictado sigue (se reanuda) o termina.
  void _onSessionClosed() {
    _cancelTimers();
    if (_sessionClosed) return;
    _sessionClosed = true;

    // El último fragmento parcial pasa a ser definitivo antes de seguir,
    // para que la nueva sesión no lo reemplace.
    if (_pendingPartial.isNotEmpty) {
      final words = _pendingPartial;
      _pendingPartial = '';
      _onResult?.call(words, true);
    }

    // Sesión "muda": el motor dejó de escuchar sin que el volumen cambiara
    // nunca, es decir, el micrófono no entregó audio.
    final muted = _engineWentDeaf && !_audioInSession;
    // Contadores: si hubo palabras se reinician; si no, se suma una sesión
    // muda o una sesión con sonido pero sin palabras.
    if (_wordsInSession) {
      _wordlessSessions = 0;
      _mutedSessions = 0;
    } else if (muted) {
      _mutedSessions++;
    } else {
      _wordlessSessions++;
    }
    final elapsed = DateTime.now().difference(_startedAt);
    // La sesión se cerró antes de tiempo si hubo una frase o si el motor
    // dejó de escuchar; si se cerró por la pausa, hubo silencio.
    final closedEarly =
        _wordsInSession ||
        (_engineWentDeaf &&
            (muted
                ? _mutedSessions < _maxMutedSessions
                : _wordlessSessions < _maxWordlessSessions));
    // El dictado sigue solo si está activo, la sesión cerró antes de tiempo,
    // no hubo error y quedan más de 2 segundos antes del máximo.
    final keepGoing =
        _active &&
        closedEarly &&
        !_sessionFailed &&
        _maxDictation - elapsed > const Duration(seconds: 2);
    // Si no sigue, se termina el dictado (con un aviso si nunca hubo voz).
    if (!keepGoing) {
      if (_active && _engineWentDeaf && !_heardSpeech) {
        // Sin audio del micrófono, o con sonido pero sin palabras.
        _showMessage(_describeError(muted ? 'error_audio' : 'error_no_match'));
      }
      _finish();
      return;
    }

    // Reconocimiento de voz: sesiones encadenadas porque Android escucha una
    // frase por sesión. Se espera un momento para que el motor libere el
    // micrófono y se abre una sesión nueva.
    developer.log('Sesión cerrada; el dictado continúa');
    Future<void>.delayed(restartDelay, () async {
      if (!_active) return; // el usuario lo detuvo mientras tanto
      try {
        await _listenSession();
      } catch (error) {
        developer.log('No se pudo reanudar el dictado', error: error);
        _finish();
      }
    });
  }

  /// Recibe los errores del motor de voz y decide si mostrar un aviso.
  void _handleError(SpeechRecognitionError error) {
    developer.log('Error de dictado: ${error.errorMsg}');
    // Android a veces informa el error después de cerrar la sesión. Si el
    // dictado se va a reanudar, ese error es de la sesión anterior: se
    // ignora para que no corte la nueva.
    if (_active && _sessionClosed) return;
    _sessionFailed = true;
    // Si ya se dictó algo, errores como "sin coincidencias" solo indican que
    // la persona terminó de hablar: no se muestra aviso. Si el error es
    // permanente, el dictado termina.
    final quiet = _heardSpeech && _quietAfterSpeech.contains(error.errorMsg);
    if (!quiet) _showMessage(_describeError(error.errorMsg));
    if (error.permanent) _finish();
  }

  /// Muestra un aviso en la pantalla, solo uno por dictado.
  void _showMessage(String message) {
    if (_messageShown) return; // un solo aviso por dictado
    _messageShown = true;
    _onError?.call(message);
  }

  /// Termina el dictado completo y avisa a la pantalla.
  void _finish() {
    _active = false;
    _cancelTimers();
    _notifyStopped();
  }

  /// Detiene los temporizadores de respaldo y de vigilancia.
  void _cancelTimers() {
    _endFallback?.cancel();
    _endFallback = null;
    _deafWatch?.cancel();
    _deafWatch = null;
  }

  /// Avisa que el dictado terminó. El callback se borra antes de llamarlo
  /// para que el aviso llegue una sola vez.
  void _notifyStopped() {
    final callback = _onStopped;
    _onStopped = null;
    callback?.call();
  }

  /// Solicita permisos e inicializa el motor una única vez.
  Future<void> _ensureReady() async {
    // Primero el permiso del micrófono y luego el de reconocimiento de voz.
    // Permiso negado vs bloqueado: se indica en la excepción.
    final mic = await _permissions.request(AppPermission.microphone);
    if (mic != PermissionStatusResult.granted) {
      throw PermissionException(
        DeviceFeature.microphone,
        permanentlyDenied: mic == PermissionStatusResult.permanentlyDenied,
      );
    }
    final speech = await _permissions.request(AppPermission.speechRecognition);
    if (speech != PermissionStatusResult.granted) {
      throw PermissionException(
        DeviceFeature.microphone,
        permanentlyDenied: speech == PermissionStatusResult.permanentlyDenied,
      );
    }

    // El motor se inicializa una sola vez y se registran los callbacks de
    // error y de estado. Si falla, se lanza una AppException en español.
    if (_initialized) return;
    try {
      _initialized = await _speech.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
      );
    } catch (error) {
      developer.log('Error al inicializar speech_to_text', error: error);
      _initialized = false;
    }
    if (!_initialized) {
      throw const HardwareUnavailableException(
        DeviceFeature.microphone,
        'El reconocimiento de voz no está disponible en este dispositivo.',
      );
    }
    // Se elige el idioma español para el dictado.
    _localeId = await _pickSpanishLocale();
  }

  /// Prefiere español de México o latinoamericano; si no hay ninguno usa
  /// otra variante de español y, en último caso, el idioma del sistema.
  Future<String?> _pickSpanishLocale() async {
    // Normaliza el código del idioma: "es-MX" y "es_mx" quedan iguales.
    String normalize(String id) => id.toLowerCase().replaceAll('-', '_');
    try {
      final locales = await _speech.locales();
      final spanish = locales
          .where((locale) => normalize(locale.localeId).startsWith('es'))
          .toList();
      if (spanish.isEmpty) return (await _speech.systemLocale())?.localeId;
      for (final preferred in _preferredLocales) {
        for (final locale in spanish) {
          if (normalize(locale.localeId) == preferred) return locale.localeId;
        }
      }
      return spanish.first.localeId;
    } catch (error) {
      developer.log('No se pudieron leer los idiomas', error: error);
      return null;
    }
  }

  /// Lleva el volumen a una escala de 0 a 1 según el mínimo y el máximo
  /// observados, porque cada plataforma usa una escala distinta.
  double _normalize(double level) {
    _minLevel = math.min(_minLevel, level);
    _maxLevel = math.max(_maxLevel, level);
    final range = _maxLevel - _minLevel;
    if (range <= 0) return 0;
    return ((level - _minLevel) / range).clamp(0.0, 1.0);
  }

  /// Traduce el código técnico del motor de voz a un mensaje en español.
  String _describeError(String code) {
    switch (code) {
      case 'error_no_match':
      case 'error_speech_timeout':
        return 'No se detectó voz. Habla más cerca del micrófono.';
      case 'error_network':
      case 'error_network_timeout':
      case 'error_server_disconnected':
        return 'El reconocimiento de voz necesita conexión a internet.';
      case 'error_audio':
      case 'error_audio_error':
        return 'No se pudo capturar el audio del micrófono.';
      case 'error_permission':
      case 'error_insufficient_permissions':
        return 'Falta el permiso del micrófono.';
      case 'error_busy':
      case 'error_recognizer_busy':
        return 'El micrófono está ocupado. Intenta de nuevo.';
      case 'error_language_not_supported':
      case 'error_language_unavailable':
        return 'El idioma de dictado no está disponible.';
      default:
        return 'Ocurrió un problema con el dictado ($code).';
    }
  }
}
