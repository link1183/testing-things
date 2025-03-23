import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:media_viewer/utils/file_utils.dart';
import 'package:path/path.dart' as path;

typedef ConversionCallback = void Function(String? jpgPath);

class HeicHandler {
  // Cache of converted files to avoid redundant conversions
  static final Map<String, String> _conversionCache = {};

  // Queue for background conversions
  static final List<_ConversionTask> _conversionQueue = [];
  static bool _isProcessingQueue = false;

  // Conversion result callback type

  /// Check if a file is a HEIC image based on extension
  static bool isHeicFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ext == '.heic' || ext == '.heif';
  }

  static Future<Directory> _getHeicTempDir() async {
    final appTempDir = await FileUtils.getAppTempDirectory();
    final heicTempDir = Directory(path.join(appTempDir.path, 'heic_converted'));

    if (!await heicTempDir.exists()) {
      await heicTempDir.create(recursive: true);
    }

    return heicTempDir;
  }

  /// Get an immediately displayable image and initiate background conversion if needed
  /// Returns the original file if it's not HEIC, a cached conversion if available,
  /// or a placeholder while the conversion runs in the background
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

    // Start conversion in background (non-isolate version)
    _convertInBackground(file);

    // Return placeholder while conversion happens in background
    return placeholderFile;
  }

  /// Convert HEIC file to JPG in background and cache the result
  static void _convertInBackground(File file) {
    // Add to conversion queue
    _conversionQueue.add(_ConversionTask(file.path));

    // Start processing queue if not already running
    if (!_isProcessingQueue) {
      _processConversionQueue();
    }
  }

  /// Process the conversion queue in the background
  static Future<void> _processConversionQueue() async {
    if (_conversionQueue.isEmpty || _isProcessingQueue) return;

    _isProcessingQueue = true;

    while (_conversionQueue.isNotEmpty) {
      final task = _conversionQueue.removeAt(0);
      final filePath = task.filePath;
      final file = File(filePath);

      try {
        // Run conversion on main isolate to avoid platform channel issues
        String? jpgPath;

        // First try platform-specific conversion
        try {
          final convertedFile = await _platformSpecificConversion(file);
          if (convertedFile != null && await convertedFile.exists()) {
            jpgPath = convertedFile.path;
          }
        } catch (e) {
          debugPrint('Platform-specific conversion failed: $e');
        }

        // If that fails, try dart-based conversion
        if (jpgPath == null) {
          try {
            final convertedFile = await _dartBasedConversion(file);
            if (convertedFile != null && await convertedFile.exists()) {
              jpgPath = convertedFile.path;
            }
          } catch (e) {
            debugPrint('Dart-based conversion failed: $e');
          }
        }

        // Cache the result
        if (jpgPath != null) {
          _conversionCache[filePath] = jpgPath;
          task.notifyConversionComplete(jpgPath);
        }
      } catch (e) {
        debugPrint('Background conversion failed: $e');
      }
    }

    _isProcessingQueue = false;
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

    // Create a task with callback
    final task = _ConversionTask(filePath);
    if (onComplete != null) {
      task.addCallback(onComplete);
    }

    // Add to queue and start processing
    _conversionQueue.add(task);
    if (!_isProcessingQueue) {
      _processConversionQueue();
    }

    return null;
  }

  /// Try platform-specific conversion methods
  static Future<File?> _platformSpecificConversion(File file) async {
    try {
      if (Platform.isLinux) {
        return await _linuxConversion(file);
      } else if (Platform.isWindows) {
        return await _windowsConversion(file);
      } else if (Platform.isMacOS) {
        return await _macOSConversion(file);
      }
      return null;
    } catch (e) {
      debugPrint('Platform-specific conversion failed: $e');
      return null;
    }
  }

  /// Linux-specific conversion using system commands
  static Future<File?> _linuxConversion(File file) async {
    // Prepare output path
    final tempDir = await _getHeicTempDir();
    final baseName = path.basenameWithoutExtension(file.path);
    final outputPath =
        path.join(tempDir.path, 'heic_converted', '$baseName.jpg');

    // Ensure output directory exists
    await Directory(path.dirname(outputPath)).create(recursive: true);

    // First try with heif-convert (from libheif package)
    try {
      final result = await Process.run('which', ['heif-convert']);
      if (result.exitCode == 0) {
        final conversionResult = await Process.run(
            'heif-convert', ['-q', '90', file.path, outputPath]);

        if (conversionResult.exitCode == 0 && await File(outputPath).exists()) {
          debugPrint('HEIC converted successfully using heif-convert');
          return File(outputPath);
        }
      }
    } catch (e) {
      debugPrint('heif-convert failed: $e');
    }

    // Then try with ImageMagick (convert command)
    try {
      final result = await Process.run('which', ['convert']);
      if (result.exitCode == 0) {
        final conversionResult =
            await Process.run('convert', [file.path, outputPath]);

        if (conversionResult.exitCode == 0 && await File(outputPath).exists()) {
          debugPrint('HEIC converted successfully using ImageMagick');
          return File(outputPath);
        }
      }
    } catch (e) {
      debugPrint('ImageMagick conversion failed: $e');
    }

    return null;
  }

  /// Windows-specific conversion
  static Future<File?> _windowsConversion(File file) async {
    // Prepare output path
    final tempDir = await _getHeicTempDir();
    final baseName = path.basenameWithoutExtension(file.path);
    final outputPath =
        path.join(tempDir.path, 'heic_converted', '$baseName.jpg');

    // Ensure output directory exists
    await Directory(path.dirname(outputPath)).create(recursive: true);

    // Try with ImageMagick if installed (less common on Windows but possible)
    try {
      // Check if ImageMagick's convert.exe is in PATH
      final result = await Process.run('where', ['magick']);
      if (result.exitCode == 0) {
        final conversionResult =
            await Process.run('magick', ['convert', file.path, outputPath]);

        if (conversionResult.exitCode == 0 && await File(outputPath).exists()) {
          debugPrint(
              'HEIC converted successfully using ImageMagick on Windows');
          return File(outputPath);
        }
      }
    } catch (e) {
      debugPrint('Windows ImageMagick conversion failed: $e');
    }

    return null;
  }

  /// macOS-specific conversion
  static Future<File?> _macOSConversion(File file) async {
    // Prepare output path
    final tempDir = await _getHeicTempDir();
    final baseName = path.basenameWithoutExtension(file.path);
    final outputPath =
        path.join(tempDir.path, 'heic_converted', '$baseName.jpg');

    // Ensure output directory exists
    await Directory(path.dirname(outputPath)).create(recursive: true);

    // macOS has native HEIC support via sips command
    try {
      final conversionResult = await Process.run(
          'sips', ['-s', 'format', 'jpeg', file.path, '--out', outputPath]);

      if (conversionResult.exitCode == 0 && await File(outputPath).exists()) {
        debugPrint('HEIC converted successfully using sips on macOS');
        return File(outputPath);
      }
    } catch (e) {
      debugPrint('macOS sips conversion failed: $e');
    }

    return null;
  }

  /// Dart-based conversion using available libraries
  static Future<File?> _dartBasedConversion(File file) async {
    // Prepare output path
    final tempDir = await _getHeicTempDir();
    final baseName = path.basenameWithoutExtension(file.path);
    final outputPath =
        path.join(tempDir.path, 'heic_converted', '$baseName.jpg');

    // Ensure output directory exists
    await Directory(path.dirname(outputPath)).create(recursive: true);

    // Pure Dart approach to extract embedded preview images from HEIC
    try {
      final bytes = await file.readAsBytes();
      final jpegData = await _extractJpegPreview(bytes);

      if (jpegData != null) {
        await File(outputPath).writeAsBytes(jpegData);
        debugPrint('HEIC converted by extracting JPEG preview');
        return File(outputPath);
      }
    } catch (e) {
      debugPrint('Dart-based HEIC preview extraction failed: $e');
    }

    return null;
  }

  /// Extract JPEG preview from HEIC files if available
  /// This is a heuristic approach that works for some HEIC files
  static Future<Uint8List?> _extractJpegPreview(Uint8List bytes) async {
    // JPEG header marker
    final jpegStart = [0xFF, 0xD8, 0xFF];

    // Look for JPEG header in the HEIC file
    for (int i = 0; i < bytes.length - 3; i++) {
      if (bytes[i] == jpegStart[0] &&
          bytes[i + 1] == jpegStart[1] &&
          bytes[i + 2] == jpegStart[2]) {
        // Found a JPEG header, now look for the end marker
        for (int j = i + 3; j < bytes.length - 1; j++) {
          if (bytes[j] == 0xFF && bytes[j + 1] == 0xD9) {
            // Found JPEG end marker, extract the data
            return bytes.sublist(i, j + 2);
          }
        }
      }
    }

    return null;
  }

  /// Create a placeholder image with "Converting..." message
  static Future<File> _createPlaceholder(File file) async {
    final tempDir = await _getHeicTempDir();
    final baseName = path.basenameWithoutExtension(file.path);
    final outputPath =
        path.join(tempDir.path, 'heic_placeholder', '$baseName.jpg');

    // Ensure output directory exists
    await Directory(path.dirname(outputPath)).create(recursive: true);

    // Create a placeholder image (nicer looking than before)
    final placeholderImage = img.Image(width: 400, height: 300);

    // Use a gradient background instead of plain color
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

/// Helper class to track conversion tasks with callbacks
class _ConversionTask {
  final String filePath;
  final List<ConversionCallback> callbacks = [];

  _ConversionTask(this.filePath);

  void addCallback(ConversionCallback callback) {
    callbacks.add(callback);
  }

  void notifyConversionComplete(String jpgPath) {
    for (final callback in callbacks) {
      callback(jpgPath);
    }
  }
}
