import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class BicepCurlAnalyzer {
  // Body type classifications for bicep curl optimization
  static const int SHORT_FOREARMS = 0;
  static const int AVERAGE_BUILD = 1;
  static const int LONG_FOREARMS = 2;
  static const int NARROW_SHOULDERS = 3;
  static const int WIDE_SHOULDERS = 4;

  // Voice feedback instance
  static FlutterTts? _flutterTts;
  static bool _isVoiceEnabled = true;
  static DateTime _lastVoiceFeedback = DateTime.now();
  static String _lastSpokenText = '';
  static bool _isSpeaking = false;

  // Body type specific ranges based on biomechanical research
  static Map<int, Map<String, double>> bodyTypeRanges = {
    SHORT_FOREARMS: {
      'optimalElbowAngleMin': 30.0,
      'optimalElbowAngleMax': 145.0,
      'elbowStabilityTolerance': 8.0,
      'shoulderStabilityMin': 85.0,
      'wristDeviationMax': 15.0,
      'concentricSpeedMin': 1.5,
      'eccentricSpeedMin': 2.0,
      'rangeOfMotionMin': 110.0,
    },
    AVERAGE_BUILD: {
      'optimalElbowAngleMin': 25.0,
      'optimalElbowAngleMax': 150.0,
      'elbowStabilityTolerance': 10.0,
      'shoulderStabilityMin': 80.0,
      'wristDeviationMax': 20.0,
      'concentricSpeedMin': 2.0,
      'eccentricSpeedMin': 2.5,
      'rangeOfMotionMin': 120.0,
    },
    LONG_FOREARMS: {
      'optimalElbowAngleMin': 20.0,
      'optimalElbowAngleMax': 155.0,
      'elbowStabilityTolerance': 12.0,
      'shoulderStabilityMin': 75.0,
      'wristDeviationMax': 25.0,
      'concentricSpeedMin': 2.5,
      'eccentricSpeedMin': 3.0,
      'rangeOfMotionMin': 130.0,
    },
    NARROW_SHOULDERS: {
      'optimalElbowAngleMin': 25.0,
      'optimalElbowAngleMax': 148.0,
      'elbowStabilityTolerance': 9.0,
      'shoulderStabilityMin': 85.0,
      'wristDeviationMax': 18.0,
      'concentricSpeedMin': 2.0,
      'eccentricSpeedMin': 2.5,
      'rangeOfMotionMin': 118.0,
    },
    WIDE_SHOULDERS: {
      'optimalElbowAngleMin': 30.0,
      'optimalElbowAngleMax': 152.0,
      'elbowStabilityTolerance': 11.0,
      'shoulderStabilityMin': 75.0,
      'wristDeviationMax': 22.0,
      'concentricSpeedMin': 2.2,
      'eccentricSpeedMin': 2.8,
      'rangeOfMotionMin': 125.0,
    },
  };

  static const List<String> bodyTypeNames = [
    'shortForearms',
    'averageBuild',
    'longForearms',
    'narrowShoulders',
    'wideShoulders',
  ];

  // Bicep curl specific constants
  static const double EXTENDED_ARM_ANGLE = 170.0;
  static const double FULL_CURL_ANGLE = 25.0;
  static const double ELBOW_STABILITY_THRESHOLD = 15.0;
  static const double SHOULDER_ELEVATION_THRESHOLD = 10.0;
  static const double MOMENTUM_THRESHOLD = 20.0;

  // Movement phases for bicep curls
  static const int PHASE_STARTING_POSITION = 0;
  static const int PHASE_CONCENTRIC = 1;
  static const int PHASE_PEAK_CONTRACTION = 2;
  static const int PHASE_ECCENTRIC = 3;
  static const int PHASE_BOTTOM_PAUSE = 4;

  // Session tracking with enhanced stability
  static int _currentPhase = PHASE_STARTING_POSITION;
  static int _repCount = 0;
  static double _previousElbowAngle = 170.0;
  static double _previousElbowPositionX = 0.0;
  static double _previousElbowPositionY = 0.0;
  static double _previousShoulderHeight = 0.0;
  static List<double> _elbowAngleHistory = [];
  static List<double> _elbowPositionHistory = [];
  static List<double> _shoulderHeightHistory = [];
  static List<double> _repSpeedHistory = [];
  static DateTime _lastPhaseChange = DateTime.now();
  static DateTime _lastFeedbackChange = DateTime.now();
  static DateTime _repStartTime = DateTime.now();
  static String _lastFeedback = '';
  static Color _lastFeedbackColor = Colors.blue;
  static int _detectedBodyType = AVERAGE_BUILD;
  static bool _bodyTypeCalibrated = false;

  // Biomechanical measurements
  static double _forearmLength = 0.0;
  static double _upperArmLength = 0.0;
  static double _shoulderWidth = 0.0;
  static double _elbowStability = 0.0;
  static List<double> _anthropometricHistory = [];
  static List<double> _formQualityHistory = [];

  // Enhanced feedback mapping for bicep curls
  static Map<String, String> _voiceFeedbackMap = {
    // Setup and positioning
    'Stand tall with shoulders back': 'Stand tall, shoulders back',
    'Keep core engaged and stable': 'Engage your core',
    'Feet shoulder-width apart': 'Feet shoulder-width apart',
    'Elbows tucked close to ribs': 'Tuck elbows to your sides',
    'Maintain neutral wrist position': 'Keep wrists neutral',
    'Perfect starting position': 'Perfect starting position',

    // Elbow positioning and stability
    'Elbows drifting forward! Keep them back': 'Keep elbows back',
    'Elbows swaying outward! Stabilize them': 'Stabilize your elbows',
    'Excellent elbow stability': 'Excellent elbow control',
    'Lock elbows to your sides': 'Lock elbows to sides',
    'Elbows moving too much! Control them': 'Control elbow movement',

    // Shoulder positioning
    'Shoulders rising! Keep them down': 'Keep shoulders down',
    'Relax shoulders, don\'t shrug': 'Relax your shoulders',
    'Shoulders stable, excellent control': 'Great shoulder control',
    'Roll shoulders back and down': 'Roll shoulders back',

    // Movement quality and tempo
    'Slow down the curl! Control the weight': 'Slow down the movement',
    'Perfect curl speed': 'Perfect speed',
    'Too fast! Focus on control': 'Too fast, slow down',
    'Slower on the way down': 'Slow the lowering phase',
    'Excellent tempo control': 'Great tempo',

    // Range of motion
    'Full range of motion! Great work': 'Full range of motion',
    'Curl higher! Get full contraction': 'Curl higher',
    'Lower all the way down': 'Lower completely',
    'Partial rep! Go full range': 'Use full range',
    'Perfect range of motion': 'Perfect range',

    // Wrist and grip
    'Wrist bending back! Keep neutral': 'Keep wrists straight',
    'Wrist curling forward! Straighten it': 'Straighten your wrists',
    'Excellent wrist position': 'Perfect wrist position',
    'Grip too tight! Relax slightly': 'Relax your grip',

    // Momentum and cheating
    'Stop swinging! Control the weight': 'Stop swinging',
    'No momentum! Strict form only': 'No momentum',
    'Body swaying! Stay stable': 'Stay stable',
    'Hips moving! Keep them still': 'Keep hips still',
    'Perfect form! No cheating': 'Perfect form',

    // Peak contraction and squeeze
    'Squeeze at the top! Feel the contraction': 'Squeeze at the top',
    'Hold the contraction': 'Hold the squeeze',
    'Great peak contraction': 'Great contraction',
    'Pause at the top': 'Pause at the top',

    // Rep completion and motivation
    'Excellent rep! Reset and continue': 'Excellent rep',
    'Great bicep activation': 'Great muscle activation',
    'Perfect curl technique': 'Perfect technique',
    'Outstanding form control': 'Outstanding form',

    // Safety and corrections
    'Weight too heavy! Reduce load': 'Weight too heavy',
    'Form breaking down! Focus': 'Focus on form',
    'Take a break if needed': 'Take a break if needed',
    'Reset your position': 'Reset your position',
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
    int minInterval = isSafety ? 1500 : (isUrgent ? 3000 : 4000);

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
      await _speakFeedback("5 reps! Keep it up", isUrgent: false);
    } else if (count == 10) {
      await _speakFeedback("10 reps! Great work", isUrgent: false);
    } else if (count == 15) {
      await _speakFeedback("15 reps! Strong biceps", isUrgent: false);
    } else if (count % 5 == 0 && count > 15) {
      await _speakFeedback("$count reps! Outstanding", isUrgent: false);
    } else if (count <= 3) {
      await _speakFeedback("Rep $count complete", isUrgent: false);
    }
  }

  // Enhanced human detection for bicep curl position
  static bool _isInBicepCurlPosition(Map<String, PoseLandmark?> landmarkMap) {
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
    ];

    for (String landmark in requiredLandmarks) {
      if (landmarkMap[landmark] == null) return false;
    }

    final leftShoulder = landmarkMap['leftShoulder']!;
    final rightShoulder = landmarkMap['rightShoulder']!;
    final leftHip = landmarkMap['leftHip']!;
    final rightHip = landmarkMap['rightHip']!;
    final leftElbow = landmarkMap['leftElbow']!;
    final rightElbow = landmarkMap['rightElbow']!;

    // Check if person is in standing position
    double shoulderHipAngle = _calculateAngle(leftShoulder, leftHip, rightHip);
    if (shoulderHipAngle < 60) return false; // Too horizontal

    // Check if elbows are in reasonable position for curls
    double leftElbowHeight = leftElbow.y;
    double rightElbowHeight = rightElbow.y;
    double shoulderHeight = (leftShoulder.y + rightShoulder.y) / 2;

    // Elbows should be roughly at shoulder level or slightly below
    if (leftElbowHeight < shoulderHeight - 100 ||
        rightElbowHeight < shoulderHeight - 100) {
      return false;
    }

    // Check if arms are in front of body (curl position)
    double leftElbowPosition = leftElbow.x;
    double rightElbowPosition = rightElbow.x;
    double leftShoulderPosition = leftShoulder.x;
    double rightShoulderPosition = rightShoulder.x;

    // At least one arm should be in curl position
    bool leftArmInPosition =
        (leftElbowPosition - leftShoulderPosition).abs() < 50;
    bool rightArmInPosition =
        (rightElbowPosition - rightShoulderPosition).abs() < 50;

    return leftArmInPosition || rightArmInPosition;
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

  // Detect body type for bicep curl optimization
  static int _detectBodyType(Map<String, PoseLandmark> landmarks) {
    final leftShoulder = landmarks['leftShoulder']!;
    final rightShoulder = landmarks['rightShoulder']!;
    final leftElbow = landmarks['leftElbow']!;
    final rightElbow = landmarks['rightElbow']!;
    final leftWrist = landmarks['leftWrist']!;
    final rightWrist = landmarks['rightWrist']!;

    // Calculate key measurements
    double shoulderWidth = _calculateDistance(leftShoulder, rightShoulder);
    double leftForearmLength = _calculateDistance(leftElbow, leftWrist);
    double rightForearmLength = _calculateDistance(rightElbow, rightWrist);
    double leftUpperArmLength = _calculateDistance(leftShoulder, leftElbow);
    double rightUpperArmLength = _calculateDistance(rightShoulder, rightElbow);

    double avgForearmLength = (leftForearmLength + rightForearmLength) / 2;
    double avgUpperArmLength = (leftUpperArmLength + rightUpperArmLength) / 2;
    double armRatio = avgForearmLength / avgUpperArmLength;

    // Store measurements
    _forearmLength = avgForearmLength;
    _upperArmLength = avgUpperArmLength;
    _shoulderWidth = shoulderWidth;

    // Add to history for stability
    _anthropometricHistory.add(armRatio);
    if (_anthropometricHistory.length > 8) {
      _anthropometricHistory.removeAt(0);
    }

    if (_anthropometricHistory.length < 4) return AVERAGE_BUILD;

    double avgArmRatio =
        _anthropometricHistory.reduce((a, b) => a + b) /
        _anthropometricHistory.length;

    // Classification based on proportions
    if (avgArmRatio < 0.85) {
      return SHORT_FOREARMS;
    } else if (avgArmRatio > 1.15) {
      return LONG_FOREARMS;
    } else if (shoulderWidth < avgUpperArmLength * 2.2) {
      return NARROW_SHOULDERS;
    } else if (shoulderWidth > avgUpperArmLength * 2.8) {
      return WIDE_SHOULDERS;
    } else {
      return AVERAGE_BUILD;
    }
  }

  // Calculate elbow stability
  static double _calculateElbowStability(
    PoseLandmark leftElbow,
    PoseLandmark rightElbow,
    PoseLandmark leftShoulder,
    PoseLandmark rightShoulder,
  ) {
    double currentElbowX = (leftElbow.x + rightElbow.x) / 2;
    double currentElbowY = (leftElbow.y + rightElbow.y) / 2;
    double shoulderCenterX = (leftShoulder.x + rightShoulder.x) / 2;

    // Calculate deviation from shoulder center
    double elbowDeviation = (currentElbowX - shoulderCenterX).abs();

    // Add to position history
    _elbowPositionHistory.add(elbowDeviation);
    if (_elbowPositionHistory.length > 5) {
      _elbowPositionHistory.removeAt(0);
    }

    // Calculate stability score (lower is better)
    if (_elbowPositionHistory.length < 3) return 0.0;

    double stability = 0.0;
    for (int i = 1; i < _elbowPositionHistory.length; i++) {
      stability += (_elbowPositionHistory[i] - _elbowPositionHistory[i - 1])
          .abs();
    }

    return stability / (_elbowPositionHistory.length - 1);
  }

  // Calculate shoulder elevation
  static double _calculateShoulderElevation(
    PoseLandmark leftShoulder,
    PoseLandmark rightShoulder,
  ) {
    double currentShoulderHeight = (leftShoulder.y + rightShoulder.y) / 2;

    _shoulderHeightHistory.add(currentShoulderHeight);
    if (_shoulderHeightHistory.length > 5) {
      _shoulderHeightHistory.removeAt(0);
    }

    if (_shoulderHeightHistory.length < 3) return 0.0;

    double baseline =
        _shoulderHeightHistory.reduce((a, b) => a + b) /
        _shoulderHeightHistory.length;
    return (currentShoulderHeight - baseline).abs();
  }

  // Calculate wrist deviation
  static double _calculateWristDeviation(
    PoseLandmark leftWrist,
    PoseLandmark rightWrist,
    PoseLandmark leftElbow,
    PoseLandmark rightElbow,
  ) {
    // Calculate wrist alignment relative to forearm
    double leftWristAngle =
        math.atan2(leftWrist.y - leftElbow.y, leftWrist.x - leftElbow.x) *
        180 /
        math.pi;

    double rightWristAngle =
        math.atan2(rightWrist.y - rightElbow.y, rightWrist.x - rightElbow.x) *
        180 /
        math.pi;

    // Ideal wrist should be in line with forearm
    double avgWristDeviation =
        ((leftWristAngle.abs() - 90).abs() +
            (rightWristAngle.abs() - 90).abs()) /
        2;
    return avgWristDeviation;
  }

  // Detect momentum and cheating
  static bool _detectMomentum(
    Map<String, PoseLandmark> landmarks,
    double currentElbowAngle,
  ) {
    double shoulderMovement = _calculateShoulderElevation(
      landmarks['leftShoulder']!,
      landmarks['rightShoulder']!,
    );

    double elbowMovement = _calculateElbowStability(
      landmarks['leftElbow']!,
      landmarks['rightElbow']!,
      landmarks['leftShoulder']!,
      landmarks['rightShoulder']!,
    );

    // Check for excessive body movement
    if (shoulderMovement > SHOULDER_ELEVATION_THRESHOLD ||
        elbowMovement > ELBOW_STABILITY_THRESHOLD) {
      return true;
    }

    // Check for sudden angle changes (momentum)
    double angleChange = (currentElbowAngle - _previousElbowAngle).abs();
    if (angleChange > MOMENTUM_THRESHOLD) {
      return true;
    }

    return false;
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

  // Main bicep curl analysis function
  static Map<String, dynamic> analyzeBicepCurlForm(
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
      'nose': landmarks[PoseLandmarkType.nose],
    };

    // Check if person is in bicep curl position
    if (!_isInBicepCurlPosition(landmarkMap)) {
      if (_currentPhase != PHASE_STARTING_POSITION) {
        _currentPhase = PHASE_STARTING_POSITION;
        _elbowAngleHistory.clear();
        _elbowPositionHistory.clear();
        _shoulderHeightHistory.clear();
      }

      return {
        'phase': PHASE_STARTING_POSITION,
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
    if (!_bodyTypeCalibrated || _repCount % 5 == 0) {
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

    // Calculate stability metrics
    double elbowStability = _calculateElbowStability(
      validLandmarks['leftElbow']!,
      validLandmarks['rightElbow']!,
      validLandmarks['leftShoulder']!,
      validLandmarks['rightShoulder']!,
    );

    double shoulderElevation = _calculateShoulderElevation(
      validLandmarks['leftShoulder']!,
      validLandmarks['rightShoulder']!,
    );

    double wristDeviation = _calculateWristDeviation(
      validLandmarks['leftWrist']!,
      validLandmarks['rightWrist']!,
      validLandmarks['leftElbow']!,
      validLandmarks['rightElbow']!,
    );

    // Check for momentum and cheating
    bool usingMomentum = _detectMomentum(validLandmarks, smoothedElbowAngle);

    // Form assessment with safety priorities
    String feedback = '';
    Color feedbackColor = Colors.green;
    int formScore = 100;

    if (usingMomentum) {
      if (shoulderElevation > SHOULDER_ELEVATION_THRESHOLD) {
        feedback = 'Shoulders rising! Keep them down';
        feedbackColor = Colors.red;
        formScore -= 35;
      } else if (elbowStability > ranges['elbowStabilityTolerance']!) {
        feedback = 'Elbows swaying outward! Stabilize them';
        feedbackColor = Colors.red;
        formScore -= 30;
      } else {
        feedback = 'Stop swinging! Control the weight';
        feedbackColor = Colors.orange;
        formScore -= 25;
      }
    }
    // Elbow stability check
    else if (elbowStability > ranges['elbowStabilityTolerance']!) {
      feedback = 'Elbows drifting forward! Keep them back';
      feedbackColor = Colors.orange;
      formScore -= 20;
    }
    // Shoulder elevation check
    else if (shoulderElevation > SHOULDER_ELEVATION_THRESHOLD) {
      feedback = 'Relax shoulders, don\'t shrug';
      feedbackColor = Colors.orange;
      formScore -= 15;
    }
    // Wrist deviation check
    else if (wristDeviation > ranges['wristDeviationMax']!) {
      feedback = 'Wrist bending back! Keep neutral';
      feedbackColor = Colors.orange;
      formScore -= 10;
    }

    // Phase detection and rep counting
    DateTime now = DateTime.now();
    bool phaseChanged = false;

    switch (_currentPhase) {
      case PHASE_STARTING_POSITION:
        if (smoothedElbowAngle < ranges['optimalElbowAngleMax']! &&
            smoothedElbowAngle > ranges['optimalElbowAngleMin']!) {
          if (feedback.isEmpty) {
            feedback = 'Perfect starting position';
            feedbackColor = Colors.green;
          }

          if (smoothedElbowAngle < 140) {
            _currentPhase = PHASE_CONCENTRIC;
            _repStartTime = now;
            phaseChanged = true;
          }
        } else if (smoothedElbowAngle > ranges['optimalElbowAngleMax']!) {
          if (feedback.isEmpty) {
            feedback = 'Lower all the way down';
            feedbackColor = Colors.blue;
          }
        }
        break;

      case PHASE_CONCENTRIC:
        if (smoothedElbowAngle < ranges['optimalElbowAngleMin']! + 10) {
          _currentPhase = PHASE_PEAK_CONTRACTION;
          phaseChanged = true;

          if (feedback.isEmpty) {
            feedback = 'Squeeze at the top! Feel the contraction';
            feedbackColor = Colors.green;
          }
        } else if (smoothedElbowAngle > _previousElbowAngle + 5) {
          _currentPhase = PHASE_ECCENTRIC;
          phaseChanged = true;
        }

        // Check concentric speed
        double concentricSpeed =
            now.difference(_repStartTime).inMilliseconds / 1000.0;
        if (concentricSpeed < ranges['concentricSpeedMin']! &&
            feedback.isEmpty) {
          feedback = 'Slow down the curl! Control the weight';
          feedbackColor = Colors.blue;
          formScore -= 10;
        }
        break;

      case PHASE_PEAK_CONTRACTION:
        if (smoothedElbowAngle > _previousElbowAngle + 5 ||
            now.difference(_lastPhaseChange).inMilliseconds > 1000) {
          _currentPhase = PHASE_ECCENTRIC;
          phaseChanged = true;
        }

        if (feedback.isEmpty) {
          feedback = 'Hold the contraction';
          feedbackColor = Colors.green;
        }
        break;

      case PHASE_ECCENTRIC:
        if (smoothedElbowAngle > ranges['optimalElbowAngleMax']! - 20) {
          _currentPhase = PHASE_BOTTOM_PAUSE;
          phaseChanged = true;
          _repCount++;
          onRepCountUpdate(_repCount);

          // Calculate rep speed
          double repDuration =
              now.difference(_repStartTime).inMilliseconds / 1000.0;
          _repSpeedHistory.add(repDuration);
          if (_repSpeedHistory.length > 5) {
            _repSpeedHistory.removeAt(0);
          }

          _announceRepCount(_repCount);

          if (feedback.isEmpty) {
            feedback = 'Excellent rep! Reset and continue';
            feedbackColor = Colors.green;
          }
        }

        // Check eccentric speed
        double eccentricSpeed =
            now.difference(_lastPhaseChange).inMilliseconds / 1000.0;
        if (eccentricSpeed < ranges['eccentricSpeedMin']! && feedback.isEmpty) {
          feedback = 'Slower on the way down';
          feedbackColor = Colors.blue;
          formScore -= 5;
        }
        break;

      case PHASE_BOTTOM_PAUSE:
        if (now.difference(_lastPhaseChange).inMilliseconds > 500) {
          _currentPhase = PHASE_STARTING_POSITION;
          phaseChanged = true;
        }

        if (feedback.isEmpty) {
          feedback = 'Reset your position';
          feedbackColor = Colors.blue;
        }
        break;
    }

    // Update phase change timestamp
    if (phaseChanged) {
      _lastPhaseChange = now;
    }

    // Range of motion assessment
    if (_elbowAngleHistory.length > 3) {
      double minAngle = _elbowAngleHistory.reduce((a, b) => a < b ? a : b);
      double maxAngle = _elbowAngleHistory.reduce((a, b) => a > b ? a : b);
      double rangeOfMotion = maxAngle - minAngle;

      if (rangeOfMotion < ranges['rangeOfMotionMin']! && feedback.isEmpty) {
        feedback = 'Partial rep! Go full range';
        feedbackColor = Colors.orange;
        formScore -= 15;
      } else if (rangeOfMotion > ranges['rangeOfMotionMin']! &&
          feedback.isEmpty) {
        feedback = 'Full range of motion! Great work';
        feedbackColor = Colors.green;
      }
    }

    // Default positive feedback for good form
    if (feedback.isEmpty && formScore > 85) {
      List<String> positiveMessages = [
        'Perfect form! No cheating',
        'Excellent elbow stability',
        'Great bicep activation',
        'Outstanding form control',
        'Perfect technique',
      ];

      feedback = positiveMessages[_repCount % positiveMessages.length];
      feedbackColor = Colors.green;
    }

    // Calculate form quality history
    _formQualityHistory.add(formScore.toDouble());
    if (_formQualityHistory.length > 10) {
      _formQualityHistory.removeAt(0);
    }

    // Update feedback
    _updateFeedback(feedback, feedbackColor, onFeedbackUpdate);

    // Update previous values for next iteration
    _previousElbowAngle = smoothedElbowAngle;
    _previousElbowPositionX =
        (validLandmarks['leftElbow']!.x + validLandmarks['rightElbow']!.x) / 2;
    _previousElbowPositionY =
        (validLandmarks['leftElbow']!.y + validLandmarks['rightElbow']!.y) / 2;
    _previousShoulderHeight =
        (validLandmarks['leftShoulder']!.y +
            validLandmarks['rightShoulder']!.y) /
        2;

    return {
      'phase': _currentPhase,
      'repCount': _repCount,
      'formScore': formScore,
      'bodyType': getBodyTypeName(_detectedBodyType),
      'humanPresent': true,
      'elbowAngle': smoothedElbowAngle,
      'elbowStability': elbowStability,
      'shoulderElevation': shoulderElevation,
      'wristDeviation': wristDeviation,
      'momentum': usingMomentum,
      'avgFormScore': _formQualityHistory.isNotEmpty
          ? _formQualityHistory.reduce((a, b) => a + b) /
                _formQualityHistory.length
          : formScore.toDouble(),
    };
  }

  // Helper function to get body type name
  static String getBodyTypeName(int bodyType) {
    if (bodyType >= 0 && bodyType < bodyTypeNames.length) {
      return bodyTypeNames[bodyType];
    }
    return 'averageBuild';
  }

  // Reset session data
  static void resetSession() {
    _currentPhase = PHASE_STARTING_POSITION;
    _repCount = 0;
    _previousElbowAngle = 170.0;
    _previousElbowPositionX = 0.0;
    _previousElbowPositionY = 0.0;
    _previousShoulderHeight = 0.0;
    _elbowAngleHistory.clear();
    _elbowPositionHistory.clear();
    _shoulderHeightHistory.clear();
    _repSpeedHistory.clear();
    _lastPhaseChange = DateTime.now();
    _lastFeedbackChange = DateTime.now();
    _repStartTime = DateTime.now();
    _lastFeedback = '';
    _lastFeedbackColor = Colors.blue;
    _bodyTypeCalibrated = false;
    _detectedBodyType = AVERAGE_BUILD;
    _anthropometricHistory.clear();
    _formQualityHistory.clear();
  }

  // Toggle voice feedback
  static void toggleVoiceFeedback() {
    _isVoiceEnabled = !_isVoiceEnabled;
  }

  // Get current voice feedback status
  static bool isVoiceEnabled() {
    return _isVoiceEnabled;
  }

  // Set voice feedback enabled/disabled
  static void setVoiceFeedback(bool enabled) {
    _isVoiceEnabled = enabled;
  }

  // Get current rep count
  static int getRepCount() {
    return _repCount;
  }

  // Get current phase
  static int getCurrentPhase() {
    return _currentPhase;
  }

  // Get phase name
  static String getPhaseName(int phase) {
    switch (phase) {
      case PHASE_STARTING_POSITION:
        return 'Starting Position';
      case PHASE_CONCENTRIC:
        return 'Lifting';
      case PHASE_PEAK_CONTRACTION:
        return 'Peak Contraction';
      case PHASE_ECCENTRIC:
        return 'Lowering';
      case PHASE_BOTTOM_PAUSE:
        return 'Bottom Pause';
      default:
        return 'Unknown';
    }
  }

  // Get body type specific recommendations
  static Map<String, String> getBodyTypeRecommendations(int bodyType) {
    switch (bodyType) {
      case SHORT_FOREARMS:
        return {
          'grip': 'Use a slightly wider grip for better leverage',
          'tempo': 'Focus on controlled movements, 1.5-2 seconds up',
          'range': 'You may not need full 180° extension',
          'tips': 'Your build is optimal for heavy bicep curls',
        };
      case LONG_FOREARMS:
        return {
          'grip': 'Use a closer grip to optimize muscle activation',
          'tempo': 'Slower tempo (2.5-3 seconds) for better control',
          'range': 'Focus on full range of motion for maximum benefit',
          'tips': 'Emphasize the stretch at the bottom position',
        };
      case NARROW_SHOULDERS:
        return {
          'grip': 'Keep elbows closer to your body',
          'tempo': 'Standard tempo works well for your build',
          'range': 'Focus on strict form over heavy weight',
          'tips': 'Your build allows for excellent bicep isolation',
        };
      case WIDE_SHOULDERS:
        return {
          'grip': 'Slightly wider grip may feel more comfortable',
          'tempo': 'You can handle faster concentric movements',
          'range': 'Full range of motion is important for your build',
          'tips': 'Focus on keeping elbows stable during the movement',
        };
      default:
        return {
          'grip': 'Standard shoulder-width grip',
          'tempo': 'Controlled 2-second concentric, 2.5-second eccentric',
          'range': 'Full range of motion for optimal results',
          'tips': 'Focus on consistent form and progressive overload',
        };
    }
  }
}
