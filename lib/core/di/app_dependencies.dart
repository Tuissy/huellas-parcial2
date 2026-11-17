import 'package:flutter/widgets.dart';

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

/// Raíz de composición: el único lugar donde se crean las implementaciones
/// concretas. El resto de la app solo conoce las interfaces del dominio,
/// por lo que cambiar SQLite, el GPS o la cámara no afecta a las pantallas
/// (Inversión de Dependencias + Abierto/Cerrado).
class AppDependencies {
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
  })  : saveDiaryEntry = SaveDiaryEntry(diaryRepository, imageStorage),
        deleteDiaryEntry = DeleteDiaryEntry(diaryRepository, imageStorage);

  final DiaryRepository diaryRepository;
  final SettingsRepository settingsRepository;
  final ImageStorageService imageStorage;
  final PermissionService permissionService;
  final MediaService mediaService;
  final SpeechService speechService;
  final LocationService locationService;
  final BiometricAuthService biometricAuthService;
  final MapsLauncher mapsLauncher;

  final SaveDiaryEntry saveDiaryEntry;
  final DeleteDiaryEntry deleteDiaryEntry;

  /// Construye las dependencias de producción.
  static Future<AppDependencies> create() async {
    final imageStorage = await LocalImageStorageService.create();
    final settings = await SharedPrefsSettingsRepository.create();
    const permissions = HandlerPermissionService();
    final database = DiaryDatabase();

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

/// Expone [AppDependencies] a todo el árbol de widgets.
///
/// Uso: `AppScope.of(context).diaryRepository`.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.dependencies,
    required super.child,
  });

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No se encontró AppScope en el árbol de widgets.');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      dependencies != oldWidget.dependencies;
}
