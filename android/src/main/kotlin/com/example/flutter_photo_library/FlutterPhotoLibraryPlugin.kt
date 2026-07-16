package com.example.flutter_photo_library

import android.Manifest
import android.app.Activity
import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.database.Cursor
import android.graphics.Bitmap
import android.net.Uri
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/** FlutterPhotoLibraryPlugin */
class FlutterPhotoLibraryPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var context: Context? = null
    private var pendingPermissionResult: Result? = null
    private val PERMISSION_REQUEST_CODE = 1001

    private val executor = Executors.newFixedThreadPool(4)
    private val mainHandler = Handler(Looper.getMainLooper())

    private val permissions: Array<String>
        get() = if (Build.VERSION.SDK_INT >= 34) { // Build.VERSION_CODES.UPSIDE_DOWN_CAKE
            arrayOf(
                Manifest.permission.READ_MEDIA_IMAGES,
                Manifest.permission.READ_MEDIA_VIDEO,
                "android.permission.READ_MEDIA_VISUAL_USER_SELECTED"
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(
                Manifest.permission.READ_MEDIA_IMAGES,
                Manifest.permission.READ_MEDIA_VIDEO
            )
        } else {
            arrayOf(
                Manifest.permission.READ_EXTERNAL_STORAGE
            )
        }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "com.example.flutter_photo_library/gallery"
        )
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "checkPermissions" -> {
                result.success(checkPermissions())
            }

            "requestPermissions" -> {
                requestPermissions(result)
            }

            "getMediaPage" -> {
                val page = call.argument<Int>("page") ?: 0
                val pageSize = call.argument<Int>("pageSize") ?: 50
                val mediaType = call.argument<String>("mediaType") ?: "all"
                val albumId = call.argument<String>("albumId")
                getMediaPage(page, pageSize, mediaType, albumId, result)
            }

            "getAlbums" -> {
                val mediaType = call.argument<String>("mediaType") ?: "all"
                getAlbums(mediaType, result)
            }

            "getThumbnail" -> {
                val id = call.argument<String>("id") ?: ""
                val type = call.argument<String>("type") ?: "image"
                val width = call.argument<Int>("width") ?: 200
                val height = call.argument<Int>("height") ?: 200
                getThumbnail(id, type, width, height, result)
            }

            "getOriginalFile" -> {
                val id = call.argument<String>("id") ?: ""
                val type = call.argument<String>("type") ?: "image"
                getOriginalFile(id, type, result)
            }

            "getVideoUrl" -> {
                val id = call.argument<String>("id") ?: ""
                val idLong = id.toLongOrNull() ?: 0L
                val contentUri =
                    ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, idLong)
                result.success(contentUri.toString())
            }

            "getMediaUrl" -> {
                val id = call.argument<String>("id") ?: ""
                val type = call.argument<String>("type") ?: "image"
                val idLong = id.toLongOrNull() ?: 0L
                val contentUri = if (type == "video") {
                    ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, idLong)
                } else {
                    ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, idLong)
                }
                result.success(contentUri.toString())
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun checkPermissions(): Boolean {
        val ctx = context ?: return false
        return permissions.any {
            ContextCompat.checkSelfPermission(ctx, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestPermissions(result: Result) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Plugin is not attached to an activity", null)
            return
        }
        if (checkPermissions()) {
            result.success("granted")
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(act, permissions, PERMISSION_REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults.any { it == PackageManager.PERMISSION_GRANTED }) {
                pendingPermissionResult?.success("granted")
            } else {
                val act = activity
                var permanentlyDenied = false
                if (act != null) {
                    permanentlyDenied = permissions.any { perm ->
                        !ActivityCompat.shouldShowRequestPermissionRationale(act, perm)
                    }
                }
                if (permanentlyDenied) {
                    pendingPermissionResult?.success("permanently_denied")
                } else {
                    pendingPermissionResult?.success("denied")
                }
            }
            pendingPermissionResult = null
            return true
        }
        return false
    }

    private fun getMediaPage(
        page: Int,
        pageSize: Int,
        mediaTypeFilter: String,
        albumId: String?,
        result: Result
    ) {
        val resolver = context?.contentResolver
        if (resolver == null) {
            result.error("NO_CONTEXT", "Context or ContentResolver is null", null)
            return
        }
        val offset = page * pageSize
        executor.execute {
            try {
                val mediaList = mutableListOf<Map<String, Any?>>()
                val collection = MediaStore.Files.getContentUri("external")

                val projectionList = mutableListOf(
                    MediaStore.Files.FileColumns._ID,
                    MediaStore.Files.FileColumns.MEDIA_TYPE,
                    MediaStore.Files.FileColumns.DATE_ADDED,
                    MediaStore.Files.FileColumns.WIDTH,
                    MediaStore.Files.FileColumns.HEIGHT,
                    MediaStore.Files.FileColumns.DATA
                )
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    projectionList.add(MediaStore.MediaColumns.DURATION)
                }
                val projection = projectionList.toTypedArray()

                var selection = ""
                var selectionArgs = arrayOf<String>()

                when (mediaTypeFilter) {
                    "image" -> {
                        selection = "${MediaStore.Files.FileColumns.MEDIA_TYPE} = ?"
                        selectionArgs =
                            arrayOf(MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString())
                    }

                    "video" -> {
                        selection = "${MediaStore.Files.FileColumns.MEDIA_TYPE} = ?"
                        selectionArgs =
                            arrayOf(MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO.toString())
                    }

                    else -> {
                        selection =
                            "${MediaStore.Files.FileColumns.MEDIA_TYPE} = ? OR ${MediaStore.Files.FileColumns.MEDIA_TYPE} = ?"
                        selectionArgs = arrayOf(
                            MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString(),
                            MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO.toString()
                        )
                    }
                }

                if (albumId != null) {
                    selection = "($selection) AND ${MediaStore.Files.FileColumns.BUCKET_ID} = ?"
                    selectionArgs = selectionArgs.plus(albumId)
                }

                val cursor = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val queryArgs = Bundle().apply {
                        putInt(ContentResolver.QUERY_ARG_LIMIT, pageSize)
                        putInt(ContentResolver.QUERY_ARG_OFFSET, offset)
                        putStringArray(
                            ContentResolver.QUERY_ARG_SORT_COLUMNS,
                            arrayOf(MediaStore.Files.FileColumns.DATE_ADDED)
                        )
                        putInt(
                            ContentResolver.QUERY_ARG_SORT_DIRECTION,
                            ContentResolver.QUERY_SORT_DIRECTION_DESCENDING
                        )
                        putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
                        putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, selectionArgs)
                    }
                    resolver.query(collection, projection, queryArgs, null)
                } else {
                    val sortOrder =
                        "${MediaStore.Files.FileColumns.DATE_ADDED} DESC LIMIT $pageSize OFFSET $offset"
                    resolver.query(collection, projection, selection, selectionArgs, sortOrder)
                }

                cursor?.use { c ->
                    val idColumn = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
                    val typeColumn =
                        c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)
                    val dateColumn =
                        c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_ADDED)
                    val widthColumn = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.WIDTH)
                    val heightColumn = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.HEIGHT)
                    val durationColumn = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        c.getColumnIndex(MediaStore.MediaColumns.DURATION)
                    } else {
                        -1
                    }

                    val dataPathColumn = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)

                    while (c.moveToNext()) {
                        val id = c.getLong(idColumn)
                        val mediaType = c.getInt(typeColumn)
                        val dateAdded = c.getLong(dateColumn)
                        val width = c.getInt(widthColumn)
                        val height = c.getInt(heightColumn)
                        val filePath = c.getString(dataPathColumn)

                        val duration = if (durationColumn != -1) c.getLong(durationColumn) else 0L

                        val type =
                            if (mediaType == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO) "video" else "image"
                        val contentUri = if (type == "video") {
                            ContentUris.withAppendedId(
                                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                                id
                            ).toString()
                        } else {
                            ContentUris.withAppendedId(
                                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                                id
                            ).toString()
                        }

                        val mediaMap = mapOf(
                            "id" to id.toString(),
                            "uri" to contentUri,
                            "type" to type,
                            "duration" to duration,
                            "width" to width,
                            "height" to height,
                            "dateAdded" to dateAdded,
                            "originalMediaUri" to filePath
                        )
                        mediaList.add(mediaMap)
                    }
                }

                mainHandler.post {
                    result.success(mediaList)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("QUERY_FAILED", e.message, null)
                }
            }
        }
    }

    private fun getThumbnail(id: String, type: String, width: Int, height: Int, result: Result) {
        val resolver = context?.contentResolver
        if (resolver == null) {
            result.success(null)
            return
        }
        executor.execute {
            try {
                val idLong = id.toLong()
                val contentUri = if (type == "video") {
                    ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, idLong)
                } else {
                    ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, idLong)
                }

                var bitmap: Bitmap? = null

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    try {
                        bitmap = resolver.loadThumbnail(contentUri, Size(width, height), null)
                    } catch (e: Exception) {
                        try {
                            bitmap = loadThumbnailLegacy(resolver, idLong, type)
                        } catch (e2: Exception) {
                        }
                    }
                } else {
                    try {
                        bitmap = loadThumbnailLegacy(resolver, idLong, type)
                    } catch (e: Exception) {
                    }
                }

                // Robust production-ready fallback for videos if MediaStore is unable to generate/find a thumbnail
                if (bitmap == null && type == "video" && context != null) {
                    bitmap = loadVideoThumbnailFallback(context!!, contentUri)
                }

                if (bitmap != null) {
                    val stream = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 80, stream)
                    val byteArray = stream.toByteArray()
                    bitmap.recycle()
                    mainHandler.post {
                        result.success(byteArray)
                    }
                } else {
                    mainHandler.post {
                        result.success(null)
                    }
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.success(null)
                }
            }
        }
    }

    private fun loadThumbnailLegacy(resolver: ContentResolver, id: Long, type: String): Bitmap? {
        return try {
            if (type == "video") {
                MediaStore.Video.Thumbnails.getThumbnail(
                    resolver,
                    id,
                    MediaStore.Video.Thumbnails.MINI_KIND,
                    null
                )
            } else {
                MediaStore.Images.Thumbnails.getThumbnail(
                    resolver,
                    id,
                    MediaStore.Images.Thumbnails.MINI_KIND,
                    null
                )
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun loadVideoThumbnailFallback(ctx: Context, uri: Uri): Bitmap? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(ctx, uri)
            // Extract the first representative frame
            val frame = retriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            frame
        } catch (e: Exception) {
            null
        } finally {
            try {
                retriever.release()
            } catch (e: Exception) {
            }
        }
    }

    private fun getOriginalFile(id: String, type: String, result: Result) {
        val resolver = context?.contentResolver
        if (resolver == null) {
            result.success(null)
            return
        }
        executor.execute {
            try {
                val idLong = id.toLong()
                val contentUri = if (type == "video") {
                    ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, idLong)
                } else {
                    ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, idLong)
                }

                val inputStream = resolver.openInputStream(contentUri)
                if (inputStream != null) {
                    val bytes = inputStream.readBytes()
                    inputStream.close()
                    mainHandler.post {
                        result.success(bytes)
                    }
                } else {
                    mainHandler.post {
                        result.success(null)
                    }
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.success(null)
                }
            }
        }
    }

    private fun getAlbums(mediaTypeFilter: String, result: Result) {
        val resolver = context?.contentResolver
        if (resolver == null) {
            result.error("NO_CONTEXT", "Context or ContentResolver is null", null)
            return
        }
        executor.execute {
            try {
                val collection = MediaStore.Files.getContentUri("external")
                var selection = ""
                var selectionArgs = arrayOf<String>()

                when (mediaTypeFilter) {
                    "image" -> {
                        selection = "${MediaStore.Files.FileColumns.MEDIA_TYPE} = ?"
                        selectionArgs =
                            arrayOf(MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString())
                    }

                    "video" -> {
                        selection = "${MediaStore.Files.FileColumns.MEDIA_TYPE} = ?"
                        selectionArgs =
                            arrayOf(MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO.toString())
                    }

                    else -> {
                        selection =
                            "${MediaStore.Files.FileColumns.MEDIA_TYPE} = ? OR ${MediaStore.Files.FileColumns.MEDIA_TYPE} = ?"
                        selectionArgs = arrayOf(
                            MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString(),
                            MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO.toString()
                        )
                    }
                }

                val albumsList = mutableListOf<Map<String, Any>>()
                val projection = arrayOf(
                    MediaStore.Files.FileColumns.BUCKET_ID,
                    MediaStore.Files.FileColumns.BUCKET_DISPLAY_NAME
                )

                val distinctAlbums = mutableListOf<Pair<String, String>>()

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val queryArgs = Bundle().apply {
                        putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
                        putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, selectionArgs)
                        putString(
                            "android:query-arg-sql-group-by",
                            MediaStore.Files.FileColumns.BUCKET_ID
                        )
                    }

                    resolver.query(collection, projection, queryArgs, null)?.use { cursor ->
                        val idColumn = cursor.getColumnIndex(MediaStore.Files.FileColumns.BUCKET_ID)
                        val nameColumn =
                            cursor.getColumnIndex(MediaStore.Files.FileColumns.BUCKET_DISPLAY_NAME)

                        while (cursor.moveToNext()) {
                            val bucketId =
                                if (idColumn >= 0) cursor.getString(idColumn) else cursor.getString(0)
                            if (bucketId == null) continue
                            val bucketName =
                                if (nameColumn >= 0) cursor.getString(nameColumn) else cursor.getString(1)

                            distinctAlbums.add(Pair(bucketId, bucketName ?: "Unknown"))
                        }
                    }
                } else {
                    val hackSelection =
                        "($selection) GROUP BY (${MediaStore.Files.FileColumns.BUCKET_ID})"
                    resolver.query(collection, projection, hackSelection, selectionArgs, null)
                        ?.use { cursor ->
                            val idColumn =
                                cursor.getColumnIndex(MediaStore.Files.FileColumns.BUCKET_ID)
                            val nameColumn =
                                cursor.getColumnIndex(MediaStore.Files.FileColumns.BUCKET_DISPLAY_NAME)

                            while (cursor.moveToNext()) {
                                val bucketId =
                                    if (idColumn >= 0) cursor.getString(idColumn) else cursor.getString(0)
                                if (bucketId == null) continue
                                val bucketName =
                                    if (nameColumn >= 0) cursor.getString(nameColumn) else cursor.getString(1)

                                distinctAlbums.add(Pair(bucketId, bucketName ?: "Unknown"))
                            }
                        }
                }

                // Query the exact count for each distinct album securely using cursor.count
                val countProjection = arrayOf(MediaStore.Files.FileColumns._ID)
                for (album in distinctAlbums) {
                    val bucketId = album.first
                    val bucketName = album.second

                    val albumSelection = "($selection) AND ${MediaStore.Files.FileColumns.BUCKET_ID} = ?"
                    val albumSelectionArgs = selectionArgs.plus(bucketId)

                    val count = resolver.query(
                        collection,
                        countProjection,
                        albumSelection,
                        albumSelectionArgs,
                        null
                    )?.use { it.count } ?: 0

                    if (count > 0) {
                        albumsList.add(
                            mapOf(
                                "id" to bucketId,
                                "name" to bucketName,
                                "count" to count
                            )
                        )
                    }
                }
                val sortedList = albumsList.sortedByDescending { it["count"] as Int }
                mainHandler.post {
                    result.success(sortedList)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("QUERY_ERROR", e.message, null)
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        this.activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        this.activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        this.activity = null
    }
}
