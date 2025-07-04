import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Abstract class to define the auth interface
abstract class AuthService {
  Future<bool> changePassword(String currentPassword, String newPassword);
}

class ChangePasswordDialog extends StatefulWidget {
  final AuthService auth;

  const ChangePasswordDialog({
    Key? key,
    required this.auth,
  }) : super(key: key);

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isLoading = false;
  bool _currentPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF5494DD),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2E3192),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      title: const Text(
        'Change Password',
        style: TextStyle(
          color: Color(0xFF5494DD),
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPasswordField(
              'Current Password',
              currentPasswordController,
              _currentPasswordVisible,
              () => setState(() => _currentPasswordVisible = !_currentPasswordVisible),
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              'New Password',
              newPasswordController,
              _newPasswordVisible,
              () => setState(() => _newPasswordVisible = !_newPasswordVisible),
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              'Confirm Password',
              confirmPasswordController,
              _confirmPasswordVisible,
              () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
            ),
            if (isLoading) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xFF5494DD),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : _handlePasswordChange,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5494DD),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            isLoading ? 'Changing...' : 'Change',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller,
    bool isVisible,
    VoidCallback onToggleVisibility,
  ) {
    return TextField(
      controller: controller,
      obscureText: !isVisible,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 12,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF5494DD)),
          borderRadius: BorderRadius.circular(8),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility_off : Icons.visibility,
            color: Colors.white.withOpacity(0.7),
            size: 20,
          ),
          onPressed: onToggleVisibility,
        ),
      ),
    );
  }

  Future<void> _handlePasswordChange() async {
    final currentPassword = currentPasswordController.text.trim();
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    // Validation
    if (currentPassword.isEmpty) {
      _showErrorSnackBar('Please enter your current password');
      return;
    }

    if (newPassword.isEmpty) {
      _showErrorSnackBar('Please enter a new password');
      return;
    }

    if (newPassword.length < 8) {
      _showErrorSnackBar('New password must be at least 8 characters');
      return;
    }

    // Enhanced password validation
    if (!_isPasswordComplex(newPassword)) {
      _showErrorSnackBar(
        'Password must contain at least one uppercase letter, one lowercase letter, and one number',
      );
      return;
    }

    if (newPassword != confirmPassword) {
      _showErrorSnackBar('New passwords do not match');
      return;
    }

    if (currentPassword == newPassword) {
      _showErrorSnackBar(
        'New password must be different from current password',
      );
      return;
    }

    // Set loading state
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final success = await widget.auth.changePassword(
        currentPassword,
        newPassword,
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          _showSuccessSnackBar('Password changed successfully');
        } else {
          _showErrorSnackBar(
            'Failed to change password. Please check your current password.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('An unexpected error occurred. Please try again.');
      }
    } finally {
      // Reset loading state
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  bool _isPasswordComplex(String password) {
    // Check for at least one uppercase letter, one lowercase letter, and one number
    return password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[0-9]'));
  }

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}

// Example usage:
class ExampleAuthService implements AuthService {
  @override
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));
    // Return true for success, false for failure
    return currentPassword == "oldpassword123"; // Mock validation
  }
}

// How to use the dialog:
void showChangePasswordDialog(BuildContext context, AuthService authService) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => ChangePasswordDialog(auth: authService),
  );
}