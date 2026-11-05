// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/gestures.dart';

/// Whether this pointer contact should erase temporarily without changing the
/// toolbar's selected tool.
bool isPhysicalStylusEraser(PointerDeviceKind kind, int buttons) =>
    kind == PointerDeviceKind.invertedStylus ||
    (kind == PointerDeviceKind.stylus &&
        (buttons & (kPrimaryStylusButton | kSecondaryStylusButton)) != 0);
