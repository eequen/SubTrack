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

    test('falls back to a generic message', () {
      expect(
        authErrorMessage(Exception('mystery')),
        'Something went wrong. Try again.',
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

    test('rejects invalid input before any network call', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = service(prefs);
      await expectLater(
        auth.signIn(email: 'not-an-email', password: 'secret'),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        auth.signIn(email: 'maria@school.edu', password: ''),
        throwsA(isA<AuthException>()),
      );
      expect(auth.currentUser, isNull);
    });
  });
}
