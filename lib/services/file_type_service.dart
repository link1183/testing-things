class FileTypeService {
  // List of supported image file extensions
  static const List<String> supportedImageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
    'heic',
    'heif',
    'tiff',
    'tif',
    'svg'
  ];

  // List of supported video file extensions
  static const List<String> supportedVideoExtensions = [
    'mp4',
    'mov',
    'avi',
    'wmv',
    'flv',
    'mkv',
    'webm',
    '3gp',
    'm4v',
    'mpg',
    'mpeg'
  ];

  // Check if a file extension is a supported media type
  static bool isMediaFile(String extension) {
    final ext = extension.toLowerCase();
    return isImageFile(ext) || isVideoFile(ext);
  }

  // Check if a file extension is a supported image type
  static bool isImageFile(String extension) {
    final ext = extension.toLowerCase();
    return supportedImageExtensions.contains(ext);
  }

  // Check if a file extension is a supported video type
  static bool isVideoFile(String extension) {
    final ext = extension.toLowerCase();
    return supportedVideoExtensions.contains(ext);
  }

  // Get MIME type from file extension
  static String getMimeType(String extension) {
    final ext = extension.toLowerCase();

    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'webm':
        return 'video/webm';
      default:
        return 'application/octet-stream';
    }
  }

  // Special handling for HEIC files
  static bool isHeicFile(String extension) {
    final ext = extension.toLowerCase();
    return ext == 'heic' || ext == 'heif';
  }
}
