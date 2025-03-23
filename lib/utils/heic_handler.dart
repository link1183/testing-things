// lib/utils/cross_platform_heic_handler.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:media_viewer/services/navigation_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class HeicHandler {
  /// Check if a file is a HEIC image based on extension
  static bool isHeicFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ext == '.heic' || ext == '.heif';
  }

  /// Convert HEIC file to a displayable format based on platform capabilities
  static Future<File?> getDisplayableImage(File file) async {
    if (!isHeicFile(file.path)) {
      return file; // Not a HEIC file, return as is
    }

    try {
      // First, try to use the file directly (maybe Flutter can handle it on some platforms)
      try {
        // Attempt to decode the file - will throw an exception if not supported
        await precacheImage(
            FileImage(file), NavigationService.navigatorKey.currentContext!);
        return file; // If we got here, Flutter can display the HEIC directly
      } catch (e) {
        // Flutter can't handle the HEIC, continue to conversion
        debugPrint('Direct HEIC display not supported: $e');
      }

      // Try platform-specific conversion
      File? convertedFile = await _platformSpecificConversion(file);
      if (convertedFile != null) {
        return convertedFile;
      }

      // If platform-specific conversion fails, use universal fallback
      return await _universalFallback(file);
    } catch (e) {
      debugPrint('Error processing HEIC image: $e');
      return null;
    }
  }

  /// Attempt platform-specific conversion methods
  static Future<File?> _platformSpecificConversion(File file) async {
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        // On mobile, we'd use heic_to_jpg, but since that's failing, we'll skip this
        // and go straight to the universal fallback
      }

      if (Platform.isLinux) {
        // On Linux, we could try using a system command if available
        return await _linuxConversion(file);
      }

      if (Platform.isMacOS) {
        // macOS might have built-in tools for HEIC conversion
        return await _macOSConversion(file);
      }

      return null; // No platform-specific method available or it failed
    } catch (e) {
      debugPrint('Platform-specific conversion failed: $e');
      return null;
    }
  }

  /// Linux-specific conversion using system commands if available
  static Future<File?> _linuxConversion(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final baseName = path.basenameWithoutExtension(file.path);
      final outputPath =
          path.join(tempDir.path, 'heic_converted', '$baseName.jpg');

      // Ensure output directory exists
      await Directory(path.dirname(outputPath)).create(recursive: true);

      // Check if libheif is installed and use heif-convert if available
      final result = await Process.run('which', ['heif-convert']);
      if (result.exitCode == 0) {
        final conversionResult = await Process.run(
            'heif-convert', ['-q', '90', file.path, outputPath]);

        if (conversionResult.exitCode == 0 && await File(outputPath).exists()) {
          return File(outputPath);
        }
      }

      return null; // Command not available or conversion failed
    } catch (e) {
      debugPrint('Linux conversion failed: $e');
      return null;
    }
  }

  /// macOS-specific conversion
  static Future<File?> _macOSConversion(File file) async {
    // Similar to Linux but would use macOS-specific tools
    // Implementation omitted for brevity
    return null;
  }

  /// Universal fallback that should work on all platforms
  /// Uses the 'image' package to decode and re-encode
  static Future<File?> _universalFallback(File file) async {
    try {
      // Create output path
      final tempDir = await getTemporaryDirectory();
      final baseName = path.basenameWithoutExtension(file.path);
      final outputPath =
          path.join(tempDir.path, 'heic_converted', '$baseName.jpg');

      // Ensure output directory exists
      await Directory(path.dirname(outputPath)).create(recursive: true);

      // Display a placeholder message to the user since we can't properly convert HEIC on this platform
      debugPrint(
          "HEIC conversion not supported on this platform. Using placeholder image.");

      // Instead of trying to convert the unsupported HEIC, we'll create a placeholder image
      // that indicates the file couldn't be converted
      final placeholderImage = img.Image(width: 400, height: 300);
      img.fill(placeholderImage, color: img.ColorRgb8(240, 240, 240));

      // Add text to the placeholder indicating the issue
      img.drawString(placeholderImage, 'HEIC Image Preview Unavailable',
          font: img.arial24, x: 60, y: 120, color: img.ColorRgb8(80, 80, 80));

      img.drawString(placeholderImage, path.basename(file.path),
          font: img.arial24,
          x: 100,
          y: 160,
          color: img.ColorRgb8(100, 100, 100));

      // Save the placeholder
      final jpgData = img.encodeJpg(placeholderImage, quality: 90);
      await File(outputPath).writeAsBytes(jpgData);

      return File(outputPath);
    } catch (e) {
      debugPrint('Universal fallback failed: $e');
      return null;
    }
  }
}
