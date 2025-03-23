import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../services/media_service.dart';
import '../models/media_item.dart';
import '../models/media_source.dart';
import '../widgets/media_grid_item.dart';
import 'media_viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  MediaType? _selectedType;
  MediaSource? _selectedSource;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaService>(
      builder: (context, mediaService, child) {
        // Filter media based on selection
        final filteredMedia = _filterMedia(mediaService.allMedia);

        return Scaffold(
          appBar: AppBar(
            title: Text('Gallery'),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () => mediaService.refreshMedia(),
                tooltip: 'Refresh media',
              ),
            ],
          ),
          body: Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: _buildGalleryGrid(filteredMedia),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              // Type filter
              DropdownButton<MediaType?>(
                value: _selectedType,
                hint: Text('All Types'),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value;
                  });
                },
                items: [
                  DropdownMenuItem<MediaType?>(
                    value: null,
                    child: Text('All Types'),
                  ),
                  DropdownMenuItem<MediaType?>(
                    value: MediaType.image,
                    child: Text('Images'),
                  ),
                  DropdownMenuItem<MediaType?>(
                    value: MediaType.video,
                    child: Text('Videos'),
                  ),
                ],
              ),

              SizedBox(width: 16),

              // Source filter
              DropdownButton<MediaSource?>(
                value: _selectedSource,
                hint: Text('All Sources'),
                onChanged: (value) {
                  setState(() {
                    _selectedSource = value;
                  });
                },
                items: [
                  DropdownMenuItem<MediaSource?>(
                    value: null,
                    child: Text('All Sources'),
                  ),
                  DropdownMenuItem<MediaSource?>(
                    value: MediaSource.local,
                    child: Text('Local Storage'),
                  ),
                  DropdownMenuItem<MediaSource?>(
                    value: MediaSource.googleDrive,
                    child: Text('Google Drive'),
                  ),
                ],
              ),

              Spacer(),

              // Search field
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryGrid(List<MediaItem> media) {
    if (media.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No media found',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Try changing your filters or add new media',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return MasonryGridView.count(
      crossAxisCount: _calculateColumnCount(context),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      itemCount: media.length,
      itemBuilder: (context, index) {
        final mediaItem = media[index];
        return MediaGridItem(
          mediaItem: mediaItem,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MediaViewerScreen(
                  mediaItem: mediaItem,
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<MediaItem> _filterMedia(List<MediaItem> allMedia) {
    return allMedia.where((media) {
      if (_selectedType != null && media.type != _selectedType) {
        return false;
      }

      if (_selectedSource != null && media.source != _selectedSource) {
        return false;
      }

      if (_searchQuery.isNotEmpty &&
          !media.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }

      return true;
    }).toList();
  }

  int _calculateColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width > 1200) {
      return 5;
    } else if (width > 900) {
      return 4;
    } else if (width > 600) {
      return 3;
    } else {
      return 2;
    }
  }
}
