package io.github.pyrhomits.not3

import android.view.InputDevice
import android.view.MotionEvent
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HuaweiStylusShortcutClassifierTest {
    private val signature = HuaweiStylusDeviceSignature(
        manufacturer = "HUAWEI",
        tabletModel = "Captured MatePad 11 model",
        descriptor = "captured-m-pencil-2",
        vendorId = 4817,
        productId = 11,
        source = InputDevice.SOURCE_STYLUS,
        toolType = MotionEvent.TOOL_TYPE_STYLUS,
        actionButton = MotionEvent.BUTTON_STYLUS_PRIMARY,
        protocol = HuaweiShortcutProtocol.TWO_BUTTON_PRESSES,
    )

    private fun event(
        time: Long,
        action: Int = MotionEvent.ACTION_BUTTON_PRESS,
        descriptor: String = signature.descriptor,
        manufacturer: String = signature.manufacturer,
        tabletModel: String = signature.tabletModel,
        source: Int = InputDevice.SOURCE_STYLUS,
        tool: Int = MotionEvent.TOOL_TYPE_STYLUS,
    ) = StylusMotionBoundary(
        manufacturer = manufacturer,
        tabletModel = tabletModel,
        descriptor = descriptor,
        vendorId = signature.vendorId,
        productId = signature.productId,
        source = source,
        action = action,
        actionButton = signature.actionButton,
        toolType = tool,
        eventTime = time,
    )

    @Test
    fun twoPressesInsideWindowEmitOneToggle() {
        val classifier = HuaweiStylusShortcutClassifier(signature)
        assertFalse(classifier.accept(event(1_000)))
        assertTrue(classifier.accept(event(1_280)))
    }

    @Test
    fun releaseDoesNotCountAsASecondTap() {
        val classifier = HuaweiStylusShortcutClassifier(signature)
        assertFalse(classifier.accept(event(1_000)))
        assertFalse(classifier.accept(event(1_050, MotionEvent.ACTION_BUTTON_RELEASE)))
    }

    @Test
    fun lateSecondPressStartsANewPair() {
        val classifier = HuaweiStylusShortcutClassifier(signature)
        assertFalse(classifier.accept(event(1_000)))
        assertFalse(classifier.accept(event(1_500)))
        assertTrue(classifier.accept(event(1_700)))
    }

    @Test
    fun unrelatedInputsAreRejected() {
        val classifier = HuaweiStylusShortcutClassifier(signature)
        assertFalse(classifier.accept(event(900, manufacturer = "Samsung")))
        assertFalse(classifier.accept(event(950, tabletModel = "Other Huawei tablet")))
        assertFalse(classifier.accept(event(1_000, descriptor = "other")))
        assertFalse(classifier.accept(event(1_100, source = InputDevice.SOURCE_MOUSE)))
        assertFalse(classifier.accept(event(1_200, tool = MotionEvent.TOOL_TYPE_FINGER)))
    }

    @Test
    fun missingProductionSignatureRejectsEverything() {
        val classifier = HuaweiStylusShortcutClassifier(null)
        assertFalse(classifier.accept(event(1_000)))
        assertFalse(classifier.accept(event(1_100)))
    }
}
