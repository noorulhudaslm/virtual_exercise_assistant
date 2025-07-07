import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:camera/camera.dart';
import '../screens/bmi_calculator.dart';
import '../screens/calorie_counter.dart';
import '../screens/camera_screen_for_ai_recognition.dart';
import '../screens/settings.dart';
import '../screens/app_intro_screen.dart';
import '../auth/auth_services.dart';
import '../screens/help_support.dart';
import '../screens/exercise_list.dart';
import '../screens/workout_plan.dart';
import '../screens/diet_plan.dart';
import '../screens/exercise_history.dart';
import '../screens/video_analysis_screen.dart';
import '../services/change_password.dart' as change_password_service;
import '../screens/camera_screen_for_ai_recognition.dart';

class AppDrawer extends StatefulWidget {
  @override
  _AppDrawerState createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _isLoading = false;
  final AuthServices _auth = AuthServices();

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
            // Custom Drawer Header
            Container(
              height: 120,
              width: double.infinity,
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 40,
                bottom: 20,
              ),
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
                alignment: Alignment.centerLeft,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Color(0xFF1BFFFF)],
                  ).createShader(bounds),
                  child: const Text(
                    'VEA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
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
                      _showExerciseOptionsDialog(context);
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ExerciseHistoryScreen(),
                        ),
                      );
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
                  _buildDrawerItem(
                    context,
                    Icons.fitness_center,
                    'Workout Plan',
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WorkoutPlan(),
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
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HelpSupportPage(),
                      ),
                    );
                  }),

                  // Change Password option
                  _buildDrawerItem(context, Icons.lock, 'Change Password', () {
                    Navigator.pop(context);
                    _showChangePasswordDialog(context);
                  }),

                  // Divider
                  _buildDivider(),

                  // Logout
                  _buildDrawerItem(
                    context,
                    Icons.logout,
                    'Logout',
                    () => _showLogoutDialog(context),
                    isLogout: true,
                  ),

                  const SizedBox(height: 25),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    );
  }

  void _showExerciseOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 700, maxWidth: 400),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4A5FBF), Color(0xFF3B4FB8)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Choose Your\nWorkout Method',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select exercises from our curated list, use AI recognition, or upload a video for analysis.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _buildExerciseOptionButton(
                      context,
                      'Browse Exercise List',
                      Icons.list_alt,
                      [Color(0xFF5494DD), Color(0xFF4A84C7)],
                      () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ExerciseListScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildExerciseOptionButton(
                      context,
                      'Use AI Recognition',
                      Icons.camera_alt,
                      [Color(0xFF00E5FF), Color(0xFF00B8CC)],
                      () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CameraScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildExerciseOptionButton(
                      context,
                      'Upload Video Analysis',
                      Icons.video_library,
                      [Color.fromARGB(255, 109, 149, 209), Color.fromARGB(255, 84, 162, 235)],
                      _isLoading ? null : () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const VideoAnalysisScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExerciseOptionButton(
    BuildContext context,
    String label,
    IconData icon,
    List<Color> gradientColors,
    VoidCallback? onPressed,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }

  Future<void> _openAIRecognitionCamera(BuildContext context) async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);

    try {
      final cameras = await availableCameras();

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (cameras.isEmpty) {
        _showSnackBar(context, 'No cameras available on this device', isError: true);
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CameraScreen(
              // Add your camera screen parameters here
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(context, 'Error accessing camera: $e', isError: true);
      }
    }
  }

  Future<void> _openVideoAnalysis(BuildContext context) async {
    if (!mounted) return;
    
    try {
      setState(() => _isLoading = true);

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const VideoAnalysisScreen()),
      );
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, 'Error opening video analysis: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => change_password_service.ChangePasswordDialog(
        auth: _auth,
        onSuccess: () => _showSnackBar(context, 'Password changed successfully'),
        onError: (error) => _showSnackBar(context, error, isError: true),
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
              Navigator.pop(context);
              
              final success = await _auth.signOut();
              
              if (mounted) {
                if (success) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                    (route) => false,
                  );
                  _showSnackBar(context, 'Logged out successfully');
                } else {
                  _showSnackBar(context, 'Failed to logout. Please try again.', isError: true);
                }
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

  // Unified snackbar method
  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF5494DD),
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