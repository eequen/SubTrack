import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:subtrack/app/scaffold_with_nav.dart';
import 'package:subtrack/features/activities/all_activities_page.dart';
import 'package:subtrack/features/activities/activities_page.dart';
import 'package:subtrack/features/auth/create_account_page.dart';
import 'package:subtrack/features/auth/login_page.dart';
import 'package:subtrack/features/cloud/cloud_page.dart';
import 'package:subtrack/features/dashboard/calendar_page.dart';
import 'package:subtrack/features/dashboard/home_page.dart';
import 'package:subtrack/features/edit/edit_page.dart';
import 'package:subtrack/features/files/activity_files_page.dart';
import 'package:subtrack/features/history/commit_page.dart';
import 'package:subtrack/features/history/version_history_page.dart';
import 'package:subtrack/features/profile/edit_profile_page.dart';
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
/// - Cloud, Subjects, Home, Calendar, and Profile occupy the five tabs.
/// - Home owns Search and All activities.
/// - Subjects owns its activity, file, and history screens.
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
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _animatedPage(state, const LoginPage()),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) =>
            _animatedPage(state, const CreateAccountPage()),
      ),
      GoRoute(
        path: '/semesters',
        pageBuilder: (context, state) =>
            _animatedPage(state, const SemestersPage()),
      ),
      GoRoute(
        path: '/semesters/new',
        pageBuilder: (context, state) =>
            _animatedPage(state, const NewSemesterPage()),
      ),
      GoRoute(
        path: '/files/:fileId/commit',
        pageBuilder: (context, state) => _animatedPage(
          state,
          CommitPage(
            fileId: state.pathParameters['fileId'] ?? '',
            args: state.extra is CommitArgs ? state.extra as CommitArgs : null,
          ),
        ),
      ),
      GoRoute(
        path: '/files/:fileId/edit',
        pageBuilder: (context, state) => _animatedPage(
          state,
          EditPage(
            fileId: state.pathParameters['fileId'] ?? '',
            baseCommitId: int.tryParse(
              state.uri.queryParameters['commit'] ?? '',
            ),
          ),
        ),
      ),
      // No bottom bar on Edit profile (AGENTS.md section 14).
      GoRoute(
        path: '/profile/edit',
        pageBuilder: (context, state) =>
            _animatedPage(state, const EditProfilePage()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNav(navigationShell: navigationShell),
        branches: [
          // Branch 0: Cloud backup.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cloud',
                pageBuilder: (context, state) =>
                    _animatedPage(state, const CloudPage()),
              ),
            ],
          ),
          // Branch 1: Subjects and the screens nested below them.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/subjects',
                pageBuilder: (context, state) =>
                    _animatedPage(state, const SubjectsPage()),
              ),
              GoRoute(
                path: '/subjects/:subjectId/activities',
                pageBuilder: (context, state) => _animatedPage(
                  state,
                  ActivitiesPage(
                    subjectId: state.pathParameters['subjectId'] ?? '',
                  ),
                ),
              ),
              GoRoute(
                path: '/activities/:activityId',
                pageBuilder: (context, state) => _animatedPage(
                  state,
                  ActivityFilesPage(
                    activityId: state.pathParameters['activityId'] ?? '',
                  ),
                ),
              ),
              GoRoute(
                path: '/files/:fileId/history',
                pageBuilder: (context, state) => _animatedPage(
                  state,
                  VersionHistoryPage(
                    fileId: state.pathParameters['fileId'] ?? '',
                  ),
                ),
              ),
            ],
          ),
          // Branch 2: Home, Search, and All activities.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) =>
                    _animatedPage(state, const HomePage()),
              ),
              GoRoute(
                path: '/search',
                pageBuilder: (context, state) =>
                    _animatedPage(state, const SearchPage()),
              ),
              GoRoute(
                path: '/activities',
                pageBuilder: (context, state) => _animatedPage(
                  state,
                  AllActivitiesPage(
                    initialFilter: state.uri.queryParameters['filter'] == 'due'
                        ? 'due_soon'
                        : null,
                  ),
                ),
              ),
            ],
          ),
          // Branch 3: Calendar.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                pageBuilder: (context, state) =>
                    _animatedPage(state, const CalendarPage()),
              ),
            ],
          ),
          // Branch 4: Profile.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) =>
                    _animatedPage(state, const ProfilePage()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

CustomTransitionPage<void> _animatedPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.025),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
