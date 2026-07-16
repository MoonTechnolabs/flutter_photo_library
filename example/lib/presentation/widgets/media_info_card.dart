import 'package:flutter/material.dart';
import 'package:flutter_photo_library/flutter_photo_library.dart';

/// An overlay card displaying metadata (resolution, date added, ID)
/// about the current [MediaItem].
class MediaInfoCard extends StatelessWidget {
  final MediaItem item;
  final String resolution;
  final String dateString;

  const MediaInfoCard({
    super.key,
    required this.item,
    required this.resolution,
    required this.dateString,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF161626),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumbnailDetail(),
            const SizedBox(height: 12),
            _buildMetaItem('Item ID', item.id),
            const SizedBox(height: 6),
            _buildMetaItem('Resolution', resolution),
            const SizedBox(height: 6),
            _buildMetaItem('Date Added', dateString),
          ],
        ),
      ),
    );
  }

  /// Builds the badge showing media type (IMAGE/VIDEO) and duration.
  Widget _buildThumbnailDetail() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: item.type == MediaFetchType.video
                ? Colors.redAccent.withValues(alpha: 0.15)
                : Colors.greenAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            item.type == MediaFetchType.video ? 'VIDEO' : 'IMAGE',
            style: TextStyle(
              color: item.type == MediaFetchType.video
                  ? Colors.redAccent
                  : Colors.greenAccent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
        if (item.type == MediaFetchType.video)
          Row(
            children: [
              const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                item.formattedDuration,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Helper method to build a row representing a metadata key-value pair.
  Widget _buildMetaItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 12,
          ),
        ),
        SizedBox(width: 20.0,),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
