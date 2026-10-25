import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import './l10n/app_localizations.dart';
import './services/supabase_service.dart';
import './widgets/custom_error_widget.dart';
import 'core/app_export.dart';
import 'services/billing_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Don't block the UI waiting for Google Fonts over the network.
  GoogleFonts.config.allowRuntimeFetching = false;

  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Failed to initialize Supabase: $e');
  }
  try {
    await BillingService.instance
        .init(appUserId: SupabaseService.instance.currentUser?.id);
  } catch (_) {}
  try {
    await AppLocalizations().loadSavedLanguage();
  } catch (_) {}

  bool hasShownError = false;

  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (!hasShownError) {
      hasShownError = true;
      Future.delayed(const Duration(seconds: 5), () {
        hasShownError = false;
      });
      return CustomErrorWidget(errorDetails: details);
    }
    return const SizedBox.shrink();
  };

  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(const MyApp());
}

/// Material/Cupertino widgets don't always ship `az`. Keep AZ UI strings
/// from AppLocalizations, but give the framework a locale it can load.
Locale _frameworkLocale(AppLanguage lang) {
  switch (lang) {
    case AppLanguage.ar:
      return const Locale('ar');
    case AppLanguage.ru:
      return const Locale('ru');
    case AppLanguage.az:
    case AppLanguage.en:
      return const Locale('en');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LocalizationsProvider(
      child: Sizer(
        builder: (context, orientation, screenType) {
          final l10n = AppLocalizations.of(context);
          return MaterialApp.router(
            title: 'Nibras Docs',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            locale: _frameworkLocale(l10n.language),
            supportedLocales: const [
              Locale('en'),
              Locale('ru'),
              Locale('ar'),
              Locale('tr'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              final dir = l10n.textDirection;
              return MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.0)),
                child: Directionality(
                  textDirection: dir,
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            debugShowCheckedModeBanner: false,
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}
