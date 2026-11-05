package io.github.pyrhomits.not3

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.util.Log
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/// Receives PDFs, standalone HTML, and Not3 archives from file managers or sharing. Incoming
/// content is copied to app cache because provider URI grants may be temporary.
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var stylusChannel: MethodChannel? = null
    private var listenForStylusShortcuts = false
    private var stylusEventId = 0L
    private val stylusClassifier = HuaweiStylusShortcutClassifier(
        ConfirmedMatePad11MPencil2.signature,
    )
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
        stylusChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "not3/stylus_shortcuts",
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "setListening" -> {
                        listenForStylusShortcuts = call.arguments == true
                        result.success(null)
                    }
                    "getSupport" -> result.success(stylusSupport())
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        logMotionBoundary("generic", event)
        return super.dispatchGenericMotionEvent(event)
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        logMotionBoundary("touch", event)
        return super.dispatchTouchEvent(event)
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (isDebuggable &&
            (event.action == KeyEvent.ACTION_DOWN || event.action == KeyEvent.ACTION_UP)
        ) {
            val device = event.device
            Log.d(
                STYLUS_LOG_TAG,
                "path=key action=${event.action} keyCode=${event.keyCode} " +
                    "repeat=${event.repeatCount} eventTime=${event.eventTime} " +
                    deviceLogFields(device),
            )
        }
        if (listenForStylusShortcuts && stylusClassifier.accept(event.toStylusBoundary())) {
            stylusChannel?.invokeMethod(
                "togglePenEraser",
                mapOf(
                    "eventId" to ++stylusEventId,
                    "eventTimeMs" to event.eventTime,
                ),
            )
            if (isDebuggable) Log.d(STYLUS_LOG_TAG, "accepted togglePenEraser")
        }
        return super.dispatchKeyEvent(event)
    }

    private fun stylusSupport(): Map<String, Any?> {
        val signature = ConfirmedMatePad11MPencil2.signature
        val target = if (
            !Build.MANUFACTURER.equals(signature.manufacturer, ignoreCase = true) ||
            !Build.MODEL.equals(signature.tabletModel, ignoreCase = true)
        ) {
            null
        } else {
            InputDevice.getDeviceIds()
                .asSequence()
                .mapNotNull(InputDevice::getDevice)
                .firstOrNull {
                    it.name == signature.deviceName &&
                        it.descriptor == signature.descriptor &&
                        it.vendorId == signature.vendorId &&
                        it.productId == signature.productId &&
                        it.sources == signature.deviceSources
                }
        }
        return mapOf(
            "targetDetected" to (target != null),
            "deviceName" to target?.name,
            "model" to Build.MODEL,
        )
    }

    private fun KeyEvent.toStylusBoundary(): StylusKeyBoundary {
        val input = device
        return StylusKeyBoundary(
            manufacturer = Build.MANUFACTURER,
            tabletModel = Build.MODEL,
            deviceName = input?.name,
            descriptor = input?.descriptor,
            vendorId = input?.vendorId ?: 0,
            productId = input?.productId ?: 0,
            deviceSources = input?.sources ?: 0,
            action = action,
            keyCode = keyCode,
            repeatCount = repeatCount,
            eventTime = eventTime,
        )
    }

    private fun logMotionBoundary(path: String, event: MotionEvent) {
        if (!isDebuggable ||
            event.actionMasked == MotionEvent.ACTION_MOVE ||
            event.actionMasked == MotionEvent.ACTION_HOVER_MOVE
        ) {
            return
        }
        val tool = if (event.pointerCount == 0) {
            MotionEvent.TOOL_TYPE_UNKNOWN
        } else {
            event.getToolType(0)
        }
        Log.d(
            STYLUS_LOG_TAG,
            "path=$path action=${event.actionMasked} actionButton=${event.actionButton} " +
                "buttonState=${event.buttonState} source=${event.source} tool=$tool " +
                "eventTime=${event.eventTime} " +
                deviceLogFields(event.device),
        )
    }

    private fun deviceLogFields(device: InputDevice?): String =
        "manufacturer=${Build.MANUFACTURER} model=${Build.MODEL} " +
            "device=${device?.name} descriptor=${device?.descriptor} " +
            "vendor=${device?.vendorId ?: 0} product=${device?.productId ?: 0} " +
            "deviceSources=${device?.sources ?: 0}"

    private val isDebuggable: Boolean
        get() = applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

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
            "html" -> if (displayName.endsWith(".htm", ignoreCase = true)) ".htm" else ".html"
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
            lowerName.endsWith(".html") ||
            lowerName.endsWith(".htm") ||
            normalizedMime in htmlMimeTypes
        ) {
            return "html"
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
        private const val STYLUS_LOG_TAG = "Not3Stylus"
        private val archiveMimeTypes = setOf(
            "application/octet-stream",
            "application/zip",
            "application/x-zip-compressed",
            "application/x-inklus",
        )
        private val htmlMimeTypes = setOf(
            "text/html",
            "application/xhtml+xml",
        )
    }
}
