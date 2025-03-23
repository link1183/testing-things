class AppConfig {
  // App metadata
  static const String appName = 'Media Viewer';
  static const String appVersion = '1.0.0';

  // Default window settings
  static const double defaultWindowWidth = 1280;
  static const double defaultWindowHeight = 720;
  static const double minimumWindowWidth = 800;
  static const double minimumWindowHeight = 600;

  // Media settings
  static const int maxRecentFolders = 10;
  static const int defaultThumbnailQuality = 80;
  static const int thumbnailCacheMaxAge = 7; // days

  // API keys and configurations
  static const String googleDriveScopes =
      'https://www.googleapis.com/auth/drive.readonly';

  // Feature flags
  static const bool enableCloudIntegration = true;
  static const bool enableVideoPlayback = true;
}
