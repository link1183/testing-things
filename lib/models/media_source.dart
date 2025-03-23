enum MediaSource {
  local,
  googleDrive,
}

extension MediaSourceExtension on MediaSource {
  String get displayName {
    switch (this) {
      case MediaSource.local:
        return 'Local Storage';
      case MediaSource.googleDrive:
        return 'Google Drive';
      default:
        return 'Unknown';
    }
  }

  String get icon {
    switch (this) {
      case MediaSource.local:
        return 'assets/icons/local_storage.png';
      case MediaSource.googleDrive:
        return 'assets/icons/google_drive.png';
      default:
        return 'assets/icons/unknown.png';
    }
  }
}
