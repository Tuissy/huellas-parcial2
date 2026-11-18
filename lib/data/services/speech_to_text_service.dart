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
class SpeechToTextService implements SpeechService {
  SpeechToTextService(this._permissions, {stt.SpeechToText? speech})
    : _speech = speech ?? stt.SpeechToText();

  /// Tiempo para empezar a hablar después de tocar el micrófono. Es más
  /// largo que la pausa normal porque el motor tarda en detectar la voz.
  static const Duration _waitForFirstWords = Duration(seconds: 10);

  /// Silencio que cierra el dictado una vez que ya se dijo algo.
  static const Duration _pauseAfterSpeech = Duration(seconds: 5);

  /// Variantes de español en orden de preferencia: México primero y luego
  /// el español latinoamericano, más parecido al acento local que es-ES.
  static const List<String> _preferredLocales = ['es_mx', 'es_us', 'es_419'];

  final PermissionService _permissions;
  final stt.SpeechToText _speech;

  bool _initialized = false;
  String? _localeId;

  // Si ya se reconocieron palabras en la sesión actual.
  bool _heardSpeech = false;

  // Callbacks de la sesión de escucha activa.
  void Function()? _onStopped;
  void Function(String message)? _onError;

  // Rango de niveles observados para normalizar el volumen a 0..1
  // (cada plataforma reporta escalas distintas).
  double _minLevel = 0;
  double _maxLevel = 1;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<void> startListening({
    required SpeechResultCallback onResult,
    void Function(double level)? onSoundLevel,
    void Function()? onStopped,
    void Function(String message)? onError,
  }) async {
    await _ensureReady();

    _onStopped = onStopped;
    _onError = onError;
    _minLevel = 0;
    _maxLevel = 1;
    _heardSpeech = false;

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          if (!_heardSpeech && result.recognizedWords.isNotEmpty) {
            // Ya hay voz: desde aquí basta una pausa corta para terminar.
            _heardSpeech = true;
            _speech.changePauseFor(_pauseAfterSpeech);
          }
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: onSoundLevel == null
            ? null
            : (level) => onSoundLevel(_normalize(level)),
        listenOptions: stt.SpeechListenOptions(
          localeId: _localeId,
          listenFor: const Duration(minutes: 2),
          pauseFor: _waitForFirstWords,
          partialResults: true,
          cancelOnError: true,
          autoPunctuation: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );
    } catch (error) {
      developer.log('No se pudo iniciar el dictado', error: error);
      _notifyStopped();
      throw HardwareUnavailableException(
        DeviceFeature.microphone,
        'No se pudo iniciar el dictado. Intenta de nuevo.',
        error,
      );
    }
  }

  @override
  Future<void> stopListening() => _speech.stop();

  @override
  Future<void> cancel() async {
    _onStopped = null;
    _onError = null;
    await _speech.cancel();
  }

  /// Solicita permisos e inicializa el motor una única vez.
  Future<void> _ensureReady() async {
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
    _localeId = await _pickSpanishLocale();
  }

  /// Prefiere español de México o latinoamericano; si no hay ninguno usa
  /// otra variante de español y, en último caso, el idioma del sistema.
  Future<String?> _pickSpanishLocale() async {
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

  void _handleStatus(String status) {
    developer.log('Estado del dictado: $status');
    if (status == stt.SpeechToText.doneStatus ||
        status == stt.SpeechToText.notListeningStatus) {
      _notifyStopped();
    }
  }

  void _handleError(SpeechRecognitionError error) {
    developer.log('Error de dictado: ${error.errorMsg}');
    _onError?.call(_describeError(error.errorMsg));
    if (error.permanent) _notifyStopped();
  }

  void _notifyStopped() {
    final callback = _onStopped;
    _onStopped = null;
    callback?.call();
  }

  double _normalize(double level) {
    _minLevel = math.min(_minLevel, level);
    _maxLevel = math.max(_maxLevel, level);
    final range = _maxLevel - _minLevel;
    if (range <= 0) return 0;
    return ((level - _minLevel) / range).clamp(0.0, 1.0);
  }

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
