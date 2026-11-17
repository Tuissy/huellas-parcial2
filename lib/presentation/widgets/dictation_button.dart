import 'package:flutter/material.dart';

/// Botón de micrófono que "respira" con el nivel de audio captado.
///
/// El halo crece según [soundLevel] (0..1), dando retroalimentación visual
/// de que el micrófono está capturando la voz del usuario.
class DictationButton extends StatelessWidget {
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
    final haloSize = isListening ? 64 + 28 * soundLevel : 56.0;

    return SizedBox.square(
      dimension: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
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
          Tooltip(
            message: isListening ? 'Detener dictado' : 'Dictar con la voz',
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
