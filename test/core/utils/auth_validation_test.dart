import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/utils/auth_validation.dart';

void main() {
  group('email', () {
    test('accepts well-formed addresses in any case', () {
      expect(AuthValidation.email('me@example.com'), isNull);
      expect(AuthValidation.email('  Me@Example.COM '), isNull);
    });

    test('rejects malformed addresses', () {
      for (final value in ['', 'me', 'me@', 'me@example', 'a b@c.d', null]) {
        expect(AuthValidation.email(value), isNotNull, reason: '$value');
      }
    });

    test('normalizes by trimming and lowercasing', () {
      expect(
        AuthValidation.normalizeEmail('  Me@Example.COM '),
        'me@example.com',
      );
    });
  });

  group('password', () {
    test('requires at least 8 characters', () {
      expect(AuthValidation.password('1234567'), isNotNull);
      expect(AuthValidation.password('12345678'), isNull);
      expect(AuthValidation.password(null), isNotNull);
    });

    test('must match its confirmation exactly', () {
      expect(AuthValidation.confirmPassword('password1', 'password1'), isNull);
      expect(
        AuthValidation.confirmPassword('password1', 'Password1'),
        isNotNull,
      );
      expect(AuthValidation.confirmPassword('password1', ''), isNotNull);
    });
  });

  group('username', () {
    test('accepts 3-30 letters, digits and underscores', () {
      expect(AuthValidation.username('abc'), isNull);
      expect(AuthValidation.username('a_1'), isNull);
      expect(AuthValidation.username('a' * 30), isNull);
    });

    test('is case-insensitive because it is lowercased before sending', () {
      expect(AuthValidation.username('MyName_1'), isNull);
      expect(AuthValidation.normalizeUsername(' MyName_1 '), 'myname_1');
    });

    test('rejects short, long and special-character names', () {
      for (final value in ['ab', 'a' * 31, 'my-name', 'my name', 'né', '']) {
        expect(AuthValidation.username(value), isNotNull, reason: value);
      }
    });
  });

  test('display name must not be blank', () {
    expect(AuthValidation.displayName('  '), isNotNull);
    expect(AuthValidation.displayName(null), isNotNull);
    expect(AuthValidation.displayName('Ada'), isNull);
  });
}
