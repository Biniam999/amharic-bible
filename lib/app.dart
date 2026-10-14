import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/settings_providers.dart';
import 'l10n/generated/app_localizations.dart';

class AmharicBibleApp extends ConsumerWidget {
  const AmharicBibleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `select` so unrelated settings (font size etc.) don't rebuild MaterialApp.
    final themeMode = ref.watch(appSettingsProvider.select((s) => s.themeMode));
    final readingFont = ref.watch(appSettingsProvider.select((s) => s.readingFont));
    final locale = ref.watch(appSettingsProvider.select((s) => s.uiLocale));
    final router = ref.watch(routerProvider);

    final (theme, darkTheme, mode) = AppTheme.resolve(themeMode, font: readingFont);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: mode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
