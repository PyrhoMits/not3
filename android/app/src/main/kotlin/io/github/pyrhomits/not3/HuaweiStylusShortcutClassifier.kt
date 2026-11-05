package io.github.pyrhomits.not3

import android.view.MotionEvent

internal enum class HuaweiShortcutProtocol {
    TWO_BUTTON_PRESSES,
    COMPLETED_DOUBLE_TAP_EVENT,
}

internal data class HuaweiStylusDeviceSignature(
    val manufacturer: String,
    val tabletModel: String,
    val descriptor: String,
    val vendorId: Int,
    val productId: Int,
    val source: Int,
    val toolType: Int,
    val actionButton: Int,
    val protocol: HuaweiShortcutProtocol,
)

internal data class StylusMotionBoundary(
    val manufacturer: String,
    val tabletModel: String,
    val descriptor: String?,
    val vendorId: Int,
    val productId: Int,
    val source: Int,
    val action: Int,
    val actionButton: Int,
    val toolType: Int,
    val eventTime: Long,
)

/** Fail-closed classifier for the MatePad 11 M-Pencil (2nd generation). */
internal class HuaweiStylusShortcutClassifier(
    private val signature: HuaweiStylusDeviceSignature?,
    private val doubleTapWindowMs: Long = 350,
) {
    private var firstPressTime: Long? = null

    fun supports(boundary: StylusMotionBoundary): Boolean {
        val target = signature ?: return false
        return boundary.manufacturer.equals(target.manufacturer, ignoreCase = true) &&
            boundary.tabletModel.equals(target.tabletModel, ignoreCase = true) &&
            boundary.descriptor == target.descriptor &&
            boundary.vendorId == target.vendorId &&
            boundary.productId == target.productId &&
            boundary.source == target.source &&
            boundary.toolType == target.toolType
    }

    /** Returns true exactly once for one confirmed physical double-tap. */
    fun accept(boundary: StylusMotionBoundary): Boolean {
        val target = signature ?: return false
        if (!supports(boundary) ||
            boundary.action != MotionEvent.ACTION_BUTTON_PRESS ||
            boundary.actionButton != target.actionButton
        ) {
            return false
        }
        if (target.protocol == HuaweiShortcutProtocol.COMPLETED_DOUBLE_TAP_EVENT) {
            firstPressTime = null
            return true
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

/**
 * Filled only after `Not3Stylus` logs have been captured from the real target.
 * A null signature deliberately disables recognition on every device.
 */
internal object ConfirmedMatePad11MPencil2 {
    val signature: HuaweiStylusDeviceSignature? = null
}
