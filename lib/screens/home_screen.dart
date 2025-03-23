import 'package:flutter/material.dart';
import 'package:media_viewer/models/media_source.dart';
import 'package:provider/provider.dart';
import '../services/media_service.dart';
import '../models/media_item.dart';
import '../widgets/image_viewer_widget.dart';
import '../widgets/video_player_widget.dart';
import 'media_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<MediaService>(
      builder: (context, mediaService, child) {
        if (mediaService.isLoading) {
          return Center(child: CircularProgressIndicator());
        }

        if (mediaService.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Error loading media',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 8),
                Text(
                  mediaService.error!,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => mediaService.refreshMedia(),
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        final randomMedia = mediaService.currentRandomMedia;

        if (randomMedia == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined,
                    size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No media available',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => mediaService.refreshMedia(),
                  child: Text('Refresh'),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Featured Media'),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () => mediaService.loadRandomMediaOnStartup(),
                tooltip: 'Load another random media',
              ),
              IconButton(
                icon: Icon(Icons.fullscreen),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MediaViewerScreen(
                        mediaItem: randomMedia,
                      ),
                    ),
                  );
                },
                tooltip: 'View fullscreen',
              ),
            ],
          ),
          body: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Media preview
                Expanded(
                  child: Center(
                    child: _buildMediaPreview(randomMedia),
                  ),
                ),

                // Media info
                SizedBox(height: 16),
                Text(
                  randomMedia.name,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      randomMedia.isImage ? Icons.image : Icons.videocam,
                      size: 16,
                      color: Colors.grey,
                    ),
                    SizedBox(width: 8),
                    Text(
                      randomMedia.isImage ? 'Image' : 'Video',
                      style: TextStyle(color: Colors.grey),
                    ),
                    SizedBox(width: 16),
                    Icon(Icons.folder, size: 16, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      randomMedia.source.displayName,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                if (randomMedia.dateCreated != null)
                  Text(
                    'Created: ${_formatDate(randomMedia.dateCreated!)}',
                    style: TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaPreview(MediaItem mediaItem) {
    if (mediaItem.isImage) {
      return ImageViewerWidget(mediaItem: mediaItem);
    } else if (mediaItem.isVideo) {
      return VideoPlayerWidget(mediaItem: mediaItem);
    } else {
      return Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insert_drive_file, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Unsupported file format',
              style: TextStyle(color: Colors.grey),
            )
          ],
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
