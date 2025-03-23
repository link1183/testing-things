// lib/utils/heic_converter_pool.dart
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Class to manage a pool of isolates for HEIC conversion
class HeicConverterPool {
  static final int _numWorkers = (Platform.numberOfProcessors / 2).ceil();

  // List of worker isolates
  static final List<_Worker> _workers = [];

  // Queue of pending conversion tasks
  static final List<_ConversionTask> _taskQueue = [];

  // Flag to track initialization
  static bool _isInitialized = false;

  /// Initialize the thread pool
  static Future<void> initialize() async {
    if (_isInitialized) return;

    print(
        '🔥 HEIC_POOL: Initializing converter pool with $_numWorkers workers');

    // Create worker isolates
    for (int i = 0; i < _numWorkers; i++) {
      final worker = _Worker();
      await worker.initialize();
      _workers.add(worker);
      print('🔥 HEIC_POOL: Worker $i initialized');
    }

    _isInitialized = true;
    _processQueue();
  }

  /// Convert a HEIC file to JPEG in a background thread
  static Future<String?> convertHeicFile(File heicFile) async {
    if (!_isInitialized) {
      await initialize();
    }

    print(
        '🔥 HEIC_POOL: Adding conversion task for ${path.basename(heicFile.path)}');

    // Create a completer to get the result asynchronously
    final completer = Completer<String?>();

    // Create and add the task to the queue
    final task = _ConversionTask(
      heicFile.path,
      completer: completer,
    );
    _taskQueue.add(task);

    // Trigger queue processing
    _processQueue();

    // Return a future that will complete when the conversion is done
    return completer.future;
  }

  /// Process the queue by assigning tasks to available workers
  static void _processQueue() {
    if (_taskQueue.isEmpty) return;

    print(
        '🔥 HEIC_POOL: Processing queue with ${_taskQueue.length} pending tasks');

    // Find idle workers
    for (final worker in _workers) {
      if (worker.isIdle && _taskQueue.isNotEmpty) {
        final task = _taskQueue.removeAt(0);
        print(
            '🔥 HEIC_POOL: Assigning task ${path.basename(task.heicFilePath)} to worker');
        worker.processTask(task);
      }
    }
  }

  /// Shutdown the thread pool
  static void shutdown() {
    for (final worker in _workers) {
      worker.dispose();
    }
    _workers.clear();
    _isInitialized = false;
  }
}

/// Class representing a conversion task
class _ConversionTask {
  final String heicFilePath;
  final Completer<String?> completer;

  _ConversionTask(this.heicFilePath, {required this.completer});
}

/// Class representing a worker isolate
class _Worker {
  Isolate? _isolate;
  final ReceivePort _receivePort = ReceivePort();
  SendPort? _sendPort;
  bool _isBusy = false;

  bool get isIdle => !_isBusy;

  /// Initialize the worker isolate
  Future<void> initialize() async {
    // Spawn the isolate
    final completer = Completer<void>();

    _isolate = await Isolate.spawn(
      _isolateMain,
      _receivePort.sendPort,
      debugName: 'HeicConverter',
    );

    // Listen for messages from the isolate
    _receivePort.listen((message) {
      if (message is SendPort) {
        // Store the send port for communication
        _sendPort = message;
        completer.complete();
      } else if (message is Map<String, dynamic>) {
        // Process conversion result
        final String taskId = message['taskId'];
        final String? resultPath = message['resultPath'];
        final String? error = message['error'];

        // Find the task in the queue
        for (final task in HeicConverterPool._taskQueue) {
          if (task.heicFilePath == taskId) {
            if (error != null) {
              task.completer.completeError(error);
            } else {
              task.completer.complete(resultPath);
            }
            HeicConverterPool._taskQueue.remove(task);
            break;
          }
        }

        // Mark worker as idle
        _isBusy = false;

        // Process next task in queue
        HeicConverterPool._processQueue();
      }
    });

    // Wait for the isolate to be initialized
    await completer.future;
  }

  /// Process a conversion task
  void processTask(_ConversionTask task) {
    if (_sendPort == null) return;

    print(
        '🔥 HEIC_POOL: Worker starting task ${path.basename(task.heicFilePath)}');
    _isBusy = true;
    _sendPort!.send(task.heicFilePath);
  }

