import 'package:flutter/material.dart';
import 'dart:async';
import '../auth/auth_services.dart';
import 'app_intro_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String username;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.username,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final AuthServices _authServices = AuthServices();
  Timer? _timer;
  bool _isResendingEmail = false;
  bool _canResendEmail = true;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    _startEmailVerificationCheck();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startEmailVerificationCheck() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _checkEmailVerification();
    });
  }

  Future<void> _checkEmailVerification() async {
    try {
      final isVerified = await _authServices.checkEmailVerification();
      if (isVerified && mounted) {
        _timer?.cancel();
        _showSnackBar('Email verified successfully!', isError: false);

        // Navigate to app intro screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AppIntroScreen()),
        );
      }
    } catch (e) {
      print('Error checking email verification: $e');
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResendEmail) return;

    setState(() {
      _isResendingEmail = true;
    });

    try {
      await _authServices.resendVerificationEmail();
      _showSnackBar('Verification email sent successfully!', isError: false);

      // Start countdown for resend button
      setState(() {
        _canResendEmail = false;
        _resendCountdown = 60;
      });

      _startResendCountdown();
    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    } finally {
      setState(() {
        _isResendingEmail = false;
      });
    }
  }

  void _startResendCountdown() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        setState(() {
          _canResendEmail = true;
        });
        timer.cancel();
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _goBack() {
    _timer?.cancel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _goBack,
                    ),
                  ],
                ),
              ),

              // Main Content - Wrapped in Expanded and SingleChildScrollView
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height - 
                                MediaQuery.of(context).padding.top - 
                                MediaQuery.of(context).padding.bottom - 
                                80, // Account for app bar height
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20), // Add some top spacing

                          // Email Icon
                          Container(
                            padding: const EdgeInsets.all(20), // Reduced padding
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.email_outlined,
                              size: 50, // Reduced size
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 24), // Reduced spacing

                          // Title
                          const Text(
                            'Verify Your Email',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26, // Slightly smaller
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),

                          const SizedBox(height: 12), // Reduced spacing

                          // Description
                          Text(
                            'Hi ${widget.username}! We\'ve sent a verification link to:',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15, // Slightly smaller
                              color: Colors.white.withOpacity(0.9),
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Email address
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              widget.email,
                              style: const TextStyle(
                                fontSize: 15, // Slightly smaller
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20), // Reduced spacing

                          Text(
                            'Please check your email and click the verification link to activate your account.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13, // Slightly smaller
                              color: Colors.white.withOpacity(0.8),
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 24), // Reduced spacing

                          // Resend Email Button
                          ElevatedButton(
                            onPressed: _canResendEmail && !_isResendingEmail
                                ? _resendVerificationEmail
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5494DD),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14), // Reduced padding
                              minimumSize: const Size(double.infinity, 50), // Reduced height
                            ),
                            child: _isResendingEmail
                                ? const SizedBox(
                                    height: 18, // Reduced size
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _canResendEmail
                                        ? 'RESEND EMAIL'
                                        : 'RESEND IN ${_resendCountdown}s',
                                    style: const TextStyle(
                                      fontSize: 15, // Slightly smaller
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),

                          const SizedBox(height: 16),

                          // Instructions
                          Container(
                            padding: const EdgeInsets.all(14), // Reduced padding
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.white.withOpacity(0.7),
                                      size: 18, // Reduced size
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Tips:',
                                      style: TextStyle(
                                        fontSize: 13, // Smaller font
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6), // Reduced spacing
                                Text(
                                  '• Check your spam/junk folder if you don\'t see the email\n• The verification link expires in 24 hours\n• You can request a new link anytime',
                                  style: TextStyle(
                                    fontSize: 11, // Smaller font
                                    color: Colors.white.withOpacity(0.7),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24), // Reduced spacing

                          // Auto-checking indicator
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 14, // Reduced size
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10), // Reduced spacing
                              Text(
                                'Checking verification status...',
                                style: TextStyle(
                                  fontSize: 13, // Smaller font
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20), // Bottom spacing
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}