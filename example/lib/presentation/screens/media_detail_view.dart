import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_photo_library/flutter_photo_library.dart';
import 'package:flutter_photo_library_example/presentation/widgets/media_info_card.dart';
import 'package:video_player/video_player.dart';

/// Full-screen viewer for a selected [MediaItem].
///
/// Videos use a playable URL from [FlutterPhotoLibraryRepository.getOriginalFile]
/// with any player library (here: `video_player`).
class MediaDetailView extends StatefulWidget {
  final MediaItem item;
  final Uint8List? initialPreviewBytes;

  const MediaDetailView({
    super.key,
    required this.item,
    this.initialPreviewBytes,
  });

  @override
  State<MediaDetailView> createState() => _MediaDetailViewState();
}

class _MediaDetailViewState extends State<MediaDetailView> {
  final FlutterPhotoLibraryRepository _repository =
      FlutterPhotoLibraryRepository();
  Uint8List? _previewBytes;
  String? _videoUrl;
  Uint8List? _imageBytes;
  bool _isLoading = true;
  VideoPlayerController? _videoController;
  bool _isPlayingVideo = false;

  @override
  void initState() {
    super.initState();
    _previewBytes = widget.initialPreviewBytes;
    _loadPreview();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateString =
        '${widget.item.dateAdded.day}/${widget.item.dateAdded.month}/${widget.item.dateAdded.year}';
    final resolution = '${widget.item.width} x ${widget.item.height}';

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.92),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_previewBytes != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.35,
                child: Image.memory(
                  _previewBytes!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
              ),
            ),
          Center(child: _buildMediaContent()),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          MediaInfoCard(
            item: widget.item,
            resolution: resolution,
            dateString: dateString,
          ),
        ],
      ),
    );
  }

  Widget _buildMediaContent() {
    if (_isLoading && !_isPlayingVideo) {
      return const CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
      );
    }

    if (_isPlayingVideo && _videoController != null) {
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(_videoController!),
            VideoProgressIndicator(
              _videoController!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.deepPurpleAccent,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white10,
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (_videoController!.value.isPlaying) {
                      _videoController!.pause();
                    } else {
                      _videoController!.play();
                    }
                  });
                },
                child: _videoController!.value.isPlaying
                    ? const SizedBox.shrink()
                    : Container(
                        color: Colors.black26,
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.item.type == MediaFetchType.image && _imageBytes != null) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 3.5,
        child: Image.memory(
          _imageBytes!,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      );
    }

    if (_previewBytes != null) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 3.5,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.memory(
              _previewBytes!,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
            if (widget.item.type == MediaFetchType.video)
              GestureDetector(
                onTap: _playVideo,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.broken_image_rounded, color: Colors.white24, size: 64),
        const SizedBox(height: 12),
        Text(
          'Failed to load image preview',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  VideoPlayerController _controllerForUrl(String url) {
    if (url.startsWith('content://')) {
      return VideoPlayerController.contentUri(Uri.parse(url));
    }
    if (url.startsWith('file://')) {
      return VideoPlayerController.file(File(Uri.parse(url).toFilePath()));
    }
    if (url.startsWith('/')) {
      return VideoPlayerController.file(File(url));
    }
    return VideoPlayerController.networkUrl(Uri.parse(url));
  }

  Future<void> _playVideo() async {
    if (_videoUrl == null) return;

    setState(() => _isLoading = true);
    await _videoController?.dispose();
    _videoController = _controllerForUrl(_videoUrl!);

    try {
      await _videoController!.initialize();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isPlayingVideo = true;
      });
      _videoController!.play();
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPreview() async {
    if (_previewBytes == null) {
      try {
        final thumbBytes = await _repository.getThumbnail(
          id: widget.item.id,
          type: widget.item.type,
          width: 600,
          height: 600,
        );
        if (mounted) {
          setState(() {
            _previewBytes = thumbBytes;
            _isLoading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    } else if (mounted) {
      setState(() => _isLoading = false);
    }

    final mediaFile = await _repository.getOriginalFile(
      id: widget.item.id,
      type: widget.item.type,
    );

    if (!mounted || mediaFile == null) return;

    setState(() {
      if (widget.item.type == MediaFetchType.video &&
          mediaFile.videoUrl != null) {
        _videoUrl = mediaFile.videoUrl;
      } else if (mediaFile.bytes != null) {
        _imageBytes = mediaFile.bytes;
      }
      _isLoading = false;
    });
  }
}
