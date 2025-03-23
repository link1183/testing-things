// lib/utils/file_utils.dart
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../services/file_type_service.dart';

class FileUtils {
  /// Get the file extension from a path (without the dot)
  static String getFileExtension(String filePath) {
    return path.extension(filePath).toLowerCase().replaceFirst('.', '');
  }

  /// Get the file name from a path
  static String getFileName(String filePath) {
    return path.basename(filePath);
  }

  /// Get the directory path from a file path
  static String getDirPath(String filePath) {
    return path.dirname(filePath);
  }

  /// Format file size in human-readable form
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';

    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
    final i = (log(bytes) / log(1024)).floor();

    return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }

  /// Check if a file is an image based on extension
  static bool isImageFile(String filePath) {
    final ext = getFileExtension(filePath);
    return FileTypeService.isImageFile(ext);
  }

  /// Check if a file is a video based on extension
  static bool isVideoFile(String filePath) {
    final ext = getFileExtension(filePath);
    return FileTypeService.isVideoFile(ext);
  }

  /// Get just the filename without extension
  static String getFileNameWithoutExt(String filePath) {
    final fileName = getFileName(filePath);
    final extIndex = fileName.lastIndexOf('.');
    if (extIndex == -1) return fileName;
    return fileName.substring(0, extIndex);
  }

  /// Calculate directory size (recursive)
  static Future<int> getDirSize(Directory dir) async {
    int totalSize = 0;

    try {
      final entities =
          await dir.list(recursive: true, followLinks: false).toList();

      for (final entity in entities) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    } catch (e) {
      debugPrint('Error calculating directory size: $e');
    }

    return totalSize;
  }

  /// Create a unique filename for a file to avoid overwriting existing files
  static String createUniqueFileName(String originalPath, {int attempt = 0}) {
    if (attempt == 0) return originalPath;

    final dir = getDirPath(originalPath);
    final ext = getFileExtension(originalPath);
    final nameWithoutExt = getFileNameWithoutExt(originalPath);

    return '$dir/$nameWithoutExt ($attempt).$ext';
  }

  /// Generate a unique filename that doesn't exist yet
  static Future<String> generateNonExistingPath(String basePath) async {
    var attempt = 0;
    var filePath = basePath;

    while (await File(filePath).exists()) {
      attempt++;
      filePath = createUniqueFileName(basePath, attempt: attempt);
    }

    return filePath;
  }

  /// Generate a deterministic hash for a file
  static Future<String> generateFileHash(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      // Fallback: use file path and size as a pseudo-hash
      final stat = await file.stat();
      final input =
          '${file.path}_${stat.size}_${stat.modified.millisecondsSinceEpoch}';
      return sha256.convert(utf8.encode(input)).toString();
    }
  }

  /// Check if a file is hidden
  static bool isHiddenFile(String filePath) {
    final fileName = getFileName(filePath);
    return fileName.startsWith('.');
  }

  /// Create a cache key for a file
  static String createCacheKey(String filePath, [String? prefix]) {
    final fileName = getFileName(filePath);
    final hash =
        sha256.convert(utf8.encode(filePath)).toString().substring(0, 10);
    return '${prefix ?? ''}${hash}_$fileName';
  }

  /// Check if a path is valid
  static bool isValidPath(String path) {
    try {
      return path.isNotEmpty && !path.contains('0');
    } catch (e) {
      return false;
    }
  }

  /// Move a file to a new location with progress tracking
  static Future<File> moveFile(
    File sourceFile,
    String destinationPath, {
    Function(double progress)? onProgress,
  }) async {
    final destFile = File(destinationPath);

    // Check if source and destination are the same
    if (path.equals(sourceFile.path, destinationPath)) {
      return sourceFile;
    }

    // Create destination directory if it doesn't exist
    await Directory(getDirPath(destinationPath)).create(recursive: true);

    // If on the same device, use rename
    try {
      return await sourceFile.rename(destinationPath);
    } catch (e) {
      // If rename fails, copy and delete
      final fileSize = await sourceFile.length();
      final input = sourceFile.openRead();
      final output = destFile.openWrite();

      int totalRead = 0;

      await for (final chunk in input) {
        output.add(chunk);
        totalRead += chunk.length;

        if (onProgress != null) {
          onProgress(totalRead / fileSize);
        }
      }

      await output.flush();
      await output.close();
      await sourceFile.delete();

      return destFile;
    }
  }
}
