import 'package:go_router/go_router.dart';
import 'package:subtrack/app/scaffold_with_nav.dart';
import 'package:subtrack/features/activities/activities_page.dart';
import 'package:subtrack/features/auth/create_account_page.dart';
import 'package:subtrack/features/auth/login_page.dart';
import 'package:subtrack/features/cloud/cloud_page.dart';
import 'package:subtrack/features/files/activity_files_page.dart';
import 'package:subtrack/features/history/commit_page.dart';
import 'package:subtrack/features/history/version_history_page.dart';
import 'package:subtrack/features/search/search_page.dart';
import 'package:subtrack/features/semesters/new_semester_page.dart';
import 'package:subtrack/features/semesters/semesters_page.dart';
import 'package:subtrack/features/subjects/subjects_page.dart';

/// Routes from AGENTS.md section 14 (including the `/signup` create-account
/// screen).
///
/// Signed-out users are redirected to `/login` (the create-account screen
/// counts as a signed-out screen too); signed-in users visiting either
/// auth screen go to `/semesters`. The router is rebuilt by [routerProvider]
/// whenever the auth state changes, so no refreshListenable is needed.
GoRouter buildRouter({bool isSignedIn = false, String? initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation ?? '/login',
    redirect: (context, state) {
      final atLogin = state.matchedLocation == '/login';
      final atCreate = state.matchedLocation == '/signup';
      final atAuth = atLogin || atCreate;
      if (!isSignedIn && !atAuth) return '/login';
      if (isSignedIn && atAuth) return '/semesters';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const CreateAccountPage(),
      ),
      GoRoute(
        path: '/semesters',
        builder: (context, state) => const SemestersPage(),
      ),
      GoRoute(
        path: '/semesters/new',
        builder: (context, state) => const NewSemesterPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNav(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/subjects',
                builder: (context, state) => const SubjectsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cloud',
                builder: (context, state) => const CloudPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/subjects/:subjectId/activities',
        builder: (context, state) =>
            ActivitiesPage(subjectId: state.pathParameters['subjectId'] ?? ''),
      ),
      GoRoute(
        path: '/activities/:activityId',
        builder: (context, state) => ActivityFilesPage(
          activityId: state.pathParameters['activityId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/files/:fileId/history',
        builder: (context, state) =>
            VersionHistoryPage(fileId: state.pathParameters['fileId'] ?? ''),
      ),
      GoRoute(
        path: '/files/:fileId/commit',
        builder: (context, state) =>
            CommitPage(fileId: state.pathParameters['fileId'] ?? ''),
      ),
    ],
  );
}
