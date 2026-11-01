// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import 'l10n/l10n.dart';

import 'theme_controller.dart';
import 'ui/theme/app_theme.dart';
import 'ui/notebook_library.dart';
import 'ui/onboarding_screen.dart';

/// Widget raíz de Not3.
///
/// Soporta tema claro y oscuro. El usuario puede alternar desde la
/// configuración del sistema o desde un toggle manual.
class Not3App extends StatefulWidget {
  /// Solo para tests: fija el idioma (null = el del sistema).
  const Not3App({super.key, this.locale});

  final Locale? locale;

  @override
  State<Not3App> createState() => _Not3AppState();
}

class _Not3AppState extends State<Not3App> {
  bool _showOnboarding = true;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    ThemeModeController.load();
  }

  Future<void> _checkOnboarding() async {
    final shouldShow = await OnboardingScreen.shouldShow();
    if (mounted) setState(() => _showOnboarding = shouldShow);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeModeController.mode,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'Not3',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // La única localización publicada es inglés.
        locale: widget.locale,
        localeListResolutionCallback: resolveAppLocale,
        home: _showOnboarding
            ? OnboardingScreen(
                onDone: () => setState(() => _showOnboarding = false),
              )
            : const NotebookLibraryScreen(),
      ),
    );
  }
}

/// Devuelve el primer idioma soportado; actualmente siempre es inglés.
Locale resolveAppLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final p in preferred ?? const <Locale>[]) {
    for (final s in supported) {
      if (s.languageCode == p.languageCode) return s;
    }
  }
  return const Locale('en');
}
