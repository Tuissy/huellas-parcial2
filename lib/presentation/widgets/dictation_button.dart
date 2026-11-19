// ARCHIVO: dictation_button.dart. Botón del micrófono para dictar con la voz.
import 'package:flutter/material.dart';

/// Botón de micrófono que "respira" con el nivel de audio captado.
///
/// El halo crece según [soundLevel] (0..1), dando retroalimentación visual
/// de que el micrófono está capturando la voz del usuario.
class DictationButton extends StatelessWidget {
  // Recibe si está escuchando, el nivel de sonido (de 0 a 1) y la acción al
  // pulsar. onPressed puede ser null para desactivar el botón, por ejemplo
  // mientras se guarda la entrada.
  const DictationButton({
    super.key,
    required this.isListening,
    required this.soundLevel,
    required this.onPressed,
  });

  final bool isListening;
  final double soundLevel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Medidor de volumen del dictado: mientras escucha, el halo mide 64
    // píxeles y crece hasta 28 más según el volumen de la voz. En reposo
    // mide 56, igual que el botón, y queda oculto.
    final haloSize = isListening ? 64 + 28 * soundLevel : 56.0;

    // Stack: el halo queda detrás y el botón encima, centrados en un cuadrado
    // de 96 píxeles.
    return SizedBox.square(
      dimension: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // El halo es un AnimatedContainer circular: cada vez que cambia
          // soundLevel anima su tamaño en 120 ms, y así parece que 'respira'
          // con la voz. Es rojo semitransparente al escuchar y transparente en
          // reposo.
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: haloSize,
            height: haloSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isListening ? scheme.error : scheme.primary).withValues(
                alpha: isListening ? 0.25 : 0,
              ),
            ),
          ),
          // El Tooltip describe la acción y también ayuda a los lectores de
          // pantalla.
          Tooltip(
            message: isListening ? 'Detener dictado' : 'Dictar con la voz',
            // Mientras graba, el botón usa el color de error (rojo) para que
            // se note que el micrófono está activo.
            child: FloatingActionButton(
              heroTag: null, // Evita conflictos con otros FAB durante Hero.
              elevation: 2,
              backgroundColor: isListening
                  ? scheme.error
                  : scheme.primaryContainer,
              foregroundColor: isListening
                  ? scheme.onError
                  : scheme.onPrimaryContainer,
              onPressed: onPressed,
              // AnimatedSwitcher cambia el ícono de micrófono por el de
              // detener con una animación de escala. La ValueKey le indica que
              // el ícono cambió y que debe animar el reemplazo.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  key: ValueKey(isListening),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
