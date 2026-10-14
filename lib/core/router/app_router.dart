import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/commentary/commentary_screen.dart';
import '../../features/devotions/devotions_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/maps/maps_screen.dart';
import '../../features/onboarding/profile_providers.dart';
import '../../features/people/people_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../../features/plans/plan_detail_screen.dart';
import '../../features/plans/plans_screen.dart';
import '../../features/reader/book_picker_screen.dart';
import '../../features/reader/chapter_picker_screen.dart';
import '../../features/reader/reader_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/about_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../widgets/home_shell.dart';

abstract final class AppRoutes {
  static const welcome = '/welcome';

  static const home = '/home';
  static const plans = '/home/plans';
  static String plan(String id) => '/home/plans/$id';
  static const people = '/home/people';
  static String person(String id) => '/home/people/${Uri.encodeComponent(id)}';
  static const devotions = '/home/devotions';
  static const maps = '/home/maps';
  static String mapsAt(String placeId) => '/home/maps?place=${Uri.encodeQueryComponent(placeId)}';
  static const read = '/read';
  static const bookPicker = '/read/books';
  static String chapterPicker(int bookId) => '/read/books/$bookId';
  /// Full-screen search, opened over the tabs (from the reader and Home).
  static const search = '/search';
  static const commentary = '/commentary';
  static const library = '/library';
  static const settings = '/settings';
  static const about = '/settings/about';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    // First launch: show the welcome screen until a name has been entered.
    redirect: (context, state) {
      final onboarded = ref.read(userProfileProvider).onboarded;
      final atWelcome = state.matchedLocation == AppRoutes.welcome;
      if (!onboarded && !atWelcome) return AppRoutes.welcome;
      if (onboarded && atWelcome) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.welcome, builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: AppRoutes.search, builder: (context, state) => const SearchScreen()),
      // Each tab keeps its own navigation stack and scroll state.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.home,
              pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreen()),
              routes: [
                GoRoute(
                  path: 'plans',
                  builder: (context, state) => const PlansScreen(),
                  routes: [
                    GoRoute(
                      path: ':planId',
                      builder: (context, state) => PlanDetailScreen(planId: state.pathParameters['planId'] ?? ''),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'people',
                  builder: (context, state) => const PeopleScreen(),
                  routes: [
                    GoRoute(
                      path: ':personId',
                      builder: (context, state) => PersonScreen(id: state.pathParameters['personId'] ?? ''),
                    ),
                  ],
                ),
                GoRoute(path: 'devotions', builder: (context, state) => const DevotionsScreen()),
                GoRoute(
                  path: 'maps',
                  builder: (context, state) => MapsScreen(initialPlaceId: state.uri.queryParameters['place']),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.read,
              pageBuilder: (context, state) => const NoTransitionPage(child: ReaderScreen()),
              routes: [
                GoRoute(
                  path: 'books',
                  builder: (context, state) => const BookPickerScreen(),
                  routes: [
                    GoRoute(
                      path: ':bookId',
                      builder: (context, state) =>
                          ChapterPickerScreen(bookId: int.tryParse(state.pathParameters['bookId'] ?? '') ?? 1),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.commentary,
              pageBuilder: (context, state) => const NoTransitionPage(child: CommentaryScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.library,
              pageBuilder: (context, state) => const NoTransitionPage(child: LibraryScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.settings,
              pageBuilder: (context, state) => const NoTransitionPage(child: SettingsScreen()),
              routes: [
                GoRoute(path: 'about', builder: (context, state) => const AboutScreen()),
              ],
            ),
          ]),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text(state.error?.toString() ?? 'Page not found')),
    ),
  );
});
