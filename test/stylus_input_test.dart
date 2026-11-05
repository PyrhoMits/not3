// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not3/logic/stylus_input.dart';

void main() {
  test('physical eraser decision is shared and contact-only', () {
    expect(isPhysicalStylusEraser(PointerDeviceKind.invertedStylus, 0), isTrue);
    expect(
      isPhysicalStylusEraser(PointerDeviceKind.stylus, kPrimaryStylusButton),
      isTrue,
    );
    expect(
      isPhysicalStylusEraser(PointerDeviceKind.stylus, kSecondaryStylusButton),
      isTrue,
    );
    expect(isPhysicalStylusEraser(PointerDeviceKind.stylus, 0), isFalse);
    expect(
      isPhysicalStylusEraser(PointerDeviceKind.mouse, kPrimaryStylusButton),
      isFalse,
    );
  });
}
