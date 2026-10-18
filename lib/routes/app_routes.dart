import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../presentation/document_editor_screen/document_editor_screen.dart';
import '../presentation/documents_list_screen/documents_list_screen.dart';
import '../presentation/subscription_plan_screen/subscription_plan_screen.dart';
import '../presentation/templates_screen/templates_screen.dart';
import '../presentation/privacy_policy_screen/privacy_policy_screen.dart';
import '../presentation/terms_of_service_screen/terms_of_service_screen.dart';
import '../presentation/settings_screen/settings_screen.dart';
import '../presentation/auth_screen/auth_screen.dart';
import '../presentation/splash_screen/splash_screen.dart';
import '../widgets/app_scaffold.dart';

class AppRoutes {
  static const String initial = '/';
  static const String splash = '/splash';
  static const String authScreen = '/auth';
  static const String documentsListScreen = '/documents-list-screen';
  static const String documentEditorScreen = '/document-editor-screen';
  static const String subscriptionPlanScreen = '/subscription-plan-screen';
  static const String templatesScreen = '/templates';
  static const String privacyPolicyScreen = '/privacy-policy';
  static const String termsOfServiceScreen = '/terms-of-service';
  static const String settingsScreen = '/settings';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  redirect: (context, state) {
    // Auth is optional — guests can use the app without logging in
    bool isAuthenticated = false;
    try {
      isAuthenticated = Supabase.instance.client.auth.currentUser != null;
    } catch (_) {
      // Supabase not initialized
    }
    final isOnAuth = state.matchedLocation == AppRoutes.authScreen;

    if (isAuthenticated && isOnAuth) {
      return AppRoutes.documentsListScreen;
    }
    return null;
  },
  routes: [
    // Splash screen — 2.5 saniyə göstərilir
    GoRoute(
      path: AppRoutes.splash,
      pageBuilder: (context, state) => const NoTransitionPage(
        child: SplashScreen(),
      ),
    ),
    // Root '/' → splash
    GoRoute(
      path: AppRoutes.initial,
      redirect: (context, state) => AppRoutes.splash,
    ),
    GoRoute(
      path: AppRoutes.authScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const AuthScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppScaffold(navigationShell: navigationShell),
      branches: [
        // Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.documentsListScreen,
              builder: (context, state) => const DocumentsListScreen(),
            ),
          ],
        ),
        // Documents tab — same list (filter via UI); editor is push-only
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/documents-library',
              builder: (context, state) => const DocumentsListScreen(),
            ),
          ],
        ),
      ],
    ),
    // Editor is a full-screen push, not a bottom-tab root
    GoRoute(
      path: AppRoutes.documentEditorScreen,
      builder: (context, state) {
        final doc = state.extra as Map<String, dynamic>?;
        return DocumentEditorScreen(documentData: doc);
      },
    ),
    GoRoute(
      path: AppRoutes.templatesScreen,
      builder: (context, state) => const TemplatesScreen(),
    ),
    GoRoute(
      path: AppRoutes.subscriptionPlanScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SubscriptionPlanScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final offset =
              Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
          return SlideTransition(
            position: offset,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    ),
    GoRoute(
      path: AppRoutes.privacyPolicyScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const PrivacyPolicyScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    ),
    GoRoute(
      path: AppRoutes.termsOfServiceScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const TermsOfServiceScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    ),
    GoRoute(
      path: AppRoutes.settingsScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    ),
  ],
);
