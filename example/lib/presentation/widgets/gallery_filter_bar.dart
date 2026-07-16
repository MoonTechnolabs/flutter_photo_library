import 'package:flutter/material.dart';
import 'package:flutter_photo_library/flutter_photo_library.dart';
import 'package:flutter_photo_library_example/presentation/providers/gallery_provider.dart';
import 'album_dropdown.dart';

/// A filter bar for selecting media types and albums.
class GalleryFilterBar extends StatelessWidget {
  final GalleryProvider provider;

  const GalleryFilterBar({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161626).withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFilterChip('All', MediaFetchType.all),
              _buildFilterChip('Images', MediaFetchType.image),
              _buildFilterChip('Videos', MediaFetchType.video),
            ],
          ),
          if (provider.albums.isNotEmpty) ...[
            const SizedBox(height: 16),
            AlbumDropdown(provider: provider),
          ],
        ],
      ),
    );
  }

  /// Builds a selectable chip for filtering media by type.
  Widget _buildFilterChip(String label, MediaFetchType type) {
    final isSelected = provider.currentFilter == type;
    return GestureDetector(
      onTap: () => provider.setFilter(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepPurpleAccent
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.deepPurpleAccent.shade100
                : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.deepPurpleAccent.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
