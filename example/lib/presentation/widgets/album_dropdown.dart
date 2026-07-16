import 'package:flutter/material.dart';
import 'package:flutter_photo_library/flutter_photo_library.dart';
import 'package:flutter_photo_library_example/presentation/providers/gallery_provider.dart';

/// A stylish dropdown for selecting a specific media album (folder).
class AlbumDropdown extends StatelessWidget {
  final GalleryProvider provider;

  const AlbumDropdown({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<MediaAlbum?>(
          isExpanded: true,
          value: provider.selectedAlbum,
          dropdownColor: const Color(0xFF1C1C2D),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white60,
          ),
          hint: const Text(
            'All Folders',
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
          items: [
            const DropdownMenuItem<MediaAlbum?>(
              value: null,
              child: Text(
                'All Folders',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            ...provider.albums.map((album) {
              return DropdownMenuItem<MediaAlbum?>(
                value: album,
                child: Text(
                  '${album.name} (${album.count})',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              );
            }),
          ],
          onChanged: (MediaAlbum? newValue) {
            provider.setAlbum(newValue);
          },
        ),
      ),
    );
  }
}
