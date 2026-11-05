package io.github.pyrhomits.not3

import android.view.KeyEvent

internal data class HuaweiStylusDeviceSignature(
    val manufacturer: String,
    val tabletModel: String,
    val deviceName: String,
    val descriptor: String,
    val vendorId: Int,
    val productId: Int,
    val deviceSources: Int,
    val keyCode: Int,
)

internal data class StylusKeyBoundary(
    val manufacturer: String,
    val tabletModel: String,
    val deviceName: String?,
    val descriptor: String?,
    val vendorId: Int,
    val productId: Int,
    val deviceSources: Int,
    val action: Int,
    val keyCode: Int,
    val repeatCount: Int,
    val eventTime: Long,
)

/** Fail-closed classifier for the MatePad 11 M-Pencil (2nd generation). */
internal class HuaweiStylusShortcutClassifier(
    private val signature: HuaweiStylusDeviceSignature,
    private val doubleTapWindowMs: Long = 350,
) {
    private var firstPressTime: Long? = null

    fun supports(boundary: StylusKeyBoundary): Boolean =
        boundary.manufacturer.equals(signature.manufacturer, ignoreCase = true) &&
            boundary.tabletModel.equals(signature.tabletModel, ignoreCase = true) &&
            boundary.deviceName == signature.deviceName &&
            boundary.descriptor == signature.descriptor &&
            boundary.vendorId == signature.vendorId &&
            boundary.productId == signature.productId &&
            boundary.deviceSources == signature.deviceSources

    /** Returns true once for the two key-down events emitted by one body double-tap. */
    fun accept(boundary: StylusKeyBoundary): Boolean {
        if (!supports(boundary) ||
            boundary.action != KeyEvent.ACTION_DOWN ||
            boundary.keyCode != signature.keyCode ||
            boundary.repeatCount != 0
        ) {
            return false
        }

        val previous = firstPressTime
        if (previous == null) {
            firstPressTime = boundary.eventTime
            return false
        }
        val elapsed = boundary.eventTime - previous
        firstPressTime = if (elapsed in 1..doubleTapWindowMs) null else boundary.eventTime
        return elapsed in 1..doubleTapWindowMs
    }
}

internal object ConfirmedMatePad11MPencil2 {
    val signature = HuaweiStylusDeviceSignature(
        manufacturer = "HUAWEI",
        tabletModel = "DBY-W09",
        deviceName = "M-Pencil Mouse",
        descriptor = "07b1a2a2713ba3b634f6cbd3d49af6895fd64026",
        vendorId = 4817,
        productId = 4261,
        deviceSources = 8451,
        keyCode = 718,
    )
}
