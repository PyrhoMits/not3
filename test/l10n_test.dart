// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:inklus/app.dart' show resolveAppLocale;
import 'package:inklus/l10n/app_localizations.dart';

void main() {
  group('system locale', () {
    const supported = AppLocalizations.supportedLocales;

    test('English is the only supported locale', () {
      expect(supported, const [Locale('en')]);
      expect(
        resolveAppLocale([const Locale('en', 'US')], supported),
        const Locale('en'),
      );
    });

    test('unsupported and missing locales fall back to English', () {
      expect(
        resolveAppLocale([const Locale('es')], supported),
        const Locale('en'),
      );
      expect(resolveAppLocale(null, supported), const Locale('en'));
    });
  });
}
