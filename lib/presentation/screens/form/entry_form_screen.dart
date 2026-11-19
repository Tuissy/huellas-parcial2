// Pantalla del formulario (capa de presentación). La misma pantalla sirve para
// crear una entrada nueva y para editar una existente.
// Librerías de Dart: dart:async para StreamSubscription y unawaited, y dart:io
// para File, que permite mostrar las fotos desde el disco.
import 'dart:async';
import 'dart:io';

// Material: los widgets visuales de Flutter (Scaffold, AppBar, botones, campos
// de texto, etc.).
import 'package:flutter/material.dart';

// Capa core: inyección de dependencias (AppScope) y los errores propios de la
// app (AppException).
import '../../../core/di/app_dependencies.dart';
import '../../../core/errors/app_exception.dart';
// Capa domain: entidades (entrada y ubicación), el servicio de fotos y el caso
// de uso SaveDiaryEntry.
import '../../../domain/entities/diary_entry.dart';
import '../../../domain/entities/geo_location.dart';
import '../../../domain/services/media_service.dart';
import '../../../domain/usecases/save_diary_entry.dart';
// Capa presentation: el controlador del formulario y widgets reutilizables
// (mensajes, botón de dictado y selector de ánimo).
import '../../controllers/entry_form_controller.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/dictation_button.dart';
import '../../widgets/mood_selector.dart';

/// Formulario para crear o editar una entrada del diario.
///
/// Integra los tres gadgets: cámara/galería, dictado por voz y GPS.
class EntryFormScreen extends StatefulWidget {
  // Constructor: si recibe initialEntry la pantalla entra en modo edición; si
  // es null, se crea una entrada nueva. La entrada llega como argumento de la
  // ruta con nombre entryForm.
  const EntryFormScreen({super.key, this.initialEntry});

  final DiaryEntry? initialEntry;

  // Un StatefulWidget crea su objeto State, que guarda los datos que cambian
  // mientras la pantalla está abierta.
  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

/// Opciones que puede elegir el usuario cuando el GPS falla al guardar:
/// cancelar, reintentar, guardar sin ubicación o abrir los ajustes del
/// teléfono.
enum _LocationDecision { cancel, retry, saveWithout, openSettings }

/// Estado de la pantalla del formulario. Aquí solo está la parte visual; la
/// lógica vive en EntryFormController (responsabilidad única).
class _EntryFormScreenState extends State<EntryFormScreen> {
  // Llave global del Form: permite validar todos los campos a la vez antes de
  // guardar.
  final _formKey = GlobalKey<FormState>();
  // El controlador (EntryFormController) separa la lógica de la pantalla:
  // maneja fotos, dictado, GPS y guardado. Es late final porque se crea una
  // sola vez, en didChangeDependencies.
  late final EntryFormController _controller;
  // Suscripción a los mensajes informativos del controlador. Se cancela en
  // dispose para no dejar escuchas abiertas.
  StreamSubscription<String>? _messagesSubscription;
  // Bandera para inicializar solo una vez, porque didChangeDependencies se
  // puede llamar varias veces.
  bool _initialized = false;

  /// Aquí se obtienen las dependencias desde AppScope usando el context y se
  /// crea el controlador. La bandera _initialized asegura que esto pase una
  /// sola vez.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si ya se inicializó antes, no se vuelve a crear nada.
    if (_initialized) return;
    _initialized = true;

