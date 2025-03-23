import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_viewer/models/media_source.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../services/media_service.dart';
import '../widgets/image_viewer_widget.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/loading_widget.dart';

class MediaViewerScreen extends StatefulWidget {
  final MediaItem mediaItem;
  final List<MediaItem>?
      mediaList; // Optional list for navigation between items

  const MediaViewerScreen({
    super.key,
    required this.mediaItem,
    this.mediaList,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen>
    with SingleTickerProviderStateMixin {
  late MediaItem _currentMedia;
  bool _isLoading = false;
  String? _error;
  bool _isInfoVisible = true;
  Timer? _hideInfoTimer;
  int _currentIndex = 0;
  List<MediaItem> _mediaList = [];

  // Controller for animations
  late AnimationController _animationController;
  late Animation<double> _infoAnimation;

  @override
  void initState() {
    super.initState();
    _currentMedia = widget.mediaItem;

    // Set up the media list for navigation
    if (widget.mediaList != null && widget.mediaList!.isNotEmpty) {
      _mediaList = widget.mediaList!;
      _currentIndex =
          _mediaList.indexWhere((item) => item.id == _currentMedia.id);
      if (_currentIndex < 0) _currentIndex = 0;
    } else {
      _mediaList = [_currentMedia];
      _currentIndex = 0;
    }

    // Set up animations
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );

    _infoAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Start with controls visible
    _showInfoWithTimeout();

    // Set up system UI
    _setSystemUIOverlays();
  }

  @override
  void dispose() {
    _hideInfoTimer?.cancel();
    _animationController.dispose();

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  void _setSystemUIOverlays() {
    // For a more immersive experience
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  void _toggleInfoVisibility() {
    setState(() {
      _isInfoVisible = !_isInfoVisible;
      if (_isInfoVisible) {
        _animationController.reverse();
        _showInfoWithTimeout();
      } else {
        _animationController.forward();
        _hideInfoTimer?.cancel();
      }
    });
  }

  void _showInfoWithTimeout() {
    // Cancel any existing timer
    _hideInfoTimer?.cancel();

    // Set up a new timer to hide the controls after a delay
    _hideInfoTimer = Timer(Duration(seconds: 3), () {
      if (mounted && _isInfoVisible) {
        setState(() {
          _isInfoVisible = false;
          _animationController.forward();
        });
      }
    });
  }

  void _navigateToMedia(int index) {
    if (index < 0 || index >= _mediaList.length) return;

    setState(() {
      _currentIndex = index;
      _currentMedia = _mediaList[index];
      _isLoading = false;
      _error = null;
      _showInfoWithTimeout();
    });
  }

  void _showMediaInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      _currentMedia.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildInfoRow(
                        'Type', _currentMedia.isImage ? 'Image' : 'Video'),
                    _buildInfoRow('Source', _currentMedia.source.displayName),
                    _buildInfoRow('Location', _getLocationText()),
                    if (_currentMedia.dateCreated != null)
                      _buildInfoRow('Created',
                          _formatDateTime(_currentMedia.dateCreated!)),
                    if (_currentMedia.dateModified != null)
                      _buildInfoRow('Modified',
                          _formatDateTime(_currentMedia.dateModified!)),
                    if (_currentMedia.metadata != null) ...[
                      SizedBox(height: 16),
                      Text(
                        'Additional Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      ..._currentMedia.metadata!.entries
                          .where((entry) => entry.value != null)
                          .map((entry) => _buildInfoRow(
                                _formatKey(entry.key),
                                _formatValue(entry.value),
                              )),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[900]),
            ),
          ),
        ],
      ),
    );
  }

  String _getLocationText() {
    if (_currentMedia.isLocal) {
      return _currentMedia.path.split('/').sublist(0, -1).join('/');
    } else {
      return 'Google Drive';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatKey(String key) {
    // Convert camelCase to Title Case with spaces
    return key
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .capitalize();
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'None';

    if (value is int) {
      return value.toString();
    } else if (value is double) {
      return value.toStringAsFixed(2);
    } else if (value is bool) {
      return value ? 'Yes' : 'No';
    } else {
      return value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Media content
          GestureDetector(
            onTap: _toggleInfoVisibility,
            child: _buildMediaContent(),
          ),

          // Loading indicator
          if (_isLoading) LoadingWidget(),

          // Error message
          if (_error != null)
            Center(
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // Info overlay at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _infoAnimation,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back),
                          color: Colors.white,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Text(
                          _currentMedia.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.info_outline),
                          color: Colors.white,
                          onPressed: _showMediaInfo,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Control overlay at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _infoAnimation,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Navigation controls
                        IconButton(
                          icon: Icon(Icons.skip_previous),
                          color: Colors.white,
                          onPressed: _currentIndex > 0
                              ? () => _navigateToMedia(_currentIndex - 1)
                              : null,
                        ),
                        Spacer(),
                        // Action buttons
                        Consumer<MediaService>(
                          builder: (context, mediaService, _) {
                            // Add to collection button (only used if collections are available)
                            return IconButton(
                              icon: Icon(Icons.collections),
                              color: Colors.white,
                              onPressed: () {
                                // This would open collection selection dialog
                                // Implementation depends on your collections management
                              },
                            );
                          },
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.skip_next),
                          color: Colors.white,
                          onPressed: _currentIndex < _mediaList.length - 1
                              ? () => _navigateToMedia(_currentIndex + 1)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaContent() {
    if (_currentMedia.isImage) {
      return ImageViewerWidget(
        mediaItem: _currentMedia,
        fullscreen: true,
      );
    } else if (_currentMedia.isVideo) {
      return VideoPlayerWidget(
        mediaItem: _currentMedia,
        fullscreen: true,
      );
    } else {
      // Fallback for unsupported media types
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_drive_file,
              size: 64,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            SizedBox(height: 16),
            Text(
              'Unsupported file format',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }
  }
}

// Helper extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
