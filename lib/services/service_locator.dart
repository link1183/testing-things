import 'package:get_it/get_it.dart';
import 'media_service.dart';
import 'storage_service.dart';
import 'preferences_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  final PreferencesService preferencesService = PreferencesService();
  await preferencesService.init();
  getIt.registerSingleton<PreferencesService>(preferencesService);

  final StorageService storageService = StorageService();
  await storageService.init();
  getIt.registerSingleton<StorageService>(storageService);

  final MediaService mediaService = MediaService(storageService);
  await mediaService.init();
  getIt.registerSingleton<MediaService>(mediaService);
}
