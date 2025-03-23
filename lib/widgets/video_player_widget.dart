import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../services/storage_service.dart';
import 'loading_widget.dart';

class VideoPlayerWidget extends StatefulWidget {
  final MediaItem mediaItem;
  final bool fullscreen;

  const VideoPlayerWidget({
    super.key,
    required this.mediaItem,
    this.fullscreen = false,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late final Player _player;
  late final VideoController _controller;
  bool _isLoading = true;
  String? _error;
  File? _localFile;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _loadVideoFile();
  }

  Future<void> _loadVideoFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.mediaItem.isLocal) {
        final file = widget.mediaItem.localFile;
        if (file == null || !await file.exists()) {
          throw Exception('Video file not found on device');
        }
        _localFile = file;
      } else {
        final storageService =
            Provider.of<StorageService>(context, listen: false);
        _localFile = await storageService
            .getCachedOrDownloadThumbnail(widget.mediaItem)
            .timeout(Duration(seconds: 30), onTimeout: () {
          throw TimeoutException('Video download timed out after 30 seconds');
        });
        if (_localFile == null) {
          throw Exception('Failed to download video file');
        }
      }

      if (_localFile != null) {
        await _player.open(Media(_localFile!.path));
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Unable to load video file';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading video: ${e.toString().split('\n')[0]}';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return LoadingWidget(message: 'Loading video...');
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(_error!),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadVideoFile,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: widget.fullscreen
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
      child: ClipRRect(
        borderRadius:
            widget.fullscreen ? BorderRadius.zero : BorderRadius.circular(8),
        child: Video(
          controller: _controller,
          controls: AdaptiveVideoControls,
        ),
      ),
    );
  }
}
