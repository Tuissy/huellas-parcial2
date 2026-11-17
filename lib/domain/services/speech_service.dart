/// Callback con el texto reconocido. [isFinal] indica que el motor terminó
/// de procesar la frase.
typedef SpeechResultCallback = void Function(String recognizedText, bool isFinal);

/// Dictado por voz: captura audio del micrófono y lo transcribe a texto.
abstract interface class SpeechService {
  bool get isListening;

  /// Inicia la captura de audio y la transcripción.
  ///
  /// * [onResult] recibe resultados parciales y finales.
  /// * [onSoundLevel] recibe el nivel de audio normalizado (0.0 – 1.0),
  ///   útil para mostrar que el micrófono está captando sonido.
  /// * [onStopped] se invoca cuando la escucha termina por cualquier motivo.
  /// * [onError] recibe errores no fatales durante la escucha.
  ///
  /// Puede lanzar `PermissionException` o `HardwareUnavailableException`.
  Future<void> startListening({
    required SpeechResultCallback onResult,
    void Function(double level)? onSoundLevel,
    void Function()? onStopped,
    void Function(String message)? onError,
  });

  /// Detiene la escucha y entrega el resultado final.
  Future<void> stopListening();

  /// Cancela la escucha descartando el resultado pendiente.
  Future<void> cancel();
}
