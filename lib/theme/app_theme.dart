import 'package:flutter/material.dart';

class AppTheme {
  static final ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF5494DD),
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 56),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.symmetric(vertical: 16),
  );

  static final ButtonStyle secondaryButton = OutlinedButton.styleFrom(
    side: const BorderSide(color: Color(0xFF5494DD)),
    backgroundColor: Colors.transparent,
    foregroundColor: const Color(0xFF5494DD),
    minimumSize: const Size(double.infinity, 56),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.symmetric(vertical: 16),
  );

  static const TextStyle headlineStyle = TextStyle(
    color: Colors.white,
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );

  static TextStyle bodyStyle(BuildContext context) => TextStyle(
    color: Colors.grey[400],
    fontSize: 16,
    height: 1.5,
  );

  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const Color primaryColor = Color(0xFF5494DD);
}