import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_viewer/utils/heic_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../services/storage_service.dart';
import 'loading_widget.dart';

class ImageViewerWidget extends StatefulWidget {
  final MediaItem mediaItem;
  final bool fullscreen;

  const ImageViewerWidget({
    super.key,
    required this.mediaItem,
    this.fullscreen = false,
  });

  @override
  State<ImageViewerWidget> createState() => _ImageViewerWidgetState();
}

class _ImageViewerWidgetState extends State<ImageViewerWidget> {
  File? _localFile;
  bool _isLoading = false;
  String? _error;

  String? _currentMediaId;

  @override
  void initState() {
    super.initState();
    _loadImageFile();
  }

  @override
  void didUpdateWidget(ImageViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentMediaId != oldWidget.mediaItem.id) {
      _localFile = null;
      _loadImageFile();
    }
  }

  Future<void> _loadImageFile() async {
    _currentMediaId = widget.mediaItem.id;

    if (widget.mediaItem.isLocal) {
      setState(() {
        _localFile = null;
        _isLoading = true;
        _error = null;
      });

      try {
        final file = widget.mediaItem.localFile;
        if (file != null) {
          // Check if it's a HEIC file and convert if needed
          if (HeicHandler.isHeicFile(file.path)) {
            final displayableFile = await HeicHandler.getDisplayableImage(file);

            setState(() {
              _localFile = displayableFile;
              _isLoading = false;
            });
          } else {
            setState(() {
              _localFile = file;
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        setState(() {
          _error = 'Error loading image: $e';
          _isLoading = false;
        });
      }
      return;
    }

    // Download cloud file - keep existing code for cloud files
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final storageService =
          Provider.of<StorageService>(context, listen: false);
      final file =
          await storageService.getCachedOrDownloadThumbnail(widget.mediaItem);

      setState(() {
        _localFile = file;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading image: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return LoadingWidget(message: 'Loading image...');
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
              onPressed: _loadImageFile,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    // For local files
    if (_localFile != null) {
      return _buildPhotoView(FileImage(_localFile!));
    }

    // For cloud images with direct URLs
    if (widget.mediaItem.downloadUrl != null) {
      return _buildPhotoView(
        CachedNetworkImageProvider(widget.mediaItem.downloadUrl!),
      );
    }

    // Fallback
    return Center(
      child: Text('Unable to display image'),
    );
  }

  Widget _buildPhotoView(ImageProvider imageProvider) {
    if (widget.fullscreen) {
      return PhotoView(
        imageProvider: imageProvider,
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2,
        backgroundDecoration: BoxDecoration(
          color: Colors.black,
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
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
          borderRadius: BorderRadius.circular(8),
          child: Image(
            image: imageProvider,
            fit: BoxFit.contain,
          ),
        ),
      );
    }
  }
}
