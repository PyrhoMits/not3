package io.github.pyrhomits.not3

import android.view.KeyEvent
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HuaweiStylusShortcutClassifierTest {
    private val signature = HuaweiStylusDeviceSignature(
        manufacturer = "HUAWEI",
        tabletModel = "DBY-W09",
        deviceName = "M-Pencil Mouse",
        descriptor = "07b1a2a2713ba3b634f6cbd3d49af6895fd64026",
        vendorId = 4817,
        productId = 4261,
        deviceSources = 8451,
        keyCode = 718,
    )

    private fun event(
        time: Long,
        action: Int = KeyEvent.ACTION_DOWN,
        keyCode: Int = signature.keyCode,
        repeatCount: Int = 0,
        manufacturer: String = signature.manufacturer,
        tabletModel: String = signature.tabletModel,
        deviceName: String = signature.deviceName,
        descriptor: String = signature.descriptor,
        vendorId: Int = signature.vendorId,
        productId: Int = signature.productId,
        deviceSources: Int = signature.deviceSources,
    ) = StylusKeyBoundary(
        manufacturer = manufacturer,
        tabletModel = tabletModel,
        deviceName = deviceName,
        descriptor = descriptor,
        vendorId = vendorId,
        productId = productId,
        deviceSources = deviceSources,
        action = action,
        keyCode = keyCode,
        repeatCount = repeatCount,
        eventTime = time,
    )

    @Test
    fun twoKeyDownEventsInsideWindowEmitOneToggle() {
        val classifier = HuaweiStylusShortcutClassifier(signature)
        assertFalse(classifier.accept(event(1_000)))
        assertTrue(classifier.accept(event(1_014)))
    }

    @Test
    fun keyUpEventsDoNotCountAsPresses() {
        val classifier = HuaweiStylusShortcutClassifier(signature)
        assertFalse(classifier.accept(event(1_000)))
        assertFalse(classifier.accept(event(1_012, action = KeyEvent.ACTION_UP)))
        assertTrue(classifier.accept(event(1_014)))
    }

    @Test
    fun lateSecondPressStartsANewPair() {
        val classifier = HuaweiStylusShortcutClassifier(signature)
        assertFalse(classifier.accept(event(1_000)))
        assertFalse(classifier.accept(event(1_500)))
        assertTrue(classifier.accept(event(1_514)))
    }

    @Test
    fun unrelatedDeviceFingerprintsAreRejected() {
        val classifier = HuaweiStylusShortcutClassifier(signature)
        assertFalse(classifier.accept(event(1_000, manufacturer = "Samsung")))
        assertFalse(classifier.accept(event(1_010, tabletModel = "Other Huawei tablet")))
        assertFalse(classifier.accept(event(1_020, deviceName = "Generic stylus")))
        assertFalse(classifier.accept(event(1_030, descriptor = "other")))
        assertFalse(classifier.accept(event(1_040, vendorId = 1)))
        assertFalse(classifier.accept(event(1_050, productId = 1)))
        assertFalse(classifier.accept(event(1_060, deviceSources = 1)))
    }

    @Test
    fun wrongKeyAndRepeatedKeyEventsAreRejected() {
        val classifier = HuaweiStylusShortcutClassifier(signature)
        assertFalse(classifier.accept(event(1_000, keyCode = 717)))
        assertFalse(classifier.accept(event(1_010, repeatCount = 1)))
    }
}
