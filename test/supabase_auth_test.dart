import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtrack/features/auth/auth_service.dart';
import 'package:subtrack/features/auth/supabase_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

void main() {
  group('authErrorMessage', () {
    test('explains wrong credentials', () {
      final message = authErrorMessage(
        const supa.AuthApiException('Invalid login credentials'),
      );
      expect(message, 'Wrong email or password.');
    });

    test('explains an unconfirmed email', () {
      final message = authErrorMessage(
        const supa.AuthApiException('Email not confirmed'),
      );
      expect(message, 'Confirm your email first — check your inbox.');
    });

    test('explains a duplicate account', () {
      final message = authErrorMessage(
        const supa.AuthApiException('User already registered'),
      );
      expect(message, contains('already exists'));
    });

    test('explains rate limiting', () {
      final message = authErrorMessage(
        const supa.AuthApiException('Rate limit exceeded'),
      );
      expect(message, contains('Too many attempts'));
    });

    test('explains a too-short password', () {
      final message = authErrorMessage(
        const supa.AuthApiException(
          'Password should be at least 6 characters.',
        ),
      );
      expect(message, 'Passwords need at least 6 characters.');
    });

    test('explains a failed account row (username collision)', () {
      final message = authErrorMessage(
        const supa.AuthApiException('Database error saving new user'),
      );
      expect(message, contains('username may be taken'));
    });

    test('explains a network failure', () {
      expect(
        authErrorMessage(const SocketException('offline')),
        contains('No internet connection'),
      );
      expect(
        authErrorMessage(supa.AuthRetryableFetchException()),
        contains('No internet connection'),
      );
    });

    test('explains a missing profiles table', () {
      final message = authErrorMessage(
        const supa.PostgrestException(
          message: 'relation does not exist',
          code: '42P01',
        ),
      );
      expect(message, contains('Cloud setup is incomplete'));
    });

    test('falls back to a generic message', () {
      expect(
        authErrorMessage(Exception('mystery')),
        'Something went wrong. Try again.',
      );
    });
  });

  group('resolveSignInEmail', () {
    test('passes email-shaped input through', () async {
      final email = await resolveSignInEmail(
        ' Maria@School.edu ',
        (username) => throw StateError('must not query for emails'),
      );
      expect(email, 'Maria@School.edu');
    });

    test('resolves a username through the lookup', () async {
      final queried = <String>[];
      final email = await resolveSignInEmail(' Maria_01 ', (username) {
        queried.add(username);
        return Future.value('maria@school.edu');
      });
      expect(email, 'maria@school.edu');
      expect(queried, ['maria_01']);
    });

    test('rejects a username nobody registered', () async {
      await expectLater(
        resolveSignInEmail('ghost', (username) => Future.value(null)),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'No account uses that username.',
          ),
        ),
      );
    });
  });

  group('SupabaseAuthService', () {
    SupabaseAuthService service(SharedPreferences prefs) {
      return SupabaseAuthService(
        // Constructing the client never touches the network.
        supa.SupabaseClient('https://example.supabase.co', 'anon'),
        prefs,
      );
    }

    test('restores the mirrored user so the app can open offline', () async {
      SharedPreferences.setMockInitialValues({
        'subtrack_supabase_user_id': 'abc-123',
        'subtrack_supabase_user_email': 'maria@school.edu',
      });
      final prefs = await SharedPreferences.getInstance();
      final restored = service(prefs);
      expect(restored.currentUser?.id, 'abc-123');
      expect(restored.currentUser?.email, 'maria@school.edu');
    });

    test('without a mirror the user is signed out', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(service(prefs).currentUser, isNull);
    });

    test('sign-in rejects empty identifiers before any network call', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = service(prefs);
      await expectLater(
        auth.signIn(identifier: '   ', password: 'secret'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Enter your email or username.',
          ),
        ),
      );
      await expectLater(
        auth.signIn(identifier: 'maria', password: ''),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Enter your password.',
          ),
        ),
      );
      expect(auth.currentUser, isNull);
    });

    test('sign-up validates username, email, and password first', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = service(prefs);

      await expectLater(
        auth.signUp(email: 'm@x.io', username: 'no!', password: 'secret123'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Usernames use 3-20'),
          ),
        ),
      );
      await expectLater(
        auth.signUp(email: 'not-an-email', username: 'maria', password: 'a'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Enter a valid email address.',
          ),
        ),
      );
      await expectLater(
        auth.signUp(email: 'm@x.io', username: 'maria', password: ''),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Passwords need at least 6 characters.',
          ),
        ),
      );
      expect(auth.currentUser, isNull);
    });
  });
}
