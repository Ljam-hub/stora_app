String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) return 'Email is required';
  final regex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,}$');
  if (!regex.hasMatch(value.trim())) {
    return 'Please enter a valid email address';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Password is required';
  if (value.length < 6) return 'Password must be at least 6 characters';
  return null;
}
