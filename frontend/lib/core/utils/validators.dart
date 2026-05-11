/// Input validators used across all forms in the app.
library;

abstract final class Validators {
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required.';
    final re = RegExp(r'^[\w.+\-]+@[a-zA-Z\d\-]+(\.[a-zA-Z\d\-]+)*\.[a-zA-Z]{2,}$');
    if (!re.hasMatch(value.trim())) return 'Please enter a valid email address.';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < 8) return 'Password must be at least 8 characters.';
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) return 'Password must contain at least one letter.';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Password must contain at least one number.';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password.';
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required.';
    if (value.trim().length < 2) return 'Name must be at least 2 characters.';
    return null;
  }

  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required.';
    return null;
  }

  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) return 'Amount is required.';
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) return 'Please enter a valid amount.';
    if (parsed <= 0) return 'Amount must be greater than zero.';
    if (parsed > 9999999) return 'Amount is too large.';
    return null;
  }

  static String? optionalAmount(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional
    return amount(value);
  }

  static String? title(String? value) {
    if (value == null || value.trim().isEmpty) return 'Title is required.';
    if (value.trim().length > 100) return 'Title must be under 100 characters.';
    return null;
  }

  static String? optionalNote(String? value) {
    if (value != null && value.length > 300) return 'Note must be under 300 characters.';
    return null;
  }

  static String? categoryName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Category name is required.';
    if (value.trim().length > 50) return 'Name must be under 50 characters.';
    return null;
  }

  static String? emoji(String? value) {
    if (value == null || value.isEmpty) return 'Please select an emoji.';
    return null;
  }

  static String? personName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Person name is required.';
    return null;
  }

  static String? resetToken(String? value) {
    if (value == null || value.trim().isEmpty) return 'Token is required.';
    return null;
  }
}
