import 'package:go_router/go_router.dart';
import 'package:subtrack/app/scaffold_with_nav.dart';
import 'package:subtrack/features/activities/activities_page.dart';
import 'package:subtrack/features/auth/login_page.dart';
import 'package:subtrack/features/cloud/cloud_page.dart';
import 'package:subtrack/features/files/activity_files_page.dart';
import 'package:subtrack/features/history/commit_page.dart';
import 'package:subtrack/features/history/version_history_page.dart';
import 'package:subtrack/features/search/search_page.dart';
import 'package:subtrack/features/semesters/new_semester_page.dart';
import 'package:subtrack/features/semesters/semesters_page.dart';
import 'package:subtrack/features/subjects/subjects_page.dart';

/// Routes from AGENTS.md section 14.
/// Auth redirect (signed-out -> /login) arrives with AuthService in the next
/// task; until then the app starts at /login.
GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
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
