class Validators {
  Validators._();

  static final _emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');

  // Letters, numbers, underscores, 3-20 chars.
  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
    final hasDigit = RegExp(r'\d').hasMatch(value);
    if (!hasLetter || !hasDigit) {
      return 'Password must contain letters and numbers';
    }
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) return 'Username is required';
    if (!_usernameRegex.hasMatch(value.trim())) {
      return '3-20 chars: letters, numbers, underscores only';
    }
    return null;
  }

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }
}
