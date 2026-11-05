// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HuaweiStylusShortcut { togglePenEraser }

@immutable
class HuaweiStylusSupport {
  const HuaweiStylusSupport({
    this.targetDetected = false,
    this.deviceName,
    this.model,
  });

  final bool targetDetected;
  final String? deviceName;
  final String? model;

  factory HuaweiStylusSupport.fromMap(Object? value) {
    if (value is! Map) return const HuaweiStylusSupport();
    return HuaweiStylusSupport(
      targetDetected: value['targetDetected'] == true,
      deviceName: value['deviceName'] as String?,
      model: value['model'] as String?,
    );
  }
}

/// Narrow bridge for the confirmed MatePad 11 M-Pencil shortcut.
///
/// This service reports shortcut intent only. It does not know about pages,
/// strokes, or toolbar widgets. Native detection uses the exact confirmed
/// MatePad and M-Pencil input-device fingerprint and otherwise fails closed.
class HuaweiStylusShortcutService extends ChangeNotifier {
  HuaweiStylusShortcutService({
    MethodChannel? channel,
    Future<SharedPreferences> Function()? preferences,
  }) : _channel = channel ?? const MethodChannel(_channelName),
       _preferences = preferences ?? SharedPreferences.getInstance;

  static final instance = HuaweiStylusShortcutService();
  static const _channelName = 'not3/stylus_shortcuts';
  static const _enabledPreference = 'huawei_matepad11_stylus_toggle';
  static const _duplicateWindow = Duration(milliseconds: 80);

  final MethodChannel _channel;
  final Future<SharedPreferences> Function() _preferences;
  final StreamController<HuaweiStylusShortcut> _events =
      StreamController<HuaweiStylusShortcut>.broadcast(sync: true);

  bool _started = false;
  bool _appActive = true;
  bool _enabled = true;
  HuaweiStylusSupport _support = const HuaweiStylusSupport();
  int? _lastEventId;
  int? _lastEventTimeMs;

  Stream<HuaweiStylusShortcut> get events => _events.stream;
  bool get enabled => _enabled;
  HuaweiStylusSupport get support => _support;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final prefs = await _preferences();
      _enabled = prefs.getBool(_enabledPreference) ?? true;
    } catch (_) {}
    _channel.setMethodCallHandler(_handleNativeCall);
    await refreshSupport();
    await _syncListening();
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _channel.setMethodCallHandler(null);
    await _setNativeListening(false);
    _lastEventId = null;
    _lastEventTimeMs = null;
  }

  Future<void> setAppActive(bool active) async {
    if (_appActive == active) return;
    _appActive = active;
    if (_started) await _syncListening();
  }

  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    _enabled = enabled;
    notifyListeners();
    try {
      final prefs = await _preferences();
      await prefs.setBool(_enabledPreference, enabled);
    } catch (_) {}
    if (_started) await _syncListening();
  }

  Future<void> refreshSupport() async {
    try {
      final value = await _channel.invokeMethod<Object?>('getSupport');
      final next = HuaweiStylusSupport.fromMap(value);
      if (next.targetDetected != _support.targetDetected ||
          next.deviceName != _support.deviceName ||
          next.model != _support.model) {
        _support = next;
        notifyListeners();
      }
    } on MissingPluginException {
      // Unsupported platform.
    } on PlatformException {
      // A missing native implementation must never affect the editor.
    }
  }

  Future<void> _syncListening() =>
      _setNativeListening(_started && _appActive && _enabled);

  Future<void> _setNativeListening(bool listening) async {
    try {
      await _channel.invokeMethod<void>('setListening', listening);
    } on MissingPluginException {
      // Unsupported platform.
    } on PlatformException {
      // Keep the editor usable if the platform bridge is unavailable.
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'togglePenEraser' ||
        !_started ||
        !_appActive ||
        !_enabled) {
      return;
    }
    final arguments = call.arguments;
    final map = arguments is Map ? arguments : const <Object?, Object?>{};
    _emitToggle(
      eventId: (map['eventId'] as num?)?.toInt(),
      eventTimeMs: (map['eventTimeMs'] as num?)?.toInt(),
    );
  }

  @visibleForTesting
  Future<void> handleNativeCallForTesting(MethodCall call) =>
      _handleNativeCall(call);

  /// Flutter-side entry point retained for devices that expose the same
  /// physical gesture through pointer input as well as the native bridge.
  @visibleForTesting
  void reportFlutterToggle({int? eventTimeMs}) {
    if (!_started || !_appActive || !_enabled) return;
    _emitToggle(eventTimeMs: eventTimeMs);
  }

  void _emitToggle({int? eventId, int? eventTimeMs}) {
    if (eventId != null && eventId == _lastEventId) return;
    final previousTime = _lastEventTimeMs;
    if (eventTimeMs != null &&
        previousTime != null &&
        (eventTimeMs - previousTime).abs() <= _duplicateWindow.inMilliseconds) {
      return;
    }
    _lastEventId = eventId;
    _lastEventTimeMs = eventTimeMs;
    _events.add(HuaweiStylusShortcut.togglePenEraser);
  }
}
