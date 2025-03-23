import 'dart:io';
import 'dart:async';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:media_viewer/utils/file_utils.dart';
import 'package:media_viewer/utils/heic_converter_pool.dart';

typedef ConversionCallback = void Function(String? jpgPath);

class HeicHandler {
  // Cache of converted files to avoid redundant conversions
  static final Map<String, String> _conversionCache = {};

  // Conversion result callback type

  /// Check if a file is a HEIC image based on extension
  static bool isHeicFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ext == '.heic' || ext == '.heif';
  }

  /// Get an immediately displayable image and initiate background conversion if needed
  static Future<File> getDisplayableImage(File file) async {
    // Return original file if not HEIC
    if (!isHeicFile(file.path)) {
      return file;
    }

    final filePath = file.path;

    // Check if we already have a cached conversion
    if (_conversionCache.containsKey(filePath)) {
      final cachedPath = _conversionCache[filePath];
      if (cachedPath != null && await File(cachedPath).exists()) {
        return File(cachedPath);
      }
      // Cached file doesn't exist, remove from cache
      _conversionCache.remove(filePath);
    }

    // Create a placeholder immediately
    final placeholderFile = await _createPlaceholder(file);

    // Start conversion in background with our multithreaded converter
    _convertInBackground(file);

    // Return placeholder while conversion happens in background
    return placeholderFile;
  }

  /// Convert HEIC file to JPG using the thread pool
  static void _convertInBackground(File file) async {
    print(
        '🔥 HEIC_POOL: Starting background conversion for ${path.basename(file.path)}');

    // Initialize the converter pool if needed
    await HeicConverterPool.initialize();

    // Start the conversion
    final resultPath = await HeicConverterPool.convertHeicFile(file);

    // Cache the result if successful
    if (resultPath != null) {
      print(
          '🔥 HEIC_POOL: Conversion completed for ${path.basename(file.path)}');
      _conversionCache[file.path] = resultPath;
    } else {
      print('🔥 HEIC_POOL: Conversion failed for ${path.basename(file.path)}');
    }
  }

  /// Request conversion and get notified when complete
  static Future<String?> convertHeicFile(File file,
      {ConversionCallback? onComplete}) async {
    if (!isHeicFile(file.path)) return null;

    final filePath = file.path;

    // Check if already converted
    if (_conversionCache.containsKey(filePath)) {
      final cachedPath = _conversionCache[filePath];
      if (cachedPath != null && await File(cachedPath).exists()) {
        if (onComplete != null) onComplete(cachedPath);
        return cachedPath;
      }
      _conversionCache.remove(filePath);
    }

    // Initialize the converter pool
    await HeicConverterPool.initialize();

    // Convert using the thread pool
    final resultPath = await HeicConverterPool.convertHeicFile(file);

    // Cache the result if successful
    if (resultPath != null) {
      _conversionCache[filePath] = resultPath;
      if (onComplete != null) onComplete(resultPath);
    }

    return resultPath;
  }

  /// Create a placeholder image with "Converting..." message
  static Future<File> _createPlaceholder(File file) async {
    final tempDir = await FileUtils.getAppTempDirectory();
    final baseName = path.basenameWithoutExtension(file.path);
    final outputPath =
        path.join(tempDir.path, 'heic_placeholder', '$baseName.jpg');

    // Ensure output directory exists
    await Directory(path.dirname(outputPath)).create(recursive: true);

    // Create a placeholder image (nicer looking than before)
    final placeholderImage = img.Image(width: 400, height: 300);

    for (int y = 0; y < 300; y++) {
      final intensity = 200 + ((y / 300) * 40).toInt(); // 200-240 gradient
      for (int x = 0; x < 400; x++) {
        placeholderImage.setPixel(
            x, y, img.ColorRgb8(intensity, intensity, intensity));
      }
    }

    // Add text indicating conversion is in progress
    img.drawString(placeholderImage, 'Converting HEIC Image...',
        font: img.arial24, x: 85, y: 120, color: img.ColorRgb8(50, 120, 200));

    img.drawString(placeholderImage, path.basename(file.path),
        font: img.arial24, x: 100, y: 160, color: img.ColorRgb8(100, 100, 100));

    // Add a progress indicator visual
    final barY = 200;
    final barWidth = 200;
    final barHeight = 10;
    final barX = (400 - barWidth) ~/ 2;

    // Draw background of progress bar
    for (int y = barY; y < barY + barHeight; y++) {
      for (int x = barX; x < barX + barWidth; x++) {
        placeholderImage.setPixel(x, y, img.ColorRgb8(220, 220, 220));
      }
    }

    // Draw animated-looking progress indicator (30% filled)
    final fillWidth = (barWidth * 0.3).toInt();
    for (int y = barY; y < barY + barHeight; y++) {
      for (int x = barX; x < barX + fillWidth; x++) {
        placeholderImage.setPixel(x, y, img.ColorRgb8(80, 150, 230));
      }
    }

    // Save the placeholder as a high-quality JPG for quick loading
    final jpgData = img.encodeJpg(placeholderImage, quality: 90);
    await File(outputPath).writeAsBytes(jpgData);

    return File(outputPath);
  }
}
