import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_viewer/utils/heic_handler.dart';
import 'package:provider/provider.dart';
import 'package:transparent_image/transparent_image.dart';
import '../models/media_item.dart';
import '../services/storage_service.dart';
import '../services/preferences_service.dart';
import 'loading_widget.dart';

class MediaGridItem extends StatefulWidget {
  // The media item to display
  final MediaItem mediaItem;

  // Callback when the grid item is tapped
  final VoidCallback onTap;

  // Whether to show details like file type, source indicators and filename
  final bool showDetails;

  const MediaGridItem({
    super.key,
    required this.mediaItem,
    required this.onTap,
    this.showDetails = true,
  });

  @override
  State<MediaGridItem> createState() => _MediaGridItemState();
}

class _MediaGridItemState extends State<MediaGridItem>
    with AutomaticKeepAliveClientMixin {
  // Keep widget alive when scrolling to avoid unnecessary rebuilds
  @override
  bool get wantKeepAlive => true;

  // State variables
  bool _isLoading = false;
  String? _error;
  File? _localFile;
  String? _thumbnailUrl;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _prepareMedia();
  }

  // Load or prepare the media for display
  Future<void> _prepareMedia() async {
    // Skip if already prepared
    if (_isLoaded) return;

    // Handle local files directly
    if (widget.mediaItem.isLocal) {
      setState(() {
        _isLoading = true;
      });

      try {
        final file = widget.mediaItem.localFile;
        if (file != null) {
          // Check if it's a HEIC file and convert if needed
          if (HeicHandler.isHeicFile(file.path)) {
            final convertedFile = await HeicHandler.getDisplayableImage(file);
            setState(() {
              _localFile = convertedFile;
              _isLoaded = true;
              _isLoading = false;
            });
          } else {
            setState(() {
              _localFile = file;
              _isLoaded = true;
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        setState(() {
          _error = 'Error loading thumbnail';
          _isLoading = false;
        });
      }
      return;
    }

    // Keep existing code for cloud items and other scenarios
    // For cloud items with thumbnails already cached
    if (widget.mediaItem.thumbnailPath != null) {
      setState(() {
        _localFile = File(widget.mediaItem.thumbnailPath!);
        _isLoaded = true;
      });
      return;
    }

    // For cloud items with direct download URLs
    if (widget.mediaItem.downloadUrl != null) {
      setState(() {
        _thumbnailUrl = widget.mediaItem.downloadUrl;
        _isLoaded = true;
      });
      return;
    }

    // Need to download the thumbnail
    if (!_isLoaded && !_isLoading) {
      _downloadThumbnail();
    }
  }

  // Download a thumbnail for cloud-based media
  Future<void> _downloadThumbnail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final storageService =
          Provider.of<StorageService>(context, listen: false);

      // For cloud items, try to get a thumbnail or download a small version
      if (widget.mediaItem.isCloud) {
        final driveApi = storageService.driveApi;

        if (driveApi != null && widget.mediaItem.cloudId != null) {
          // Access Google Drive thumbnail service for efficient loading
          setState(() {
            _thumbnailUrl =
                'https://drive.google.com/thumbnail?id=${widget.mediaItem.cloudId}&sz=w320';
            _isLoaded = true;
            _isLoading = false;
          });
          return;
        }
      }

      // If we can't get a thumbnail, download the actual file
      final file =
          await storageService.getCachedOrDownloadThumbnail(widget.mediaItem);

      setState(() {
        _localFile = file;
        _isLoaded = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Must call super for AutomaticKeepAliveClientMixin
    super.build(context);

    // Access user preferences to check if filenames should be shown
    final preferences = Provider.of<PreferencesService>(context);

    return Card(
      // Visual styling for the card
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          // This is the key fix - set mainAxisSize to min so Column doesn't try to expand infinitely
          mainAxisSize: MainAxisSize.min,
          children: [
            // Media thumbnail
            AspectRatio(
              aspectRatio: 1.0, // Square aspect ratio for the media thumbnail
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Media content
                  _buildMediaThumbnail(),

                  // Loading indicator
                  if (_isLoading) LoadingWidget(size: 24),

                  // Indicators for type and source (only if showDetails is true)
                  if (widget.showDetails) ...[
                    // Media type indicator (image or video)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          widget.mediaItem.isVideo
                              ? Icons.videocam
                              : Icons.image,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),

                    // Source indicator (local or cloud)
                    Positioned(
                      top: 8,
                      left: 8,
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
                  ],
                ],
              ),
            ),

            // File name (if enabled in preferences and showDetails is true)
            if (preferences.showFilenames && widget.showDetails)
              Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Text(
                  widget.mediaItem.name,
                  style: TextStyle(
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build the appropriate media thumbnail based on available data
  Widget _buildMediaThumbnail() {
    // Show error placeholder if loading failed
    if (_error != null) {
      return _buildErrorPlaceholder();
    }

    // Show local file if available
    if (_localFile != null && _localFile!.existsSync()) {
      // Use FadeInImage for smooth loading transition
      return FadeInImage(
        placeholder: MemoryImage(kTransparentImage),
        image: FileImage(_localFile!),
        fit: BoxFit.cover,
        imageErrorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder();
        },
      );
    }

    // Show remote thumbnail if URL is available
    if (_thumbnailUrl != null) {
      return CachedNetworkImage(
        imageUrl: _thumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey[200]),
        errorWidget: (context, url, error) => _buildErrorPlaceholder(),
      );
    }

    // Default placeholder during loading or if nothing is available
    return Container(color: Colors.grey[200]);
  }

  // Error placeholder with appropriate icon based on media type
  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          widget.mediaItem.isVideo ? Icons.videocam_off : Icons.broken_image,
          color: Colors.grey[600],
          size: 32,
        ),
      ),
    );
  }
}
