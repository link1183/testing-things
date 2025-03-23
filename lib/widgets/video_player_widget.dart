import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
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
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  File? _localFile;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideoFile();
  }

  Future<void> _loadVideoFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.mediaItem.isLocal) {
        _localFile = widget.mediaItem.localFile;
      } else {
        // Download cloud file
        final storageService =
            Provider.of<StorageService>(context, listen: false);
        _localFile =
            await storageService.downloadGoogleDriveFile(widget.mediaItem);
      }

      if (_localFile != null) {
        await _initializeVideoPlayer();
      } else {
        setState(() {
          _error = 'Unable to load video file';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading video: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.file(_localFile!);
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: widget.fullscreen,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        autoInitialize: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: TextStyle(color: Colors.white),
            ),
          );
        },
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error initializing video: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
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

    if (_chewieController != null) {
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
          child: Chewie(
            controller: _chewieController!,
          ),
        ),
      );
    }

    // Fallback
    return Center(
      child: Text('Unable to play video'),
    );
  }
}
