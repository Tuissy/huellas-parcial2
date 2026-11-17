import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/di/app_dependencies.dart';
import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/diary_entry.dart';
import '../../../domain/entities/geo_location.dart';
import '../../../domain/services/media_service.dart';
import '../../../domain/usecases/save_diary_entry.dart';
import '../../controllers/entry_form_controller.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/dictation_button.dart';
import '../../widgets/mood_selector.dart';

/// Formulario para crear o editar una entrada del diario.
///
/// Integra los tres gadgets: cámara/galería, dictado por voz y GPS.
class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({super.key, this.initialEntry});

  final DiaryEntry? initialEntry;

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

enum _LocationDecision { cancel, retry, saveWithout, openSettings }

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final EntryFormController _controller;
  StreamSubscription<String>? _messagesSubscription;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final deps = AppScope.of(context);
    _controller = EntryFormController(
      mediaService: deps.mediaService,
      speechService: deps.speechService,
      locationService: deps.locationService,
      saveDiaryEntry: deps.saveDiaryEntry,
      initialEntry: widget.initialEntry,
    );
    _messagesSubscription = _controller.messages.listen((message) {
      if (mounted) {
        AppFeedback.showMessage(context, message, icon: Icons.info_outline);
      }
    });
    // Android puede cerrar la app mientras la cámara está abierta.
    unawaited(_controller.recoverLostPhotos());
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ acciones
  Future<void> _addPhoto(PhotoSource source) async {
    try {
      await _controller.addPhoto(source);
    } on AppException catch (error) {
      if (mounted) await AppFeedback.showError(context, error);
    }
  }

  Future<void> _toggleDictation() async {
    try {
      await _controller.toggleDictation();
    } on AppException catch (error) {
      if (mounted) await AppFeedback.showError(context, error);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Paso 1: ubicación GPS (con reintentos y opción de guardar sin ella).
    GeoLocation? location = _controller.existingLocation;
    if (_controller.needsGpsCapture) {
      while (true) {
        try {
          location = await _controller.captureLocation();
          break;
        } on AppException catch (error) {
          if (!mounted) return;
          final decision = await _askLocationDecision(error);
          switch (decision) {
            case _LocationDecision.retry:
              continue;
            case _LocationDecision.saveWithout:
              location = null;
            case _LocationDecision.openSettings:
              await _openSettingsFor(error);
              return;
            case _LocationDecision.cancel:
              return;
          }
          break;
        }
      }
    }

    // Paso 2: guardar en SQLite (y copiar fotos al almacenamiento interno).
    try {
      final saved = await _controller.save(location: location);
      if (!mounted) return;
      AppFeedback.showMessage(
        context,
        _controller.isEditing ? 'Cambios guardados' : 'Entrada guardada',
        icon: Icons.check_circle_outline,
      );
      Navigator.pop(context, saved);
    } on AppException catch (error) {
      if (mounted) await AppFeedback.showError(context, error);
    }
  }

  Future<_LocationDecision> _askLocationDecision(AppException error) async {
    final canOpenSettings =
        (error is PermissionException && error.permanentlyDenied) ||
        error is ServiceDisabledException;

    final decision = await showDialog<_LocationDecision>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.location_disabled_outlined),
        title: const Text('No se obtuvo la ubicación'),
        content: Text(
          '${error.message}\n\n¿Quieres guardar la entrada sin ubicación?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _LocationDecision.cancel),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              canOpenSettings
                  ? _LocationDecision.openSettings
                  : _LocationDecision.retry,
            ),
            child: Text(canOpenSettings ? 'Abrir ajustes' : 'Reintentar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _LocationDecision.saveWithout),
            child: const Text('Guardar sin ubicación'),
          ),
        ],
      ),
    );
    return decision ?? _LocationDecision.cancel;
  }

  Future<void> _openSettingsFor(AppException error) async {
    final deps = AppScope.of(context);
    if (error is ServiceDisabledException) {
      await deps.locationService.openLocationSettings();
    } else {
      await deps.permissionService.openAppSettings();
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await AppFeedback.confirm(
      context,
      icon: Icons.edit_off_outlined,
      title: '¿Descartar cambios?',
      message: 'Perderás lo que escribiste y las fotos nuevas.',
      confirmLabel: 'Descartar',
      destructive: true,
    );
    if (discard && mounted) Navigator.pop(context);
  }

  // ------------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final canLeave = !_controller.hasUnsavedChanges && !_controller.isBusy;
        return PopScope(
          canPop: canLeave,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop || _controller.isBusy) return;
            _confirmDiscard();
          },
          child: Stack(
            children: [
              Scaffold(
                appBar: AppBar(
                  title: Text(
                    _controller.isEditing ? 'Editar entrada' : 'Nueva entrada',
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'Guardar',
                      icon: const Icon(Icons.check),
                      onPressed: _controller.isBusy ? null : _save,
                    ),
                  ],
                ),
                body: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _SectionTitle(
                        icon: Icons.photo_camera_outlined,
                        title: 'Fotos del día',
                        trailing:
                            '${_controller.images.length}/${SaveDiaryEntry.maxImages}',
                      ),
                      _PhotoPicker(
                        images: _controller.images,
                        canAdd: _controller.canAddImages && !_controller.isBusy,
                        onAdd: _addPhoto,
                        onRemove: _controller.removeImage,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _controller.titleController,
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Título',
                          hintText: 'Ej. Un día en el parque',
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Escribe un título'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      const _SectionTitle(
                        icon: Icons.mood,
                        title: '¿Cómo te sientes?',
                      ),
                      MoodSelector(
                        selected: _controller.mood,
                        onChanged: _controller.setMood,
                      ),
                      const SizedBox(height: 20),
                      const _SectionTitle(icon: Icons.notes, title: 'Tu día'),
                      _DictationPanel(
                        isListening: _controller.isListening,
                        soundLevel: _controller.soundLevel,
                        onToggle: _controller.isBusy ? null : _toggleDictation,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _controller.contentController,
                        minLines: 6,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Escribe o dicta lo que pasó hoy…',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SectionTitle(
                        icon: Icons.place_outlined,
                        title: 'Ubicación',
                      ),
                      _LocationOptions(controller: _controller),
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        onPressed: _controller.isBusy ? null : _save,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          _controller.isEditing
                              ? 'Guardar cambios'
                              : 'Guardar entrada',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Capa de progreso: retroalimentación mientras el GPS responde
              // y mientras se guarda en la base de datos.
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_controller.isBusy,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _controller.isBusy
                        ? _BusyOverlay(
                            key: ValueKey(_controller.status),
                            status: _controller.status,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
          if (trailing != null)
            Text(trailing!, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.images,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> images;
  final bool canAdd;
  final ValueChanged<PhotoSource> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: images.isEmpty
              ? const SizedBox(width: double.infinity)
              : SizedBox(
                  height: 116,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => _Thumbnail(
                      key: ValueKey(images[index]),
                      path: images[index],
                      isCover: index == 0,
                      onRemove: () => onRemove(images[index]),
                    ),
                  ),
                ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canAdd ? () => onAdd(PhotoSource.camera) : null,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Cámara'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canAdd ? () => onAdd(PhotoSource.gallery) : null,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galería'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    super.key,
    required this.path,
    required this.isCover,
    required this.onRemove,
  });

  final String path;
  final bool isCover;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(path),
              width: 104,
              height: 104,
              fit: BoxFit.cover,
              cacheWidth: 300,
              errorBuilder: (_, _, _) => Container(
                width: 104,
                height: 104,
                color: Colors.black12,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          if (isCover)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Portada',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          Positioned(
            right: 2,
            top: 2,
            child: IconButton.filled(
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              tooltip: 'Quitar foto',
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              onPressed: onRemove,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _DictationPanel extends StatelessWidget {
  const _DictationPanel({
    required this.isListening,
    required this.soundLevel,
    required this.onToggle,
  });

  final bool isListening;
  final double soundLevel;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: isListening
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.5)
          : theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
        child: Row(
          children: [
            DictationButton(
              isListening: isListening,
              soundLevel: soundLevel,
              onPressed: onToggle,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Column(
                  key: ValueKey(isListening),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isListening ? 'Escuchando…' : 'Dictado por voz',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isListening
                          ? 'Habla con naturalidad. Toca para terminar.'
                          : 'Toca el micrófono y cuenta cómo fue tu día.',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (isListening) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: soundLevel,
                          minHeight: 6,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationOptions extends StatelessWidget {
  const _LocationOptions({required this.controller});

  final EntryFormController controller;

  @override
  Widget build(BuildContext context) {
    final existing = controller.initialEntry?.location;
    final theme = Theme.of(context);

    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.my_location),
            title: Text(
              existing == null
                  ? 'Guardar mi ubicación GPS'
                  : 'Conservar ubicación',
            ),
            subtitle: Text(
              existing == null
                  ? 'Se capturará tu posición actual al guardar.'
                  : existing.formatted,
            ),
            value: controller.attachLocation,
            onChanged: controller.isBusy ? null : controller.setAttachLocation,
          ),
          if (existing != null && controller.attachLocation)
            CheckboxListTile(
              secondary: const Icon(Icons.refresh),
              title: const Text('Actualizar a mi ubicación actual'),
              value: controller.refreshLocation,
              onChanged: controller.isBusy
                  ? null
                  : (value) => controller.setRefreshLocation(value ?? false),
            ),
          if (!controller.attachLocation)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'La entrada se guardará sin coordenadas.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay({super.key, required this.status});

  final FormStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, title, subtitle) = switch (status) {
      FormStatus.locating => (
        Icons.satellite_alt_outlined,
        'Obteniendo tu ubicación GPS…',
        'Puede tardar unos segundos si estás en interiores.',
      ),
      _ => (
        Icons.save_outlined,
        'Guardando tu entrada…',
        'Copiando fotos y escribiendo en la base de datos.',
      ),
    };

    return ColoredBox(
      color: Colors.black45,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(40),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const SizedBox.square(
                      dimension: 64,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    Icon(icon, color: theme.colorScheme.primary),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
