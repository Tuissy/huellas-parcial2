import 'package:flutter_test/flutter_test.dart';
import 'package:parcial2/data/services/speech_to_text_service.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../helpers/fakes.dart';

/// Motor de voz simulado: emite resultados, errores y cierres de sesión
/// como lo hace el SpeechRecognizer de Android.
class FakeSpeechToText implements stt.SpeechToText {
  stt.SpeechErrorListener? _onError;
  stt.SpeechStatusListener? _onStatus;
  stt.SpeechResultListener? _onResult;
  stt.SpeechSoundLevelChange? _onLevel;
  bool _listening = false;

  /// Veces que el servicio cerró una sesión con `stop`.
  int stopCalls = 0;

  /// Opciones de cada sesión abierta con `listen`.
  final List<stt.SpeechListenOptions> sessions = [];

  /// Cambios de pausa pedidos con `changePauseFor`.
  final List<Duration> pauseChanges = [];

  @override
  bool get isListening => _listening;

  @override
  Future<bool> initialize({
    stt.SpeechErrorListener? onError,
    stt.SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = stt.SpeechToText.defaultFinalTimeout,
    List<stt.SpeechConfigOption>? options,
  }) async {
    _onError = onError;
    _onStatus = onStatus;
    return true;
  }

  @override
  Future listen({
    stt.SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    stt.SpeechSoundLevelChange? onSoundLevelChange,
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    stt.ListenMode listenMode = stt.ListenMode.confirmation,
    sampleRate = 0,
    stt.SpeechListenOptions? listenOptions,
  }) async {
    _onResult = onResult;
    _onLevel = onSoundLevelChange;
    sessions.add(listenOptions!);
    _listening = true;
    _onStatus?.call(stt.SpeechToText.listeningStatus);
  }

  @override
  void changePauseFor(Duration pauseFor) {
    // Igual que el plugin real: falla si la sesión ya se cerró.
    if (!_listening) throw stt.ListenNotStartedException();
    pauseChanges.add(pauseFor);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    closeSession();
  }

  @override
  Future<void> cancel() async => closeSession();

  @override
  Future<List<stt.LocaleName>> locales() async => [
    stt.LocaleName('es_ES', 'Español (España)'),
    stt.LocaleName('es_US', 'Español (Estados Unidos)'),
    stt.LocaleName('en_US', 'English (United States)'),
  ];

  @override
  Future<stt.LocaleName?> systemLocale() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  // ------------------------------------------------ acciones de la prueba
  void emit(String words, {bool isFinal = false}) => _onResult?.call(
    SpeechRecognitionResult([
      SpeechRecognitionWords(words, null, 0.9),
    ], isFinal ? ResultType.finalResult.value : ResultType.partial.value),
  );

  /// El motor cierra la sesión y confirma el texto final.
  void closeSession() {
    stopWithoutDone();
    _onStatus?.call(stt.SpeechToText.doneStatus);
  }

  /// El motor deja de escuchar pero no confirma el cierre.
  void stopWithoutDone() {
    _listening = false;
    _onStatus?.call(stt.SpeechToText.notListeningStatus);
  }

  /// El motor reporta el volumen del micrófono.
  void emitLevel(double level) => _onLevel?.call(level);

  void fail(String code) => _onError?.call(SpeechRecognitionError(code, true));
}

