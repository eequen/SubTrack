import 'package:go_router/go_router.dart';
import 'package:subtrack/app/scaffold_with_nav.dart';
import 'package:subtrack/features/activities/all_activities_page.dart';
import 'package:subtrack/features/activities/activities_page.dart';
import 'package:subtrack/features/auth/create_account_page.dart';
import 'package:subtrack/features/auth/login_page.dart';
import 'package:subtrack/features/cloud/cloud_page.dart';
import 'package:subtrack/features/dashboard/calendar_page.dart';
import 'package:subtrack/features/dashboard/home_page.dart';
import 'package:subtrack/features/files/activity_files_page.dart';
import 'package:subtrack/features/history/commit_page.dart';
import 'package:subtrack/features/history/version_history_page.dart';
import 'package:subtrack/features/profile/profile_page.dart';
import 'package:subtrack/features/search/search_page.dart';
import 'package:subtrack/features/semesters/new_semester_page.dart';
import 'package:subtrack/features/semesters/semesters_page.dart';
import 'package:subtrack/features/subjects/subjects_page.dart';

/// Routes from AGENTS.md section 14.
///
/// Signed-out users are redirected to `/login` (the create-account screen
/// counts as a signed-out screen too); signed-in users visiting either
/// auth screen go to `/home`. The router is rebuilt by [routerProvider]
/// whenever the auth state changes, so no refreshListenable is needed.
///
/// - Branch 1 (home tab) holds every subject/activity/file screen so they
///   all show the bottom bar with Home highlighted.
/// - Search is its own branch, and the profile branch holds Profile and
///   Cloud backup.
/// - Login, signup, the semester chooser, commit, and (later) edit-profile
///   live outside the shell: no bottom bar there.
GoRouter buildRouter({bool isSignedIn = false, String? initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation ?? '/login',
    redirect: (context, state) {
      final atLogin = state.matchedLocation == '/login';
      final atCreate = state.matchedLocation == '/signup';
      final atAuth = atLogin || atCreate;
      if (!isSignedIn && !atAuth) return '/login';
      if (isSignedIn && atAuth) return '/home';
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
      GoRoute(
        path: '/files/:fileId/commit',
        builder: (context, state) =>
            CommitPage(fileId: state.pathParameters['fileId'] ?? ''),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNav(navigationShell: navigationShell),
        branches: [
          // Branch 0: Search
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchPage(),
              ),
            ],
          ),
          // Branch 1: Home (middle tab) and everything it reaches.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
              GoRoute(
                path: '/subjects',
                builder: (context, state) => const SubjectsPage(),
              ),
              GoRoute(
                path: '/subjects/:subjectId/activities',
                builder: (context, state) => ActivitiesPage(
                  subjectId: state.pathParameters['subjectId'] ?? '',
                ),
              ),
              GoRoute(
                path: '/activities',
                builder: (context, state) => AllActivitiesPage(
                  initialFilter: state.uri.queryParameters['filter'] == 'due'
                      ? 'due_soon'
                      : null,
                ),
              ),
              GoRoute(
                path: '/activities/:activityId',
                builder: (context, state) => ActivityFilesPage(
                  activityId: state.pathParameters['activityId'] ?? '',
                ),
              ),
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarPage(),
              ),
              GoRoute(
                path: '/files/:fileId/history',
                builder: (context, state) => VersionHistoryPage(
                  fileId: state.pathParameters['fileId'] ?? '',
                ),
              ),
            ],
          ),
          // Branch 2: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
              GoRoute(
                path: '/cloud',
                builder: (context, state) => const CloudPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
