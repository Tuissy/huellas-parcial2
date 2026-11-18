import 'package:parcial2/core/di/app_dependencies.dart';
import 'package:parcial2/core/errors/app_exception.dart';
import 'package:parcial2/domain/entities/diary_entry.dart';
import 'package:parcial2/domain/entities/geo_location.dart';
import 'package:parcial2/domain/repositories/diary_repository.dart';
import 'package:parcial2/domain/repositories/settings_repository.dart';
import 'package:parcial2/domain/services/biometric_auth_service.dart';
import 'package:parcial2/domain/services/image_storage_service.dart';
import 'package:parcial2/domain/services/location_service.dart';
import 'package:parcial2/domain/services/maps_launcher.dart';
import 'package:parcial2/domain/services/media_service.dart';
import 'package:parcial2/domain/services/permission_service.dart';
import 'package:parcial2/domain/services/speech_service.dart';

/// Repositorio en memoria. Gracias a la interfaz [DiaryRepository], las
/// pantallas se prueban sin SQLite (Inversión de Dependencias).
class InMemoryDiaryRepository implements DiaryRepository {
  InMemoryDiaryRepository([List<DiaryEntry> initial = const []]) {
    for (final entry in initial) {
      _entries[entry.id ?? ++_nextId] = entry;
      if ((entry.id ?? 0) > _nextId) _nextId = entry.id!;
    }
  }

  final Map<int, DiaryEntry> _entries = {};
  int _nextId = 0;
  int getAllCalls = 0;
  bool failOnWrite = false;

  @override
  Future<List<DiaryEntry>> getAll() async {
    getAllCalls++;
    return _entries.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<DiaryEntry?> getById(int id) async => _entries[id];

  @override
  Future<List<DiaryEntry>> search(String query) async => (await getAll())
      .where((e) => e.title.contains(query) || e.content.contains(query))
      .toList();

  @override
  Future<DiaryEntry> create(DiaryEntry entry) async {
    if (failOnWrite) throw const StorageException('fallo simulado');
    final saved = entry.copyWith(id: ++_nextId);
    _entries[saved.id!] = saved;
    return saved;
  }

  @override
  Future<DiaryEntry> update(DiaryEntry entry) async {
    if (failOnWrite) throw const StorageException('fallo simulado');
    _entries[entry.id!] = entry;
    return entry;
  }

  @override
  Future<void> delete(int id) async => _entries.remove(id);

  @override
  Future<int> count() async => _entries.length;
}

/// Almacenamiento de imágenes simulado: "copia" anteponiendo `perm/`.
class FakeImageStorage implements ImageStorageService {
  final List<String> deleted = [];

  @override
  Future<String> persist(String sourcePath) async =>
      sourcePath.startsWith('perm/') ? sourcePath : 'perm/$sourcePath';

  @override
  Future<void> delete(String path) async => deleted.add(path);

  @override
  String toAbsolutePath(String storedPath) => storedPath;

  @override
  String toStoredPath(String absolutePath) => absolutePath;
}

class FakeSettingsRepository implements SettingsRepository {
  @override
  bool biometricLockEnabled = false;

  @override
  ThemePreference themePreference = ThemePreference.light;

  @override
  Future<void> setBiometricLockEnabled(bool enabled) async =>
      biometricLockEnabled = enabled;

  @override
  Future<void> setThemePreference(ThemePreference preference) async =>
      themePreference = preference;
}

class FakePermissionService implements PermissionService {
  PermissionStatusResult result = PermissionStatusResult.granted;

  @override
  Future<PermissionStatusResult> request(AppPermission permission) async =>
      result;

  @override
  Future<bool> openAppSettings() async => true;
}

class FakeMediaService implements MediaService {
  String? nextPhoto;

  @override
  Future<String?> pickPhoto(PhotoSource source) async => nextPhoto;

  @override
  Future<List<String>> recoverLostPhotos() async => const [];
}

class FakeSpeechService implements SpeechService {
  @override
  bool isListening = false;

  @override
  Future<void> startListening({
    required SpeechResultCallback onResult,
    void Function(double level)? onSoundLevel,
    void Function()? onStopped,
    void Function(String message)? onError,
  }) async {
    isListening = true;
    onResult('hola diario', true);
  }

  @override
  Future<void> stopListening() async => isListening = false;

  @override
  Future<void> cancel() async => isListening = false;
}

class FakeLocationService implements LocationService {
  GeoLocation location = const GeoLocation(latitude: 21.1112, longitude: -89.6124);

  @override
  Future<GeoLocation> getCurrentLocation() async => location;

  @override
  Future<bool> openLocationSettings() async => true;
}

class FakeBiometricService implements BiometricAuthService {
  @override
  Future<bool> authenticate({required String reason}) async => true;

  @override
  Future<bool> isAvailable() async => true;
}

class FakeMapsLauncher implements MapsLauncher {
  @override
  Future<void> openLocation(GeoLocation location) async {}
}

/// Dependencias completas con dobles de prueba.
AppDependencies buildFakeDependencies({InMemoryDiaryRepository? repository}) {
  return AppDependencies(
    diaryRepository: repository ?? InMemoryDiaryRepository(),
    settingsRepository: FakeSettingsRepository(),
    imageStorage: FakeImageStorage(),
    permissionService: FakePermissionService(),
    mediaService: FakeMediaService(),
    speechService: FakeSpeechService(),
    locationService: FakeLocationService(),
    biometricAuthService: FakeBiometricService(),
    mapsLauncher: FakeMapsLauncher(),
  );
}
