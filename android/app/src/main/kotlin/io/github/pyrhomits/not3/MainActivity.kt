package io.github.pyrhomits.not3

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/// Receives PDFs and Not3 archives from file managers or sharing. Incoming
/// content is copied to app cache because provider URI grants may be temporary.
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: Map<String, Any>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pending = copyIncoming(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "inklus/open").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "take") {
                    result.success(pending)
                    pending = null
                } else result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val incoming = copyIncoming(intent) ?: return
        val activeChannel = channel
        if (activeChannel == null) {
            pending = incoming
        } else {
            pending = null
            activeChannel.invokeMethod("file", incoming)
        }
    }

    private fun copyIncoming(intent: Intent?): Map<String, Any>? {
        val uri: Uri = when (intent?.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        } ?: return null

        val displayName = queryDisplayName(uri)
            ?: uri.lastPathSegment?.substringAfterLast('/')
            ?: "shared-file"
        val mimeType = intent?.type ?: contentResolver.getType(uri)
        val kind = resolveKind(mimeType, displayName)
        val suffix = when (kind) {
            "pdf" -> ".pdf"
            "archive" -> if (displayName.endsWith(".zip", ignoreCase = true)) ".zip" else ".inklus"
            else -> ".bin"
        }
        return try {
            val incomingDir = File(cacheDir, "incoming").apply { mkdirs() }
            val out = File.createTempFile("not3_", suffix, incomingDir)
            contentResolver.openInputStream(uri)?.use { input ->
                out.outputStream().use { input.copyTo(it) }
            } ?: run {
                out.delete()
                return null
            }
            mapOf(
                "path" to out.path,
                "displayName" to displayName,
                "kind" to kind,
                "temporary" to true,
            )
        } catch (e: Exception) {
            null
        }
    }

    private fun queryDisplayName(uri: Uri): String? = try {
        contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (!cursor.moveToFirst()) return@use null
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index < 0 || cursor.isNull(index)) null else cursor.getString(index)
        }
    } catch (_: Exception) {
        null
    }

    private fun resolveKind(mimeType: String?, displayName: String): String {
        val normalizedMime = mimeType?.lowercase()?.substringBefore(';')?.trim()
        val lowerName = displayName.lowercase()
        if (normalizedMime == "application/pdf" || lowerName.endsWith(".pdf")) {
            return "pdf"
        }
        if (
            lowerName.endsWith(".inklus") ||
            lowerName.endsWith(".zip") ||
            normalizedMime in archiveMimeTypes
        ) {
            return "archive"
        }
        return "unsupported"
    }

    companion object {
        private val archiveMimeTypes = setOf(
            "application/octet-stream",
            "application/zip",
            "application/x-zip-compressed",
            "application/x-inklus",
        )
    }
}
