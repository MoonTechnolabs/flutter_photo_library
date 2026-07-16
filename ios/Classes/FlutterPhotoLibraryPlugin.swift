import Flutter
import UIKit
import Photos
import AVFoundation

public class FlutterPhotoLibraryPlugin: NSObject, FlutterPlugin {
  private let imageManager = PHCachingImageManager()
  private var fetchResult: PHFetchResult<PHAsset>?
  private var currentMediaTypeFilter: String = "all"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.example.flutter_photo_library/gallery", binaryMessenger: registrar.messenger())
    let instance = FlutterPhotoLibraryPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "checkPermissions":
      result(checkPermissions())
    case "requestPermissions":
      requestPermissions(result: result)
    case "getMediaPage":
      guard let args = call.arguments as? [String: Any],
            let page = args["page"] as? Int,
            let pageSize = args["pageSize"] as? Int else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments missing", details: nil))
        return
      }
      let mediaType = args["mediaType"] as? String ?? "all"
      let albumId = args["albumId"] as? String
      getMediaPage(page: page, pageSize: pageSize, mediaType: mediaType, albumId: albumId, result: result)
    case "getAlbums":
      let args = call.arguments as? [String: Any]
      let mediaType = args?["mediaType"] as? String ?? "all"
      getAlbums(mediaType: mediaType, result: result)
    case "getThumbnail":
      guard let args = call.arguments as? [String: Any],
            let id = args["id"] as? String,
            let width = args["width"] as? Int,
            let height = args["height"] as? Int else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments missing", details: nil))
        return
      }
      getThumbnail(id: id, width: width, height: height, result: result)
    case "startCaching":
      guard let args = call.arguments as? [String: Any],
            let ids = args["ids"] as? [String],
            let width = args["width"] as? Int,
            let height = args["height"] as? Int else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments missing", details: nil))
        return
      }
      startCaching(ids: ids, width: width, height: height)
      result(nil)
    case "stopCaching":
      guard let args = call.arguments as? [String: Any],
            let ids = args["ids"] as? [String],
            let width = args["width"] as? Int,
            let height = args["height"] as? Int else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments missing", details: nil))
        return
      }
      stopCaching(ids: ids, width: width, height: height)
      result(nil)
    case "getOriginalFile":
      guard let args = call.arguments as? [String: Any],
            let id = args["id"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "id is missing", details: nil))
        return
      }
      getOriginalFile(id: id, result: result)
    case "getMediaUrl":
      guard let args = call.arguments as? [String: Any],
            let id = args["id"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "id is missing", details: nil))
        return
      }
      getMediaUrl(id: id, result: result)
    case "getVideoUrl":
      guard let args = call.arguments as? [String: Any],
            let id = args["id"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "id is missing", details: nil))
        return
      }
      getVideoUrl(id: id, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func checkPermissions() -> Bool {
    let status: PHAuthorizationStatus
    if #available(iOS 14, *) {
      status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    } else {
      status = PHPhotoLibrary.authorizationStatus()
    }
      if #available(iOS 14, *) {
          return status == .authorized || status == .limited
      } else {
          // Fallback on earlier versions
          return true
      }
  }

  private func requestPermissions(result: @escaping FlutterResult) {
    if #available(iOS 14, *) {
      PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
        DispatchQueue.main.async {
          if status == .authorized || status == .limited {
            result("granted")
          } else if status == .denied || status == .restricted {
            result("permanently_denied")
          } else {
            result("denied")
          }
        }
      }
    } else {
      PHPhotoLibrary.requestAuthorization { status in
        DispatchQueue.main.async {
          if status == .authorized {
            result("granted")
          } else if status == .denied || status == .restricted {
            result("permanently_denied")
          } else {
            result("denied")
          }
        }
      }
    }
  }

  private var currentAlbumIdFilter: String? = nil

  private func getMediaPage(page: Int, pageSize: Int, mediaType: String, albumId: String?, result: @escaping FlutterResult) {
    if self.fetchResult == nil || self.currentMediaTypeFilter != mediaType || self.currentAlbumIdFilter != albumId {
      let options = PHFetchOptions()
      options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

      if mediaType == "image" {
          options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
      } else if mediaType == "video" {
          options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
      } else {
          options.predicate = NSPredicate(format: "mediaType == %d || mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
      }

      if let albumId = albumId, !albumId.isEmpty {
          let collectionFetch = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumId], options: nil)
          if let collection = collectionFetch.firstObject {
              self.fetchResult = PHAsset.fetchAssets(in: collection, options: options)
          } else {
              self.fetchResult = PHAsset.fetchAssets(with: options)
          }
      } else {
          self.fetchResult = PHAsset.fetchAssets(with: options)
      }

      self.currentMediaTypeFilter = mediaType
      self.currentAlbumIdFilter = albumId
    }
    guard let fetchResult = self.fetchResult else {
      result([])
      return
    }
    let offset = page * pageSize
    let totalCount = fetchResult.count
    if offset >= totalCount {
      result([])
      return
    }
    let end = min(offset + pageSize, totalCount)
    var mediaList: [[String: Any]] = []

    for i in offset..<end {
      let asset = fetchResult.object(at: i)
      var mediaMap: [String: Any] = [:]
      mediaMap["id"] = asset.localIdentifier
      mediaMap["uri"] = asset.localIdentifier
      mediaMap["type"] = asset.mediaType == .video ? "video" : "image"
      mediaMap["duration"] = Int(asset.duration * 1000) // milliseconds
      mediaMap["width"] = asset.pixelWidth
      mediaMap["height"] = asset.pixelHeight
      mediaMap["dateAdded"] = Int(asset.creationDate?.timeIntervalSince1970 ?? 0)

      mediaList.append(mediaMap)
    }

    result(mediaList)
  }

  private func getThumbnail(id: String, width: Int, height: Int, result: @escaping FlutterResult) {
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
    guard let asset = fetchResult.firstObject else {
      result(nil)
      return
    }
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = true
    options.isSynchronous = false
    options.deliveryMode = .highQualityFormat
    imageManager.requestImage(for: asset, targetSize: CGSize(width: width, height: height), contentMode: .aspectFill, options: options) {
      image, info in
      if let image = image {
        if let data = image.jpegData(compressionQuality: 0.8) {
          result(FlutterStandardTypedData(bytes: data))
        } else {
          result(nil)
        }
      } else {
        result(nil)
      }
    }
  }

  private func startCaching(ids: [String], width: Int, height: Int) {
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
    var assets: [PHAsset] = []
    fetchResult.enumerateObjects { asset, _, _ in
      assets.append(asset)
    }
    imageManager.startCachingImages(for: assets, targetSize: CGSize(width: width, height: height), contentMode: .aspectFill, options: nil)
  }

  private func stopCaching(ids: [String], width: Int, height: Int) {
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
    var assets: [PHAsset] = []
    fetchResult.enumerateObjects { asset, _, _ in
      assets.append(asset)
    }
    imageManager.stopCachingImages(for: assets, targetSize: CGSize(width: width, height: height), contentMode: .aspectFill, options: nil)
  }

  private func getOriginalFile(id: String, result: @escaping FlutterResult) {
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
    guard let asset = fetchResult.firstObject else {
      result(nil)
      return
    }
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = true
    options.isSynchronous = false
    options.version = .current

    if #available(iOS 13, *) {
      imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
        if let data = data {
          result(FlutterStandardTypedData(bytes: data))
        } else {
          result(nil)
        }
      }
    } else {
      imageManager.requestImageData(for: asset, options: options) { data, _, _, _ in
        if let data = data {
          result(FlutterStandardTypedData(bytes: data))
        } else {
          result(nil)
        }
      }
    }
  }

  private func getMediaUrl(id: String, result: @escaping FlutterResult) {
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
    guard let asset = fetchResult.firstObject else {
      result(nil)
      return
    }

    if asset.mediaType == .video {
      resolvePlayableVideoURL(for: asset, result: result)
    } else {
      let options = PHContentEditingInputRequestOptions()
      options.isNetworkAccessAllowed = true
      asset.requestContentEditingInput(with: options) { input, _ in
        DispatchQueue.main.async {
          if let url = input?.fullSizeImageURL {
            result(url.absoluteString)
          } else {
            result(nil)
          }
        }
      }
    }
  }

  private func getVideoUrl(id: String, result: @escaping FlutterResult) {
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
    guard let asset = fetchResult.firstObject else {
      result(nil)
      return
    }
    resolvePlayableVideoURL(for: asset, result: result)
  }

  /// Returns a sandbox `file://` URL that any Flutter video player can open.
  ///
  /// Photos DCIM paths are not readable by third-party players (OSStatus -12203).
  /// Same approach as photo_manager: fast `copyItem` into app temp + cache.
  /// No re-encode for normal videos; only compositions (e.g. Slow-Mo) export.
  private func resolvePlayableVideoURL(for asset: PHAsset, result: @escaping FlutterResult) {
    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = true
    options.deliveryMode = .automatic
    options.version = .current

    DispatchQueue.main.async {
      self.imageManager.requestAVAsset(forVideo: asset, options: options) { [weak self] avAsset, _, info in
        guard let self = self else { return }

        if let error = info?[PHImageErrorKey] as? Error {
          DispatchQueue.main.async {
            result(FlutterError(
              code: "VIDEO_LOAD_FAILED",
              message: error.localizedDescription,
              details: nil
            ))
          }
          return
        }

        if let urlAsset = avAsset as? AVURLAsset {
          self.copyVideoToCache(from: urlAsset.url, asset: asset, result: result)
        } else if avAsset != nil {
          self.exportVideoToCache(asset: asset, result: result)
        } else {
          DispatchQueue.main.async { result(nil) }
        }
      }
    }
  }

  private func videoCacheDirectory() -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("flutter_photo_library_videos", isDirectory: true)
    if !FileManager.default.fileExists(atPath: dir.path) {
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    return dir
  }

  private func cachedVideoURL(for asset: PHAsset, pathExtension: String) -> URL {
    let safeId = asset.localIdentifier
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: ":", with: "_")
    return videoCacheDirectory()
      .appendingPathComponent(safeId)
      .appendingPathExtension(pathExtension)
  }

  private func copyVideoToCache(from sourceURL: URL, asset: PHAsset, result: @escaping FlutterResult) {
    let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
    let destURL = cachedVideoURL(for: asset, pathExtension: ext)

    if FileManager.default.fileExists(atPath: destURL.path) {
      DispatchQueue.main.async { result(destURL.absoluteString) }
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try FileManager.default.copyItem(at: sourceURL, to: destURL)
        DispatchQueue.main.async { result(destURL.absoluteString) }
      } catch {
        self.exportVideoToCache(asset: asset, result: result)
      }
    }
  }

  private func exportVideoToCache(asset: PHAsset, result: @escaping FlutterResult) {
    let destURL = cachedVideoURL(for: asset, pathExtension: "mp4")
    if FileManager.default.fileExists(atPath: destURL.path) {
      DispatchQueue.main.async { result(destURL.absoluteString) }
      return
    }

    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = true
    options.deliveryMode = .automatic

    imageManager.requestExportSession(
      forVideo: asset,
      options: options,
      exportPreset: AVAssetExportPresetHighestQuality
    ) { session, _ in
      guard let session = session else {
        DispatchQueue.main.async { result(nil) }
        return
      }

      if FileManager.default.fileExists(atPath: destURL.path) {
        try? FileManager.default.removeItem(at: destURL)
      }

      session.outputURL = destURL
      if session.supportedFileTypes.contains(.mp4) {
        session.outputFileType = .mp4
      } else if let first = session.supportedFileTypes.first {
        session.outputFileType = first
      } else {
        DispatchQueue.main.async { result(nil) }
        return
      }

      session.exportAsynchronously {
        DispatchQueue.main.async {
          if session.status == .completed {
            result(destURL.absoluteString)
          } else {
            result(FlutterError(
              code: "VIDEO_EXPORT_FAILED",
              message: session.error?.localizedDescription ?? "Failed to export video",
              details: nil
            ))
          }
        }
      }
    }
  }

  private func getAlbums(mediaType: String, result: @escaping FlutterResult) {
    var albumsList: [[String: Any]] = []
    let options = PHFetchOptions()
    if mediaType == "image" {
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
    } else if mediaType == "video" {
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
    } else {
        options.predicate = NSPredicate(format: "mediaType == %d || mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
    }
    let types: [PHAssetCollectionType] = [.smartAlbum, .album]
    for type in types {
        let collections = PHAssetCollection.fetchAssetCollections(with: type, subtype: .any, options: nil)
        collections.enumerateObjects { (collection, _, _) in
            // Filter out empty and unwanted albums
            let assetsFetch = PHAsset.fetchAssets(in: collection, options: options)
            let count = assetsFetch.count
            if count > 0 {
                let name = collection.localizedTitle ?? "Unknown"
                let albumMap: [String: Any] = [
                    "id": collection.localIdentifier,
                    "name": name,
                    "count": count
                ]
                albumsList.append(albumMap)
            }
        }
    }

    // Sort by count descending
    albumsList.sort {
        let count1 = $0["count"] as? Int ?? 0
        let count2 = $1["count"] as? Int ?? 0
        return count1 > count2
    }

    result(albumsList)
  }
}
