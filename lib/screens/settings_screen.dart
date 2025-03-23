import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/preferences_service.dart';
import '../services/storage_service.dart';
import '../services/media_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _clearingCache = false;
  String? _cacheSize;

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheSize = await _getTotalDirectorySize(cacheDir);
      final cacheSizeInMB = (cacheSize / (1024 * 1024)).toStringAsFixed(2);

      setState(() {
        _cacheSize = cacheSizeInMB;
      });
    } catch (e) {
      print('Error calculating cache size: $e');
      setState(() {
        _cacheSize = 'Unknown';
      });
    }
  }

  Future<int> _getTotalDirectorySize(Directory dir) async {
    int totalSize = 0;

    try {
      final entities = dir.listSync(recursive: true, followLinks: false);

      for (final entity in entities) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    } catch (e) {
      print('Error getting directory size: $e');
    }

    return totalSize;
  }

  Future<void> _clearCache() async {
    setState(() {
      _clearingCache = true;
    });

    try {
      final cacheDir = await getTemporaryDirectory();
      final entities = cacheDir.listSync(recursive: true, followLinks: false);

      for (final entity in entities) {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          try {
            await entity.delete(recursive: true);
          } catch (e) {
            // Skip directories that can't be deleted
            print('Could not delete directory: ${entity.path}');
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cache cleared successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await _calculateCacheSize();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clearing cache: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _clearingCache = false;
      });
    }
  }

  Future<void> _refreshMedia() async {
    final mediaService = Provider.of<MediaService>(context, listen: false);
    await mediaService.refreshMedia();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Media library refreshed'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _showResetConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Reset All Settings'),
          content: Text(
            'Are you sure you want to reset all settings to their defaults? '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final preferencesService =
          Provider.of<PreferencesService>(context, listen: false);
      await preferencesService.resetAllPreferences();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All settings have been reset to defaults'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PreferencesService>(
      builder: (context, preferences, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Settings'),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh),
                tooltip: 'Refresh Media',
                onPressed: _refreshMedia,
              ),
            ],
          ),
          body: ListView(
            children: [
              // Appearance Section
              _buildSectionHeader('Appearance'),
              SwitchListTile(
                title: Text('Dark Mode'),
                subtitle: Text('Use dark theme for the app'),
                value: preferences.isDarkMode,
                onChanged: (value) {
                  preferences.setDarkMode(value);
                },
              ),

              // Display Settings
              _buildSectionHeader('Display'),
              ListTile(
                title: Text('Gallery Columns (Portrait)'),
                subtitle: Text('Number of columns in portrait mode'),
                trailing: DropdownButton<int>(
                  value: preferences.galleryColumnsPortrait,
                  onChanged: (value) {
                    if (value != null) {
                      preferences.setGalleryColumnsPortrait(value);
                    }
                  },
                  items: [2, 3, 4, 5].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value'),
                    );
                  }).toList(),
                ),
              ),
              ListTile(
                title: Text('Gallery Columns (Landscape)'),
                subtitle: Text('Number of columns in landscape mode'),
                trailing: DropdownButton<int>(
                  value: preferences.galleryColumnsLandscape,
                  onChanged: (value) {
                    if (value != null) {
                      preferences.setGalleryColumnsLandscape(value);
                    }
                  },
                  items: [3, 4, 5, 6, 7].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value'),
                    );
                  }).toList(),
                ),
              ),
              SwitchListTile(
                title: Text('Show Filenames'),
                subtitle: Text('Display filenames under thumbnails'),
                value: preferences.showFilenames,
                onChanged: (value) {
                  preferences.setShowFilenames(value);
                },
              ),

              // Sorting and Organization
              _buildSectionHeader('Sorting'),
              ListTile(
                title: Text('Sort Media By'),
                subtitle: Text('How media is ordered in gallery'),
                trailing: DropdownButton<String>(
                  value: preferences.sortBy,
                  onChanged: (value) {
                    if (value != null) {
                      preferences.setSortBy(value);
                    }
                  },
                  items: [
                    DropdownMenuItem<String>(
                      value: 'date',
                      child: Text('Date'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'name',
                      child: Text('Name'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'type',
                      child: Text('Type'),
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                title: Text('Sort Ascending'),
                subtitle: Text(
                    'Sort oldest/A-Z first (On) or newest/Z-A first (Off)'),
                value: preferences.sortAscending,
                onChanged: (value) {
                  preferences.setSortAscending(value);
                },
              ),

              // Media Playback
              _buildSectionHeader('Media Playback'),
              SwitchListTile(
                title: Text('Autoplay Videos'),
                subtitle: Text('Automatically play videos when viewing'),
                value: preferences.autoplayVideos,
                onChanged: (value) {
                  preferences.setAutoplayVideos(value);
                },
              ),

              // Startup Options
              _buildSectionHeader('Startup Options'),
              SwitchListTile(
                title: Text('Show Random Media on Startup'),
                subtitle:
                    Text('Display a random media item when the app starts'),
                value: preferences.showRandomOnStartup,
                onChanged: (value) {
                  preferences.setShowRandomOnStartup(value);
                },
              ),
              ListTile(
                title: Text('Default Screen'),
                subtitle: Text('Screen to show when app starts'),
                trailing: DropdownButton<String>(
                  value: preferences.startupScreen,
                  onChanged: (value) {
                    if (value != null) {
                      preferences.setStartupScreen(value);
                    }
                  },
                  items: [
                    DropdownMenuItem<String>(
                      value: 'home',
                      child: Text('Home'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'gallery',
                      child: Text('Gallery'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'calendar',
                      child: Text('Calendar'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'collections',
                      child: Text('Collections'),
                    ),
                  ],
                ),
              ),

              // Storage Settings
              _buildSectionHeader('Storage'),
              SwitchListTile(
                title: Text('Save Downloaded Files'),
                subtitle: Text('Save cloud files locally after viewing'),
                value: preferences.saveDownloadedFiles,
                onChanged: (value) {
                  preferences.setSaveDownloadedFiles(value);
                },
              ),

              // Recent Locations
              if (preferences.recentLocalPaths.isNotEmpty) ...[
                _buildSectionHeader('Recent Folders'),
                ...preferences.recentLocalPaths.map((path) => ListTile(
                      title: Text(
                        path.split('/').last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      leading: Icon(Icons.folder),
                      onTap: () {
                        // Open this folder again (implementation depends on your navigation)
                      },
                    )),
                ListTile(
                  title: Text('Clear Recent Folders'),
                  leading: Icon(Icons.clear_all),
                  onTap: () {
                    preferences.clearRecentLocalPaths();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Recent folders cleared')),
                    );
                  },
                ),
              ],

              // Cloud Storage
              _buildSectionHeader('Cloud Storage'),
              Consumer<StorageService>(
                builder: (context, storageService, child) {
                  return SwitchListTile(
                    title: Text('Connect to Google Drive'),
                    subtitle: Text(
                      storageService.isGoogleDriveConnected
                          ? 'Connected to Google Drive'
                          : 'Not connected to Google Drive',
                    ),
                    value: storageService.isGoogleDriveConnected,
                    onChanged: (value) async {
                      if (value) {
                        await storageService.connectToGoogleDrive();
                      } else {
                        await storageService.disconnectGoogleDrive();
                      }
                      // Refresh media after connection change
                      _refreshMedia();
                    },
                  );
                },
              ),

              // Cache Management
              _buildSectionHeader('Cache Management'),
              ListTile(
                title: Text('Clear Media Cache'),
                subtitle: Text(
                  'Current cache size: ${_cacheSize ?? '...'}MB',
                ),
                leading: Icon(Icons.cleaning_services),
                trailing: _clearingCache
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _clearingCache ? null : _clearCache,
              ),

              // About & Reset
              _buildSectionHeader('Advanced'),
              ListTile(
                title: Text('Reset All Settings'),
                subtitle: Text('Restore all settings to their default values'),
                leading: Icon(Icons.restore),
                onTap: _showResetConfirmDialog,
              ),

              // App Information
              _buildSectionHeader('About'),
              ListTile(
                title: Text('Media Viewer'),
                subtitle: Text('Version 1.0.0'),
                leading: Icon(Icons.info_outline),
              ),

              SizedBox(height: 32), // Bottom padding
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: 8),
          Divider(height: 1),
        ],
      ),
    );
  }
}
