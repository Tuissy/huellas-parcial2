import 'package:flutter/material.dart';

import '../../domain/entities/mood.dart';
import 'mood_style.dart';

/// Selector horizontal de estado de ánimo con animación de escala.
class MoodSelector extends StatelessWidget {
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final mood in Mood.values)
          Expanded(
            child: Semantics(
              selected: mood == selected,
              button: true,
              label: mood.label,
              child: GestureDetector(
                onTap: () => onChanged(mood),
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
