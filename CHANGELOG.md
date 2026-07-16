## 0.0.1

* Initial release of the `flutter_photo_library` plugin.
* **Folder/Album Support**: Added APIs to fetch local albums/folders (`getAlbums`) and filter media by `albumId` in `fetchMediaPage`.
* **Performance Boost**: Included `originalMediaUri` in the `MediaItem` model during pagination. This removes the need to make additional native calls when launching full-screen media viewers or playing videos.
* **Example App Enhancements**: Refactored the included example app into separated files, demonstrating a high-performance grid gallery with folder-based dropdown filtering and a fully immersive `MediaDetailView`.
* Added APIs to fetch paginated lists of images and videos from local device storage on Android and iOS.
* Included native thumbnail generation with built-in LRU memory caching for optimal performance.
* Supported native iOS background pre-fetching methods to speed up grid scrolling.
* Added capabilities to extract raw image bytes or video URIs for high-resolution displays.
* Implemented comprehensive permission handling, returning granular statuses (`granted`, `denied`, `permanentlyDenied`).
* Added Android `<uses-permission>` tags directly into the package's manifest to streamline setup.
* Optimized package compatibility to support Dart SDK `>=2.12.0` and Flutter `>=2.0.0`.
