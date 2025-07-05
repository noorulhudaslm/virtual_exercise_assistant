import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class LatPulldownAnalyzer {
  // Body type classifications for lat pulldown optimization
  static const int NARROW_SHOULDERS = 0;
  static const int AVERAGE_BUILD = 1;
  static const int WIDE_SHOULDERS = 2;
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
    NARROW_SHOULDERS: {
      'elbowAngleMin': 50.0,
      'elbowAngleMax': 70.0,
      'shoulderFlexionMin': 140.0,
      'shoulderFlexionMax': 170.0,
      'gripWidthRatio': 1.2,
      'pullDepthMax': 20.0, // Distance from chin to bar
      'torsoLeanMax': 15.0,
      'scapularRetractionMin': 80.0,
    },
    AVERAGE_BUILD: {
      'elbowAngleMin': 55.0,
      'elbowAngleMax': 75.0,
      'shoulderFlexionMin': 135.0,
      'shoulderFlexionMax': 165.0,
      'gripWidthRatio': 1.5,
      'pullDepthMax': 25.0,
      'torsoLeanMax': 20.0,
      'scapularRetractionMin': 75.0,
    },
    WIDE_SHOULDERS: {
      'elbowAngleMin': 60.0,
      'elbowAngleMax': 80.0,
      'shoulderFlexionMin': 130.0,
      'shoulderFlexionMax': 160.0,
      'gripWidthRatio': 1.8,
      'pullDepthMax': 30.0,
      'torsoLeanMax': 25.0,
      'scapularRetractionMin': 70.0,
    },
    LONG_ARMS: {
      'elbowAngleMin': 60.0,
      'elbowAngleMax': 85.0,
      'shoulderFlexionMin': 140.0,
      'shoulderFlexionMax': 170.0,
      'gripWidthRatio': 1.6,
      'pullDepthMax': 35.0,
      'torsoLeanMax': 18.0,
      'scapularRetractionMin': 80.0,
    },
    SHORT_ARMS: {
      'elbowAngleMin': 45.0,
      'elbowAngleMax': 65.0,
      'shoulderFlexionMin': 130.0,
      'shoulderFlexionMax': 155.0,
      'gripWidthRatio': 1.3,
      'pullDepthMax': 20.0,
      'torsoLeanMax': 22.0,
      'scapularRetractionMin': 85.0,
    },
  };

  static const List<String> bodyTypeNames = [
    'narrowShoulders',
    'averageBuild',
    'wideShoulders',
    'longArms',
    'shortArms',
  ];

  // Lat pulldown specific constants
  static const double EXTENDED_ARM_ANGLE = 170.0;
  static const double CHIN_CONTACT_THRESHOLD = 30.0;
  static const double EXCESSIVE_LEAN_THRESHOLD = 30.0;
  static const double SHOULDER_IMPINGEMENT_THRESHOLD = 120.0;

  // Movement phases for lat pulldown
  static const int PHASE_SETUP = 0;
  static const int PHASE_INITIATION = 1;
  static const int PHASE_PULLING = 2;
  static const int PHASE_PEAK_CONTRACTION = 3;
  static const int PHASE_ECCENTRIC = 4;
  static const int PHASE_BOTTOM_POSITION = 5;

  // Session tracking with enhanced stability
  static int _currentPhase = PHASE_SETUP;
  static int _repCount = 0;
  static double _previousElbowAngle = 170.0;
  static double _previousBarHeight = 0.0;
  static List<double> _elbowAngleHistory = [];
  static List<double> _shoulderFlexionHistory = [];
  static List<double> _torsoAngleHistory = [];
  static DateTime _lastPhaseChange = DateTime.now();
  static DateTime _lastFeedbackChange = DateTime.now();
  static String _lastFeedback = '';
  static Color _lastFeedbackColor = Colors.blue;
  static int _detectedBodyType = AVERAGE_BUILD;
  static bool _bodyTypeCalibrated = false;

  // Biomechanical measurements
  static double _shoulderWidth = 0.0;
  static double _armLength = 0.0;
  static double _torsoLength = 0.0;
  static List<double> _anthropometricHistory = [];
  static List<double> _pullPathHistory = [];

  // Enhanced feedback mapping for lat pulldown
  static Map<String, String> _voiceFeedbackMap = {
    // Setup and positioning
    'Sit upright with feet flat on floor': 'Sit upright, feet flat',
    'Adjust seat height for proper reach': 'Adjust seat height',
    'Secure thighs under pad': 'Secure thighs under pad',
    'Grip bar with palms facing forward': 'Grip bar palms forward',
    'Grip too narrow! Widen for better lat activation': 'Widen your grip',
    'Grip too wide! Risk of shoulder injury': 'Narrow your grip',

    // Pull initiation and mechanics
    'Initiate pull with lats, not arms': 'Pull with lats, not arms',
    'Depress and retract shoulder blades': 'Squeeze shoulder blades down',
    'Keep chest up and shoulders back': 'Chest up, shoulders back',
    'Pull bar to upper chest level': 'Pull to upper chest',
    'Don\'t pull behind neck! Injury risk': 'Never pull behind neck',

    // Movement control
    'Control the eccentric! Don\'t let bar fly up': 'Control the weight up',
    'Slow and controlled descent': 'Slow controlled movement',
    'Perfect lat activation! Feel the squeeze': 'Perfect lat squeeze',
    'Maintain constant tension': 'Keep tension constant',

    // Posture and alignment
    'Stop leaning back! Stay upright': 'Stay more upright',
    'Don\'t swing or use momentum': 'No swinging or momentum',
    'Keep core engaged throughout': 'Engage your core',
    'Maintain neutral spine': 'Keep spine neutral',

    // Range of motion
    'Full range of motion! Stretch those lats': 'Full range of motion',
    'Don\'t pull too low! Stop at chin level': 'Stop at chin level',
    'Feel the stretch at the top': 'Feel the stretch',
    'Squeeze lats at bottom position': 'Squeeze at bottom',

    // Safety corrections
    'Shoulders hunching! Keep them down': 'Keep shoulders down',
    'Elbows flaring too wide! Injury risk': 'Bring elbows closer',
    'Wrists bending! Keep them straight': 'Keep wrists straight',
    'Excellent form! Perfect lat engagement': 'Excellent form',

    // Rep completion
    'Great rep! Reset for next one': 'Great rep, reset',
    'Outstanding lat activation!': 'Outstanding activation',
    'Perfect control throughout range': 'Perfect control',
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
      await _speakFeedback("5 reps! Great lat activation", isUrgent: false);
    } else if (count == 10) {
      await _speakFeedback("10 reps! Excellent back strength", isUrgent: false);
    } else if (count % 5 == 0 && count > 10) {
      await _speakFeedback(
        "$count reps! Outstanding endurance",
        isUrgent: false,
      );
    } else if (count <= 3) {
      await _speakFeedback("Rep $count complete", isUrgent: false);
    }
  }

  // Enhanced human detection for lat pulldown position
  static bool _isInPulldownPosition(Map<String, PoseLandmark?> landmarkMap) {
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
      'nose',
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
    final nose = landmarkMap['nose']!;

    // Check if person is in seated position (shoulders above hips)
    double avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    double avgHipY = (leftHip.y + rightHip.y) / 2;
    if (avgShoulderY > avgHipY) return false; // Shoulders should be above hips

    // Check if knees are bent (seated position)
    // Create reference points for ankle position estimation
    double leftAnkleX = leftKnee.x;
    double leftAnkleY = leftKnee.y + 50; // Estimated ankle position
    double rightAnkleX = rightKnee.x;
    double rightAnkleY = rightKnee.y + 50; // Estimated ankle position

    double leftKneeAngle = _calculateAngleFromCoordinates(
      leftHip.x,
      leftHip.y,
      leftKnee.x,
      leftKnee.y,
      leftAnkleX,
      leftAnkleY,
    );
    double rightKneeAngle = _calculateAngleFromCoordinates(
      rightHip.x,
      rightHip.y,
      rightKnee.x,
      rightKnee.y,
      rightAnkleX,
      rightAnkleY,
    );

    if (leftKneeAngle > 150 || rightKneeAngle > 150)
      return false; // Knees should be bent

    // Check if arms are in pulling position (above shoulder level)
    double avgElbowY =
        (landmarkMap['leftElbow']!.y + landmarkMap['rightElbow']!.y) / 2;
    if (avgElbowY > avgShoulderY)
      return false; // Elbows should be above shoulders

    // Check if person is facing forward (nose between shoulders)
    double shoulderCenterX = (leftShoulder.x + rightShoulder.x) / 2;
    double noseOffset = (nose.x - shoulderCenterX).abs();
    double shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    if (noseOffset > shoulderWidth * 0.3)
      return false; // Nose should be centered

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

  static double _calculateAngleFromCoordinates(
    double x1,
    double y1, // Point 1
    double x2,
    double y2, // Point 2 (vertex)
    double x3,
    double y3, // Point 3
  ) {
    double angle1 = math.atan2(y1 - y2, x1 - x2);
    double angle2 = math.atan2(y3 - y2, x3 - x2);
    double angle = (angle2 - angle1) * 180 / math.pi;
    return angle.abs() > 180 ? 360 - angle.abs() : angle.abs();
  }

  // Detect body type for lat pulldown optimization
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
    _shoulderWidth = shoulderWidth / hipWidth;
    _armLength = avgArmLength / avgTorsoLength;
    _torsoLength = avgTorsoLength;

    // Add to history for stability
    _anthropometricHistory.add(_armLength);
    if (_anthropometricHistory.length > 8) {
      _anthropometricHistory.removeAt(0);
    }

    if (_anthropometricHistory.length < 4) return AVERAGE_BUILD;

    double avgArmRatio =
        _anthropometricHistory.reduce((a, b) => a + b) /
        _anthropometricHistory.length;

    // Classification based on research and pulldown biomechanics
    if (_shoulderWidth > 1.4 && avgArmRatio < 1.3) {
      return WIDE_SHOULDERS;
    } else if (_shoulderWidth < 1.1 && avgArmRatio < 1.4) {
      return NARROW_SHOULDERS;
    } else if (avgArmRatio > 1.5) {
      return LONG_ARMS;
    } else if (avgArmRatio < 1.1) {
      return SHORT_ARMS;
    } else {
      return AVERAGE_BUILD;
    }
  }

  // Calculate pull path (hand tracking during movement)
  static double _calculatePullPath(
    PoseLandmark leftWrist,
    PoseLandmark rightWrist,
    PoseLandmark leftShoulder,
    PoseLandmark rightShoulder,
  ) {
    double handCenterX = (leftWrist.x + rightWrist.x) / 2;
    double handCenterY = (leftWrist.y + rightWrist.y) / 2;
    double shoulderCenterX = (leftShoulder.x + rightShoulder.x) / 2;

    // Calculate deviation from vertical pull path
    double pathDeviation = (handCenterX - shoulderCenterX).abs();

    _pullPathHistory.add(pathDeviation);
    if (_pullPathHistory.length > 5) {
      _pullPathHistory.removeAt(0);
    }

    return _pullPathHistory.length > 0
        ? _pullPathHistory.reduce((a, b) => a + b) / _pullPathHistory.length
        : 0.0;
  }

  // Calculate torso angle (leaning back assessment)
  static double _calculateTorsoAngle(
    PoseLandmark leftShoulder,
    PoseLandmark rightShoulder,
    PoseLandmark leftHip,
    PoseLandmark rightHip,
  ) {
    double shoulderCenterX = (leftShoulder.x + rightShoulder.x) / 2;
    double shoulderCenterY = (leftShoulder.y + rightShoulder.y) / 2;
    double hipCenterX = (leftHip.x + rightHip.x) / 2;
    double hipCenterY = (leftHip.y + rightHip.y) / 2;

    // Calculate angle from vertical
    double angle =
        math.atan2(shoulderCenterX - hipCenterX, shoulderCenterY - hipCenterY) *
        180 /
        math.pi;

    return angle.abs();
  }

  // Calculate shoulder flexion angle
  static double _calculateShoulderFlexion(
    PoseLandmark shoulder,
    PoseLandmark elbow,
    PoseLandmark hip,
  ) {
    // Create a point directly below the shoulder for vertical reference
    double verticalRefX = shoulder.x;
    double verticalRefY = shoulder.y + 100;

    // Calculate vectors
    double shoulderToVerticalX = verticalRefX - shoulder.x;
    double shoulderToVerticalY = verticalRefY - shoulder.y;
    double shoulderToElbowX = elbow.x - shoulder.x;
    double shoulderToElbowY = elbow.y - shoulder.y;

    // Calculate angle using dot product
    double dotProduct =
        shoulderToVerticalX * shoulderToElbowX +
        shoulderToVerticalY * shoulderToElbowY;
    double magnitudeVertical = math.sqrt(
      shoulderToVerticalX * shoulderToVerticalX +
          shoulderToVerticalY * shoulderToVerticalY,
    );
    double magnitudeElbow = math.sqrt(
      shoulderToElbowX * shoulderToElbowX + shoulderToElbowY * shoulderToElbowY,
    );

    double cosAngle = dotProduct / (magnitudeVertical * magnitudeElbow);
    cosAngle = math.max(-1.0, math.min(1.0, cosAngle)); // Clamp to [-1, 1]

    double angle = math.acos(cosAngle) * 180 / math.pi;
    return angle;
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

  // Calculate scapular retraction
  static double _calculateScapularRetraction(
    PoseLandmark leftShoulder,
    PoseLandmark rightShoulder,
    PoseLandmark leftElbow,
    PoseLandmark rightElbow,
  ) {
    double shoulderWidth = _calculateDistance(leftShoulder, rightShoulder);
    double elbowWidth = _calculateDistance(leftElbow, rightElbow);

    // Higher values indicate better scapular retraction
    return (elbowWidth / shoulderWidth) * 100;
  }

  // Main lat pulldown analysis function
  static Map<String, dynamic> analyzeLatPulldownForm(
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

    // Check if person is in lat pulldown position
    if (!_isInPulldownPosition(landmarkMap)) {
      if (_currentPhase != PHASE_SETUP) {
        _currentPhase = PHASE_SETUP;
        _elbowAngleHistory.clear();
        _shoulderFlexionHistory.clear();
        _torsoAngleHistory.clear();
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
          'Position yourself in full view of camera',
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
        _speakFeedback("Optimizing for $bodyTypeName build", isUrgent: false);
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

    // Shoulder flexion analysis
    double leftShoulderFlexion = _calculateShoulderFlexion(
      validLandmarks['leftShoulder']!,
      validLandmarks['leftElbow']!,
      validLandmarks['leftHip']!,
    );
    double rightShoulderFlexion = _calculateShoulderFlexion(
      validLandmarks['rightShoulder']!,
      validLandmarks['rightElbow']!,
      validLandmarks['rightHip']!,
    );
    double avgShoulderFlexion =
        (leftShoulderFlexion + rightShoulderFlexion) / 2;

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

    // Torso angle (leaning back assessment)
    double torsoAngle = _calculateTorsoAngle(
      validLandmarks['leftShoulder']!,
      validLandmarks['rightShoulder']!,
      validLandmarks['leftHip']!,
      validLandmarks['rightHip']!,
    );

    // Pull path analysis
    double pullPath = _calculatePullPath(
      validLandmarks['leftWrist']!,
      validLandmarks['rightWrist']!,
      validLandmarks['leftShoulder']!,
      validLandmarks['rightShoulder']!,
    );

    // Scapular retraction assessment
    double scapularRetraction = _calculateScapularRetraction(
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
    if (avgShoulderFlexion < SHOULDER_IMPINGEMENT_THRESHOLD) {
      feedback = 'Don\'t pull behind neck! Injury risk';
      feedbackColor = Colors.red;
      formScore -= 50;
    } else if (torsoAngle > EXCESSIVE_LEAN_THRESHOLD) {
      feedback = 'Stop leaning back! Stay upright';
      feedbackColor = Colors.red;
      formScore -= 35;
    } else if (gripRatio < ranges['gripWidthRatio']! - 0.4) {
      feedback = 'Grip too narrow! Widen for better lat activation';
      feedbackColor = Colors.orange;
      formScore -= 25;
    } else if (gripRatio > ranges['gripWidthRatio']! + 0.4) {
      feedback = 'Grip too wide! Risk of shoulder injury';
      feedbackColor = Colors.orange;
      formScore -= 25;
    } else if (scapularRetraction < ranges['scapularRetractionMin']!) {
      feedback = 'Depress and retract shoulder blades';
      feedbackColor = Colors.orange;
      formScore -= 20;
    } else if (pullPath > 25.0) {
      feedback = 'Don\'t swing or use momentum';
      feedbackColor = Colors.orange;
      formScore -= 20;
    }

    // Phase detection and movement-specific feedback
    int newPhase = _currentPhase;

    // Phase transitions based on elbow angle and movement
    if (smoothedElbowAngle >= 160.0) {
      newPhase = PHASE_SETUP;
    } else if (smoothedElbowAngle > 140.0 && smoothedElbowAngle < 160.0) {
      newPhase = PHASE_INITIATION;
    } else if (smoothedElbowAngle > 90.0 && smoothedElbowAngle <= 140.0) {
      newPhase = PHASE_PULLING;
    } else if (smoothedElbowAngle >= ranges['elbowAngleMin']! &&
        smoothedElbowAngle <= ranges['elbowAngleMax']!) {
      newPhase = PHASE_PEAK_CONTRACTION;
    } else if (smoothedElbowAngle < ranges['elbowAngleMin']!) {
      newPhase = PHASE_ECCENTRIC;
    }

    // Rep counting logic
    if (newPhase == PHASE_PEAK_CONTRACTION &&
        _currentPhase != PHASE_PEAK_CONTRACTION) {
      _repCount++;
      onRepCountUpdate(_repCount);
      _announceRepCount(_repCount);

      if (feedback.isEmpty) {
        feedback = 'Great rep! Reset for next one';
        feedbackColor = Colors.green;
      }
    }

    // Movement-specific feedback if no critical issues
    if (feedback.isEmpty) {
      switch (newPhase) {
        case PHASE_SETUP:
          feedback = 'Grip bar with palms facing forward';
          feedbackColor = Colors.blue;
          break;
        case PHASE_INITIATION:
          feedback = 'Initiate pull with lats, not arms';
          feedbackColor = Colors.blue;
          break;
        case PHASE_PULLING:
          if (smoothedElbowAngle - _previousElbowAngle > 5.0) {
            feedback = 'Control the eccentric! Don\'t let bar fly up';
            feedbackColor = Colors.orange;
            formScore -= 15;
          } else {
            feedback = 'Keep chest up and shoulders back';
            feedbackColor = Colors.green;
          }
          break;
        case PHASE_PEAK_CONTRACTION:
          feedback = 'Perfect lat activation! Feel the squeeze';
          feedbackColor = Colors.green;
          break;
        case PHASE_ECCENTRIC:
          feedback = 'Slow and controlled descent';
          feedbackColor = Colors.blue;
          break;
      }
    }

    // Form score adjustments based on range compliance
    if (smoothedElbowAngle < ranges['elbowAngleMin']! - 10.0) {
      formScore -= 20;
    } else if (smoothedElbowAngle > ranges['elbowAngleMax']! + 10.0) {
      formScore -= 15;
    }

    if (avgShoulderFlexion < ranges['shoulderFlexionMin']!) {
      formScore -= 15;
    } else if (avgShoulderFlexion > ranges['shoulderFlexionMax']!) {
      formScore -= 10;
    }

    if (torsoAngle > ranges['torsoLeanMax']!) {
      formScore -= 10;
    }

    // Ensure form score doesn't go below 0
    formScore = math.max(0, formScore);

    // Update phase and previous values
    _currentPhase = newPhase;
    _previousElbowAngle = smoothedElbowAngle;

    // Update feedback
    _updateFeedback(feedback, feedbackColor, onFeedbackUpdate);

    return {
      'phase': _currentPhase,
      'repCount': _repCount,
      'formScore': formScore,
      'bodyType': getBodyTypeName(_detectedBodyType),
      'humanPresent': true,
      'elbowAngle': smoothedElbowAngle,
      'shoulderFlexion': avgShoulderFlexion,
      'torsoAngle': torsoAngle,
      'gripRatio': gripRatio,
      'scapularRetraction': scapularRetraction,
      'pullPath': pullPath,
    };
  }

  // Reset session data
  static void resetSession() {
    _currentPhase = PHASE_SETUP;
    _repCount = 0;
    _previousElbowAngle = 170.0;
    _previousBarHeight = 0.0;
    _elbowAngleHistory.clear();
    _shoulderFlexionHistory.clear();
    _torsoAngleHistory.clear();
    _lastPhaseChange = DateTime.now();
    _lastFeedbackChange = DateTime.now();
    _lastFeedback = '';
    _lastFeedbackColor = Colors.blue;
    _bodyTypeCalibrated = false;
    _detectedBodyType = AVERAGE_BUILD;
    _anthropometricHistory.clear();
    _pullPathHistory.clear();
  }

  // Get body type name
  static String getBodyTypeName(int bodyType) {
    if (bodyType < 0 || bodyType >= bodyTypeNames.length) {
      return bodyTypeNames[AVERAGE_BUILD];
    }
    return bodyTypeNames[bodyType];
  }

  // Toggle voice feedback
  static void toggleVoiceFeedback() {
    _isVoiceEnabled = !_isVoiceEnabled;
  }

  // Get current session stats
  static Map<String, dynamic> getSessionStats() {
    return {
      'repCount': _repCount,
      'currentPhase': _currentPhase,
      'bodyType': getBodyTypeName(_detectedBodyType),
      'isVoiceEnabled': _isVoiceEnabled,
      'bodyTypeCalibrated': _bodyTypeCalibrated,
    };
  }

  // Dispose resources
  static void dispose() {
    _flutterTts?.stop();
    _flutterTts = null;
    resetSession();
  }
}