  /// Dispose of the worker
  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort.close();
  }

  /// Main function for the isolate
  static Future<void> _isolateMain(SendPort sendPort) async {
    final receivePort = ReceivePort();

    print('🔥 HEIC_POOL: Worker isolate started');

    sendPort.send(receivePort.sendPort);

    // Process initialization for platform channels in isolate
    // This is crucial for calling platform-specific code
    await _initializeBackgroundIsolate();

    // Listen for tasks
    receivePort.listen((message) async {
      if (message is String) {
        print('🔥 HEIC_POOL: Worker received task ${path.basename(message)}');
        // Process HEIC conversion
        final heicFilePath = message;

        try {
          // Convert the file
          final resultPath = await _convertHeicFile(heicFilePath);

          // Send the result back
          sendPort.send({
            'taskId': heicFilePath,
            'resultPath': resultPath,
            'error': null,
          });
        } catch (e) {
          // Send error back
          sendPort.send({
            'taskId': heicFilePath,
            'resultPath': null,
            'error': e.toString(),
          });
        }
      }
    });
  }

  /// Initialize platform channels in the background isolate
  static Future<void> _initializeBackgroundIsolate() async {
    // Initialize the binary messenger
    // This fixes the BackgroundIsolateBinaryMessenger issue
    try {
      DartPluginRegistrant.ensureInitialized();
    } catch (e) {
      debugPrint('Error initializing plugin registrant: $e');
    }
  }

  /// Convert a HEIC file to JPEG
  static Future<String?> _convertHeicFile(String heicFilePath) async {
    final file = File(heicFilePath);
    if (!file.existsSync()) {
      throw Exception('HEIC file not found: $heicFilePath');
    }

    // Create output path
    final tempDir = await getTemporaryDirectory();
    final baseName = path.basenameWithoutExtension(heicFilePath);
    final outputDir = Directory('${tempDir.path}/heic_converted');

    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final outputPath = '${outputDir.path}/$baseName.jpg';

    // Try platform-specific conversion first
    try {
      if (Platform.isLinux) {
        final result = await _linuxConversion(heicFilePath, outputPath);
        if (result != null) return result;
      } else if (Platform.isWindows) {
        final result = await _windowsConversion(heicFilePath, outputPath);
        if (result != null) return result;
      }
    } catch (e) {
      debugPrint('Platform conversion failed: $e');
    }

    // Try JPEG extraction as fallback
    try {
      final result = await _extractJpegPreview(file, outputPath);
      if (result != null) return result;
    } catch (e) {
      debugPrint('JPEG extraction failed: $e');
    }

    // If all conversions failed, return null
    return null;
  }

  /// Linux-specific conversion
  static Future<String?> _linuxConversion(
      String inputPath, String outputPath) async {
    try {
      final result = await Process.run('which', ['heif-convert']);
      if (result.exitCode == 0) {
        final conversionResult = await Process.run(
            'heif-convert', ['-q', '90', inputPath, outputPath]);

        if (conversionResult.exitCode == 0 && await File(outputPath).exists()) {
          return outputPath;
        }
      }

      // Try ImageMagick
      final magickResult = await Process.run('which', ['convert']);
      if (magickResult.exitCode == 0) {
        final conversionResult =
            await Process.run('convert', [inputPath, outputPath]);

        if (conversionResult.exitCode == 0 && await File(outputPath).exists()) {
          return outputPath;
        }
      }
    } catch (e) {
      debugPrint('Linux conversion error: $e');
    }
    return null;
  }

  /// Windows-specific conversion
  static Future<String?> _windowsConversion(
      String inputPath, String outputPath) async {
    print(
        '🔥 HEIC_POOL: Attempting Windows conversion for ${path.basename(inputPath)}');
    try {
      final result = await Process.run('where', ['magick']);
      if (result.exitCode == 0) {
        final conversionResult =
            await Process.run('magick', ['convert', inputPath, outputPath]);

        if (conversionResult.exitCode == 0 && await File(outputPath).exists()) {
          return outputPath;
        }
      }
    } catch (e) {
      debugPrint('Windows conversion error: $e');
    }
    return null;
  }

  /// Extract JPEG preview from HEIC file
  static Future<String?> _extractJpegPreview(
      File file, String outputPath) async {
    try {
      final bytes = await file.readAsBytes();

      // Look for JPEG header (FF D8 FF)
      final jpegStart = [0xFF, 0xD8, 0xFF];

      for (int i = 0; i < bytes.length - 3; i++) {
        if (bytes[i] == jpegStart[0] &&
            bytes[i + 1] == jpegStart[1] &&
            bytes[i + 2] == jpegStart[2]) {
          // Found JPEG header, look for end marker (FF D9)
          for (int j = i + 3; j < bytes.length - 1; j++) {
            if (bytes[j] == 0xFF && bytes[j + 1] == 0xD9) {
              // Extract JPEG data
              final jpegData = bytes.sublist(i, j + 2);

              // Write to file
              await File(outputPath).writeAsBytes(jpegData);

              if (await File(outputPath).exists()) {
                return outputPath;
              }
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('JPEG extraction error: $e');
    }
    return null;
  }
}
