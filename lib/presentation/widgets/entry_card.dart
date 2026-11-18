import 'package:flutter/material.dart';

import '../../core/utils/date_formatter.dart';
import '../../domain/entities/diary_entry.dart';
import 'entry_image.dart';
import 'mood_style.dart';

/// Tarjeta de una entrada en la lista, con estilo de página de diario: una
/// franja con el color del ánimo y la foto con marco blanco, como una foto
/// impresa. La miniatura está envuelta en un [Hero] que se anima hacia la
/// cabecera de la pantalla de detalle.
class EntryCard extends StatelessWidget {
  const EntryCard({super.key, required this.entry, required this.onTap});

  final DiaryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final moodColor = entry.mood.color;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Franja con el color del estado de ánimo.
              Container(width: 6, color: moodColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: HeroTags.entryImage(entry.id),
                        child: _PhotoFrame(
                          child: EntryImage(
                            path: entry.coverImage,
                            mood: entry.mood,
                            cacheWidth: 300,
                            emojiSize: 34,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: moodColor.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    entry.mood.emoji,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormatter.relative(entry.createdAt),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              entry.content.isEmpty
                                  ? 'Sin texto'
                                  : entry.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (entry.hasLocation)
                                  const _Meta(
                                    icon: Icons.place,
                                    label: 'Con ubicación',
                                  ),
                                if (entry.imagePaths.length > 1)
                                  _Meta(
                                    icon: Icons.photo_library,
                                    label: '${entry.imagePaths.length} fotos',
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marco blanco con sombra suave alrededor de la miniatura.
class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: SizedBox.square(dimension: 86, child: child),
      ),
    );
  }
}

/// Etiqueta pequeña (ubicación, número de fotos).
class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: scheme.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
