import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:media_viewer/screens/media_viewer_screen.dart';
import 'package:media_viewer/widgets/media_grid_item.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../models/media_item.dart';
import '../services/media_service.dart';
import '../widgets/loading_widget.dart';

// Collection model to represent a group of media items
class Collection {
  String id;
  String name;
  String? description;
  DateTime createdAt;
  DateTime modifiedAt;
  List<String> mediaIds; // IDs of media items in this collection
  String? thumbnailId; // ID of the media item to use as thumbnail

  Collection({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.modifiedAt,
    required this.mediaIds,
    this.thumbnailId,
  });

  // Create a new empty collection
  factory Collection.create(String name, {String? description}) {
    final now = DateTime.now();
    return Collection(
      id: 'collection_${now.millisecondsSinceEpoch}',
      name: name,
      description: description,
      createdAt: now,
      modifiedAt: now,
      mediaIds: [],
    );
  }

  // Convert to and from JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
      'mediaIds': mediaIds,
      'thumbnailId': thumbnailId,
    };
  }

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
      modifiedAt: DateTime.parse(json['modifiedAt']),
      mediaIds: List<String>.from(json['mediaIds']),
      thumbnailId: json['thumbnailId'],
    );
  }

  // Helper methods
  int get itemCount => mediaIds.length;

  bool containsMedia(String mediaId) => mediaIds.contains(mediaId);

  void addMedia(String mediaId) {
    if (!mediaIds.contains(mediaId)) {
      mediaIds.add(mediaId);
      modifiedAt = DateTime.now();

      // If this is the first item, use it as the thumbnail
      if (mediaIds.length == 1 && thumbnailId == null) {
        thumbnailId = mediaId;
      }
    }
  }

  void removeMedia(String mediaId) {
    if (mediaIds.contains(mediaId)) {
      mediaIds.remove(mediaId);
      modifiedAt = DateTime.now();

      // If we removed the thumbnail, pick a new one if available
      if (thumbnailId == mediaId) {
        thumbnailId = mediaIds.isNotEmpty ? mediaIds.first : null;
      }
    }
  }
}

// CollectionsManager to handle collections storage and operations
class CollectionsManager extends ChangeNotifier {
  List<Collection> _collections = [];
  File? _collectionsFile;
  bool _isLoading = false;
  String? _error;

