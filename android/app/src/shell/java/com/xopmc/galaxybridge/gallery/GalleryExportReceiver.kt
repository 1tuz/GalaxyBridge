package com.xopmc.galaxybridge.gallery

import android.content.BroadcastReceiver
import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Bundle
import android.provider.BaseColumns
import android.provider.MediaStore
import android.util.Size
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class GalleryExportReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        Thread({
            try {
                when (intent.action) {
                    ACTION_PAGE -> exportPage(context, intent)
                    ACTION_MEDIA -> exportMedia(context, intent)
                }
            } finally {
                pending.finish()
            }
        }, "GB-gallery-export").start()
    }

    private fun exportPage(context: Context, intent: Intent) {
        val requestID = requestID(intent) ?: return
        val offset = intent.getIntExtra(EXTRA_OFFSET, 0).coerceAtLeast(0)
        val limit = intent.getIntExtra(EXTRA_LIMIT, DEFAULT_LIMIT).coerceIn(1, MAX_LIMIT)
        val root = outputRoot(context, PAGE_DIRECTORY, requestID) ?: return
        if (!GalleryPermissions.hasFullAccess(context)) {
            writeJSON(root, JSONObject()
                .put("version", 1)
                .put("permission", "required")
                .put("offset", offset)
                .put("has_more", false)
                .put("items", JSONArray()))
            return
        }

        val resolver = context.contentResolver
        val filesUri = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)
        val projection = arrayOf(
            BaseColumns._ID,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.MIME_TYPE,
            MediaStore.MediaColumns.DATE_ADDED,
            MediaStore.MediaColumns.WIDTH,
            MediaStore.MediaColumns.HEIGHT,
            MediaStore.MediaColumns.SIZE,
            MediaStore.Files.FileColumns.MEDIA_TYPE,
        )
        val queryArgs = Bundle().apply {
            putString(
                ContentResolver.QUERY_ARG_SQL_SELECTION,
                "${MediaStore.Files.FileColumns.MEDIA_TYPE} IN (?,?)",
            )
            putStringArray(
                ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS,
                arrayOf(
                    MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString(),
                    MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO.toString(),
                ),
            )
            putStringArray(
                ContentResolver.QUERY_ARG_SORT_COLUMNS,
                arrayOf(MediaStore.MediaColumns.DATE_ADDED),
            )
            putInt(ContentResolver.QUERY_ARG_SORT_DIRECTION, ContentResolver.QUERY_SORT_DIRECTION_DESCENDING)
            putInt(ContentResolver.QUERY_ARG_OFFSET, offset)
            putInt(ContentResolver.QUERY_ARG_LIMIT, limit + 1)
        }
        val rows = mutableListOf<JSONObject>()
        resolver.query(filesUri, projection, queryArgs, null)?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(BaseColumns._ID)
            val nameIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
            val mimeIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.MIME_TYPE)
            val dateIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_ADDED)
            val widthIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.WIDTH)
            val heightIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.HEIGHT)
            val sizeIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
            val typeIndex = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)
            while (cursor.moveToNext() && rows.size < limit + 1) {
                val id = cursor.getLong(idIndex)
                val mediaType = cursor.getInt(typeIndex)
                val mediaUri = mediaUri(mediaType, id) ?: continue
                val thumbnailName = "thumb-$id.jpg"
                val thumbnail = runCatching {
                    resolver.loadThumbnail(mediaUri, Size(360, 360), null)
                }.getOrNull()
                val thumbnailWritten = thumbnail?.let { bitmap ->
                    File(root, thumbnailName).outputStream().use {
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 84, it)
                    }
                } == true
                rows += JSONObject()
                    .put("id", id)
                    .put("name", cursor.getString(nameIndex) ?: "media-$id")
                    .put("mime", cursor.getString(mimeIndex) ?: "application/octet-stream")
                    .put("date_added", cursor.getLong(dateIndex))
                    .put("width", cursor.getInt(widthIndex).coerceAtLeast(0))
                    .put("height", cursor.getInt(heightIndex).coerceAtLeast(0))
                    .put("size", cursor.getLong(sizeIndex).coerceAtLeast(0))
                    .put("kind", if (mediaType == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO) "video" else "image")
                    .put("thumbnail", if (thumbnailWritten) thumbnailName else JSONObject.NULL)
            }
        }
        val hasMore = rows.size > limit
        val visibleRows = if (hasMore) rows.take(limit) else rows
        val items = JSONArray().also { array -> visibleRows.forEach { array.put(it) } }
        writeJSON(root, JSONObject()
            .put("version", 1)
            .put("permission", "granted")
            .put("offset", offset)
            .put("has_more", hasMore)
            .put("items", items))
    }

    private fun exportMedia(context: Context, intent: Intent) {
        val requestID = requestID(intent) ?: return
        val mediaID = intent.getLongExtra(EXTRA_MEDIA_ID, -1)
        if (mediaID <= 0) return
        val root = outputRoot(context, MEDIA_DIRECTORY, requestID) ?: return
        if (!GalleryPermissions.hasFullAccess(context)) {
            writeJSON(root, JSONObject().put("version", 1).put("permission", "required"))
            return
        }
        val resolver = context.contentResolver
        val filesUri = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)
        val projection = arrayOf(
            BaseColumns._ID,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.MIME_TYPE,
            MediaStore.MediaColumns.SIZE,
            MediaStore.Files.FileColumns.MEDIA_TYPE,
        )
        resolver.query(
            filesUri,
            projection,
            "${BaseColumns._ID}=? AND ${MediaStore.Files.FileColumns.MEDIA_TYPE} IN (?,?)",
            arrayOf(
                mediaID.toString(),
                MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString(),
                MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO.toString(),
            ),
            null,
        )?.use { cursor ->
            if (!cursor.moveToFirst()) {
                writeJSON(root, JSONObject().put("version", 1).put("error", "not_found"))
                return
            }
            val mediaType = cursor.getInt(cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE))
            val size = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)).coerceAtLeast(0)
            if (size > MAX_EXPORT_BYTES) {
                writeJSON(root, JSONObject().put("version", 1).put("error", "too_large"))
                return
            }
            val source = mediaUri(mediaType, mediaID) ?: return
            val name = safeName(
                cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)) ?: "media-$mediaID",
                mediaID,
            )
            val destination = File(root, name)
            resolver.openInputStream(source)?.use { input ->
                destination.outputStream().buffered().use { output -> input.copyTo(output, 256 * 1024) }
            } ?: run {
                writeJSON(root, JSONObject().put("version", 1).put("error", "unavailable"))
                return
            }
            writeJSON(root, JSONObject()
                .put("version", 1)
                .put("permission", "granted")
                .put("file", name)
                .put("mime", cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.MIME_TYPE))
                    ?: "application/octet-stream"))
        }
    }

    private fun mediaUri(mediaType: Int, id: Long) = when (mediaType) {
        MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE ->
            ContentUris.withAppendedId(MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL), id)
        MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO ->
            ContentUris.withAppendedId(MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL), id)
        else -> null
    }

    private fun outputRoot(context: Context, namespace: String, requestID: String): File? {
        val external = context.getExternalFilesDir(null) ?: return null
        val parent = File(external, namespace)
        val root = File(parent, requestID)
        if (root.exists()) root.deleteRecursively()
        if (!root.mkdirs() && !root.isDirectory) return null
        parent.listFiles()?.filter { it.isDirectory && it.name != requestID }
            ?.sortedByDescending(File::lastModified)
            ?.drop(4)
            ?.forEach(File::deleteRecursively)
        return root
    }

    private fun requestID(intent: Intent): String? {
        val value = intent.getStringExtra(EXTRA_REQUEST_ID) ?: return null
        return value.takeIf { it.length == 32 && it.all { c -> c in '0'..'9' || c in 'a'..'f' } }
    }

    private fun safeName(value: String, mediaID: Long): String {
        val cleaned = value.filterNot { it == '/' || it == '\\' || it.code < 32 }.take(180).trim()
        return if (cleaned.isBlank()) "media-$mediaID" else cleaned
    }

    private fun writeJSON(root: File, value: JSONObject) {
        File(root, MANIFEST).writeText(value.toString(), Charsets.UTF_8)
    }

    companion object {
        const val ACTION_PAGE = "com.xopmc.galaxybridge.EXPORT_GALLERY_PAGE"
        const val ACTION_MEDIA = "com.xopmc.galaxybridge.EXPORT_GALLERY_MEDIA"
        const val EXTRA_REQUEST_ID = "request_id"
        const val EXTRA_OFFSET = "offset"
        const val EXTRA_LIMIT = "limit"
        const val EXTRA_MEDIA_ID = "media_id"
        const val PAGE_DIRECTORY = "gallery-catalog"
        const val MEDIA_DIRECTORY = "gallery-media"
        const val MANIFEST = "manifest.json"
        const val DEFAULT_LIMIT = 96
        const val MAX_LIMIT = 200
        const val MAX_EXPORT_BYTES = 10L * 1024L * 1024L * 1024L
    }
}
