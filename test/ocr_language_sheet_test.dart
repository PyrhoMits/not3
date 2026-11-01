// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not3/l10n/l10n.dart';
import 'package:not3/ui/widgets/ocr_language_sheet.dart';

void main() {
  Widget app({required Widget home}) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );

  testWidgets('shows three languages and the download notice', (tester) async {
    await tester.pumpWidget(
      app(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showOcrLanguageSheet(
                context,
                currentCode: 'en',
                downloadedCodes: const {'en', 'ja'},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Recognition language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('日本語 (Japanese)'), findsOneWidget);
    expect(find.text('ไทย (Thai)'), findsOneWidget);
    // Only Thai needs a download.
    expect(find.text('Download (~20 MB)'), findsOneWidget);
  });

  testWidgets('canceling the download does not select a language', (
    tester,
  ) async {
    OcrLanguageSelection? selection;
    await tester.pumpWidget(
      app(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selection = await showOcrLanguageSheet(
                  context,
                  currentCode: 'en',
                  downloadedCodes: const {'en', 'ja'},
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ไทย (Thai)'));
    await tester.pumpAndSettle();

    expect(find.text('Download the ไทย (Thai) model?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(selection, isNull);
    // The language sheet remains open.
    expect(find.text('Recognition language'), findsOneWidget);
  });

  testWidgets('confirming the download returns the selected language', (
    tester,
  ) async {
    OcrLanguageSelection? selection;
    await tester.pumpWidget(
      app(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selection = await showOcrLanguageSheet(
                  context,
                  currentCode: 'en',
                  downloadedCodes: const {'en', 'ja'},
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ไทย (Thai)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Download (~20 MB)'));
    await tester.pumpAndSettle();

    expect(selection?.language.code, 'th');
    expect(selection?.needsDownload, isTrue);
  });

  testWidgets('a downloaded language does not ask for confirmation', (
    tester,
  ) async {
    OcrLanguageSelection? selection;
    await tester.pumpWidget(
      app(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selection = await showOcrLanguageSheet(
                  context,
                  currentCode: 'en',
                  downloadedCodes: const {'en', 'ja'},
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日本語 (Japanese)'));
    await tester.pumpAndSettle();

    expect(selection?.language.code, 'ja');
    expect(selection?.needsDownload, isFalse);
  });
}