  List<Collection> get collections => _collections;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Initialize the collections manager
  Future<void> init() async {
    _setLoading(true);

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _collectionsFile = File('${appDir.path}/collections.json');

      // Load collections from file if it exists
      if (await _collectionsFile!.exists()) {
        final jsonString = await _collectionsFile!.readAsString();
        final jsonData = jsonDecode(jsonString) as List;
        _collections =
            jsonData.map((item) => Collection.fromJson(item)).toList();
      }

      _setError(null);
    } catch (e) {
      _setError('Error loading collections: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Save collections to persistent storage
  Future<void> _saveCollections() async {
    if (_collectionsFile == null) return;

    try {
      final jsonData = _collections.map((c) => c.toJson()).toList();
      final jsonString = jsonEncode(jsonData);
      await _collectionsFile!.writeAsString(jsonString);
    } catch (e) {
      _setError('Error saving collections: $e');
    }
  }

  // Collection operations
  Future<Collection> createCollection(String name,
      {String? description}) async {
    final collection = Collection.create(name, description: description);
    _collections.add(collection);
    await _saveCollections();
    notifyListeners();
    return collection;
  }

  Future<void> updateCollection(Collection collection) async {
    final index = _collections.indexWhere((c) => c.id == collection.id);
    if (index >= 0) {
      collection.modifiedAt = DateTime.now();
      _collections[index] = collection;
      await _saveCollections();
      notifyListeners();
    }
  }

  Future<void> deleteCollection(String collectionId) async {
    _collections.removeWhere((c) => c.id == collectionId);
    await _saveCollections();
    notifyListeners();
  }

  Future<void> addMediaToCollection(String collectionId, String mediaId) async {
    final collection = _collections.firstWhere(
      (c) => c.id == collectionId,
      orElse: () => throw Exception('Collection not found'),
    );

    collection.addMedia(mediaId);
    await _saveCollections();
    notifyListeners();
  }

  Future<void> removeMediaFromCollection(
      String collectionId, String mediaId) async {
    final collection = _collections.firstWhere(
      (c) => c.id == collectionId,
      orElse: () => throw Exception('Collection not found'),
    );

    collection.removeMedia(mediaId);
    await _saveCollections();
    notifyListeners();
  }

  Collection? getCollectionById(String id) {
    try {
      return _collections.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Collection> getCollectionsContainingMedia(String mediaId) {
    return _collections.where((c) => c.containsMedia(mediaId)).toList();
  }

  // Helper methods for state management
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? errorMsg) {
    _error = errorMsg;
    notifyListeners();
  }
}

// Main CollectionsScreen widget
class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  // Define a collections manager
  final CollectionsManager _collectionsManager = CollectionsManager();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCollections();
  }

  Future<void> _initializeCollections() async {
    if (!_isInitialized) {
      await _collectionsManager.init();
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _collectionsManager.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Collections'),
        ),
        body: LoadingWidget(message: 'Loading collections...'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Collections'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            tooltip: 'Create new collection',
            onPressed: _showCreateCollectionDialog,
          ),
        ],
      ),
      body: _buildCollectionsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateCollectionDialog,
        tooltip: 'Create Collection',
        child: Icon(Icons.create_new_folder),
      ),
    );
  }

  Widget _buildCollectionsList() {
    final collections = _collectionsManager.collections;

    if (collections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.collections_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No collections yet',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Create your first collection to organize your media',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateCollectionDialog,
              icon: Icon(Icons.create_new_folder),
              label: Text('Create Collection'),
            ),
          ],
        ),
      );
    }

    // Sort collections by modified date (most recent first)
    collections.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));

    return Consumer<MediaService>(
      builder: (context, mediaService, child) {
        return GridView.builder(
          padding: EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _calculateColumnCount(context),
            childAspectRatio: 0.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: collections.length,
          itemBuilder: (context, index) {
            final collection = collections[index];
            return _buildCollectionCard(context, collection, mediaService);
          },
        );
      },
    );
  }

  Widget _buildCollectionCard(
      BuildContext context, Collection collection, MediaService mediaService) {
    // Find the thumbnail media item
    MediaItem? thumbnailMedia;
    if (collection.thumbnailId != null) {
      try {
        thumbnailMedia = mediaService.allMedia.firstWhere(
          (media) => media.id == collection.thumbnailId,
        );
      } catch (e) {
        // Thumbnail not found, will use placeholder
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _openCollectionDetails(collection),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail or placeholder
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Thumbnail
                  thumbnailMedia != null
                      ? MediaGridItem(
                          mediaItem: thumbnailMedia,
                          onTap: () => _openCollectionDetails(collection),
                          showDetails: false,
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: Icon(
                            Icons.collections,
                            size: 64,
                            color: Colors.grey[600],
                          ),
                        ),

                  // Item count badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${collection.itemCount}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Collection info
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  if (collection.description != null)
                    Text(
                      collection.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  SizedBox(height: 4),
                  Text(
                    'Last updated: ${_formatDate(collection.modifiedAt)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCollectionDetails(Collection collection) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollectionDetailScreen(
          collection: collection,
          collectionsManager: _collectionsManager,
        ),
      ),
    );
  }

  Future<void> _showCreateCollectionDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Create New Collection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Collection Name',
                  hintText: 'Enter a name for this collection',
                ),
                autofocus: true,
              ),
              SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Enter a description',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final description = descriptionController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Collection name is required')),
                  );
                  return;
                }

                Navigator.pop(
                  context,
                  {
                    'name': name,
                    'description': description.isEmpty ? null : description,
                  },
                );
              },
              child: Text('Create'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      await _collectionsManager.createCollection(
        result['name']!,
        description: result['description'],
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Collection "${result['name']}" created'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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

// Screen to display collection contents
class CollectionDetailScreen extends StatefulWidget {
  final Collection collection;
  final CollectionsManager collectionsManager;

  const CollectionDetailScreen({
    super.key,
    required this.collection,
    required this.collectionsManager,
  });

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  Collection get collection => widget.collection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(collection.name),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            tooltip: 'Edit collection',
            onPressed: _showEditCollectionDialog,
          ),
          IconButton(
            icon: Icon(Icons.add_photo_alternate),
            tooltip: 'Add media',
            onPressed: _showAddMediaDialog,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('Rename Collection'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Collection',
                        style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<MediaService>(
        builder: (context, mediaService, child) {
          // Filter media items to only those in the collection
          final collectionMedia = mediaService.allMedia
              .where((media) => collection.mediaIds.contains(media.id))
              .toList();

          if (collectionMedia.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No media in this collection',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add media to get started',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showAddMediaDialog,
                    icon: Icon(Icons.add_photo_alternate),
                    label: Text('Add Media'),
                  ),
                ],
              ),
            );
          }

          // Sort media by date (newest first)
          collectionMedia.sort((a, b) {
            final aDate = a.dateModified ?? a.dateCreated;
            final bDate = b.dateModified ?? b.dateCreated;
            if (aDate == null || bDate == null) return 0;
            return bDate.compareTo(aDate);
          });

          return GridView.builder(
            padding: EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _calculateColumnCount(context),
              childAspectRatio: 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: collectionMedia.length,
            itemBuilder: (context, index) {
              final mediaItem = collectionMedia[index];
              return Stack(
                children: [
                  MediaGridItem(
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
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: Icon(
                        Icons.remove_circle,
                        color: Colors.red.withValues(alpha: 0.8),
                      ),
                      tooltip: 'Remove from collection',
                      onPressed: () => _removeMediaFromCollection(mediaItem.id),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMediaDialog,
        tooltip: 'Add Media',
        child: Icon(Icons.add_photo_alternate),
      ),
    );
  }

  Future<void> _showEditCollectionDialog() async {
    final nameController = TextEditingController(text: collection.name);
    final descriptionController =
        TextEditingController(text: collection.description ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Collection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Collection Name',
                ),
                autofocus: true,
              ),
              SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final description = descriptionController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Collection name is required')),
                  );
                  return;
                }

                Navigator.pop(
                  context,
                  {
                    'name': name,
                    'description': description.isEmpty ? null : description,
                  },
                );
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      // Update collection
      collection.name = result['name']!;
      collection.description = result['description'];
      await widget.collectionsManager.updateCollection(collection);

      // Force a UI update
      setState(() {});

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Collection updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'rename':
        _showEditCollectionDialog();
        break;
      case 'delete':
        _confirmDeleteCollection();
        break;
    }
  }

  Future<void> _confirmDeleteCollection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Collection'),
          content: Text(
            'Are you sure you want to delete "${collection.name}"? '
            'This action cannot be undone. The media files will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await widget.collectionsManager.deleteCollection(collection.id);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Collection deleted'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      Navigator.pop(context);
    }
  }

  Future<void> _showAddMediaDialog() async {
    // Show media selection screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaSelectionScreen(
          collection: collection,
          collectionsManager: widget.collectionsManager,
        ),
      ),
    ).then((_) {
      // Refresh UI when returning from media selection
      setState(() {});
    });
  }

  Future<void> _removeMediaFromCollection(String mediaId) async {
    // Confirm removal
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Remove Media'),
          content: Text(
            'Remove this item from the collection? The media file will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await widget.collectionsManager.removeMediaFromCollection(
        collection.id,
        mediaId,
      );

      // Force UI update
      setState(() {});

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Media removed from collection'),
        ),
      );
    }
  }

  int _calculateColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width > 1200) {
      return 6;
    } else if (width > 900) {
      return 5;
    } else if (width > 600) {
      return 4;
    } else {
      return 3;
    }
  }
}

