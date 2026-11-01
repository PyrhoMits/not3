// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not3/l10n/l10n.dart';
import 'package:not3/ui/create_notebook_screen.dart';
import 'package:not3/ui/marketplace_screen.dart';

void main() {
  Widget app(Locale locale, Widget home) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );

  testWidgets('create notebook uses English', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(const Locale('en'), const CreateNotebookScreen(notebookCount: 2)),
    );
    await tester.pump();
    expect(find.text('New notebook'), findsOneWidget);
    expect(find.text('Your image'), findsOneWidget);
    expect(find.text('Notebook 2'), findsOneWidget);
    expect(find.text('Nuevo cuaderno'), findsNothing);
  });

  testWidgets('marketplace en inglés', (tester) async {
    await tester.pumpWidget(app(const Locale('en'), const MarketplaceScreen()));
    await tester.pump();
    expect(find.text('Discover and customize'), findsOneWidget);
    expect(find.text('Descubre y personaliza'), findsNothing);
  });
}
