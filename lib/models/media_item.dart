import 'dart:io';
import 'media_source.dart';

enum MediaType {
  image,
  video,
  unknown,
}

class MediaItem {
  final String id;
  final String name;
  final String path;
  final MediaType type;
  final MediaSource source;
  final DateTime? dateCreated;
  final DateTime? dateModified;
  final String? thumbnailPath;
  final Map<String, dynamic>? metadata;

  // Cloud items
  final String? downloadUrl;
  final String? cloudId;

  MediaItem({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.source,
    this.dateCreated,
    this.dateModified,
    this.thumbnailPath,
    this.metadata,
    this.downloadUrl,
    this.cloudId,
  });

  bool get isLocal => source == MediaSource.local;
  bool get isCloud => source == MediaSource.googleDrive;
  bool get isImage => type == MediaType.image;
  bool get isVideo => type == MediaType.video;

  File? get localFile => isLocal ? File(path) : null;

  static MediaType getTypeFromExtension(String extension) {
    final ext = extension.toLowerCase();

    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic', 'heif']
        .contains(ext)) {
      return MediaType.image;
    } else if (['mp4', 'mov', 'avi', 'wmv', 'flv', 'mkv', 'webm', '3gp', 'm4v']
        .contains(ext)) {
      return MediaType.video;
    }

    print('Unknown file extension: $ext');

    return MediaType.unknown;
  }

  static MediaItem fromFile(File file) {
    final name = file.path.split('/').last;
    final extension = name.split('.').last;
    final type = getTypeFromExtension(extension);

    return MediaItem(
      id: file.path,
      name: name,
      path: file.path,
      type: type,
      source: MediaSource.local,
      dateCreated: file.statSync().changed,
      dateModified: file.statSync().modified,
    );
  }

  static MediaItem fromGoogleDriveFile(Map<String, dynamic> driveFile) {
    final name = driveFile['name'] as String;
    final extension = name.split('.').last.toLowerCase();
    final type = getTypeFromExtension(extension);

    return MediaItem(
      id: 'gdrive_${driveFile['id']}',
      name: name,
      path: '', // No local path initially
      type: type,
      source: MediaSource.googleDrive,
      dateCreated: DateTime.parse(driveFile['createdTime']),
      dateModified: DateTime.parse(driveFile['modifiedTime']),
      cloudId: driveFile['id'],
      downloadUrl: driveFile['webContentLink'],
      metadata: {
        'mimeType': driveFile['mimeType'],
        'size': driveFile['size'],
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'type': type.toString(),
      'source': source.toString(),
      'dateCreated': dateCreated?.toIso8601String(),
      'dateModified': dateModified?.toIso8601String(),
      'thumbnailPath': thumbnailPath,
      'metadata': metadata,
      'downloadUrl': downloadUrl,
      'cloudId': cloudId,
    };
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'],
      name: json['name'],
      path: json['path'],
      type: MediaType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => MediaType.unknown,
      ),
      source: MediaSource.values.firstWhere(
        (e) => e.toString() == json['source'],
        orElse: () => MediaSource.local,
      ),
      dateCreated: json['dateCreated'] != null
          ? DateTime.parse(json['dateCreated'])
          : null,
      dateModified: json['dateModified'] != null
          ? DateTime.parse(json['dateModified'])
          : null,
      thumbnailPath: json['thumbnailPath'],
      metadata: json['metadata'],
      downloadUrl: json['downloadUrl'],
      cloudId: json['cloudId'],
    );
  }
}
