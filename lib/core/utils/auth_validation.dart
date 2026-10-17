abstract final class AuthValidation {
  static const minPasswordLength = 8;
  static const maxUsernameLength = 30;

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _usernamePattern = RegExp(r'^[a-z0-9_]{3,30}$');

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static String normalizeUsername(String value) => value.trim().toLowerCase();

  static String? email(String? value) =>
      _emailPattern.hasMatch(normalizeEmail(value ?? ''))
      ? null
      : 'Enter a valid email address';

  static String? password(String? value) =>
      (value ?? '').length >= minPasswordLength
      ? null
      : 'Password must be at least $minPasswordLength characters';

  static String? confirmPassword(String? password, String? confirmation) =>
      password == confirmation ? null : 'Passwords do not match';

  static String? username(String? value) =>
      _usernamePattern.hasMatch(normalizeUsername(value ?? ''))
      ? null
      : 'Use 3-30 letters, numbers or underscores';

  static String? displayName(String? value) =>
      (value ?? '').trim().isEmpty ? 'Enter a display name' : null;
}
