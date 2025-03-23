import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../services/storage_service.dart';
import '../services/preferences_service.dart';
import 'loading_widget.dart';

class MediaCalendarItem extends StatefulWidget {
  final MediaItem mediaItem;
  final VoidCallback onTap;

  const MediaCalendarItem({
    super.key,
    required this.mediaItem,
    required this.onTap,
  });

  @override
  State<MediaCalendarItem> createState() => _MediaCalendarItemState();
}

class _MediaCalendarItemState extends State<MediaCalendarItem> {
  bool _isLoading = false;
  String? _error;
  File? _localFile;

  @override
  void initState() {
    super.initState();
    _prepareMedia();
  }

  Future<void> _prepareMedia() async {
    // Skip if already local
    if (widget.mediaItem.isLocal) {
      setState(() {
        _localFile = widget.mediaItem.localFile;
      });
      return;
    }

    // For cloud items with thumbnails, we don't need to download the full file
    if (widget.mediaItem.thumbnailPath != null) {
      setState(() {
        _localFile = File(widget.mediaItem.thumbnailPath!);
      });
      return;
    }

    // Check if we need to download from cloud
    if (widget.mediaItem.isCloud && widget.mediaItem.downloadUrl == null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final storageService =
            Provider.of<StorageService>(context, listen: false);
        final file =
            await storageService.downloadGoogleDriveFile(widget.mediaItem);

        setState(() {
          _localFile = file;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _error = 'Failed to load';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = Provider.of<PreferencesService>(context);

    return InkWell(
      onTap: widget.onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media thumbnail
            _buildMediaThumbnail(),

            // Media type indicator
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  widget.mediaItem.isVideo ? Icons.videocam : Icons.image,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),

            // Source indicator
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  widget.mediaItem.isCloud ? Icons.cloud : Icons.folder,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),

            // Filename (if enabled)
            if (preferences.showFilenames)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  color: Colors.black54,
                  child: Text(
                    widget.mediaItem.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaThumbnail() {
    if (_isLoading) {
      return LoadingWidget(size: 24);
    }

    if (_error != null) {
      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Icon(
            Icons.error_outline,
            color: Colors.red,
          ),
        ),
      );
    }

    // Local file is available
    if (_localFile != null && _localFile!.existsSync()) {
      return Image.file(
        _localFile!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder();
        },
      );
    }

    // Cloud file with download URL
    if (widget.mediaItem.downloadUrl != null) {
      return CachedNetworkImage(
        imageUrl: widget.mediaItem.downloadUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => LoadingWidget(size: 24),
        errorWidget: (context, url, error) => _buildErrorPlaceholder(),
      );
    }

    // Fallback
    return _buildErrorPlaceholder();
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          widget.mediaItem.isVideo ? Icons.videocam : Icons.image,
          color: Colors.grey[600],
          size: 32,
        ),
      ),
    );
  }
}
