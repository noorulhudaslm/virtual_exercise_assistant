import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class BenchPressAnalyzer {
  // Body type classifications for bench press optimization
  static const int NARROW_TORSO = 0;
  static const int AVERAGE_BUILD = 1;
  static const int WIDE_TORSO = 2;
  static const int LONG_ARMS = 3;
  static const int SHORT_ARMS = 4;

  // Voice feedback instance
  static FlutterTts? _flutterTts;
  static bool _isVoiceEnabled = true;
  static DateTime _lastVoiceFeedback = DateTime.now();
  static String _lastSpokenText = '';
  static bool _isSpeaking = false;

  // Body type specific ranges based on biomechanical research
  static Map<int, Map<String, double>> bodyTypeRanges = {
    NARROW_TORSO: {
      'elbowAngleMin': 60.0,
      'elbowAngleMax': 80.0,
      'elbowFlareMin': 30.0,
      'elbowFlareMax': 50.0,
      'gripWidthRatio': 1.3,
      'barPathTolerance': 15.0,
      'shoulderStabilityMin': 85.0,
    },
    AVERAGE_BUILD: {
      'elbowAngleMin': 70.0,
      'elbowAngleMax': 90.0,
      'elbowFlareMin': 40.0,
      'elbowFlareMax': 60.0,
      'gripWidthRatio': 1.5,
      'barPathTolerance': 20.0,
      'shoulderStabilityMin': 80.0,
    },
    WIDE_TORSO: {
      'elbowAngleMin': 75.0,
      'elbowAngleMax': 95.0,
      'elbowFlareMin': 50.0,
      'elbowFlareMax': 70.0,
      'gripWidthRatio': 1.7,
      'barPathTolerance': 25.0,
      'shoulderStabilityMin': 75.0,
    },
    LONG_ARMS: {
      'elbowAngleMin': 80.0,
      'elbowAngleMax': 100.0,
      'elbowFlareMin': 35.0,
      'elbowFlareMax': 55.0,
      'gripWidthRatio': 1.6,
      'barPathTolerance': 22.0,
      'shoulderStabilityMin': 80.0,
    },
    SHORT_ARMS: {
      'elbowAngleMin': 65.0,
      'elbowAngleMax': 85.0,
      'elbowFlareMin': 45.0,
      'elbowFlareMax': 65.0,
      'gripWidthRatio': 1.4,
      'barPathTolerance': 18.0,
      'shoulderStabilityMin': 85.0,
    },
  };

  static const List<String> bodyTypeNames = [
    'narrowTorso',
    'averageBuild',
    'wideTorso',
    'longArms',
    'shortArms',
  ];

  // Bench press specific constants
  static const double EXTENDED_ARM_ANGLE = 170.0;
  static const double CHEST_CONTACT_THRESHOLD = 25.0;
  static const double SCAPULAR_RETRACTION_THRESHOLD = 15.0;

  // Movement phases for bench press
  static const int PHASE_SETUP = 0;
  static const int PHASE_UNRACK = 1;
  static const int PHASE_DESCENT = 2;
  static const int PHASE_CHEST_PAUSE = 3;
  static const int PHASE_ASCENT = 4;
  static const int PHASE_LOCKOUT = 5;

  // Session tracking with enhanced stability
  static int _currentPhase = PHASE_SETUP;
  static int _repCount = 0;
  static double _previousElbowAngle = 180.0;
  static double _previousBarHeight = 0.0;
  static List<double> _elbowAngleHistory = [];
  static List<double> _barHeightHistory = [];
  static DateTime _lastPhaseChange = DateTime.now();
  static DateTime _lastFeedbackChange = DateTime.now();
  static String _lastFeedback = '';
  static Color _lastFeedbackColor = Colors.blue;
  static int _detectedBodyType = AVERAGE_BUILD;
  static bool _bodyTypeCalibrated = false;

  // Biomechanical measurements
  static double _torsoWidth = 0.0;
  static double _armLength = 0.0;
  static double _shoulderMobility = 0.0;
  static List<double> _anthropometricHistory = [];
  static List<double> _barPathHistory = [];

  // Enhanced feedback mapping for bench press
  static Map<String, String> _voiceFeedbackMap = {
    // Setup and positioning
    'Retract shoulder blades! Create stable base':
        'Retract your shoulder blades',
    'Keep shoulder blades pinched together': 'Keep shoulder blades pinched',
    'Maintain arch in lower back': 'Maintain your back arch',
    'Feet firmly planted on ground': 'Keep feet planted firmly',
    'Grip too narrow for your build!': 'Grip too narrow, widen it',
    'Grip too wide! Narrow your grip': 'Grip too wide, narrow it',

    // Bar path and movement
    'Bar drifting toward head! Control the path': 'Control the bar path',
    'Bar too low on chest! Aim for nipple line': 'Bring bar higher on chest',
    'Bar too high! Lower to chest level': 'Lower bar to chest level',
    'Perfect bar path! Keep it straight': 'Perfect bar path',
    'Touch chest gently, don\'t bounce': 'Touch chest gently',

    // Elbow and shoulder positioning
    'Elbows flared too wide! Injury risk': 'Elbows too wide, bring them in',
    'Elbows too tucked! Allow natural angle': 'Allow natural elbow angle',
    'Perfect elbow position for your build': 'Perfect elbow position',
    'Shoulders rolling forward! Stay tight': 'Keep shoulders back and tight',

    // Movement phases
    'Control the descent! Slow and steady': 'Control the descent',
    'Pause at chest, then drive up': 'Pause at chest, drive up',
    'Drive through heels! Engage legs': 'Drive through your heels',
    'Push bar in straight line to lockout': 'Push straight to lockout',
    'Excellent rep! Reset for next one': 'Excellent rep, reset',
    'Great lockout! Control the descent': 'Great lockout',

    // Safety and corrections
    'Maintain tension! Don\'t lose tightness': 'Maintain full body tension',
    'Head neutral! Don\'t crane neck': 'Keep head neutral',
    'Breathe at top! Don\'t hold breath': 'Breathe at the top',
    'Setup position optimal for your build': 'Perfect setup position',
  };

  // Initialize voice feedback system
  static Future<void> initializeVoiceFeedback() async {
    _flutterTts = FlutterTts();

    await _flutterTts!.setLanguage("en-US");
    await _flutterTts!.setSpeechRate(
      0.65,
    ); // Slightly slower for complex instructions
    await _flutterTts!.setVolume(0.8);
    await _flutterTts!.setPitch(1.0);

    _flutterTts!.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _flutterTts!.setErrorHandler((msg) {
      _isSpeaking = false;
      print("TTS Error: $msg");
    });
  }

  // Enhanced voice feedback with priority system
  static Future<void> _speakFeedback(
    String text, {
    bool isUrgent = false,
    bool isSafety = false,
  }) async {
    if (!_isVoiceEnabled || _flutterTts == null) return;

    DateTime now = DateTime.now();
    String voiceText = _voiceFeedbackMap[text] ?? text;

    // Priority system: Safety > Urgent > Normal
    int minInterval = isSafety ? 1500 : (isUrgent ? 3000 : 5000);

    if (!isSafety &&
        !isUrgent &&
        _lastSpokenText == voiceText &&
        now.difference(_lastVoiceFeedback).inMilliseconds < minInterval) {
      return;
    }

    if ((_isSpeaking && (isSafety || isUrgent)) ||
        (!_isSpeaking &&
            now.difference(_lastVoiceFeedback).inMilliseconds >= minInterval)) {
      if (isSafety && _isSpeaking) {
        await _flutterTts!.stop();
      }

      _isSpeaking = true;
      _lastSpokenText = voiceText;
      _lastVoiceFeedback = now;

      try {
        await _flutterTts!.speak(voiceText);
      } catch (e) {
        _isSpeaking = false;
        print("TTS Error: $e");
      }
    }
  }

  // Rep count announcements with motivation
  static Future<void> _announceRepCount(int count) async {
    if (count == 1) {
      await _speakFeedback("First rep complete", isUrgent: false);
    } else if (count == 5) {
      await _speakFeedback("5 reps! Strong work", isUrgent: false);
    } else if (count == 10) {
      await _speakFeedback("10 reps! Excellent strength", isUrgent: false);
    } else if (count % 5 == 0 && count > 10) {
      await _speakFeedback("$count reps! Outstanding", isUrgent: false);
    } else if (count <= 3) {
      await _speakFeedback("Rep $count complete", isUrgent: false);
    }
  }

  // Enhanced human detection for bench press position
  static bool _isInBenchPosition(Map<String, PoseLandmark?> landmarkMap) {
    List<String> requiredLandmarks = [
      'leftShoulder',
      'rightShoulder',
      'leftElbow',
      'rightElbow',
      'leftWrist',
      'rightWrist',
      'leftHip',
      'rightHip',
      'leftKnee',
      'rightKnee',
      'leftAnkle',
      'rightAnkle',
    ];

    for (String landmark in requiredLandmarks) {
      if (landmarkMap[landmark] == null) return false;
    }

    final leftShoulder = landmarkMap['leftShoulder']!;
    final rightShoulder = landmarkMap['rightShoulder']!;
    final leftHip = landmarkMap['leftHip']!;
    final rightHip = landmarkMap['rightHip']!;
    final leftKnee = landmarkMap['leftKnee']!;
    final rightKnee = landmarkMap['rightKnee']!;

    // Check if person is in lying position (shoulders roughly level with hips)
    double shoulderHipAngle = _calculateAngle(leftShoulder, leftHip, rightHip);
    if (shoulderHipAngle > 30) return false; // Too upright

    // Check if knees are bent (typical bench press foot position)
    double leftKneeAngle = _calculateAngle(
      leftHip,
      leftKnee,
      landmarkMap['leftAnkle']!,
    );
    double rightKneeAngle = _calculateAngle(
      rightHip,
      rightKnee,
      landmarkMap['rightAnkle']!,
    );

    if (leftKneeAngle > 160 || rightKneeAngle > 160)
      return false; // Legs too straight

    return true;
  }

  // Calculate angle between three points
  static double _calculateAngle(
    PoseLandmark point1,
    PoseLandmark point2,
    PoseLandmark point3,
  ) {
    double angle1 = math.atan2(point1.y - point2.y, point1.x - point2.x);
    double angle2 = math.atan2(point3.y - point2.y, point3.x - point2.x);
    double angle = (angle2 - angle1) * 180 / math.pi;
    return angle.abs() > 180 ? 360 - angle.abs() : angle.abs();
  }

  // Calculate distance between two points
  static double _calculateDistance(PoseLandmark point1, PoseLandmark point2) {
    return math.sqrt(
      math.pow(point1.x - point2.x, 2) + math.pow(point1.y - point2.y, 2),
    );
  }

  // Detect body type for bench press optimization
  static int _detectBodyType(Map<String, PoseLandmark> landmarks) {
    final leftShoulder = landmarks['leftShoulder']!;
    final rightShoulder = landmarks['rightShoulder']!;
    final leftElbow = landmarks['leftElbow']!;
    final rightElbow = landmarks['rightElbow']!;
    final leftWrist = landmarks['leftWrist']!;
    final rightWrist = landmarks['rightWrist']!;
    final leftHip = landmarks['leftHip']!;
    final rightHip = landmarks['rightHip']!;

    // Calculate key measurements
    double shoulderWidth = _calculateDistance(leftShoulder, rightShoulder);
    double hipWidth = _calculateDistance(leftHip, rightHip);
    double leftArmLength = _calculateDistance(leftShoulder, leftWrist);
    double rightArmLength = _calculateDistance(rightShoulder, rightWrist);
    double avgArmLength = (leftArmLength + rightArmLength) / 2;

    // Calculate torso measurements
    double leftTorsoLength = _calculateDistance(leftShoulder, leftHip);
    double rightTorsoLength = _calculateDistance(rightShoulder, rightHip);
    double avgTorsoLength = (leftTorsoLength + rightTorsoLength) / 2;

    // Store measurements
    _torsoWidth = shoulderWidth / hipWidth;
    _armLength = avgArmLength / avgTorsoLength;

    // Add to history for stability
    _anthropometricHistory.add(_armLength);
    if (_anthropometricHistory.length > 8) {
      _anthropometricHistory.removeAt(0);
    }

    if (_anthropometricHistory.length < 4) return AVERAGE_BUILD;

    double avgArmRatio =
        _anthropometricHistory.reduce((a, b) => a + b) /
        _anthropometricHistory.length;

    // Classification based on research
    if (_torsoWidth > 1.3 && avgArmRatio < 1.2) {
      return WIDE_TORSO;
    } else if (_torsoWidth < 1.1 && avgArmRatio < 1.3) {
      return NARROW_TORSO;
    } else if (avgArmRatio > 1.4) {
      return LONG_ARMS;
    } else if (avgArmRatio < 1.1) {
      return SHORT_ARMS;
    } else {
      return AVERAGE_BUILD;
    }
  }

  // Calculate bar path deviation (simulated from hand position)
  static double _calculateBarPath(
    PoseLandmark leftWrist,
    PoseLandmark rightWrist,
  ) {
    double barCenterX = (leftWrist.x + rightWrist.x) / 2;
    double barCenterY = (leftWrist.y + rightWrist.y) / 2;

    _barHeightHistory.add(barCenterY);
    if (_barHeightHistory.length > 5) {
      _barHeightHistory.removeAt(0);
    }

    // Calculate path deviation from vertical
    if (_barHeightHistory.length < 3) return 0.0;

    double pathDeviation = 0.0;
    for (int i = 1; i < _barHeightHistory.length; i++) {
      pathDeviation += (_barHeightHistory[i] - _barHeightHistory[i - 1]).abs();
    }

    return pathDeviation / (_barHeightHistory.length - 1);
  }

  // Calculate shoulder stability
  static double _calculateShoulderStability(
    PoseLandmark leftShoulder,
    PoseLandmark rightShoulder,
    PoseLandmark leftElbow,
    PoseLandmark rightElbow,
  ) {
    double shoulderLevel = (leftShoulder.y - rightShoulder.y).abs();
    double elbowLevel = (leftElbow.y - rightElbow.y).abs();

    // Lower values indicate better stability
    return shoulderLevel + elbowLevel;
  }

  // Enhanced feedback system with safety priorities
  static void _updateFeedback(
    String feedback,
    Color color,
    Function(String, Color) onFeedbackUpdate,
  ) {
    DateTime now = DateTime.now();

    bool isSafety = color == Colors.red;
    bool isUrgent = color == Colors.orange;

    if (feedback != _lastFeedback &&
        (isSafety ||
            now.difference(_lastFeedbackChange).inMilliseconds > 2500)) {
      _lastFeedback = feedback;
      _lastFeedbackColor = color;
      _lastFeedbackChange = now;
      onFeedbackUpdate(feedback, color);

      _speakFeedback(feedback, isUrgent: isUrgent, isSafety: isSafety);
    } else if (_lastFeedback.isNotEmpty) {
      onFeedbackUpdate(_lastFeedback, _lastFeedbackColor);
    }
  }

  // Main bench press analysis function
  static Map<String, dynamic> analyzeBenchPressForm(
    Pose pose,
    Function(String, Color) onFeedbackUpdate,
    Function(int) onRepCountUpdate,
  ) {
    final landmarks = pose.landmarks;

    // Create landmark map
    Map<String, PoseLandmark?> landmarkMap = {
      'leftShoulder': landmarks[PoseLandmarkType.leftShoulder],
      'rightShoulder': landmarks[PoseLandmarkType.rightShoulder],
      'leftElbow': landmarks[PoseLandmarkType.leftElbow],
      'rightElbow': landmarks[PoseLandmarkType.rightElbow],
      'leftWrist': landmarks[PoseLandmarkType.leftWrist],
      'rightWrist': landmarks[PoseLandmarkType.rightWrist],
      'leftHip': landmarks[PoseLandmarkType.leftHip],
      'rightHip': landmarks[PoseLandmarkType.rightHip],
      'leftKnee': landmarks[PoseLandmarkType.leftKnee],
      'rightKnee': landmarks[PoseLandmarkType.rightKnee],
      'leftAnkle': landmarks[PoseLandmarkType.leftAnkle],
      'rightAnkle': landmarks[PoseLandmarkType.rightAnkle],
      'nose': landmarks[PoseLandmarkType.nose],
    };

    // Check if person is in bench press position
    if (!_isInBenchPosition(landmarkMap)) {
      if (_currentPhase != PHASE_SETUP) {
        _currentPhase = PHASE_SETUP;
        _elbowAngleHistory.clear();
        _barHeightHistory.clear();
      }

      return {
        'phase': PHASE_SETUP,
        'repCount': _repCount,
        'formScore': 0,
        'bodyType': getBodyTypeName(_detectedBodyType),
        'humanPresent': false,
      };
    }

    // Check for critical landmarks
    List<String> criticalLandmarks = [
      'leftShoulder',
      'rightShoulder',
      'leftElbow',
      'rightElbow',
      'leftWrist',
      'rightWrist',
      'leftHip',
      'rightHip',
    ];

    for (String landmark in criticalLandmarks) {
      if (landmarkMap[landmark] == null) {
        _updateFeedback(
          'Position yourself in full view',
          Colors.blue,
          onFeedbackUpdate,
        );
        return {
          'phase': _currentPhase,
          'repCount': _repCount,
          'formScore': 0,
          'bodyType': getBodyTypeName(_detectedBodyType),
          'humanPresent': true,
        };
      }
    }

    // Create valid landmarks map
    Map<String, PoseLandmark> validLandmarks = {};
    landmarkMap.forEach((key, value) {
      if (value != null) validLandmarks[key] = value;
    });

    // Body type detection and adaptation
    if (!_bodyTypeCalibrated || _repCount % 3 == 0) {
      int previousBodyType = _detectedBodyType;
      _detectedBodyType = _detectBodyType(validLandmarks);

      if (!_bodyTypeCalibrated && _detectedBodyType != AVERAGE_BUILD) {
        String bodyTypeName = getBodyTypeName(_detectedBodyType);
        _speakFeedback("Adapting to $bodyTypeName build", isUrgent: false);
      }

      _bodyTypeCalibrated = true;
    }

    // Get body type specific ranges
    Map<String, double> ranges = bodyTypeRanges[_detectedBodyType]!;

    // Calculate key measurements
    double leftElbowAngle = _calculateAngle(
      validLandmarks['leftShoulder']!,
      validLandmarks['leftElbow']!,
      validLandmarks['leftWrist']!,
    );
    double rightElbowAngle = _calculateAngle(
      validLandmarks['rightShoulder']!,
      validLandmarks['rightElbow']!,
      validLandmarks['rightWrist']!,
    );
    double avgElbowAngle = (leftElbowAngle + rightElbowAngle) / 2;

    // Smooth angle tracking
    _elbowAngleHistory.add(avgElbowAngle);
    if (_elbowAngleHistory.length > 6) {
      _elbowAngleHistory.removeAt(0);
    }
    double smoothedElbowAngle =
        _elbowAngleHistory.reduce((a, b) => a + b) / _elbowAngleHistory.length;

    // Grip width analysis
    double gripWidth = _calculateDistance(
      validLandmarks['leftWrist']!,
      validLandmarks['rightWrist']!,
    );
    double shoulderWidth = _calculateDistance(
      validLandmarks['leftShoulder']!,
      validLandmarks['rightShoulder']!,
    );
    double gripRatio = gripWidth / shoulderWidth;

    // Elbow flare calculation
    double leftElbowFlare = _calculateElbowFlare(
      validLandmarks['leftShoulder']!,
      validLandmarks['leftElbow']!,
      validLandmarks['leftWrist']!,
    );
    double rightElbowFlare = _calculateElbowFlare(
      validLandmarks['rightShoulder']!,
      validLandmarks['rightElbow']!,
      validLandmarks['rightWrist']!,
    );
    double avgElbowFlare = (leftElbowFlare + rightElbowFlare) / 2;

    // Bar path analysis
    double barPath = _calculateBarPath(
      validLandmarks['leftWrist']!,
      validLandmarks['rightWrist']!,
    );

    // Shoulder stability
    double shoulderStability = _calculateShoulderStability(
      validLandmarks['leftShoulder']!,
      validLandmarks['rightShoulder']!,
      validLandmarks['leftElbow']!,
      validLandmarks['rightElbow']!,
    );

    // Form assessment with safety priorities
    String feedback = '';
    Color feedbackColor = Colors.green;
    int formScore = 100;

    // Critical safety checks first
    if (avgElbowFlare > 80) {
      feedback = 'Elbows flared too wide! Injury risk';
      feedbackColor = Colors.red;
      formScore -= 40;
    } else if (gripRatio < ranges['gripWidthRatio']! - 0.3) {
      feedback = 'Grip too narrow for your build!';
      feedbackColor = Colors.red;
      formScore -= 30;
    } else if (gripRatio > ranges['gripWidthRatio']! + 0.3) {
      feedback = 'Grip too wide! Narrow your grip';
      feedbackColor = Colors.red;
      formScore -= 30;
    } else if (shoulderStability > ranges['shoulderStabilityMin']!) {
      feedback = 'Retract shoulder blades! Create stable base';
      feedbackColor = Colors.red;
      formScore -= 35;
    } else if (barPath > ranges['barPathTolerance']!) {
      feedback = 'Bar drifting toward head! Control the path';
      feedbackColor = Colors.orange;
      formScore -= 25;
    } else if (avgElbowFlare > ranges['elbowFlareMax']!) {
      feedback = 'Elbows flared too wide! Injury risk';
      feedbackColor = Colors.orange;
      formScore -= 20;
    } else if (avgElbowFlare < ranges['elbowFlareMin']!) {
      feedback = 'Elbows too tucked! Allow natural angle';
      feedbackColor = Colors.orange;
      formScore -= 15;
    }

    // Phase detection and movement-specific feedback
    int newPhase = _detectBenchPhase(smoothedElbowAngle, _currentPhase, ranges);

    if (newPhase != _currentPhase) {
      DateTime now = DateTime.now();
      if (now.difference(_lastPhaseChange).inMilliseconds > 800) {
        _currentPhase = newPhase;
        _lastPhaseChange = now;

        if (_currentPhase == PHASE_LOCKOUT) {
          _repCount++;
          onRepCountUpdate(_repCount);
          _announceRepCount(_repCount);
        }
      }
    }

    // Phase-specific feedback (only if no critical issues)
    if (feedback.isEmpty) {
      switch (_currentPhase) {
        case PHASE_SETUP:
          feedback = 'Setup position optimal for your build';
          feedbackColor = Colors.blue;
          break;
        case PHASE_DESCENT:
          if (smoothedElbowAngle > 120) {
            feedback = 'Control the descent! Slow and steady';
            feedbackColor = Colors.blue;
          } else {
            feedback = 'Good descent! Touch chest gently';
            feedbackColor = Colors.green;
          }
          break;
        case PHASE_CHEST_PAUSE:
          if (smoothedElbowAngle > ranges['elbowAngleMax']! + 10) {
            feedback = 'Touch chest gently, don\'t bounce';
            feedbackColor = Colors.orange;
          } else {
            feedback = 'Pause at chest, then drive up';
            feedbackColor = Colors.green;
          }
          break;
        case PHASE_ASCENT:
          feedback = 'Push bar in straight line to lockout';
          feedbackColor = Colors.blue;
          break;
        case PHASE_LOCKOUT:
          feedback = 'Excellent rep! Reset for next one';
          feedbackColor = Colors.green;
          break;
        default:
          feedback = 'Perfect elbow position for your build';
          feedbackColor = Colors.green;
      }
    }

    _updateFeedback(feedback, feedbackColor, onFeedbackUpdate);
    _previousElbowAngle = smoothedElbowAngle;

    return {
      'phase': _currentPhase,
      'repCount': _repCount,
      'formScore': formScore,
      'elbowAngle': smoothedElbowAngle,
      'gripWidth': gripRatio,
      'elbowFlare': avgElbowFlare,
      'barPath': barPath,
      'shoulderStability': shoulderStability,
      'bodyType': getBodyTypeName(_detectedBodyType),
      'humanPresent': true,
    };
  }

  // Calculate elbow flare angle
  static double _calculateElbowFlare(
    PoseLandmark shoulder,
    PoseLandmark elbow,
    PoseLandmark wrist,
  ) {
    double shoulderElbowAngle = math.atan2(
      elbow.y - shoulder.y,
      elbow.x - shoulder.x,
    );
    double shoulderWristAngle = math.atan2(
      wrist.y - shoulder.y,
      wrist.x - shoulder.x,
    );
    double flareAngle =
        (shoulderElbowAngle - shoulderWristAngle).abs() * 180 / math.pi;
    return flareAngle > 180 ? 360 - flareAngle : flareAngle;
  }

  // Bench press phase detection
  static int _detectBenchPhase(
    double currentAngle,
    int currentPhase,
    Map<String, double> ranges,
  ) {
    switch (currentPhase) {
      case PHASE_SETUP:
        if (currentAngle < 140) {
          return PHASE_DESCENT;
        }
        break;
      case PHASE_DESCENT:
        if (currentAngle < ranges['elbowAngleMax']! + 10) {
          return PHASE_CHEST_PAUSE;
        }
        break;
      case PHASE_CHEST_PAUSE:
        if (currentAngle > ranges['elbowAngleMax']! + 15) {
          return PHASE_ASCENT;
        }
        break;
      case PHASE_ASCENT:
        if (currentAngle > EXTENDED_ARM_ANGLE - 15) {
          return PHASE_LOCKOUT;
        }
        break;
      case PHASE_LOCKOUT:
        if (currentAngle < 150) {
          return PHASE_DESCENT;
        }
        break;
    }
    return currentPhase;
  }

  // Voice control methods
  // Voice control methods
  static void setVoiceEnabled(bool enabled) {
    _isVoiceEnabled = enabled;
    if (!enabled && _flutterTts != null) {
      _flutterTts!.stop();
      _isSpeaking = false;
    }
  }

  static bool isVoiceEnabled() => _isVoiceEnabled;

  static void stopVoiceFeedback() {
    if (_flutterTts != null) {
      _flutterTts!.stop();
      _isSpeaking = false;
    }
  }

  // Reset session data
  static void resetSession() {
    _currentPhase = PHASE_SETUP;
    _repCount = 0;
    _previousElbowAngle = 180.0;
    _previousBarHeight = 0.0;
    _elbowAngleHistory.clear();
    _barHeightHistory.clear();
    _anthropometricHistory.clear();
    _barPathHistory.clear();
    _lastPhaseChange = DateTime.now();
    _lastFeedbackChange = DateTime.now();
    _lastFeedback = '';
    _lastFeedbackColor = Colors.blue;
    _detectedBodyType = AVERAGE_BUILD;
    _bodyTypeCalibrated = false;
    _torsoWidth = 0.0;
    _armLength = 0.0;
    _shoulderMobility = 0.0;
    _lastVoiceFeedback = DateTime.now();
    _lastSpokenText = '';
    _isSpeaking = false;
  }

  // Get body type name for display
  static String getBodyTypeName(int bodyType) {
    if (bodyType >= 0 && bodyType < bodyTypeNames.length) {
      return bodyTypeNames[bodyType];
    }
    return 'averageBuild';
  }

  // Get current phase name
  static String getCurrentPhaseName() {
    switch (_currentPhase) {
      case PHASE_SETUP:
        return 'Setup';
      case PHASE_UNRACK:
        return 'Unrack';
      case PHASE_DESCENT:
        return 'Descent';
      case PHASE_CHEST_PAUSE:
        return 'Chest Pause';
      case PHASE_ASCENT:
        return 'Ascent';
      case PHASE_LOCKOUT:
        return 'Lockout';
      default:
        return 'Unknown';
    }
  }

  // Get current rep count
  static int getCurrentRepCount() => _repCount;

  // Get detected body type
  static int getDetectedBodyType() => _detectedBodyType;

  // Check if body type is calibrated
  static bool isBodyTypeCalibrated() => _bodyTypeCalibrated;

  // Get anthropometric measurements
  static Map<String, double> getAnthropometricData() {
    return {
      'torsoWidth': _torsoWidth,
      'armLength': _armLength,
      'shoulderMobility': _shoulderMobility,
    };
  }

  // Get optimal ranges for current body type
  static Map<String, double> getOptimalRanges() {
    return bodyTypeRanges[_detectedBodyType] ?? bodyTypeRanges[AVERAGE_BUILD]!;
  }

  // Force body type calibration
  static void forceBodyTypeCalibration() {
    _bodyTypeCalibrated = false;
    _anthropometricHistory.clear();
  }

  // Get exercise statistics
  static Map<String, dynamic> getExerciseStats() {
    return {
      'totalReps': _repCount,
      'currentPhase': getCurrentPhaseName(),
      'bodyType': getBodyTypeName(_detectedBodyType),
      'isCalibrated': _bodyTypeCalibrated,
      'sessionDuration': DateTime.now().difference(_lastPhaseChange).inSeconds,
      'averageElbowAngle': _elbowAngleHistory.isNotEmpty
          ? _elbowAngleHistory.reduce((a, b) => a + b) /
                _elbowAngleHistory.length
          : 0.0,
      'barPathStability': _barPathHistory.isNotEmpty
          ? _barPathHistory.reduce((a, b) => a + b) / _barPathHistory.length
          : 0.0,
    };
  }

  // Dispose resources
  static void dispose() {
    if (_flutterTts != null) {
      _flutterTts!.stop();
      _flutterTts = null;
    }
    resetSession();
  }

  // Advanced biomechanical analysis
  static Map<String, double> performBiomechanicalAnalysis(
    Map<String, PoseLandmark> landmarks,
  ) {
    // Scapular retraction analysis
    double scapularRetraction = _calculateScapularRetraction(
      landmarks['leftShoulder']!,
      landmarks['rightShoulder']!,
      landmarks['leftElbow']!,
      landmarks['rightElbow']!,
    );

    // Leg drive assessment
    double legDrive = _calculateLegDrive(
      landmarks['leftHip']!,
      landmarks['rightHip']!,
      landmarks['leftKnee']!,
      landmarks['rightKnee']!,
    );

    // Core stability
    double coreStability = _calculateCoreStability(
      landmarks['leftShoulder']!,
      landmarks['rightShoulder']!,
      landmarks['leftHip']!,
      landmarks['rightHip']!,
    );

    return {
      'scapularRetraction': scapularRetraction,
      'legDrive': legDrive,
      'coreStability': coreStability,
    };
  }

  // Calculate scapular retraction
  static double _calculateScapularRetraction(
    PoseLandmark leftShoulder,
    PoseLandmark rightShoulder,
    PoseLandmark leftElbow,
    PoseLandmark rightElbow,
  ) {
    double shoulderWidth = _calculateDistance(leftShoulder, rightShoulder);
    double elbowWidth = _calculateDistance(leftElbow, rightElbow);
    return (shoulderWidth - elbowWidth) / shoulderWidth * 100;
  }

  // Calculate leg drive contribution
  static double _calculateLegDrive(
    PoseLandmark leftHip,
    PoseLandmark rightHip,
    PoseLandmark leftKnee,
    PoseLandmark rightKnee,
  ) {
    double hipStability = (leftHip.y - rightHip.y).abs();
    double kneeStability = (leftKnee.y - rightKnee.y).abs();
    return math.max(0, 100 - (hipStability + kneeStability) * 10);
  }

  // Calculate core stability
  static double _calculateCoreStability(
    PoseLandmark leftShoulder,
    PoseLandmark rightShoulder,
    PoseLandmark leftHip,
    PoseLandmark rightHip,
  ) {
    double shoulderLevel = (leftShoulder.y - rightShoulder.y).abs();
    double hipLevel = (leftHip.y - rightHip.y).abs();
    double stability = shoulderLevel + hipLevel;
    return math.max(0, 100 - stability * 5);
  }

  // Safety assessment
  static Map<String, dynamic> performSafetyAssessment(
    Map<String, PoseLandmark> landmarks,
  ) {
    bool isSafe = true;
    List<String> safetyIssues = [];

    // Check for extreme elbow flare
    double leftElbowFlare = _calculateElbowFlare(
      landmarks['leftShoulder']!,
      landmarks['leftElbow']!,
      landmarks['leftWrist']!,
    );
    double rightElbowFlare = _calculateElbowFlare(
      landmarks['rightShoulder']!,
      landmarks['rightElbow']!,
      landmarks['rightWrist']!,
    );

    if (leftElbowFlare > 85 || rightElbowFlare > 85) {
      isSafe = false;
      safetyIssues.add('Extreme elbow flare detected - injury risk');
    }

    // Check for shoulder impingement risk
    double shoulderHeight =
        (landmarks['leftShoulder']!.y + landmarks['rightShoulder']!.y) / 2;
    double elbowHeight =
        (landmarks['leftElbow']!.y + landmarks['rightElbow']!.y) / 2;

    if (elbowHeight < shoulderHeight - 50) {
      isSafe = false;
      safetyIssues.add('Elbows too low - shoulder impingement risk');
    }

    // Check for wrist alignment
    double leftWristAngle = _calculateWristAngle(
      landmarks['leftElbow']!,
      landmarks['leftWrist']!,
    );
    double rightWristAngle = _calculateWristAngle(
      landmarks['rightElbow']!,
      landmarks['rightWrist']!,
    );

    if (leftWristAngle > 30 || rightWristAngle > 30) {
      isSafe = false;
      safetyIssues.add('Wrist hyperextension detected');
    }

    return {
      'isSafe': isSafe,
      'safetyIssues': safetyIssues,
      'riskLevel': safetyIssues.length == 0
          ? 'Low'
          : safetyIssues.length == 1
          ? 'Medium'
          : 'High',
    };
  }

  // Calculate wrist angle
  static double _calculateWristAngle(PoseLandmark elbow, PoseLandmark wrist) {
    double angle =
        math.atan2(wrist.y - elbow.y, wrist.x - elbow.x) * 180 / math.pi;
    return angle.abs();
  }

  // Get personalized recommendations
  static List<String> getPersonalizedRecommendations() {
    List<String> recommendations = [];
    Map<String, double> ranges = getOptimalRanges();
    String bodyType = getBodyTypeName(_detectedBodyType);

    switch (_detectedBodyType) {
      case NARROW_TORSO:
        recommendations.addAll([
          'Use a slightly narrower grip (1.3x shoulder width)',
          'Keep elbows at 30-50 degree angle',
          'Focus on upper chest development',
          'Maintain strict form over heavy weight',
        ]);
        break;
      case WIDE_TORSO:
        recommendations.addAll([
          'Use a wider grip (1.7x shoulder width)',
          'Allow 50-70 degree elbow flare',
          'Focus on lower chest engagement',
          'Emphasize shoulder blade retraction',
        ]);
        break;
      case LONG_ARMS:
        recommendations.addAll([
          'Use moderate grip width (1.6x shoulder width)',
          'Control descent speed carefully',
          'Focus on tricep strength development',
          'Consider slight arch for better leverage',
        ]);
        break;
      case SHORT_ARMS:
        recommendations.addAll([
          'Use closer grip (1.4x shoulder width)',
          'Maintain 45-65 degree elbow angle',
          'Focus on chest activation',
          'Emphasize full range of motion',
        ]);
        break;
      default:
        recommendations.addAll([
          'Use standard grip (1.5x shoulder width)',
          'Maintain 40-60 degree elbow angle',
          'Focus on balanced development',
          'Progress weight gradually',
        ]);
    }

    return recommendations;
  }
}
