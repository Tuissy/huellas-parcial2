// ARCHIVO: mood_selector.dart. Selector de estado de ánimo del formulario.
import 'package:flutter/material.dart';

import '../../domain/entities/mood.dart';
import 'mood_style.dart';

/// Selector horizontal de estado de ánimo con animación de escala.
class MoodSelector extends StatelessWidget {
  // Widget sin estado: recibe el ánimo seleccionado y avisa con onChanged
  // cuando el usuario elige otro. El valor real lo guarda EntryFormController
  // (el formulario le pasa setMood).
  const MoodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Mood selected;
  final ValueChanged<Mood> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Una fila con un botón por cada valor del enum Mood (bucle for dentro de
    // la lista de hijos). Expanded reparte el ancho en partes iguales.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final mood in Mood.values)
          Expanded(
            // Semantics indica a los lectores de pantalla que es un botón, su
            // nombre y si está seleccionado (accesibilidad).
            child: Semantics(
              selected: mood == selected,
              button: true,
              label: mood.label,
              // Al tocar, se avisa qué ánimo se eligió.
              child: GestureDetector(
                onTap: () => onChanged(mood),
                // AnimatedContainer anima solo el cambio de color y de borde
                // cuando cambia la selección. La curva easeOutBack da un
                // pequeño rebote.
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: mood == selected
                        ? mood.color.withValues(alpha: 0.22)
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: mood == selected ? mood.color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      // El emoji seleccionado crece un 25 % con animación.
                      AnimatedScale(
                        scale: mood == selected ? 1.25 : 1,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutBack,
                        child: Text(
                          mood.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Nombre del ánimo en una sola línea; si no cabe, se
                      // desvanece en lugar de saltar de línea.
                      Text(
                        mood.label,
                        style: theme.textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
