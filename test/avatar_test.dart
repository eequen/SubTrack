import 'package:flutter_test/flutter_test.dart';
import 'package:subtrack/core/avatar.dart';

void main() {
  test('each pick gets a unique file name, so the image cache refreshes', () {
    final first = avatarFileName(
      'kent@gmail.com',
      '/tmp/photo.jpg',
      at: DateTime(2026, 10, 28, 10),
    );
    final second = avatarFileName(
      'kent@gmail.com',
      '/tmp/photo.jpg',
      at: DateTime(2026, 10, 28, 10, 0, 0, 0, 1),
    );

    expect(first, isNot(second));
    expect(first, endsWith('.jpg'));
    expect(first, startsWith('kent_gmail_com_'));
    expect(first, isNot(contains('@')));
  });

  test('the picked extension is kept, with .jpg as the fallback', () {
    expect(avatarFileName('u1', '/tmp/a.PNG'), endsWith('.png'));
    expect(avatarFileName('u1', '/tmp/photo'), endsWith('.jpg'));
  });
}
