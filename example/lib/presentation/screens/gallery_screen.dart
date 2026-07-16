import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_photo_library/flutter_photo_library.dart';
import 'package:flutter_photo_library_example/presentation/providers/gallery_provider.dart';
import 'package:flutter_photo_library_example/presentation/widgets/gallery_filter_bar.dart';
import 'package:flutter_photo_library_example/presentation/widgets/thumbnail_widget.dart';
import 'media_detail_view.dart';
import 'package:provider/provider.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Consumer<GalleryProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [
                // Top App Bar with title and refresh button
                _buildAppBar(context, provider),
                // Type filters and Folder selection dropdown
                if (provider.hasPermission)
                  GalleryFilterBar(provider: provider),
                // The main content area (loading, error, empty, or the grid itself)
                Expanded(child: _buildBody(context, provider)),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds the custom app bar with the title and refresh button.
  Widget _buildAppBar(BuildContext context, GalleryProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161626).withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Media Gallery',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                provider.hasPermission
                    ? '${provider.mediaItems.length} items loaded'
                    : 'Permissions required',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (provider.hasPermission)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () => provider.refresh(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Returns the appropriate body widget based on the current state: of the provider.
  Widget _buildBody(BuildContext context, GalleryProvider provider) {
    if (provider.isCheckingPermission) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
        ),
      );
    }
    if (!provider.hasPermission) {
      return _buildPermissionScreen(context, provider);
    }
    if (provider.isInitialLoading) {
      return _buildLoadingGrid();
    }
    if (provider.errorMessage != null && provider.mediaItems.isEmpty) {
      return _buildErrorScreen(provider.errorMessage!);
    }
    if (provider.mediaItems.isEmpty) {
      return _buildEmptyScreen();
    }
    // Grid build
    return _buildGrid(context, provider);
  }

  /// Builds the permission request screen when storage access is not granted.
  Widget _buildPermissionScreen(
    BuildContext context,
    GalleryProvider provider,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                size: 64,
                color: Colors.deepPurpleAccent,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Access Required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'To show photos and videos from your device storage, the app needs permission access. The gallery is loaded efficiently using native caching APIs.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => provider.requestAndLoadMedia(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
                shadowColor: Colors.deepPurpleAccent.withValues(alpha: 0.4),
              ),
              child: const Text(
                'Grant Storage Access',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            if (provider.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds a loading grid with placeholder cells while media is being fetched.
  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 15,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white12),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the error screen when media loading fails, displaying the error message.
  Widget _buildErrorScreen(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the empty screen when no media items are found on the device.
  Widget _buildEmptyScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_rounded,
            color: Colors.white.withValues(alpha: 0.2),
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            'No media found on device',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the grid view of media thumbnails, including loading placeholders for pagination.
  Widget _buildGrid(BuildContext context, GalleryProvider provider) {
    final int itemsCount =
        provider.mediaItems.length + (provider.hasMore ? 9 : 0);
    final double cellWidth = (MediaQuery.of(context).size.width - 44) / 3;

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: itemsCount,
      itemBuilder: (context, index) {
        if (index >= provider.mediaItems.length) {
          // Render skeleton/spinner loading cell
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white24),
                ),
              ),
            ),
          );
        }
        final item = provider.mediaItems[index];
        return ThumbnailWidget(
          key: ValueKey(item.id),
          item: item,
          size: cellWidth,
          onTapBytes: (bytes) => _openDetailView(context, item, bytes),
          onTap: () {},
        );
      },
    );
  }

  /// Opens the MediaDetailView for the selected media item with a fade transition.
  void _openDetailView(BuildContext context, MediaItem item, Uint8List? bytes) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return MediaDetailView(item: item, initialPreviewBytes: bytes);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  /// Listener for scroll events to trigger loading more media when nearing the bottom.
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      context.read<GalleryProvider>().loadMoreMedia();
    }
  }

  /// Cleans up the scroll controller when the widget is disposed to prevent memory leaks.
  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
}
