import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum MediaFetchType { all, image, video }

enum PhotoLibraryPermissionStatus { granted, denied, permanentlyDenied }

class MediaItem {
  final String id;
  final String uri;
  final MediaFetchType type;
  final int duration; // in milliseconds (0 for images)
  final int width;
  final int height;
  final DateTime dateAdded;
  final String? originalMediaUri;

  MediaItem({
    required this.id,
    required this.uri,
    required this.type,
    required this.duration,
    required this.width,
    required this.height,
    required this.dateAdded,
    this.originalMediaUri,
  });

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type'] as String? ?? 'image';
    final mediaType = MediaFetchType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => MediaFetchType.image,
    );
    final int dateSec = map['dateAdded'] as int? ?? 0;

    return MediaItem(
      id: map['id'] as String? ?? '',
      uri: map['uri'] as String? ?? '',
      type: mediaType,
      duration: map['duration'] as int? ?? 0,
      width: map['width'] as int? ?? 0,
      height: map['height'] as int? ?? 0,
      dateAdded: DateTime.fromMillisecondsSinceEpoch(dateSec * 1000),
      originalMediaUri: map['originalMediaUri'] as String?,
    );
  }

  String get formattedDuration {
    if (type != MediaFetchType.video || duration <= 0) return '';
    final seconds = (duration / 1000).round();
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class MediaFile {
  final Uint8List? bytes;
  final String? videoUrl;

  MediaFile({this.bytes, this.videoUrl});

  bool get isImage => bytes != null;

  bool get isVideo => videoUrl != null;
}

class FlutterPhotoLibrary {
  static const MethodChannel _channel = MethodChannel(
    'com.example.flutter_photo_library/gallery',
  );

  /// Checks if media access permissions are currently granted on the device.
  static Future<bool> checkPermissions() async {
    try {
      final bool result = await _channel.invokeMethod('checkPermissions');
      return result;
    } on PlatformException catch (e) {
      debugPrint(
        'FlutterPhotoLibrary: Failed to check permissions: ${e.message}',
      );
      return false;
    }
  }

  /// Requests media access permissions from the native operating system.
  static Future<PhotoLibraryPermissionStatus> requestPermissions() async {
    try {
      final String? result = await _channel.invokeMethod('requestPermissions');
      switch (result) {
        case 'granted':
          return PhotoLibraryPermissionStatus.granted;
        case 'permanently_denied':
          return PhotoLibraryPermissionStatus.permanentlyDenied;
        case 'denied':
        default:
          return PhotoLibraryPermissionStatus.denied;
      }
    } on PlatformException catch (e) {
      debugPrint(
        'FlutterPhotoLibrary: Failed to request permissions: ${e.message}',
      );
      return PhotoLibraryPermissionStatus.denied;
    }
  }
}

/// Represents a folder or album containing media.
class MediaAlbum {
  final String id;
  final String name;
  final int count;

  MediaAlbum({required this.id, required this.name, required this.count});

  factory MediaAlbum.fromMap(Map<String, dynamic> map) {
    return MediaAlbum(
      id: map['id'] as String,
      name: map['name'] as String,
      count: map['count'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaAlbum && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class FlutterPhotoLibraryRepository {
  static final FlutterPhotoLibraryRepository _instance =
      FlutterPhotoLibraryRepository._internal();

  factory FlutterPhotoLibraryRepository() => _instance;

  FlutterPhotoLibraryRepository._internal();

  static const MethodChannel _channel = MethodChannel(
    'com.example.flutter_photo_library/gallery',
  );
  final LinkedHashMap<String, Uint8List> _thumbnailCache =
      LinkedHashMap<String, Uint8List>();
  final Map<String, Future<Uint8List?>> _inflightThumbnails = {};

  // Maximum thumbnail byte cache size in Flutter memory to avoid bloat
  static const int _maxCacheSize = 400;

  /// Default values used across the repository when no explicit value is provided.
  static const int defaultPageSize = 50;
  static const int defaultThumbnailWidth = 200;
  static const int defaultThumbnailHeight = 200;
  static const int defaultThumbnailQuality = 80;

  /// Fetches a paginated list of [MediaItem] objects from native storage.
  ///
  /// [page] is 0-indexed. Defaults to `0` (first page).
  /// [pageSize] defaults to `50`.
  /// [albumId] optional ID of a specific album to filter media from.
  Future<List<MediaItem>> fetchMediaPage({
    int page = 0,
    int pageSize = defaultPageSize,
    MediaFetchType fetchType = MediaFetchType.all,
    String? albumId,
  }) async {
    try {
      String typeStr = 'all';
      if (fetchType == MediaFetchType.image) typeStr = 'image';
      if (fetchType == MediaFetchType.video) typeStr = 'video';

      final List<dynamic>? result =
          await _channel.invokeMethod('getMediaPage', {
        'page': page,
        'pageSize': pageSize,
        'mediaType': typeStr,
        if (albumId != null) 'albumId': albumId,
      });
      if (result == null) return [];
      return result
          .map(
            (item) => MediaItem.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } on PlatformException catch (e) {
      debugPrint(
        'FlutterPhotoLibraryRepository: Failed to get media page: ${e.message}',
      );
      return [];
    }
  }

  /// Retrieves thumbnail bytes for a media item, returning from LRU memory cache if present.
  ///
  /// Only [id] is required. All other parameters have sensible defaults:
  /// - [type] defaults to `MediaFetchType.image`
  /// - [width] defaults to `200` (physical pixels)
  /// - [height] defaults to `200` (physical pixels)
  /// - [quality] defaults to `80` (0–100; mapped to iOS compressionQuality)
  /// - [format] defaults to `'jpeg'` (`jpeg`, `png`, or `webp`)
  ///
  /// Concurrent requests for the same cache key are coalesced. Call
  /// [cancelThumbnail] when a grid cell is disposed / recycled to stop native work.
  Future<Uint8List?> getThumbnail({
    required String id,
    MediaFetchType type = MediaFetchType.image,
    int width = defaultThumbnailWidth,
    int height = defaultThumbnailHeight,
    int quality = defaultThumbnailQuality,
    String format = 'jpeg',
  }) async {
    final cacheKey = '${id}_${width}x${height}_${format}_$quality';

    // Check memory cache
    if (_thumbnailCache.containsKey(cacheKey)) {
      final data = _thumbnailCache.remove(cacheKey)!;
      _thumbnailCache[cacheKey] = data; // mark as most recently used
      return data;
    }

    final inflight = _inflightThumbnails[cacheKey];
    if (inflight != null) {
      return inflight;
    }

    final future = _fetchThumbnailBytes(
      id: id,
      type: type,
      width: width,
      height: height,
      quality: quality,
      format: format,
      cacheKey: cacheKey,
    );
    _inflightThumbnails[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inflightThumbnails.remove(cacheKey);
    }
  }

  Future<Uint8List?> _fetchThumbnailBytes({
    required String id,
    required MediaFetchType type,
    required int width,
    required int height,
    required int quality,
    required String format,
    required String cacheKey,
  }) async {
    try {
      final Uint8List? bytes = await _channel.invokeMethod('getThumbnail', {
        'id': id,
        'type': type == MediaFetchType.video ? 'video' : 'image',
        'width': width,
        'height': height,
        'quality': quality,
        'format': format,
      });

      if (bytes != null) {
        _thumbnailCache[cacheKey] = bytes;
        if (_thumbnailCache.length > _maxCacheSize) {
          _thumbnailCache.remove(_thumbnailCache.keys.first); // Evict oldest
        }
      }
      return bytes;
    } on PlatformException catch (e) {
      debugPrint(
        'FlutterPhotoLibraryRepository: Failed to get thumbnail: ${e.message}',
      );
      return null;
    }
  }

  /// Cancels an in-flight native thumbnail decode for [id].
  ///
  /// Safe to call from widget `dispose` / when a recycled cell changes item.
  /// The pending [getThumbnail] Future completes with `null`.
  void cancelThumbnail(String id) {
    _inflightThumbnails.removeWhere((key, _) => key.startsWith('${id}_'));
    try {
      _channel.invokeMethod('cancelThumbnail', {'id': id});
    } on PlatformException catch (e) {
      debugPrint(
        'FlutterPhotoLibraryRepository: Failed to cancel thumbnail: ${e.message}',
      );
    }
  }

  /// Fetches a playable media URL for a specific item.
  ///
  /// For videos, this returns the path to the video file.
  /// For images, this returns the path to the high-res image (on iOS this may trigger a download).
  Future<String?> getMediaUrl({
    required String id,
    MediaFetchType type = MediaFetchType.image,
  }) async {
    try {
      final String? url = await _channel.invokeMethod('getMediaUrl', {
        'id': id,
        'type': type == MediaFetchType.video ? 'video' : 'image',
      });
      return url;
    } on PlatformException catch (e) {
      debugPrint(
        'FlutterPhotoLibraryRepository: Failed to get media URL: ${e.message}',
      );
      return null;
    }
  }

  /// Loads the original media file.
  ///
  /// For images, this returns a [MediaFile] containing the raw JPEG bytes.
  /// For videos, this returns a [MediaFile] containing the file URI string.
  /// Returns `null` if loading fails.
  ///
  /// **Note:** For very large images this may use significant memory.
  Future<MediaFile?> getOriginalFile({
    required String id,
    MediaFetchType type = MediaFetchType.image,
  }) async {
    if (type == MediaFetchType.video) {
      try {
        final String? url = await _channel.invokeMethod('getVideoUrl', {
          'id': id,
        });
        return url != null ? MediaFile(videoUrl: url) : null;
      } on PlatformException catch (e) {
        debugPrint(
          'FlutterPhotoLibraryRepository: Failed to get video URL: ${e.message}',
        );
        return null;
      }
    }

    try {
      final Uint8List? bytes = await _channel.invokeMethod('getOriginalFile', {
        'id': id,
        'type': 'image',
      });
      return bytes != null ? MediaFile(bytes: bytes) : null;
    } on PlatformException catch (e) {
      debugPrint(
        'FlutterPhotoLibraryRepository: Failed to get original file: ${e.message}',
      );
      return null;
    }
  }

  /// Fetches a list of non-empty media albums (folders) from the device.
  Future<List<MediaAlbum>> getAlbums({
    MediaFetchType type = MediaFetchType.all,
  }) async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getAlbums', {
        'mediaType': type.toString().split('.').last,
      });
      return result
          .cast<Map<Object?, Object?>>()
          .map((map) => MediaAlbum.fromMap(Map<String, dynamic>.from(map)))
          .toList();
    } on PlatformException catch (e) {
      debugPrint(
        'FlutterPhotoLibraryRepository: Failed to get albums: ${e.message}',
      );
      return [];
    }
  }

  /// Clears the in-memory thumbnail cache.
  void clearCache() {
    _inflightThumbnails.clear();
    _thumbnailCache.clear();
  }
}