void main() {
  late FakeSpeechToText engine;
  late SpeechToTextService service;
  late List<(String, bool)> results;
  late List<String> errors;
  late int stoppedCalls;

  setUp(() {
    engine = FakeSpeechToText();
    service = SpeechToTextService(
      FakePermissionService(),
      speech: engine,
      restartDelay: Duration.zero,
      sessionEndGrace: const Duration(milliseconds: 10),
    );
    results = [];
    errors = [];
    stoppedCalls = 0;
  });

  Future<void> start() => service.startListening(
    onResult: (text, isFinal) => results.add((text, isFinal)),
    onStopped: () => stoppedCalls++,
    onError: errors.add,
  );

  // Deja correr los temporizadores de reanudación y de cierre.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 40));

  List<String> finalTexts() =>
      results.where((r) => r.$2).map((r) => r.$1).toList();

  test('usa español latinoamericano si el motor no ofrece es-MX', () async {
    await start();
    expect(engine.sessions.single.localeId, 'es_US');
  });

  test('da 10 s para empezar a hablar y luego acorta la pausa a 5 s', () async {
    await start();
    expect(engine.sessions.single.pauseFor, const Duration(seconds: 10));

    engine.emit('hoy');
    expect(engine.pauseChanges, [const Duration(seconds: 5)]);
  });

  test('si el motor cierra la sesión mientras se habla, el dictado sigue '
      'hasta que hay silencio', () async {
    await start();
    engine.emit('hoy fui');
    engine.emit('hoy fui a clase', isFinal: true);
    engine.closeSession();
    await settle();

    expect(engine.sessions, hasLength(2));
    expect(engine.sessions.last.pauseFor, const Duration(seconds: 5));
    expect(service.isListening, isTrue);
    expect(stoppedCalls, 0);

    engine.emit('y comí tacos', isFinal: true);
    engine.closeSession();
    await settle();
    expect(engine.sessions, hasLength(3));

    // Una sesión sin palabras (silencio) termina el dictado.
    engine.closeSession();
    await settle();
    expect(engine.sessions, hasLength(3));
    expect(stoppedCalls, 1);
    expect(service.isListening, isFalse);
    expect(finalTexts(), ['hoy fui a clase', 'y comí tacos']);
    expect(errors, isEmpty);
  });

  test('sin voz termina en la primera sesión y avisa', () async {
    await start();
    engine.fail('error_speech_timeout');
    engine.closeSession();
    await settle();

    expect(engine.sessions, hasLength(1));
    expect(stoppedCalls, 1);
    expect(errors, ['No se detectó voz. Habla más cerca del micrófono.']);
  });

  test('el silencio después de dictar no se muestra como error', () async {
    await start();
    engine.emit('ya terminé', isFinal: true);
    engine.closeSession();
    await settle();

    engine.fail('error_no_match');
    engine.closeSession();
    await settle();

    expect(engine.sessions, hasLength(2));
    expect(stoppedCalls, 1);
    expect(errors, isEmpty);
  });

  test(
    'un error tardío de la sesión anterior no corta la reanudación',
    () async {
      await start();
      engine.emit('primera frase', isFinal: true);
      engine.closeSession();
      // Android avisa el error después de cerrar la sesión.
      engine.fail('error_no_match');
      await settle();

      expect(engine.sessions, hasLength(2));
      expect(service.isListening, isTrue);
      expect(stoppedCalls, 0);
      expect(errors, isEmpty);
    },
  );

  test('al terminar una frase cierra la sesión y abre otra sin esperar '
      'la pausa', () async {
    await start();
    engine.emit('primera frase', isFinal: true);

    // No espera los 10 s de pausa: la cierra en cuanto llega la frase.
    expect(engine.stopCalls, 1);
    await settle();
    expect(engine.sessions, hasLength(2));
    expect(service.isListening, isTrue);
  });

  SpeechToTextService fastDeafService() => SpeechToTextService(
    FakePermissionService(),
    speech: engine,
    restartDelay: Duration.zero,
    sessionEndGrace: const Duration(milliseconds: 10),
    deafAfter: const Duration(milliseconds: 60),
  );

  // Espera a que el vigilante detecte que el motor dejó de escuchar.
  Future<void> waitDeaf() =>
      Future<void>.delayed(const Duration(milliseconds: 150));

  test('si el motor oye sonido pero no entiende palabras, reabre la sesión; '
      'tras tres sesiones así termina y avisa', () async {
    service = fastDeafService();
    await start();
    for (var i = 1; i <= 3; i++) {
      // El volumen cambia (hay sonido) y luego el motor deja de reportarlo.
      engine.emitLevel(2);
      engine.emitLevel(7);
      await waitDeaf();
    }

    expect(engine.sessions, hasLength(3));
    expect(stoppedCalls, 1);
    expect(errors, ['No se detectó voz. Habla más cerca del micrófono.']);
  });

  test('si el micrófono no entrega audio (volumen fijo), reintenta hasta '
      'cuatro veces y avisa', () async {
    service = fastDeafService();
    await start();
    for (var i = 1; i <= 4; i++) {
      engine.emitLevel(-2);
      await waitDeaf();
    }

    expect(engine.sessions, hasLength(4));
    expect(stoppedCalls, 1);
    expect(errors, ['No se pudo capturar el audio del micrófono.']);
  });

  test(
    'una sesión con palabras reinicia la cuenta de sesiones fallidas',
    () async {
      service = fastDeafService();
      await start();
      for (var i = 1; i <= 3; i++) {
        engine.emitLevel(-2);
        await waitDeaf();
      }
      engine.emit('por fin', isFinal: true);
      await settle();
      for (var i = 1; i <= 3; i++) {
        engine.emitLevel(-2);
        await waitDeaf();
      }

      expect(engine.sessions, hasLength(8));
      expect(service.isListening, isTrue);
      expect(stoppedCalls, 0);
    },
  );

  test('sin reportes de volumen no da por sordo al motor', () async {
    service = SpeechToTextService(
      FakePermissionService(),
      speech: engine,
      restartDelay: Duration.zero,
      deafAfter: const Duration(milliseconds: 30),
    );
    await start();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(engine.stopCalls, 0);
    expect(engine.sessions, hasLength(1));
  });

  test('detenerlo a mano no lo reanuda', () async {
    await start();
    engine.emit('una frase');
    await service.stopListening();
    await settle();

    expect(engine.sessions, hasLength(1));
    expect(stoppedCalls, 1);
  });

  test('si el motor no confirma el cierre, el texto parcial no se pierde y '
      'el dictado sigue', () async {
    await start();
    engine.emit('texto sin confirmar');
    engine.stopWithoutDone();
    await settle();

    expect(results.last, ('texto sin confirmar', true));
    expect(engine.sessions, hasLength(2));
  });

  test(
    'un resultado que llega con la sesión ya cerrada no se pierde',
    () async {
      await start();
      engine.stopWithoutDone();
      engine.emit('llegó tarde', isFinal: true);

      expect(finalTexts(), ['llegó tarde']);
    },
  );
}
