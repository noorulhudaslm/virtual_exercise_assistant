import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:virtual_exercise_assistant/screens/delete_account_screen.dart';
import '../auth/auth_services.dart';
import 'package:time/time.dart';

// You'll need to add this global navigator key to your main.dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
 

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _soundEnabled = true;
  final AuthServices _auth = AuthServices();
  

  TimeOfDay _reminderTime = TimeOfDay(hour: 9, minute: 0);
  Set<int> _selectedDays = {
    1,
    2,
    3,
    4,
    5,
    6,
    7,
  }; // All days selected by default
  bool _isEveryday = true;

  // Days of the week mapping
  final Map<int, String> _dayNames = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF5494DD),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        backgroundColor: const Color(0xFF5494DD),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _scheduleWorkoutReminders() {
    // For now, just show confirmation - you'll need to implement actual scheduling
    // with flutter_local_notifications or similar package
    print('Scheduling reminders for ${_reminderTime.format(context)}');
    print(
      'Selected days: ${_selectedDays.map((day) => _dayNames[day]).join(', ')}',
    );

    _showSuccessSnackBar(
      'Workout reminders set for ${_reminderTime.format(context)} on ${_isEveryday ? 'everyday' : _selectedDays.map((day) => _dayNames[day]).join(', ')}',
    );
  }

  void _cancelWorkoutReminders() {
    // Cancel all scheduled workout reminders
    print('Cancelling workout reminders');
    _showSuccessSnackBar('Workout reminders cancelled');

    // TODO: Implement actual notification cancellation
    // Example:
    // await flutterLocalNotificationsPlugin.cancelAll();
    // or cancel specific notification IDs:
    // for (int day in _selectedDays) {
    //   await flutterLocalNotificationsPlugin.cancel(day);
    // }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final displayName = user?.displayName ?? 'User';
    final email = user?.email ?? 'No email';

    return Scaffold(
      body: Container(
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
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Colors.white, Color(0xFF1BFFFF)],
                        ).createShader(bounds),
                        child: const Text(
                          'Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Settings Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Section
                      _buildSectionHeader('PROFILE'),
                      const SizedBox(height: 8),
                      _buildProfileCard(displayName, email),
                      const SizedBox(height: 24),

                      // App Preferences
                      _buildSectionHeader('PREFERENCES'),
                      const SizedBox(height: 8),
                      _buildSettingsCard([
                        _buildSwitchTile(
                          icon: Icons.notifications,
                          title: 'Notifications',
                          subtitle: 'Receive workout reminders',
                          value: _notificationsEnabled,
                          onChanged: (value) async {
                            if (value) {
                              // Show popup when enabling notifications
                              final result =
                                  await _showReminderSettingsDialog();
                              if (result == true) {
                                setState(() => _notificationsEnabled = value);
                                // Schedule the notifications here
                                _scheduleWorkoutReminders();
                              }
                            } else {
                              setState(() => _notificationsEnabled = value);
                              // Cancel existing notifications
                              _cancelWorkoutReminders();
                            }
                          },
                        ),
                        _buildDivider(),
                        _buildSwitchTile(
                          icon: Icons.dark_mode,
                          title: 'Dark Mode',
                          subtitle: 'Switch to dark theme',
                          value: _darkModeEnabled,
                          onChanged: (value) =>
                              setState(() => _darkModeEnabled = value),
                        ),
                        _buildDivider(),
                        _buildSwitchTile(
                          icon: Icons.volume_up,
                          title: 'Sound Effects',
                          subtitle: 'Play sounds during workouts',
                          value: _soundEnabled,
                          onChanged: (value) =>
                              setState(() => _soundEnabled = value),
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // Account Section
                      _buildSectionHeader('ACCOUNT'),
                      const SizedBox(height: 8),
                      _buildSettingsCard([
                        _buildActionTile(
                          icon: Icons.lock,
                          title: 'Change Password',
                          subtitle: 'Update your password',
                          onTap: () => _showChangePasswordDialog(context),
                        ),
                        _buildDivider(),
                        _buildActionTile(
                          icon: Icons.logout,
                          title: 'Logout',
                          subtitle: 'Sign out of your account',
                          onTap: () => _showLogoutDialog(context),
                          isDestructive: false,
                        ),
                        _buildDivider(),
                        _buildActionTile(
                          icon: Icons.delete_forever,
                          title: 'Delete Account',
                          subtitle: 'Permanently delete your account',
                          onTap: () => _showDeleteAccountDialog(context),
                          isDestructive: true,
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // Support Section
                      _buildSectionHeader('SUPPORT'),
                      const SizedBox(height: 8),
                      _buildSettingsCard([
                        _buildActionTile(
                          icon: Icons.help,
                          title: 'Help & Support',
                          subtitle: 'Get help with the app',
                          onTap: () => _showComingSoon('Help & Support'),
                        ),
                        _buildDivider(),
                        _buildActionTile(
                          icon: Icons.info,
                          title: 'About',
                          subtitle: 'App version and info',
                          onTap: () => _showAboutDialog(context),
                        ),
                      ]),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white.withOpacity(0.8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildProfileCard(String name, String email) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5494DD), Color(0xFF1BFFFF)],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () => _showEditProfileDialog(context),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final nameController = TextEditingController(
      text: _auth.currentUser?.displayName ?? '',
    );
    final emailController = TextEditingController(
      text: _auth.currentUser?.email ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E3192),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFF5494DD),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF5494DD)),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ],
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
              if (nameController.text.isNotEmpty) {
                try {
                  await _auth.updateDisplayName(nameController.text);
                  setState(() {});
                  Navigator.pop(context);
                  _showSuccessSnackBar('Profile updated successfully');
                } catch (e) {
                  _showErrorSnackBar('Failed to update profile');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5494DD),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF5494DD).withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF1BFFFF),
            activeTrackColor: const Color(0xFF1BFFFF).withOpacity(0.3),
            inactiveThumbColor: Colors.white.withOpacity(0.5),
            inactiveTrackColor: Colors.white.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive
                    ? Colors.red.withOpacity(0.2)
                    : const Color(0xFF5494DD).withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red.shade300 : Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive ? Colors.red.shade300 : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDestructive
                          ? Colors.red.shade300.withOpacity(0.7)
                          : Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isDestructive
                  ? Colors.red.shade300.withOpacity(0.7)
                  : Colors.white.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 1,
      color: Colors.white.withOpacity(0.1),
    );
  }

  Future<bool?> _showReminderSettingsDialog() async {
    TimeOfDay? tempTime = _reminderTime;
    Set<int> tempSelectedDays = Set.from(_selectedDays);
    bool tempIsEveryday = _isEveryday;
    

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2E3192),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              title: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF5494DD), Color(0xFF1BFFFF)],
                ).createShader(bounds),
                child: const Text(
                  'Set Workout Reminder',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time Picker Section
                    const Text(
                      'Reminder Time',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          
                          initialTime: tempTime ?? TimeOfDay.now(),
                          builder: (BuildContext context, Widget? child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Color(0xFF5494DD),
                                  onPrimary: Colors.white,
                                  surface: Color(0xFF2E3192),
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            tempTime = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          border: Border.all(
                            color: const Color(0xFF5494DD).withOpacity(0.5),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: const Color(0xFF1BFFFF),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              tempTime!.format(context),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Day Selection Section
                    const Text(
                      'Reminder Days',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Everyday toggle
                    Theme(
                      data: Theme.of(context).copyWith(
                        checkboxTheme: CheckboxThemeData(
                          fillColor: MaterialStateProperty.resolveWith<Color>((
                            states,
                          ) {
                            if (states.contains(MaterialState.selected)) {
                              return const Color(0xFF5494DD);
                            }
                            return Colors.transparent;
                          }),
                          checkColor: MaterialStateProperty.all(Colors.white),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                      child: CheckboxListTile(
                        title: const Text(
                          'Everyday',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value: tempIsEveryday,
                        onChanged: (value) {
                          setDialogState(() {
                            tempIsEveryday = value!;
                            if (tempIsEveryday) {
                              tempSelectedDays = {1, 2, 3, 4, 5, 6, 7};
                            } else {
                              tempSelectedDays.clear();
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF5494DD),
                      ),
                    ),

                    // Individual day selection (only show if not everyday)
                    if (!tempIsEveryday) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Select specific days:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(7, (index) {
                        final dayNumber = index + 1;
                        return Theme(
                          data: Theme.of(context).copyWith(
                            checkboxTheme: CheckboxThemeData(
                              fillColor:
                                  MaterialStateProperty.resolveWith<Color>((
                                    states,
                                  ) {
                                    if (states.contains(
                                      MaterialState.selected,
                                    )) {
                                      return const Color(0xFF5494DD);
                                    }
                                    return Colors.transparent;
                                  }),
                              checkColor: MaterialStateProperty.all(
                                Colors.white,
                              ),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ),
                          child: CheckboxListTile(
                            title: Text(
                              _dayNames[dayNumber]!,
                              style: const TextStyle(color: Colors.white),
                            ),
                            value: tempSelectedDays.contains(dayNumber),
                            onChanged: (value) {
                              setDialogState(() {
                                if (value!) {
                                  tempSelectedDays.add(dayNumber);
                                } else {
                                  tempSelectedDays.remove(dayNumber);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.only(left: 16),
                            activeColor: const Color(0xFF5494DD),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5494DD), Color(0xFF1BFFFF)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton(
                    onPressed: tempSelectedDays.isEmpty
                        ? null
                        : () {
                            // Save the settings
                            _reminderTime = tempTime!;
                            _selectedDays = tempSelectedDays;
                            _isEveryday = tempIsEveryday;
                            Navigator.of(context).pop(true);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Set Reminder',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  DateTime _nextInstanceOfTime(TimeOfDay time, int weekday) {
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // Find the next occurrence of the specified weekday
    while (scheduledDate.weekday != weekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  // Fixed Change Password Dialog Integration
  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChangePasswordDialog(
        auth: _auth,
        onSuccess: () => _showSuccessSnackBar('Password changed successfully'),
        onError: (error) => _showErrorSnackBar(error),
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
              try {
                final success = await _auth.signOut();
                if (success) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                  _showSuccessSnackBar('Logged out successfully');
                } else {
                  _showErrorSnackBar('Failed to logout. Please try again.');
                }
              } catch (e) {
                _showErrorSnackBar('An error occurred during logout.');
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

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E3192),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.withOpacity(0.3)),
        ),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DeleteAccountScreen()),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E3192),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        title: const Text(
          'About VEA',
          style: TextStyle(
            color: Color(0xFF5494DD),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Version: 1.0.0', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            const Text(
              'VEA - Virtual Exercise Assistant',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Your personal fitness companion',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5494DD),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Enhanced Change Password Dialog with better integration
class ChangePasswordDialog extends StatefulWidget {
  final AuthServices auth;
  final VoidCallback? onSuccess;
  final Function(String)? onError;

  const ChangePasswordDialog({
    Key? key,
    required this.auth,
    this.onSuccess,
    this.onError,
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
        style: TextStyle(color: Color(0xFF5494DD), fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPasswordField(
              'Current Password',
              currentPasswordController,
              _currentPasswordVisible,
              () => setState(
                () => _currentPasswordVisible = !_currentPasswordVisible,
              ),
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
              () => setState(
                () => _confirmPasswordVisible = !_confirmPasswordVisible,
              ),
            ),
            if (isLoading) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5494DD)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
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
      widget.onError?.call('Please enter your current password');
      return;
    }

    if (newPassword.isEmpty) {
      widget.onError?.call('Please enter a new password');
      return;
    }

    if (newPassword.length < 8) {
      widget.onError?.call('New password must be at least 8 characters');
      return;
    }

    // Enhanced password validation
    if (!_isPasswordComplex(newPassword)) {
      widget.onError?.call(
        'Password must contain at least one uppercase letter, one lowercase letter, and one number',
      );
      return;
    }

    if (newPassword != confirmPassword) {
      widget.onError?.call('New passwords do not match');
      return;
    }

    if (currentPassword == newPassword) {
      widget.onError?.call(
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
          widget.onSuccess?.call();
        } else {
          widget.onError?.call(
            'Failed to change password. Please check your current password.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        widget.onError?.call('An unexpected error occurred. Please try again.');
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