// Screen for selecting media to add to a collection
class MediaSelectionScreen extends StatefulWidget {
  final Collection collection;
  final CollectionsManager collectionsManager;

  const MediaSelectionScreen({
    super.key,
    required this.collection,
    required this.collectionsManager,
  });

  @override
  State<MediaSelectionScreen> createState() => _MediaSelectionScreenState();
}

class _MediaSelectionScreenState extends State<MediaSelectionScreen> {
  Collection get collection => widget.collection;
  final Set<String> _selectedMediaIds = {};
  MediaType? _selectedType;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add to ${collection.name}'),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.check),
            label: Text('Add Selected (${_selectedMediaIds.length})'),
            onPressed: _selectedMediaIds.isEmpty ? null : _addSelectedMedia,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _buildMediaGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
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
    );
  }

  Widget _buildMediaGrid() {
    return Consumer<MediaService>(
      builder: (context, mediaService, child) {
        // Filter media based on selection criteria and exclude items already in collection
        final filteredMedia = mediaService.allMedia.where((media) {
          // Skip items already in the collection
          if (collection.containsMedia(media.id)) {
            return false;
          }

          // Filter by type
          if (_selectedType != null && media.type != _selectedType) {
            return false;
          }

          // Search by name
          if (_searchQuery.isNotEmpty &&
              !media.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
            return false;
          }

          return true;
        }).toList();

        if (filteredMedia.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No media available',
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

        // Sort media by date (newest first)
        filteredMedia.sort((a, b) {
          final aDate = a.dateModified ?? a.dateCreated;
          final bDate = b.dateModified ?? b.dateCreated;
          if (aDate == null || bDate == null) return 0;
          return bDate.compareTo(aDate);
        });

        return GridView.builder(
          padding: EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _calculateColumnCount(context),
            childAspectRatio: 1,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: filteredMedia.length,
          itemBuilder: (context, index) {
            final mediaItem = filteredMedia[index];
            final isSelected = _selectedMediaIds.contains(mediaItem.id);

            return Stack(
              children: [
                MediaGridItem(
                  mediaItem: mediaItem,
                  onTap: () => _toggleMediaSelection(mediaItem.id),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.white.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(2),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : SizedBox(width: 20, height: 20),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleMediaSelection(String mediaId) {
    setState(() {
      if (_selectedMediaIds.contains(mediaId)) {
        _selectedMediaIds.remove(mediaId);
      } else {
        _selectedMediaIds.add(mediaId);
      }
    });
  }

  Future<void> _addSelectedMedia() async {
    if (_selectedMediaIds.isEmpty) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Adding media to collection...'),
          ],
        ),
      ),
    );

    try {
      // Add each selected media to the collection
      for (final mediaId in _selectedMediaIds) {
        await widget.collectionsManager.addMediaToCollection(
          collection.id,
          mediaId,
        );
      }

      // Close loading dialog
      Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${_selectedMediaIds.length} items to ${collection.name}',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Return to collection detail
      Navigator.pop(context);
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding media: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int _calculateColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width > 1200) {
      return 6;
    } else if (width > 900) {
      return 5;
    } else if (width > 600) {
      return 4;
    } else {
      return 3;
    }
  }
}
