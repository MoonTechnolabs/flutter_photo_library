import 'package:flutter/foundation.dart';
import 'package:flutter_photo_library/flutter_photo_library.dart';

class GalleryProvider extends ChangeNotifier {
  final FlutterPhotoLibraryRepository _repository =
      FlutterPhotoLibraryRepository();

  // 60-80 items is optimal to bridge smooth grid updates without overwhelming channel latency
  static const int _pageSize = 80;

  bool _hasPermission = false;
  bool _isCheckingPermission = true;
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  MediaFetchType _currentFilter = MediaFetchType.all;
  List<MediaAlbum> _albums = [];
  MediaAlbum? _selectedAlbum;
  List<MediaItem> _mediaItems = [];
  String? _errorMessage;

  bool get hasPermission => _hasPermission;

  bool get isCheckingPermission => _isCheckingPermission;

  bool get isInitialLoading => _isInitialLoading;

  bool get isLoadingMore => _isLoadingMore;

  bool get hasMore => _hasMore;

  MediaFetchType get currentFilter => _currentFilter;

  List<MediaAlbum> get albums => _albums;

  MediaAlbum? get selectedAlbum => _selectedAlbum;

  List<MediaItem> get mediaItems => _mediaItems;

  String? get errorMessage => _errorMessage;

  void setFilter(MediaFetchType type) {
    if (_currentFilter == type) return;
    _currentFilter = type;
    _selectedAlbum = null; // Reset to "All" when switching tabs
    if (_hasPermission) {
      loadInitialMedia();
    }
  }

  void setAlbum(MediaAlbum? album) {
    if (_selectedAlbum?.id == album?.id) return;
    _selectedAlbum = album;
    if (_hasPermission) {
      loadInitialMedia(fetchAlbums: false);
    }
  }

  GalleryProvider() {
    init();
  }

  /// Initializes the provider by checking current permissions and loading media if authorized.
  Future<void> init() async {
    _isCheckingPermission = true;
    _errorMessage = null;
    notifyListeners();

    _hasPermission = await FlutterPhotoLibrary.checkPermissions();
    _isCheckingPermission = false;

    if (_hasPermission) {
      await loadInitialMedia();
    } else {
      notifyListeners();
    }
  }

  /// Requests permission from the system and triggers loading if granted.
  Future<void> requestAndLoadMedia() async {
    _isCheckingPermission = true;
    _errorMessage = null;
    notifyListeners();

    final PhotoLibraryPermissionStatus status =
        await FlutterPhotoLibrary.requestPermissions();
    _hasPermission = status == PhotoLibraryPermissionStatus.granted;
    _isCheckingPermission = false;

    if (_hasPermission) {
      await loadInitialMedia();
    } else {
      if (status == PhotoLibraryPermissionStatus.permanentlyDenied) {
        _errorMessage =
            "Permission permanently denied. Please enable access to media storage in app settings to display your gallery.";
      } else {
        _errorMessage =
            "Permission denied. Access to media storage is required to display your gallery.";
      }
      notifyListeners();
    }
  }

  /// Performs the initial query of device storage.
  Future<void> loadInitialMedia({bool fetchAlbums = true}) async {
    _isInitialLoading = true;
    _currentPage = 0;
    _hasMore = true;
    _errorMessage = null;
    _mediaItems = [];
    notifyListeners();

    try {
      if (fetchAlbums) {
        final fetchedAlbums = await _repository.getAlbums(type: _currentFilter);
        _albums = fetchedAlbums;

        // Ensure selected album is still valid for this filter, or reset to null (all)
        if (_selectedAlbum != null &&
            !_albums.any((a) => a.id == _selectedAlbum!.id)) {
          _selectedAlbum = null;
        }
      }

      final items = await _repository.fetchMediaPage(
        page: _currentPage,
        pageSize: _pageSize,
        fetchType: _currentFilter,
        albumId: _selectedAlbum?.id,
      );
      _mediaItems = items;
      if (items.length < _pageSize) {
        _hasMore = false;
      }
      _isInitialLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = "Failed to load media: $e";
      _isInitialLoading = false;
      notifyListeners();
    }
  }

  /// Loads the next page of media for infinite scrolling.
  Future<void> loadMoreMedia() async {
    if (_isLoadingMore || !_hasMore || !_hasPermission) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final items = await _repository.fetchMediaPage(
        page: nextPage,
        pageSize: _pageSize,
        fetchType: _currentFilter,
        albumId: _selectedAlbum?.id,
      );

      if (items.isEmpty) {
        _hasMore = false;
      } else {
        _mediaItems.addAll(items);
        _currentPage = nextPage;
        if (items.length < _pageSize) {
          _hasMore = false;
        }
      }
      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading more media in provider: $e");
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Refreshes the gallery by clearing cached bytes and querying the database again.
  void refresh() {
    _repository.clearCache();
    if (_hasPermission) {
      loadInitialMedia();
    } else {
      init();
    }
  }
}
