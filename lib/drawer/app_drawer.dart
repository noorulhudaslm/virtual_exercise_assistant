import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/bmi_calculator.dart';
import '../services/calorie_counter.dart';
import '../screens/camera_screen_for_ai_recognition.dart';
import '../screens/settings.dart';
import '../screens/app_intro_screen.dart';
import '../auth/auth_services.dart';
import '../screens/help_support.dart';
import '../screens/exercise_list.dart';
import '../screens/homepage.dart';
import '../screens/diet_plan.dart';

class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF2E3192), // Deep purple
              Color(0xFF1BFFFF), // Cyan
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Custom Drawer Header - Fixed height with proper padding
            Container(
              height: 120, // Increased height
              width: double.infinity,
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 40,
                bottom: 20,
              ), // Added top padding for status bar
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2E3192).withOpacity(0.9),
                    const Color(0xFF5494DD).withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Align(
                alignment: Alignment
                    .centerLeft, // Changed from bottomLeft to centerLeft
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Color(0xFF1BFFFF)],
                  ).createShader(bounds),
                  child: const Text(
                    'VEA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30, // Increased font size
                      fontWeight: FontWeight.bold,
                      letterSpacing: 5,
                    ),
                  ),
                ),
              ),
            ),

            // Scrollable content
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Home
                  _buildDrawerItem(context, Icons.home, 'Home', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AppIntroScreen()),
                    );
                  }),

                  // Fitness Section
                  _buildSectionHeader('FITNESS'),
                  _buildDrawerItem(
                    context,
                    Icons.camera_alt,
                    'Start Workout',
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExerciseListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.fitness_center,
                    'Exercise List',
                    () {
                      Navigator.pop(context);
                      _showAllExercises(context);
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.history,
                    'Workout History',
                    () {
                      Navigator.pop(context);
                      _showComingSoon(context, 'Workout History');
                    },
                  ),

                  // Health Section
                  _buildSectionHeader('HEALTH'),
                  _buildDrawerItem(
                    context,
                    Icons.calculate,
                    'BMI Calculator',
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BMICalculator(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.restaurant,
                    'Calorie Counter',
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CalorieCounter(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.restaurant_menu,
                    'Diet Plan',
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DietPlan(),
                        ),
                      );
                    },
                  ),

                  // Settings Section
                  _buildSectionHeader('MORE'),
                  _buildDrawerItem(context, Icons.settings, 'Settings', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsPage()),
                    );
                  }),
                  _buildDrawerItem(context, Icons.help, 'Help & Support', () {
                    Navigator.pop(context); // Close the drawer first
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HelpSupportPage(),
                      ),
                    );
                  }),

                  // Add Change Password option
                  _buildDrawerItem(context, Icons.lock, 'Change Password', () {
                    Navigator.pop(context);
                    _showChangePasswordDialog(context);
                  }),

                  // Divider
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),

                  // Logout
                  _buildDrawerItem(
                    context,
                    Icons.logout,
                    'Logout',
                    () => _showLogoutDialog(context),
                    isLogout: true,
                  ),

                  // Add bottom padding to prevent overflow
                  const SizedBox(height: 25),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 16, 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white.withOpacity(0.7),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withOpacity(0.05),
      ),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isLogout
                ? Colors.red.withOpacity(0.2)
                : const Color(0xFF5494DD).withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: isLogout ? Colors.red.shade300 : Colors.white,
            size: 18,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isLogout ? Colors.red.shade300 : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        minVerticalPadding: 0,
        dense: true,
      ),
    );
  }

  // Fixed Change Password Dialog with proper overflow handling
  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E3192),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        // Add this to prevent overflow
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
        contentPadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(20),
          child: const Text(
            'Change Password',
            style: TextStyle(
              color: Color(0xFF5494DD),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        content: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Current Password
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF5494DD)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // New Password
              TextField(
                controller: newPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF5494DD)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Confirm Password
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF5494DD)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // Add password change logic here
                    if (newPasswordController.text !=
                        confirmPasswordController.text) {
                      _showErrorSnackBar(context, 'Passwords do not match');
                      return;
                    }

                    Navigator.pop(context);
                    _showSuccessSnackBar(
                      context,
                      'Password changed successfully',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5494DD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Change',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E3192),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        title: const Text(
          'Logout',
          style: TextStyle(
            color: Color(0xFF5494DD),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog first

              // Create AuthServices instance
              final authServices = AuthServices();

              // Attempt to sign out
              final success = await authServices.signOut();

              if (success) {
                // Navigate to homepage and clear all routes
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home', // Change this to your homepage route name
                  (route) => false, // Remove all previous routes
                );

                _showSuccessSnackBar(context, 'Logged out successfully');
              } else {
                _showErrorSnackBar(
                  context,
                  'Failed to logout. Please try again.',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5494DD),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Helper method to show error messages - now accepts context parameter
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Updated success snackbar method to accept context parameter
  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF5494DD),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showAllExercises(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E3192),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        title: const Text(
          'Supported Exercises',
          style: TextStyle(
            color: Color(0xFF5494DD),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _ExerciseItem('• Squats'),
              _ExerciseItem('• Deadlifts'),
              _ExerciseItem('• Bicep Curls'),
              _ExerciseItem('• Tricep Pushdowns'),
              _ExerciseItem('• Bench Press'),
              _ExerciseItem('• Lat Pulldowns'),
              _ExerciseItem('• Push ups'),
              _ExerciseItem('• Pull ups'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF5494DD),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        backgroundColor: const Color(0xFF5494DD),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ExerciseItem extends StatelessWidget {
  final String text;
  const _ExerciseItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.3),
      ),
    );
  }
}
