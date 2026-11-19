// Capa core: código compartido por todas las capas. Este archivo es la
// raíz de composición (inyección de dependencias) de la aplicación.
import 'package:flutter/widgets.dart';

// Implementaciones concretas de la capa de datos (SQLite,
// SharedPreferences, GPS, cámara, micrófono, biometría, mapas). Este
// es el único lugar donde se crean; las pantallas no las importan.
import '../../data/datasources/diary_database.dart';
import '../../data/datasources/diary_local_data_source.dart';
import '../../data/repositories/shared_prefs_settings_repository.dart';
import '../../data/repositories/sqlite_diary_repository.dart';
import '../../data/services/geolocator_location_service.dart';
import '../../data/services/handler_permission_service.dart';
import '../../data/services/image_picker_media_service.dart';
import '../../data/services/local_auth_biometric_service.dart';
import '../../data/services/local_image_storage_service.dart';
import '../../data/services/speech_to_text_service.dart';
import '../../data/services/url_maps_launcher.dart';
// Abstracciones de la capa de dominio: interfaces y casos de uso. Son
// los tipos con los que trabaja el resto de la app.
import '../../domain/repositories/diary_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/services/biometric_auth_service.dart';
import '../../domain/services/image_storage_service.dart';
import '../../domain/services/location_service.dart';
import '../../domain/services/maps_launcher.dart';
import '../../domain/services/media_service.dart';
import '../../domain/services/permission_service.dart';
import '../../domain/services/speech_service.dart';
import '../../domain/usecases/delete_diary_entry.dart';
import '../../domain/usecases/save_diary_entry.dart';

// Clase contenedora: guarda una instancia de cada repositorio,
// servicio y caso de uso que necesitan las pantallas.
/// Raíz de composición: el único lugar donde se crean las implementaciones
/// concretas. El resto de la app solo conoce las interfaces del dominio,
/// por lo que cambiar SQLite, el GPS o la cámara no afecta a las pantallas
/// (Inversión de Dependencias + Abierto/Cerrado).
class AppDependencies {
  // Constructor con parámetros nombrados obligatorios. Todos los tipos
  // son interfaces: en producción se pasan las clases reales y en las
  // pruebas se pasan clases falsas (fakes), sin cambiar nada más.
  AppDependencies({
    required this.diaryRepository,
    required this.settingsRepository,
    required this.imageStorage,
    required this.permissionService,
    required this.mediaService,
    required this.speechService,
    required this.locationService,
    required this.biometricAuthService,
    required this.mapsLauncher,
    // Los casos de uso se arman aquí, en la lista de inicialización, a
    // partir del repositorio del diario y del almacenamiento de imágenes.
  }) : saveDiaryEntry = SaveDiaryEntry(diaryRepository, imageStorage),
       deleteDiaryEntry = DeleteDiaryEntry(diaryRepository, imageStorage);

  // Los campos se declaran con el tipo de la interfaz del dominio, no
  // con la clase concreta: principio de inversión de dependencias (la D
  // de SOLID).
  final DiaryRepository diaryRepository;
  final SettingsRepository settingsRepository;
  final ImageStorageService imageStorage;
  final PermissionService permissionService;
  final MediaService mediaService;
  final SpeechService speechService;
  final LocationService locationService;
  final BiometricAuthService biometricAuthService;
  final MapsLauncher mapsLauncher;

  // Casos de uso: reglas de negocio que combinan varias dependencias
  // (guardar y eliminar entradas junto con sus fotos).
  final SaveDiaryEntry saveDiaryEntry;
  final DeleteDiaryEntry deleteDiaryEntry;

  // Método de fábrica estático y asíncrono: algunas piezas necesitan
  // esperar (await) para inicializarse, y un constructor no puede usar
  // await.
  /// Construye las dependencias de producción.
  static Future<AppDependencies> create() async {
    // Primero se preparan las piezas base: el almacenamiento de fotos y
    // las preferencias (SharedPreferences), que se esperan con await; el
    // servicio de permisos, que lo usan varias clases; y el objeto de la
    // base de datos SQLite.
    final imageStorage = await LocalImageStorageService.create();
    final settings = await SharedPrefsSettingsRepository.create();
    const permissions = HandlerPermissionService();
    final database = DiaryDatabase();

    // Luego se conectan las piezas: el repositorio del diario usa la
    // fuente de datos local (SQLite) y el almacenamiento de fotos; la
    // cámara y el dictado reciben el servicio de permisos que necesitan.
    return AppDependencies(
      diaryRepository: SqliteDiaryRepository(
        DiaryLocalDataSource(database),
        imageStorage,
      ),
      settingsRepository: settings,
      imageStorage: imageStorage,
      permissionService: permissions,
      mediaService: ImagePickerMediaService(permissions),
      speechService: SpeechToTextService(permissions),
      locationService: const GeolocatorLocationService(),
      biometricAuthService: LocalAuthBiometricService(),
      mapsLauncher: const UrlMapsLauncher(),
    );
  }
}

// InheritedWidget: mecanismo de Flutter para compartir datos hacia
// abajo en el árbol de widgets sin pasarlos de constructor en
// constructor.
/// Expone [AppDependencies] a todo el árbol de widgets.
///
/// Uso: `AppScope.of(context).diaryRepository`.
class AppScope extends InheritedWidget {
  // Recibe las dependencias y el widget hijo (toda la app).
  const AppScope({super.key, required this.dependencies, required super.child});

  /// Dependencias que se comparten con todo el árbol de widgets.
  final AppDependencies dependencies;

  /// Busca el [AppScope] más cercano hacia arriba en el árbol y devuelve
  /// sus dependencias. Usa getInheritedWidgetOfExactType, que solo lee
  /// el valor sin suscribirse a cambios, porque las dependencias no
  /// cambian.
  static AppDependencies of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    // En modo depuración, assert avisa con un mensaje claro si falta
    // AppScope en el árbol.
    assert(scope != null, 'No se encontró AppScope en el árbol de widgets.');
    return scope!.dependencies;
  }

  // updateShouldNotify decide si hay que avisar a los widgets que
  // dependen de este: solo si llegó un objeto de dependencias distinto.
  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      dependencies != oldWidget.dependencies;
}
