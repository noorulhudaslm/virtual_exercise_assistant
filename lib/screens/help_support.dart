import 'package:flutter/material.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4A47E8), // Deep blue
              Color(0xFF00D4AA), // Teal
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
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
                    const Text(
                      'Help & Support',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      
                      // FAQ Section
                      const Text(
                        'FREQUENTLY ASKED',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      _buildFAQCard(
                        icon: Icons.help_outline,
                        question: 'How do I start a workout?',
                        answer: 'Navigate to the workout section and select your preferred routine. Tap "Start Workout" to begin.',
                        context: context,
                      ),
                      
                      _buildFAQCard(
                        icon: Icons.notifications_outlined,
                        question: 'How do I enable notifications?',
                        answer: 'Go to Settings > Notifications and toggle on "Receive workout reminders".',
                        context: context,
                      ),
                      
                      _buildFAQCard(
                        icon: Icons.sync_outlined,
                        question: 'How do I sync my data?',
                        answer: 'Your workout data automatically syncs when you\'re connected to the internet.',
                        context: context,
                      ),
                      
                      _buildFAQCard(
                        icon: Icons.dark_mode_outlined,
                        question: 'Can I change the app theme?',
                        answer: 'Yes! Go to Settings and toggle "Dark Mode" to switch between light and dark themes.',
                        context: context,
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Contact Section
                      const Text(
                        'CONTACT US',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      _buildContactCard(
                        icon: Icons.email_outlined,
                        title: 'Email Support',
                        subtitle: 'support@workoutapp.com',
                        onTap: () {
                          // Handle email tap
                        },
                      ),
                      
                      _buildContactCard(
                        icon: Icons.chat_outlined,
                        title: 'Live Chat',
                        subtitle: 'Available 24/7',
                        onTap: () {
                          // Handle chat tap
                        },
                      ),
                      
                      _buildContactCard(
                        icon: Icons.phone_outlined,
                        title: 'Phone Support',
                        subtitle: '+1 (555) 123-4567',
                        onTap: () {
                          // Handle phone tap
                        },
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Other Options
                      const Text(
                        'OTHER',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      _buildOptionCard(
                        icon: Icons.article_outlined,
                        title: 'User Guide',
                        subtitle: 'Complete guide to using the app',
                        onTap: () {
                          // Handle user guide tap
                        },
                      ),
                      
                      _buildOptionCard(
                        icon: Icons.bug_report_outlined,
                        title: 'Report a Bug',
                        subtitle: 'Help us improve the app',
                        onTap: () {
                          // Handle bug report tap
                        },
                      ),
                      
                      _buildOptionCard(
                        icon: Icons.star_outline,
                        title: 'Rate Our App',
                        subtitle: 'Share your experience',
                        onTap: () {
                          // Handle rating tap
                        },
                      ),
                      
                      _buildOptionCard(
                        icon: Icons.policy_outlined,
                        title: 'Privacy Policy',
                        subtitle: 'How we protect your data',
                        onTap: () {
                          // Handle privacy policy tap
                        },
                      ),
                      
                      const SizedBox(height: 100), // Bottom padding
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

  Widget _buildFAQCard({
    required IconData icon,
    required String question,
    required String answer,
    required BuildContext context,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        leading: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
        title: Text(
          question,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.white.withOpacity(0.6),
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.white.withOpacity(0.6),
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }
}