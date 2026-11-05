// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not3/services/huawei_stylus_shortcut_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('not3/test_stylus_shortcuts');
  late HuaweiStylusShortcutService service;
  late List<MethodCall> nativeCalls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    nativeCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add(call);
          if (call.method == 'getSupport') {
            return {
              'targetDetected': true,
              'deviceName': 'Captured M-Pencil',
              'model': 'MatePad 11',
            };
          }
          return null;
        });
    service = HuaweiStylusShortcutService(channel: channel);
  });

  tearDown(() async {
    await service.stop();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('subscribes only while active and reports typed toggles', () async {
    final events = <HuaweiStylusShortcut>[];
    final subscription = service.events.listen(events.add);
    await service.start();

    expect(service.support.targetDetected, isTrue);
    expect(nativeCalls.map((call) => call.method), contains('setListening'));
    await service.handleNativeCallForTesting(
      const MethodCall('togglePenEraser', {'eventId': 1, 'eventTimeMs': 1000}),
    );
    expect(events, [HuaweiStylusShortcut.togglePenEraser]);

    await service.setAppActive(false);
    await service.handleNativeCallForTesting(
      const MethodCall('togglePenEraser', {'eventId': 2, 'eventTimeMs': 1500}),
    );
    expect(events, hasLength(1));
    await subscription.cancel();
  });

  test('deduplicates native and Flutter reports of one gesture', () async {
    final events = <HuaweiStylusShortcut>[];
    final subscription = service.events.listen(events.add);
    await service.start();
    await service.handleNativeCallForTesting(
      const MethodCall('togglePenEraser', {'eventId': 7, 'eventTimeMs': 2000}),
    );
    service.reportFlutterToggle(eventTimeMs: 2040);
    await service.handleNativeCallForTesting(
      const MethodCall('togglePenEraser', {'eventId': 7, 'eventTimeMs': 2300}),
    );
    expect(events, hasLength(1));
    await subscription.cancel();
  });

  test('disabled preference ignores shortcuts and persists', () async {
    final events = <HuaweiStylusShortcut>[];
    final subscription = service.events.listen(events.add);
    await service.start();
    await service.setEnabled(false);
    await service.handleNativeCallForTesting(
      const MethodCall('togglePenEraser', {'eventId': 1, 'eventTimeMs': 1000}),
    );
    expect(events, isEmpty);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'huawei_matepad11_stylus_toggle',
      ),
      isFalse,
    );
    await subscription.cancel();
  });
}
