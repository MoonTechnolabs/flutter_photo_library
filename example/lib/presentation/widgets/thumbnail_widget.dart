import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_photo_library/flutter_photo_library.dart';

class ThumbnailWidget extends StatefulWidget {
  final MediaItem item;
  final double size;
  final VoidCallback onTap;
  final void Function(Uint8List? bytes)? onTapBytes;

  const ThumbnailWidget({
    super.key,
    required this.item,
    required this.size,
    required this.onTap,
    this.onTapBytes,
  });

  @override
  State<ThumbnailWidget> createState() => _ThumbnailWidgetState();
}

class _ThumbnailWidgetState extends State<ThumbnailWidget> {
  final FlutterPhotoLibraryRepository _repository =
      FlutterPhotoLibraryRepository();
  Uint8List? _thumbnailBytes;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_thumbnailBytes == null && _isLoading) {
      _loadThumbnail();
    }
  }

  @override
  void didUpdateWidget(covariant ThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id || oldWidget.size != widget.size) {
      setState(() {
        _thumbnailBytes = null;
        _isLoading = true;
        _hasError = false;
      });
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    // We request a thumbnail scaled to physical pixels to keep it crisp and high-quality,
    // but not excessively large to avoid unnecessary memory consumption (target ~200-300px physical).
    final int pixelSize = (widget.size * devicePixelRatio)
        .clamp(100.0, 400.0)
        .round();

    try {
      final bytes = await _repository.getThumbnail(
        id: widget.item.id,
        type: widget.item.type,
        width: pixelSize,
        height: pixelSize,
      );

      if (mounted) {
        setState(() {
          _thumbnailBytes = bytes;
          _isLoading = false;
          _hasError = bytes == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onTap();
        widget.onTapBytes?.call(_thumbnailBytes);
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail Content (bytes or spinner or error placeholder)
            _buildContent(),

            // Video Duration & Icon Overlay
            if (widget.item.type == MediaFetchType.video)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.75),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.deepPurpleAccent.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                      Text(
                        widget.item.formattedDuration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Selection / hover splash overlay for interactions
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    widget.onTap();
                    widget.onTapBytes?.call(_thumbnailBytes);
                  },
                  splashColor: Colors.deepPurpleAccent.withValues(alpha: 0.2),
                  highlightColor: Colors.deepPurpleAccent.withValues(
                    alpha: 0.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Container(
        color: const Color(0xFF1E1E2E),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.deepPurpleAccent,
              ),
            ),
          ),
        ),
      );
    }

    if (_hasError || _thumbnailBytes == null) {
      return Container(
        color: const Color(0xFF1B1B2A),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.item.type == MediaFetchType.video
                  ? Icons.video_library_rounded
                  : Icons.image_not_supported_rounded,
              color: Colors.white.withValues(alpha: 0.25),
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              'No Thumbnail',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Image.memory(
      _thumbnailBytes!,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: child,
        );
      },
    );
  }
}
