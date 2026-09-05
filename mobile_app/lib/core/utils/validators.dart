class Validators {
  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (trimmed.length > 30) {
      return 'Username cannot exceed 30 characters';
    }
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_-]+$');
    if (!usernameRegex.hasMatch(trimmed)) {
      return 'Only letters, numbers, hyphens, and underscores allowed';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final trimmed = value.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? validateServerUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Server URL is required';
    }
    final uri = Uri.tryParse(value.trim());
    if (uri == null || (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https'))) {
      return 'Must be a valid HTTP or HTTPS URL';
    }
    return null;
  }
}
