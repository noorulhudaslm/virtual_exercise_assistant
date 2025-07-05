import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class DeadliftAnalyzer {
  // Body type classifications for deadlift optimization
  static const int SHORT_TORSO = 0;
  static const int AVERAGE_BUILD = 1;
  static const int LONG_TORSO = 2;
  static const int LONG_ARMS = 3;
  static const int SHORT_ARMS = 4;
  static const int WIDE_HIPS = 5;
  static const int NARROW_HIPS = 6;

  // Voice feedback instance
  static FlutterTts? _flutterTts;
  static bool _isVoiceEnabled = true;
  static DateTime _lastVoiceFeedback = DateTime.now();
  static String _lastSpokenText = '';
  static bool _isSpeaking = false;

  // Deadlift style recommendations based on body type
  static Map<int, String> bodyTypeToStyle = {
    SHORT_TORSO: 'conventional',
    AVERAGE_BUILD: 'conventional',
    LONG_TORSO: 'sumo',
    LONG_ARMS: 'conventional',
    SHORT_ARMS: 'sumo',
    WIDE_HIPS: 'sumo',
    NARROW_HIPS: 'conventional',
  };

  // Body type specific ranges based on biomechanical research
  static Map<int, Map<String, double>> bodyTypeRanges = {
    SHORT_TORSO: {
      'kneeAngleMin': 60.0,
      'kneeAngleMax': 90.0,
      'hipAngleMin': 70.0,
      'hipAngleMax': 110.0,
      'backAngleMin': 30.0,
      'backAngleMax': 45.0,
      'barDistanceMax': 8.0,
      'shoulderBarAlignmentTolerance': 15.0,
      'hipHingeRatio': 0.6,
    },
    AVERAGE_BUILD: {
      'kneeAngleMin': 70.0,
      'kneeAngleMax': 100.0,
      'hipAngleMin': 80.0,
      'hipAngleMax': 120.0,
      'backAngleMin': 35.0,
      'backAngleMax': 50.0,
      'barDistanceMax': 10.0,
      'shoulderBarAlignmentTolerance': 20.0,
      'hipHingeRatio': 0.65,
    },
    LONG_TORSO: {
      'kneeAngleMin': 80.0,
      'kneeAngleMax': 130.0,
      'hipAngleMin': 90.0,
      'hipAngleMax': 140.0,
      'backAngleMin': 40.0,
      'backAngleMax': 55.0,
      'barDistanceMax': 12.0,
      'shoulderBarAlignmentTolerance': 25.0,
      'hipHingeRatio': 0.7,
    },
    LONG_ARMS: {
      'kneeAngleMin': 65.0,
      'kneeAngleMax': 95.0,
      'hipAngleMin': 75.0,
      'hipAngleMax': 115.0,
      'backAngleMin': 32.0,
      'backAngleMax': 47.0,
      'barDistanceMax': 9.0,
      'shoulderBarAlignmentTolerance': 18.0,
      'hipHingeRatio': 0.6,
    },
    SHORT_ARMS: {
      'kneeAngleMin': 75.0,
      'kneeAngleMax': 120.0,
      'hipAngleMin': 85.0,
      'hipAngleMax': 135.0,
      'backAngleMin': 38.0,
      'backAngleMax': 52.0,
      'barDistanceMax': 11.0,
      'shoulderBarAlignmentTolerance': 22.0,
      'hipHingeRatio': 0.68,
    },
    WIDE_HIPS: {
      'kneeAngleMin': 85.0,
      'kneeAngleMax': 135.0,
      'hipAngleMin': 95.0,
      'hipAngleMax': 145.0,
      'backAngleMin': 42.0,
      'backAngleMax': 57.0,
      'barDistanceMax': 13.0,
      'shoulderBarAlignmentTolerance': 27.0,
      'hipHingeRatio': 0.72,
    },
    NARROW_HIPS: {
      'kneeAngleMin': 60.0,
      'kneeAngleMax': 85.0,
      'hipAngleMin': 70.0,
      'hipAngleMax': 105.0,
      'backAngleMin': 28.0,
      'backAngleMax': 43.0,
      'barDistanceMax': 7.0,
      'shoulderBarAlignmentTolerance': 12.0,
      'hipHingeRatio': 0.58,
    },
  };

  static const List<String> bodyTypeNames = [
    'shortTorso',
    'averageBuild',
    'longTorso',
    'longArms',
    'shortArms',
    'wideHips',
    'narrowHips',
  ];

  // Deadlift specific constants
  static const double STANDING_KNEE_ANGLE = 175.0;
  static const double STANDING_HIP_ANGLE = 175.0;
  static const double LOCKOUT_THRESHOLD = 160.0;
  static const double SETUP_THRESHOLD = 120.0;
  static const double DANGER_BACK_ANGLE = 20.0;

  // Movement phases for deadlift
  static const int PHASE_SETUP = 0;
  static const int PHASE_LIFTOFF = 1;
  static const int PHASE_KNEE_PASS = 2;
  static const int PHASE_HIP_EXTENSION = 3;
  static const int PHASE_LOCKOUT = 4;
  static const int PHASE_DESCENT = 5;

  // Session tracking with enhanced stability
  static int _currentPhase = PHASE_SETUP;
  static int _repCount = 0;
  static double _previousKneeAngle = 180.0;
  static double _previousHipAngle = 180.0;
  static List<double> _kneeAngleHistory = [];
  static List<double> _hipAngleHistory = [];
  static List<double> _backAngleHistory = [];
  static DateTime _lastPhaseChange = DateTime.now();
  static DateTime _lastFeedbackChange = DateTime.now();
  static String _lastFeedback = '';
  static Color _lastFeedbackColor = Colors.blue;
  static int _detectedBodyType = AVERAGE_BUILD;
  static bool _bodyTypeCalibrated = false;

  // Biomechanical measurements
  static double _torsoLength = 0.0;
  static double _armLength = 0.0;
  static double _hipWidth = 0.0;
  static double _shoulderWidth = 0.0;
  static List<double> _anthropometricHistory = [];
  static List<double> _barPathHistory = [];

  // Enhanced feedback mapping for deadlift
  static Map<String, String> _voiceFeedbackMap = {
    // Setup and positioning
    'Setup position: Bar over mid-foot': 'Bar over mid-foot',
    'Grip the bar with straight arms': 'Grip with straight arms',
    'Chest up, shoulders back': 'Chest up, shoulders back',
    'Engage lats! Pull bar to body': 'Engage lats, pull bar close',
    'Lower back neutral! Avoid rounding': 'Keep lower back neutral',
    'Shoulders over bar at setup': 'Shoulders over bar',

    // Liftoff and movement
    'Drive through heels! Leg drive': 'Drive through heels',
    'Bar drifting away! Keep it close': 'Keep bar close to body',
    'Knees tracking out over toes': 'Knees track over toes',
    'Hip hinge! Push hips back': 'Hip hinge movement',
    'Maintain back angle during liftoff': 'Maintain back angle',
    'Bar speed too fast! Control it': 'Control bar speed',

    // Knee pass and hip extension
    'Knees clearing! Begin hip drive': 'Begin hip drive',
    'Drive hips forward! Squeeze glutes': 'Drive hips forward',
    'Bar path perfect! Straight line': 'Perfect bar path',
    'Maintain tension! Don\'t lose tightness': 'Maintain tension',
    'Head neutral! Eyes forward': 'Keep head neutral',

    // Lockout
    'Full lockout! Hips and knees extended': 'Full lockout position',
    'Excellent rep! Control the descent': 'Excellent rep',
    'Stand tall! Complete the movement': 'Stand tall, complete lift',
    'Perfect form for your build': 'Perfect form',

    // Safety and corrections
    'DANGER! Back rounding! Stop immediately': 'Stop! Back rounding',
    'Bar too far from body! Injury risk': 'Bar too far, injury risk',
    'Knees caving in! Push out': 'Knees out, push them out',
    'Loss of balance! Reset position': 'Reset your position',
    'Hyperextension! Don\'t lean back': 'Don\'t lean back',

    // Style-specific feedback
    'Conventional style suits your build': 'Conventional style optimal',
    'Sumo style better for your proportions': 'Sumo style better',
    'Stance width optimal for your hips': 'Stance width perfect',
    'Grip width appropriate': 'Grip width good',
  };

  // Initialize voice feedback system
  static Future<void> initializeVoiceFeedback() async {
    _flutterTts = FlutterTts();

    await _flutterTts!.setLanguage("en-US");
    await _flutterTts!.setSpeechRate(0.7);
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
    int minInterval = isSafety ? 1000 : (isUrgent ? 2500 : 4000);

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

  // Rep count announcements
  static Future<void> _announceRepCount(int count) async {
    if (count == 1) {
      await _speakFeedback("First rep complete", isUrgent: false);
    } else if (count == 5) {
      await _speakFeedback("5 reps! Great strength", isUrgent: false);
    } else if (count == 10) {
      await _speakFeedback("10 reps! Excellent power", isUrgent: false);
    } else if (count % 5 == 0 && count > 10) {
      await _speakFeedback("$count reps! Outstanding", isUrgent: false);
    } else if (count <= 3) {
      await _speakFeedback("Rep $count complete", isUrgent: false);
    }
  }

  // Enhanced human detection for deadlift position
  static bool _isInDeadliftPosition(Map<String, PoseLandmark?> landmarkMap) {
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
    final leftAnkle = landmarkMap['leftAnkle']!;
    final rightAnkle = landmarkMap['rightAnkle']!;

    // Check if person is in standing/deadlift position
    double avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    double avgHipY = (leftHip.y + rightHip.y) / 2;
    double avgKneeY = (leftKnee.y + rightKnee.y) / 2;
    double avgAnkleY = (leftAnkle.y + rightAnkle.y) / 2;

    // Check vertical alignment (shoulder > hip > knee > ankle)
    if (avgShoulderY > avgHipY || avgHipY > avgKneeY || avgKneeY > avgAnkleY) {
      return false;
    }

    // Check if feet are roughly level (not lying down)
    if ((leftAnkle.y - rightAnkle.y).abs() > 50) return false;

    // Check if person is facing forward (not sideways)
    double shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    double hipWidth = (leftHip.x - rightHip.x).abs();
    if (shoulderWidth < 20 || hipWidth < 15) return false;

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

  // Detect body type for deadlift optimization
  static int _detectBodyType(Map<String, PoseLandmark> landmarks) {
    final leftShoulder = landmarks['leftShoulder']!;
    final rightShoulder = landmarks['rightShoulder']!;
    final leftHip = landmarks['leftHip']!;
    final rightHip = landmarks['rightHip']!;
    final leftKnee = landmarks['leftKnee']!;
    final rightKnee = landmarks['rightKnee']!;
    final leftWrist = landmarks['leftWrist']!;
    final rightWrist = landmarks['rightWrist']!;

    // Calculate key measurements
    double shoulderWidth = _calculateDistance(leftShoulder, rightShoulder);
    double hipWidth = _calculateDistance(leftHip, rightHip);
    double leftTorsoLength = _calculateDistance(leftShoulder, leftHip);
    double rightTorsoLength = _calculateDistance(rightShoulder, rightHip);
    double avgTorsoLength = (leftTorsoLength + rightTorsoLength) / 2;

    double leftArmLength = _calculateDistance(leftShoulder, leftWrist);
    double rightArmLength = _calculateDistance(rightShoulder, rightWrist);
    double avgArmLength = (leftArmLength + rightArmLength) / 2;

    double leftLegLength = _calculateDistance(leftHip, leftKnee);
    double rightLegLength = _calculateDistance(rightHip, rightKnee);
    double avgLegLength = (leftLegLength + rightLegLength) / 2;

    // Store measurements
    _torsoLength = avgTorsoLength;
    _armLength = avgArmLength;
    _hipWidth = hipWidth;
    _shoulderWidth = shoulderWidth;

    // Calculate ratios
    double torsoToLegRatio = avgTorsoLength / avgLegLength;
    double armToTorsoRatio = avgArmLength / avgTorsoLength;
    double hipToShoulderRatio = hipWidth / shoulderWidth;

    // Add to history for stability
    _anthropometricHistory.add(torsoToLegRatio);
    if (_anthropometricHistory.length > 8) {
      _anthropometricHistory.removeAt(0);
    }

    if (_anthropometricHistory.length < 4) return AVERAGE_BUILD;

    double avgTorsoRatio =
        _anthropometricHistory.reduce((a, b) => a + b) /
        _anthropometricHistory.length;

    // Classification based on research
    if (avgTorsoRatio > 1.15 && armToTorsoRatio > 1.2) {
      return LONG_TORSO;
    } else if (avgTorsoRatio < 0.85 && armToTorsoRatio < 1.1) {
      return SHORT_TORSO;
    } else if (armToTorsoRatio > 1.3) {
      return LONG_ARMS;
    } else if (armToTorsoRatio < 0.9) {
      return SHORT_ARMS;
    } else if (hipToShoulderRatio > 1.1) {
      return WIDE_HIPS;
    } else if (hipToShoulderRatio < 0.85) {
      return NARROW_HIPS;
    } else {
      return AVERAGE_BUILD;
    }
  }

  // Calculate bar path from hand position
  static double _calculateBarPath(
    PoseLandmark leftWrist,
    PoseLandmark rightWrist,
  ) {
    double barCenterX = (leftWrist.x + rightWrist.x) / 2;
    double barCenterY = (leftWrist.y + rightWrist.y) / 2;

    _barPathHistory.add(barCenterX);
    if (_barPathHistory.length > 5) {
      _barPathHistory.removeAt(0);
    }

    if (_barPathHistory.length < 3) return 0.0;

    double pathDeviation = 0.0;
    for (int i = 1; i < _barPathHistory.length; i++) {
      pathDeviation += (_barPathHistory[i] - _barPathHistory[i - 1]).abs();
    }

    return pathDeviation / (_barPathHistory.length - 1);
  }

  // Calculate back angle
  static double _calculateBackAngle(
    PoseLandmark shoulder,
    PoseLandmark hip,
    PoseLandmark knee,
  ) {
    double hipToShoulderAngle = math.atan2(
      shoulder.y - hip.y,
      shoulder.x - hip.x,
    );
    double hipToKneeAngle = math.atan2(knee.y - hip.y, knee.x - hip.x);
    double backAngle =
        (hipToShoulderAngle - hipToKneeAngle).abs() * 180 / math.pi;
    return backAngle > 180 ? 360 - backAngle : backAngle;
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
            now.difference(_lastFeedbackChange).inMilliseconds > 2000)) {
      _lastFeedback = feedback;
      _lastFeedbackColor = color;
      _lastFeedbackChange = now;
      onFeedbackUpdate(feedback, color);

      _speakFeedback(feedback, isUrgent: isUrgent, isSafety: isSafety);
    } else if (_lastFeedback.isNotEmpty) {
      onFeedbackUpdate(_lastFeedback, _lastFeedbackColor);
    }
  }

  // Main deadlift analysis function
  static Map<String, dynamic> analyzeDeadliftForm(
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

    // Check if person is in deadlift position
    if (!_isInDeadliftPosition(landmarkMap)) {
      if (_currentPhase != PHASE_SETUP) {
        _currentPhase = PHASE_SETUP;
        _kneeAngleHistory.clear();
        _hipAngleHistory.clear();
        _backAngleHistory.clear();
      }

      return {
        'phase': PHASE_SETUP,
        'repCount': _repCount,
        'formScore': 0,
        'bodyType': getBodyTypeName(_detectedBodyType),
        'recommendedStyle': getRecommendedStyle(_detectedBodyType),
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
      'leftKnee',
      'rightKnee',
      'leftAnkle',
      'rightAnkle',
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
          'recommendedStyle': getRecommendedStyle(_detectedBodyType),
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
        String recommendedStyle = getRecommendedStyle(_detectedBodyType);
        _speakFeedback(
          "$recommendedStyle style suits your build",
          isUrgent: false,
        );
      }

      _bodyTypeCalibrated = true;
    }

    // Get body type specific ranges
    Map<String, double> ranges = bodyTypeRanges[_detectedBodyType]!;

    // Calculate key measurements
    double leftKneeAngle = _calculateAngle(
      validLandmarks['leftHip']!,
      validLandmarks['leftKnee']!,
      validLandmarks['leftAnkle']!,
    );
    double rightKneeAngle = _calculateAngle(
      validLandmarks['rightHip']!,
      validLandmarks['rightKnee']!,
      validLandmarks['rightAnkle']!,
    );
    double avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2;

    double leftHipAngle = _calculateAngle(
      validLandmarks['leftShoulder']!,
      validLandmarks['leftHip']!,
      validLandmarks['leftKnee']!,
    );
    double rightHipAngle = _calculateAngle(
      validLandmarks['rightShoulder']!,
      validLandmarks['rightHip']!,
      validLandmarks['rightKnee']!,
    );
    double avgHipAngle = (leftHipAngle + rightHipAngle) / 2;

    // Back angle calculation
    double leftBackAngle = _calculateBackAngle(
      validLandmarks['leftShoulder']!,
      validLandmarks['leftHip']!,
      validLandmarks['leftKnee']!,
    );
    double rightBackAngle = _calculateBackAngle(
      validLandmarks['rightShoulder']!,
      validLandmarks['rightHip']!,
      validLandmarks['rightKnee']!,
    );
    double avgBackAngle = (leftBackAngle + rightBackAngle) / 2;

    // Smooth tracking
    _kneeAngleHistory.add(avgKneeAngle);
    _hipAngleHistory.add(avgHipAngle);
    _backAngleHistory.add(avgBackAngle);

    if (_kneeAngleHistory.length > 5) {
      _kneeAngleHistory.removeAt(0);
      _hipAngleHistory.removeAt(0);
      _backAngleHistory.removeAt(0);
    }

    double smoothedKneeAngle =
        _kneeAngleHistory.reduce((a, b) => a + b) / _kneeAngleHistory.length;
    double smoothedHipAngle =
        _hipAngleHistory.reduce((a, b) => a + b) / _hipAngleHistory.length;
    double smoothedBackAngle =
        _backAngleHistory.reduce((a, b) => a + b) / _backAngleHistory.length;

    // Bar path analysis
    double barPath = _calculateBarPath(
      validLandmarks['leftWrist']!,
      validLandmarks['rightWrist']!,
    );

    // Shoulder-bar alignment
    double shoulderBarAlignment = _calculateShoulderBarAlignment(
      validLandmarks['leftShoulder']!,
      validLandmarks['rightShoulder']!,
      validLandmarks['leftWrist']!,
      validLandmarks['rightWrist']!,
    );

    // Form assessment with safety priorities
    String feedback = '';
    Color feedbackColor = Colors.green;
    int formScore = 100;

    // Critical safety checks first
    if (smoothedBackAngle < DANGER_BACK_ANGLE) {
      feedback = 'DANGER! Back rounding! Stop immediately';
      feedbackColor = Colors.red;
      formScore -= 50;
    } else if (barPath > ranges['barDistanceMax']!) {
      feedback = 'Bar too far from body! Injury risk';
      feedbackColor = Colors.red;
      formScore -= 30;
    } else if (shoulderBarAlignment >
        ranges['shoulderBarAlignmentTolerance']!) {
      feedback = 'Shoulders not over bar! Adjust position';
      feedbackColor = Colors.orange;
      formScore -= 20;
    } else if (smoothedBackAngle < ranges['backAngleMin']!) {
      feedback = 'Lower back neutral! Avoid rounding';
      feedbackColor = Colors.orange;
      formScore -= 25;
    } else if (smoothedBackAngle > ranges['backAngleMax']!) {
      feedback = 'Chest up, shoulders back';
      feedbackColor = Colors.orange;
      formScore -= 15;
    }

    // Phase detection and movement analysis
    DateTime now = DateTime.now();
    int previousPhase = _currentPhase;

    // Phase transitions with stability
    if (smoothedKneeAngle < SETUP_THRESHOLD &&
        smoothedHipAngle < SETUP_THRESHOLD) {
      if (_currentPhase != PHASE_SETUP &&
          now.difference(_lastPhaseChange).inMilliseconds > 1000) {
        _currentPhase = PHASE_SETUP;
        _lastPhaseChange = now;
      }
    } else if (smoothedKneeAngle > ranges['kneeAngleMin']! &&
        smoothedKneeAngle < ranges['kneeAngleMax']! &&
        smoothedHipAngle > ranges['hipAngleMin']! &&
        smoothedHipAngle < ranges['hipAngleMax']!) {
      if (_currentPhase == PHASE_SETUP) {
        _currentPhase = PHASE_LIFTOFF;
        _lastPhaseChange = now;
      }
    } else if (smoothedKneeAngle > 120 && smoothedHipAngle > 120) {
      if (_currentPhase == PHASE_LIFTOFF) {
        _currentPhase = PHASE_KNEE_PASS;
        _lastPhaseChange = now;
      }
    } else if (smoothedKneeAngle > 140 && smoothedHipAngle > 140) {
      if (_currentPhase == PHASE_KNEE_PASS) {
        _currentPhase = PHASE_HIP_EXTENSION;
        _lastPhaseChange = now;
      }
    } else if (smoothedKneeAngle > LOCKOUT_THRESHOLD &&
        smoothedHipAngle > LOCKOUT_THRESHOLD) {
      if (_currentPhase == PHASE_HIP_EXTENSION) {
        _currentPhase = PHASE_LOCKOUT;
        _lastPhaseChange = now;
        _repCount++;
        onRepCountUpdate(_repCount);
        _announceRepCount(_repCount);
      }
    }

    // Descent detection
    if (_currentPhase == PHASE_LOCKOUT &&
        (smoothedKneeAngle < _previousKneeAngle - 10 ||
            smoothedHipAngle < _previousHipAngle - 10)) {
      _currentPhase = PHASE_DESCENT;
      _lastPhaseChange = now;
    }

    // Return to setup
    if (_currentPhase == PHASE_DESCENT &&
        smoothedKneeAngle < SETUP_THRESHOLD &&
        smoothedHipAngle < SETUP_THRESHOLD) {
      _currentPhase = PHASE_SETUP;
      _lastPhaseChange = now;
    }

    // Phase-specific feedback
    if (feedbackColor != Colors.red) {
      switch (_currentPhase) {
        case PHASE_SETUP:
          if (smoothedKneeAngle < ranges['kneeAngleMin']!) {
            feedback = 'Setup position: Bar over mid-foot';
            feedbackColor = Colors.blue;
          } else if (barPath > ranges['barDistanceMax']! * 0.7) {
            feedback = 'Engage lats! Pull bar to body';
            feedbackColor = Colors.blue;
          } else {
            feedback = 'Grip the bar with straight arms';
            feedbackColor = Colors.blue;
          }
          break;

        case PHASE_LIFTOFF:
          if (barPath > ranges['barDistanceMax']! * 0.8) {
            feedback = 'Bar drifting away! Keep it close';
            feedbackColor = Colors.orange;
            formScore -= 10;
          } else if (smoothedKneeAngle < ranges['kneeAngleMin']!) {
            feedback = 'Drive through heels! Leg drive';
            feedbackColor = Colors.green;
          } else {
            feedback = 'Maintain back angle during liftoff';
            feedbackColor = Colors.green;
          }
          break;

        case PHASE_KNEE_PASS:
          if (smoothedHipAngle < ranges['hipAngleMin']!) {
            feedback = 'Hip hinge! Push hips back';
            feedbackColor = Colors.orange;
            formScore -= 8;
          } else {
            feedback = 'Knees clearing! Begin hip drive';
            feedbackColor = Colors.green;
          }
          break;

        case PHASE_HIP_EXTENSION:
          if (smoothedHipAngle > ranges['hipAngleMax']!) {
            feedback = 'Drive hips forward! Squeeze glutes';
            feedbackColor = Colors.green;
          } else if (barPath < ranges['barDistanceMax']! * 0.5) {
            feedback = 'Bar path perfect! Straight line';
            feedbackColor = Colors.green;
          } else {
            feedback = 'Maintain tension! Don\'t lose tightness';
            feedbackColor = Colors.blue;
          }
          break;

        case PHASE_LOCKOUT:
          if (smoothedKneeAngle > LOCKOUT_THRESHOLD &&
              smoothedHipAngle > LOCKOUT_THRESHOLD) {
            feedback = 'Full lockout! Hips and knees extended';
            feedbackColor = Colors.green;
          } else if (smoothedHipAngle < LOCKOUT_THRESHOLD - 5) {
            feedback = 'Stand tall! Complete the movement';
            feedbackColor = Colors.blue;
          } else {
            feedback = 'Excellent rep! Control the descent';
            feedbackColor = Colors.green;
          }
          break;

        case PHASE_DESCENT:
          if (barPath > ranges['barDistanceMax']!) {
            feedback = 'Control the descent! Keep bar close';
            feedbackColor = Colors.orange;
            formScore -= 5;
          } else {
            feedback = 'Controlled descent! Great form';
            feedbackColor = Colors.green;
          }
          break;
      }
    }

    // Body type specific adjustments
    if (_bodyTypeCalibrated && _repCount > 0 && _repCount % 5 == 0) {
      if (formScore > 85) {
        feedback = 'Perfect form for your build';
        feedbackColor = Colors.green;
      } else if (_detectedBodyType == LONG_TORSO ||
          _detectedBodyType == WIDE_HIPS) {
        feedback = 'Sumo style better for your proportions';
        feedbackColor = Colors.blue;
      } else if (_detectedBodyType == SHORT_TORSO ||
          _detectedBodyType == NARROW_HIPS) {
        feedback = 'Conventional style suits your build';
        feedbackColor = Colors.blue;
      }
    }

    // Update feedback
    _updateFeedback(feedback, feedbackColor, onFeedbackUpdate);

    // Store previous values
    _previousKneeAngle = smoothedKneeAngle;
    _previousHipAngle = smoothedHipAngle;

    return {
      'phase': _currentPhase,
      'repCount': _repCount,
      'formScore': formScore,
      'bodyType': getBodyTypeName(_detectedBodyType),
      'recommendedStyle': getRecommendedStyle(_detectedBodyType),
      'humanPresent': true,
      'kneeAngle': smoothedKneeAngle,
      'hipAngle': smoothedHipAngle,
      'backAngle': smoothedBackAngle,
      'barPath': barPath,
      'shoulderBarAlignment': shoulderBarAlignment,
    };
  }

  // Helper function for shoulder-bar alignment
  static double _calculateShoulderBarAlignment(
    PoseLandmark leftShoulder,
    PoseLandmark rightShoulder,
    PoseLandmark leftWrist,
    PoseLandmark rightWrist,
  ) {
    double shoulderCenterX = (leftShoulder.x + rightShoulder.x) / 2;
    double shoulderCenterY = (leftShoulder.y + rightShoulder.y) / 2;
    double barCenterX = (leftWrist.x + rightWrist.x) / 2;
    double barCenterY = (leftWrist.y + rightWrist.y) / 2;

    return math.sqrt(
      math.pow(shoulderCenterX - barCenterX, 2) +
          math.pow(shoulderCenterY - barCenterY, 2),
    );
  }

  // Get body type name
  static String getBodyTypeName(int bodyType) {
    if (bodyType >= 0 && bodyType < bodyTypeNames.length) {
      return bodyTypeNames[bodyType];
    }
    return 'averageBuild';
  }

  // Get recommended deadlift style
  static String getRecommendedStyle(int bodyType) {
    return bodyTypeToStyle[bodyType] ?? 'conventional';
  }

  // Toggle voice feedback
  static void toggleVoiceFeedback() {
    _isVoiceEnabled = !_isVoiceEnabled;
  }

  // Get voice feedback status
  static bool get isVoiceEnabled => _isVoiceEnabled;

  // Reset session
  static void resetSession() {
    _currentPhase = PHASE_SETUP;
    _repCount = 0;
    _previousKneeAngle = 180.0;
    _previousHipAngle = 180.0;
    _kneeAngleHistory.clear();
    _hipAngleHistory.clear();
    _backAngleHistory.clear();
    _anthropometricHistory.clear();
    _barPathHistory.clear();
    _lastPhaseChange = DateTime.now();
    _lastFeedbackChange = DateTime.now();
    _lastFeedback = '';
    _lastFeedbackColor = Colors.blue;
    _bodyTypeCalibrated = false;
    _detectedBodyType = AVERAGE_BUILD;
  }

  // Get current phase name
  static String getCurrentPhaseName() {
    switch (_currentPhase) {
      case PHASE_SETUP:
        return 'Setup';
      case PHASE_LIFTOFF:
        return 'Liftoff';
      case PHASE_KNEE_PASS:
        return 'Knee Pass';
      case PHASE_HIP_EXTENSION:
        return 'Hip Extension';
      case PHASE_LOCKOUT:
        return 'Lockout';
      case PHASE_DESCENT:
        return 'Descent';
      default:
        return 'Unknown';
    }
  }

  // Dispose resources
  static Future<void> dispose() async {
    if (_flutterTts != null) {
      await _flutterTts!.stop();
      _flutterTts = null;
    }
  }
}