    // Inyección de dependencias: AppScope entrega los servicios ya construidos
    // (cámara, micrófono, GPS) y el caso de uso de guardado.
    final deps = AppScope.of(context);
    // Se crea el controlador con esos servicios y con la entrada a editar, si
    // existe.
    _controller = EntryFormController(
      mediaService: deps.mediaService,
      speechService: deps.speechService,
      locationService: deps.locationService,
      saveDiaryEntry: deps.saveDiaryEntry,
      initialEntry: widget.initialEntry,
    );
    // Escucha los mensajes del controlador (por ejemplo, el aviso del límite
    // de fotos) y los muestra en un SnackBar con AppFeedback. Se revisa mounted
    // para no usar el context de una pantalla ya cerrada.
    _messagesSubscription = _controller.messages.listen((message) {
      if (mounted) {
        AppFeedback.showMessage(context, message, icon: Icons.info_outline);
      }
    });
    // Android puede cerrar la app mientras la cámara está abierta.
    // Por eso, al abrir el formulario se intenta recuperar la foto que se
    // estaba tomando. Con unawaited se indica que, a propósito, no se espera
    // el resultado.
    unawaited(_controller.recoverLostPhotos());
  }

  /// Al cerrar la pantalla se liberan los recursos: se cancela la suscripción
  /// y se desecha el controlador, que libera los campos de texto y detiene el
  /// dictado si seguía activo.
  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ acciones
  /// Agrega una foto desde la cámara o la galería. Usa try-catch y
  /// AppFeedback para mostrar errores (por ejemplo, permiso de cámara negado)
  /// sin cerrar la app. Solo muestra el error si la pantalla sigue abierta
  /// (mounted).
  Future<void> _addPhoto(PhotoSource source) async {
    try {
      await _controller.addPhoto(source);
    } on AppException catch (error) {
      if (mounted) await AppFeedback.showError(context, error);
    }
  }

  /// Inicia o detiene el dictado por voz con el micrófono. Si no hay permiso
  /// de micrófono o el reconocimiento de voz no está disponible, el error se
  /// muestra con AppFeedback.
  Future<void> _toggleDictation() async {
    try {
      await _controller.toggleDictation();
    } on AppException catch (error) {
      if (mounted) await AppFeedback.showError(context, error);
    }
  }

  /// Guarda la entrada en dos pasos: primero obtiene la ubicación GPS y
  /// después la guarda en la base de datos SQLite.
  Future<void> _save() async {
    // Oculta el teclado y valida el formulario (el título es obligatorio). Si
    // algo no es válido, no se guarda.
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Paso 1: ubicación GPS (con reintentos y opción de guardar sin ella).
    // Al editar, si se conserva la ubicación anterior se reutiliza; si no,
    // empieza en null.
    GeoLocation? location = _controller.existingLocation;
    // Solo se le pide una posición nueva al GPS cuando hace falta: entrada
    // nueva con ubicación activada, o el usuario marcó actualizar la
    // ubicación.
    if (_controller.needsGpsCapture) {
      // Ciclo para que el usuario pueda reintentar las veces que quiera.
      while (true) {
        try {
          // captureLocation pone el estado 'locating', que muestra la capa de
          // progreso del GPS. Si funciona, break sale del ciclo.
          location = await _controller.captureLocation();
          break;
        } on AppException catch (error) {
          // El GPS falló (permiso negado, GPS apagado, tiempo agotado, etc.).
          // Si la pantalla sigue abierta, se le pregunta al usuario qué hacer.
          if (!mounted) return;
          final decision = await _askLocationDecision(error);
          // Se actúa según lo que eligió el usuario en el diálogo.
          switch (decision) {
            // Reintentar: continue vuelve al inicio del ciclo y pide el GPS
            // otra vez.
            case _LocationDecision.retry:
              continue;
            // Guardar sin ubicación: la entrada se guarda sin coordenadas.
            case _LocationDecision.saveWithout:
              location = null;
            // Abrir ajustes: se abren los ajustes del sistema y por ahora no se
            // guarda.
            case _LocationDecision.openSettings:
              await _openSettingsFor(error);
              return;
            // Cancelar: no se guarda y el usuario sigue en el formulario.
            case _LocationDecision.cancel:
              return;
          }
          // Solo la opción de guardar sin ubicación llega aquí: break sale
          // del ciclo y se continúa con el paso 2.
          break;
        }
      }
    }

    // Paso 2: guardar en SQLite (y copiar fotos al almacenamiento interno).
    try {
      // save pone el estado 'saving' (capa de progreso) y llama al caso de uso
      // SaveDiaryEntry, que valida y guarda la entrada.
      final saved = await _controller.save(location: location);
      // Si la pantalla ya se cerró, no se hace nada más.
      if (!mounted) return;
      // Mensaje de éxito, distinto si se creó o si se editó la entrada.
      AppFeedback.showMessage(
        context,
        _controller.isEditing ? 'Cambios guardados' : 'Entrada guardada',
        icon: Icons.check_circle_outline,
      );
      // Regresa a la pantalla anterior y devuelve la entrada guardada como
      // resultado de Navigator.pop.
      Navigator.pop(context, saved);
    } on AppException catch (error) {
      // Si el guardado falla (validación o error de almacenamiento), se
      // muestra el error sin cerrar la app y sin perder lo escrito.
      if (mounted) await AppFeedback.showError(context, error);
    }
  }

  /// Muestra un AlertDialog cuando no se pudo obtener la ubicación y devuelve
  /// la opción que eligió el usuario.
  Future<_LocationDecision> _askLocationDecision(AppException error) async {
    // Si el permiso quedó negado para siempre o el GPS está apagado,
    // reintentar no sirve; en ese caso se ofrece abrir los ajustes.
    final canOpenSettings =
        (error is PermissionException && error.permanentlyDenied) ||
        error is ServiceDisabledException;

    // showDialog devuelve un Future con el valor que se pasa a Navigator.pop al
    // cerrar el diálogo.
    final decision = await showDialog<_LocationDecision>(
      context: context,
      builder: (context) => AlertDialog(
        // Icono, título y mensaje del error, con la pregunta al usuario.
        icon: const Icon(Icons.location_disabled_outlined),
        title: const Text('No se obtuvo la ubicación'),
        content: Text(
          '${error.message}\n\n¿Quieres guardar la entrada sin ubicación?',
        ),
        // Botones del diálogo: Cancelar, Reintentar (o Abrir ajustes) y
        // Guardar sin ubicación.
        actions: [
          // Cancelar: cierra el diálogo sin guardar.
          TextButton(
            onPressed: () => Navigator.pop(context, _LocationDecision.cancel),
            child: const Text('Cancelar'),
          ),
          // El segundo botón cambia según el tipo de error.
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              canOpenSettings
                  ? _LocationDecision.openSettings
                  : _LocationDecision.retry,
            ),
            child: Text(canOpenSettings ? 'Abrir ajustes' : 'Reintentar'),
          ),
          // Botón principal: guardar la entrada aunque no tenga ubicación.
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _LocationDecision.saveWithout),
            child: const Text('Guardar sin ubicación'),
          ),
        ],
      ),
    );
    // Si el usuario cierra el diálogo tocando afuera, se toma como cancelar.
    return decision ?? _LocationDecision.cancel;
  }

  /// Abre los ajustes correctos según el error: los de ubicación si el GPS
  /// está apagado, o los de la app si el permiso está negado.
  Future<void> _openSettingsFor(AppException error) async {
    final deps = AppScope.of(context);
    if (error is ServiceDisabledException) {
      await deps.locationService.openLocationSettings();
    } else {
      await deps.permissionService.openAppSettings();
    }
  }

  /// Pregunta si se quieren descartar los cambios antes de salir. Lo llama
  /// PopScope cuando hay cambios sin guardar.
  Future<void> _confirmDiscard() async {
    final discard = await AppFeedback.confirm(
      context,
      icon: Icons.edit_off_outlined,
      title: '¿Descartar cambios?',
      message: 'Perderás lo que escribiste y las fotos nuevas.',
      confirmLabel: 'Descartar',
      destructive: true,
    );
    // Solo se cierra la pantalla si el usuario confirma.
    if (discard && mounted) Navigator.pop(context);
  }

  // ------------------------------------------------------------------ UI
  /// Construye la interfaz del formulario. Se vuelve a dibujar cada vez que el
  /// controlador avisa un cambio con notifyListeners.
  @override
  Widget build(BuildContext context) {
    // ListenableBuilder escucha al controlador (un ChangeNotifier) y redibuja
    // esta parte cuando cambia su estado, sin usar setState.
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        // Se puede salir sin preguntar solo si no hay cambios sin guardar y no
        // hay una operación en curso.
        final canLeave = !_controller.hasUnsavedChanges && !_controller.isBusy;
        // PopScope para no perder cambios: intercepta el botón o el gesto de
        // atrás. Si canPop es false, se bloquea la salida y se pide
        // confirmación.
        return PopScope(
          canPop: canLeave,
          onPopInvokedWithResult: (didPop, result) {
            // Si ya se salió, o si se está guardando, no se muestra el
            // diálogo.
            if (didPop || _controller.isBusy) return;
            _confirmDiscard();
          },
          // Stack: el formulario va abajo y la capa de progreso encima.
          child: Stack(
            children: [
              // Scaffold con AppBar: la estructura básica de la pantalla.
              Scaffold(
                appBar: AppBar(
                  // El título cambia según si se crea o se edita la entrada.
                  title: Text(
                    _controller.isEditing ? 'Editar entrada' : 'Nueva entrada',
                  ),
                  // Botón de guardar en la barra superior; queda desactivado
                  // (null) mientras hay una operación en curso.
                  actions: [
                    IconButton(
                      tooltip: 'Guardar',
                      icon: const Icon(Icons.check),
                      onPressed: _controller.isBusy ? null : _save,
                    ),
                  ],
                ),
                // Form agrupa los campos para validarlos juntos con _formKey.
                body: Form(
                  key: _formKey,
                  // ListView para que todo el formulario se pueda desplazar,
                  // por ejemplo cuando aparece el teclado.
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      // Sección de fotos: título con un contador, por ejemplo
                      // 2/4.
                      _SectionTitle(
                        icon: Icons.photo_camera_outlined,
                        title: 'Fotos del día',
                        trailing:
                            '${_controller.images.length}/${SaveDiaryEntry.maxImages}',
                      ),
                      // Selector de fotos: miniaturas y botones de cámara y
                      // galería. Se desactiva al llegar al máximo de fotos o
                      // mientras se guarda.
                      _PhotoPicker(
                        images: _controller.images,
                        canAdd: _controller.canAddImages && !_controller.isBusy,
                        onAdd: _addPhoto,
                        onRemove: _controller.removeImage,
                      ),
                      const SizedBox(height: 20),
                      // Campo del título: obligatorio, de máximo 80
                      // caracteres y con mayúscula automática al inicio de
                      // cada oración.
                      TextFormField(
                        controller: _controller.titleController,
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Título',
                          hintText: 'Ej. Un día en el parque',
                          prefixIcon: Icon(Icons.title),
                        ),
                        // Validación: si el título está vacío muestra
                        // 'Escribe un título'.
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Escribe un título'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      // Sección del estado de ánimo.
                      const _SectionTitle(
                        icon: Icons.mood,
                        title: '¿Cómo te sientes?',
                      ),
                      // MoodSelector: el usuario elige cómo se siente y el
                      // cambio se guarda en el controlador.
                      MoodSelector(
                        selected: _controller.mood,
                        onChanged: _controller.setMood,
                      ),
                      const SizedBox(height: 20),
                      // Sección del texto del día.
                      const _SectionTitle(icon: Icons.notes, title: 'Tu día'),
                      // Panel de dictado por voz con medidor de volumen: indica
                      // si el micrófono está escuchando y el nivel del
                      // sonido.
                      _DictationPanel(
                        isListening: _controller.isListening,
                        soundLevel: _controller.soundLevel,
                        onToggle: _controller.isBusy ? null : _toggleDictation,
                      ),
                      const SizedBox(height: 12),
                      // Campo de texto libre que crece con el contenido
                      // (maxLines null). Aquí también aparece el texto
                      // dictado.
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
                      // Sección de ubicación: opciones para guardar o no la
                      // ubicación GPS.
                      const _SectionTitle(
                        icon: Icons.place_outlined,
                        title: 'Ubicación',
                      ),
                      _LocationOptions(controller: _controller),
                      const SizedBox(height: 28),
                      // Botón grande para guardar; se desactiva mientras hay
                      // una operación en curso.
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
              // Positioned.fill hace que la capa cubra toda la pantalla.
              Positioned.fill(
                // IgnorePointer: cuando no hay nada en proceso, los toques
                // pasan al formulario que está debajo.
                child: IgnorePointer(
                  ignoring: !_controller.isBusy,
                  // AnimatedSwitcher muestra y oculta la capa con un fundido.
                  // La key cambia con el estado para animar el paso de ubicar a
                  // guardar.
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

/// Título de cada sección del formulario: icono, texto y un texto opcional a
/// la derecha (por ejemplo, el contador de fotos).
class _SectionTitle extends StatelessWidget {
  // Recibe el icono, el título y el texto opcional de la derecha.
  const _SectionTitle({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final String? trailing;

  // Dibuja la fila con los colores y estilos del tema de la app.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      // Fila con el icono en el color primario, el título y, al final, el
      // texto opcional.
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
          // El texto de la derecha solo se dibuja si existe (if dentro de la
          // lista de hijos).
          if (trailing != null)
            Text(trailing!, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// Muestra las fotos elegidas en una fila horizontal y los botones para agregar
/// fotos con la cámara o la galería.
class _PhotoPicker extends StatelessWidget {
  // Recibe la lista de fotos, si se pueden agregar más y las funciones de la
  // pantalla para agregar o quitar una foto.
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

  // Columna con las miniaturas arriba y los botones abajo.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // AnimatedSize anima el cambio de alto cuando aparece la primera foto o
        // se quita la última.
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: images.isEmpty
              ? const SizedBox(width: double.infinity)
              : SizedBox(
                  height: 116,
                  // Lista horizontal de miniaturas; ListView.separated pone un
                  // espacio entre cada una.
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    // Cada miniatura usa su ruta como key para que Flutter no
                    // confunda las fotos al quitar una. La primera foto es la
                    // portada.
                    itemBuilder: (context, index) => _Thumbnail(
                      key: ValueKey(images[index]),
                      path: images[index],
                      isCover: index == 0,
                      onRemove: () => onRemove(images[index]),
                    ),
                  ),
                ),
        ),
        // Botones para agregar fotos con la cámara o la galería. Se
        // desactivan (onPressed null) cuando ya no se puede agregar.
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

/// Miniatura de una foto con animación de entrada, etiqueta 'Portada' en la
/// primera y un botón para quitarla.
class _Thumbnail extends StatelessWidget {
  // Recibe la ruta de la foto, si es la portada y qué hacer al quitarla.
  const _Thumbnail({
    super.key,
    required this.path,
    required this.isCover,
    required this.onRemove,
  });

  final String path;
  final bool isCover;
  final VoidCallback onRemove;

  // Dibuja la miniatura animada con sus elementos encima.
  @override
  Widget build(BuildContext context) {
    // TweenAnimationBuilder: la miniatura aparece creciendo del 60% al 100% de
    // su tamaño con un pequeño rebote (easeOutBack).
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      // Stack para poner la etiqueta y el botón encima de la foto.
      child: Stack(
        children: [
          // Foto con bordes redondeados. Image.file la lee del disco y
          // cacheWidth reduce la memoria que usa.
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(path),
              width: 104,
              height: 104,
              fit: BoxFit.cover,
              cacheWidth: 300,
              // errorBuilder: si el archivo no se puede leer, muestra un icono
              // de imagen rota en lugar de fallar.
              errorBuilder: (_, _, _) => Container(
                width: 104,
                height: 104,
                color: Colors.black12,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          // Etiqueta 'Portada' solo en la primera foto, que es la que se ve en
          // la lista.
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
          // Botón X en la esquina superior para quitar la foto.
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

/// Panel de dictado por voz: botón de micrófono y textos que cambian mientras
/// escucha, con medidor de volumen.
class _DictationPanel extends StatelessWidget {
  // Recibe si está escuchando, el nivel de sonido (de 0 a 1) y la acción del
  // botón (null cuando está desactivado).
  const _DictationPanel({
    required this.isListening,
    required this.soundLevel,
    required this.onToggle,
  });

  final bool isListening;
  final double soundLevel;
  final VoidCallback? onToggle;

  // Dibuja la tarjeta del dictado según su estado.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // La tarjeta cambia de color mientras el micrófono escucha, para que se
    // note claramente.
    return Card(
      color: isListening
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.5)
          : theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
        child: Row(
          children: [
            // DictationButton: botón de micrófono cuyo halo crece con el
            // nivel de audio.
            DictationButton(
              isListening: isListening,
              soundLevel: soundLevel,
              onPressed: onToggle,
            ),
            const SizedBox(width: 4),
            Expanded(
              // AnimatedSwitcher cambia los textos con una transición suave;
              // la key con isListening le indica cuándo cambiar.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Column(
                  key: ValueKey(isListening),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título y texto de ayuda según el estado del dictado.
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
                    // Medidor de volumen: barra que se llena con el nivel de
                    // sonido del micrófono. Solo aparece mientras escucha.
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

/// Opciones de ubicación del formulario: guardar o no la ubicación GPS y, al
/// editar, la opción de actualizarla.
class _LocationOptions extends StatelessWidget {
  // Recibe el controlador para leer y cambiar las opciones de ubicación.
  const _LocationOptions({required this.controller});

  final EntryFormController controller;

  // Dibuja una tarjeta con las opciones de ubicación.
  @override
  Widget build(BuildContext context) {
    // Ubicación que ya tenía la entrada; solo existe al editar.
    final existing = controller.initialEntry?.location;
    final theme = Theme.of(context);

    return Card(
      child: Column(
        children: [
          // Interruptor para adjuntar la ubicación. En una entrada nueva se
          // captura al guardar; al editar se ven las coordenadas guardadas. Se
          // desactiva mientras hay una operación en curso.
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
          // Si ya había ubicación y se conserva, una casilla permite
          // reemplazarla por la posición actual.
          if (existing != null && controller.attachLocation)
            CheckboxListTile(
              secondary: const Icon(Icons.refresh),
              title: const Text('Actualizar a mi ubicación actual'),
              value: controller.refreshLocation,
              onChanged: controller.isBusy
                  ? null
                  : (value) => controller.setRefreshLocation(value ?? false),
            ),
          // Aviso cuando el usuario decide no guardar la ubicación.
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

/// Capa de progreso que tapa el formulario mientras el GPS responde o mientras
/// se guarda, para que el usuario sepa qué está pasando.
class _BusyOverlay extends StatelessWidget {
  // Recibe el estado actual del formulario (ubicando o guardando).
  const _BusyOverlay({super.key, required this.status});

  final FormStatus status;

  // Dibuja la capa de progreso con textos según el estado.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Switch como expresión (Dart 3): según el estado devuelve un record con
    // el icono, el título y el subtítulo.
    final (icon, title, subtitle) = switch (status) {
      // Buscando la ubicación GPS.
      FormStatus.locating => (
        Icons.satellite_alt_outlined,
        'Obteniendo tu ubicación GPS…',
        'Puede tardar unos segundos si estás en interiores.',
      ),
      // Cualquier otro estado ocupado es el guardado.
      _ => (
        Icons.save_outlined,
        'Guardando tu entrada…',
        'Copiando fotos y escribiendo en la base de datos.',
      ),
    };

    // Fondo oscuro semitransparente con una tarjeta en el centro.
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
                // Indicador circular girando con el icono en el centro.
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
                // Título y explicación de lo que está pasando.
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
