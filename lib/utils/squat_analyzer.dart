import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SquatAnalyzer {
  // Body type classifications for squat optimization
  static const int LONG_FEMUR = 0;
  static const int SHORT_FEMUR = 1;
  static const int LONG_TORSO = 2;
  static const int SHORT_TORSO = 3;
  static const int AVERAGE_BUILD = 4;
  static const int ANKLE_MOBILITY_LIMITED = 5;
  static const int HIP_MOBILITY_LIMITED = 6;

  // Voice feedback instance
  static FlutterTts? _flutterTts;
  static bool _isVoiceEnabled = true;
  static DateTime _lastVoiceFeedback = DateTime.now();
  static String _lastSpokenText = '';
  static bool _isSpeaking = false;

  // Body type specific ranges based on biomechanical research
  static Map<int, Map<String, double>> bodyTypeRanges = {
    LONG_FEMUR: {
      'kneeAngleMin': 70.0,
      'kneeAngleMax': 110.0,
      'hipAngleMin': 60.0,
      'hipAngleMax': 100.0,
      'ankleAngleMin': 60.0,
      'ankleAngleMax': 90.0,
      'trunkAngleMin': 30.0,
      'trunkAngleMax': 45.0,
      'stanceWidthRatio': 1.2,
      'toeOutAngle': 15.0,
      'depthRatio': 0.9,
      'kneeTrackingTolerance': 15.0,
    },
    SHORT_FEMUR: {
      'kneeAngleMin': 80.0,
      'kneeAngleMax': 130.0,
      'hipAngleMin': 70.0,
      'hipAngleMax': 120.0,
      'ankleAngleMin': 70.0,
      'ankleAngleMax': 100.0,
      'trunkAngleMin': 15.0,
      'trunkAngleMax': 30.0,
      'stanceWidthRatio': 1.0,
      'toeOutAngle': 10.0,
      'depthRatio': 1.1,
      'kneeTrackingTolerance': 10.0,
    },
    LONG_TORSO: {
      'kneeAngleMin': 75.0,
      'kneeAngleMax': 120.0,
      'hipAngleMin': 65.0,
      'hipAngleMax': 110.0,
      'ankleAngleMin': 65.0,
      'ankleAngleMax': 95.0,
      'trunkAngleMin': 10.0,
      'trunkAngleMax': 25.0,
      'stanceWidthRatio': 1.1,
      'toeOutAngle': 12.0,
      'depthRatio': 1.0,
      'kneeTrackingTolerance': 12.0,
    },
    SHORT_TORSO: {
      'kneeAngleMin': 70.0,
      'kneeAngleMax': 115.0,
      'hipAngleMin': 60.0,
      'hipAngleMax': 105.0,
      'ankleAngleMin': 60.0,
      'ankleAngleMax': 85.0,
      'trunkAngleMin': 25.0,
      'trunkAngleMax': 40.0,
      'stanceWidthRatio': 1.3,
      'toeOutAngle': 18.0,
      'depthRatio': 0.95,
      'kneeTrackingTolerance': 18.0,
    },
    AVERAGE_BUILD: {
      'kneeAngleMin': 75.0,
      'kneeAngleMax': 120.0,
      'hipAngleMin': 65.0,
      'hipAngleMax': 110.0,
      'ankleAngleMin': 65.0,
      'ankleAngleMax': 95.0,
      'trunkAngleMin': 15.0,
      'trunkAngleMax': 30.0,
      'stanceWidthRatio': 1.15,
      'toeOutAngle': 15.0,
      'depthRatio': 1.0,
      'kneeTrackingTolerance': 15.0,
    },
    ANKLE_MOBILITY_LIMITED: {
      'kneeAngleMin': 70.0,
      'kneeAngleMax': 110.0,
      'hipAngleMin': 60.0,
      'hipAngleMax': 100.0,
      'ankleAngleMin': 70.0,
      'ankleAngleMax': 85.0,
      'trunkAngleMin': 20.0,
      'trunkAngleMax': 35.0,
      'stanceWidthRatio': 1.25,
      'toeOutAngle': 20.0,
      'depthRatio': 0.85,
      'kneeTrackingTolerance': 20.0,
    },
    HIP_MOBILITY_LIMITED: {
      'kneeAngleMin': 80.0,
      'kneeAngleMax': 115.0,
      'hipAngleMin': 70.0,
      'hipAngleMax': 105.0,
      'ankleAngleMin': 60.0,
      'ankleAngleMax': 90.0,
      'trunkAngleMin': 25.0,
      'trunkAngleMax': 40.0,
      'stanceWidthRatio': 1.3,
      'toeOutAngle': 25.0,
      'depthRatio': 0.9,
      'kneeTrackingTolerance': 25.0,
    },
  };

  static const List<String> bodyTypeNames = [
    'longFemur',
    'shortFemur',
    'longTorso',
    'shortTorso',
    'averageBuild',
    'ankleMobilityLimited',
    'hipMobilityLimited',
  ];

  // Squat specific constants
  static const double STANDING_KNEE_ANGLE = 170.0;
  static const double DEEP_SQUAT_KNEE_ANGLE = 70.0;
  static const double PROPER_DEPTH_RATIO = 0.9; // Hip crease below knee
  static const double KNEE_VALGUS_THRESHOLD = 15.0;
  static const double HEEL_RAISE_THRESHOLD = 10.0;

  // Movement phases for squat
  static const int PHASE_STANDING = 0;
  static const int PHASE_DESCENT = 1;
  static const int PHASE_BOTTOM = 2;
  static const int PHASE_ASCENT = 3;
  static const int PHASE_LOCKOUT = 4;

  // Session tracking with enhanced stability
  static int _currentPhase = PHASE_STANDING;
  static int _repCount = 0;
  static double _previousKneeAngle = 170.0;
  static double _previousHipAngle = 180.0;
  static double _previousAnkleAngle = 90.0;
  static List<double> _kneeAngleHistory = [];
  static List<double> _hipAngleHistory = [];
  static List<double> _ankleAngleHistory = [];
  static List<double> _trunkAngleHistory = [];
  static DateTime _lastPhaseChange = DateTime.now();
  static DateTime _lastFeedbackChange = DateTime.now();
  static String _lastFeedback = '';
  static Color _lastFeedbackColor = Colors.blue;
  static int _detectedBodyType = AVERAGE_BUILD;
  static bool _bodyTypeCalibrated = false;

  // Biomechanical measurements
  static double _femurLength = 0.0;
  static double _tibiaLength = 0.0;
  static double _torsoLength = 0.0;
  static double _ankleMobility = 0.0;
  static double _hipMobility = 0.0;
  static List<double> _anthropometricHistory = [];
  static List<double> _kneeTrackingHistory = [];
  static List<double> _heelRaiseHistory = [];

  // Enhanced feedback mapping for squat
  static Map<String, String> _voiceFeedbackMap = {
    // Setup and positioning
    'Feet shoulder-width apart! Check stance': 'Feet shoulder-width apart',
    'Toes pointed out 15 degrees': 'Point toes out slightly',
    'Core engaged! Maintain neutral spine': 'Engage your core',
    'Chest up! Keep proud posture': 'Keep chest up',
    'Weight on whole foot! Not on toes': 'Weight on whole foot',
    'Stance too narrow for your build': 'Widen your stance',
    'Stance too wide! Narrow it down': 'Narrow your stance',

    // Descent phase
    'Hips back first! Lead with hips': 'Hips back first',
    'Knees tracking over toes! Good form': 'Knees tracking well',
    'Knees caving in! Push them out': 'Push knees out',
    'Control the descent! Slow and steady': 'Control the descent',
    'Keep heels down! No heel raise': 'Keep heels down',
    'Maintain neutral spine! Don\'t round': 'Keep spine neutral',

    // Bottom position
    'Perfect depth! Hip crease below knee': 'Perfect depth',
    'Go deeper! Not quite parallel': 'Go deeper',
    'Too deep! Risk of butt wink': 'Come up slightly',
    'Hold position! Feel the stretch': 'Hold the position',
    'Knees out! Maintain knee position': 'Keep knees out',

    // Ascent phase
    'Drive through heels! Push the floor': 'Drive through heels',
    'Hips and chest up together': 'Hips and chest together',
    'Knees out on the way up': 'Push knees out',
    'Don\'t let knees cave! Stay strong': 'Don\'t let knees cave',
    'Almost there! Push to lockout': 'Push to lockout',

    // Lockout and completion
    'Excellent rep! Reset position': 'Excellent rep',
    'Full lockout! Stand tall': 'Stand tall',
    'Great form! Maintain consistency': 'Great form',
    'Perfect squat for your build': 'Perfect squat',

    // Safety and corrections
    'Butt wink detected! Limit depth': 'Limit your depth',
    'Excessive forward lean! More upright': 'More upright',
    'Heel raise! Improve ankle mobility': 'Keep heels down',
    'Knee valgus! Strengthen glutes': 'Strengthen your glutes',
    'Maintain tension! Don\'t relax': 'Maintain tension',
    'Breathe at top! Don\'t hold breath': 'Breathe at the top',
  };

  // Initialize voice feedback system
  static Future<void> initializeVoiceFeedback() async {
    _flutterTts = FlutterTts();

    await _flutterTts!.setLanguage("en-US");
    await _flutterTts!.setSpeechRate(0.65);
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
      await _speakFeedback("First squat complete", isUrgent: false);
    } else if (count == 5) {
      await _speakFeedback("5 squats! Building strength", isUrgent: false);
    } else if (count == 10) {
      await _speakFeedback("10 squats! Excellent endurance", isUrgent: false);
    } else if (count % 10 == 0 && count > 10) {
      await _speakFeedback("$count squats! Outstanding", isUrgent: false);
    } else if (count <= 3) {
      await _speakFeedback("Squat $count complete", isUrgent: false);
    }
  }

  // Enhanced human detection for squat position
  static bool _isInSquatPosition(Map<String, PoseLandmark?> landmarkMap) {
    List<String> requiredLandmarks = [
      'leftShoulder',
      'rightShoulder',
      'leftHip',
      'rightHip',
      'leftKnee',
      'rightKnee',
      'leftAnkle',
      'rightAnkle',
      'leftHeel',
      'rightHeel',
    ];

    // Check for hip landmark (most critical for squat)
    if (landmarkMap['leftHip'] == null || landmarkMap['rightHip'] == null) {
      return false;
    }

    // Check if person is in standing/squatting position (not lying down)
    final leftHip = landmarkMap['leftHip']!;
    final rightHip = landmarkMap['rightHip']!;
    final leftKnee = landmarkMap['leftKnee'];
    final rightKnee = landmarkMap['rightKnee'];
    final leftAnkle = landmarkMap['leftAnkle'];
    final rightAnkle = landmarkMap['rightAnkle'];

    if (leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return false;
    }

    // Check if person is upright (hip above knee above ankle)
    bool leftLegUpright = leftHip.y < leftKnee.y && leftKnee.y < leftAnkle.y;
    bool rightLegUpright =
        rightHip.y < rightKnee.y && rightKnee.y < rightAnkle.y;

    if (!leftLegUpright && !rightLegUpright) {
      return false;
    }

    // Check if feet are roughly at the same level (standing position)
    double footLevelDifference = (leftAnkle.y - rightAnkle.y).abs();
    if (footLevelDifference > 50)
      return false; // Too much difference in foot height

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

  // Detect body type for squat optimization
  static int _detectBodyType(Map<String, PoseLandmark> landmarks) {
    final leftHip = landmarks['leftHip']!;
    final rightHip = landmarks['rightHip']!;
    final leftKnee = landmarks['leftKnee']!;
    final rightKnee = landmarks['rightKnee']!;
    final leftAnkle = landmarks['leftAnkle']!;
    final rightAnkle = landmarks['rightAnkle']!;
    final leftShoulder = landmarks['leftShoulder']!;
    final rightShoulder = landmarks['rightShoulder']!;

    // Calculate key measurements
    double leftFemurLength = _calculateDistance(leftHip, leftKnee);
    double rightFemurLength = _calculateDistance(rightHip, rightKnee);
    double avgFemurLength = (leftFemurLength + rightFemurLength) / 2;

    double leftTibiaLength = _calculateDistance(leftKnee, leftAnkle);
    double rightTibiaLength = _calculateDistance(rightKnee, rightAnkle);
    double avgTibiaLength = (leftTibiaLength + rightTibiaLength) / 2;

    double leftTorsoLength = _calculateDistance(leftShoulder, leftHip);
    double rightTorsoLength = _calculateDistance(rightShoulder, rightHip);
    double avgTorsoLength = (leftTorsoLength + rightTorsoLength) / 2;

    // Store measurements
    _femurLength = avgFemurLength / avgTibiaLength;
    _tibiaLength = avgTibiaLength;
    _torsoLength = avgTorsoLength / avgFemurLength;

    // Add to history for stability
    _anthropometricHistory.add(_femurLength);
    if (_anthropometricHistory.length > 8) {
      _anthropometricHistory.removeAt(0);
    }

    if (_anthropometricHistory.length < 4) return AVERAGE_BUILD;

    double avgFemurRatio =
        _anthropometricHistory.reduce((a, b) => a + b) /
        _anthropometricHistory.length;

    // Classification based on research
    if (avgFemurRatio > 1.3) {
      return LONG_FEMUR;
    } else if (avgFemurRatio < 0.9) {
      return SHORT_FEMUR;
    } else if (_torsoLength > 1.4) {
      return LONG_TORSO;
    } else if (_torsoLength < 1.1) {
      return SHORT_TORSO;
    } else {
      return AVERAGE_BUILD;
    }
  }

  // Calculate knee tracking (knee valgus/varus)
  static double _calculateKneeTracking(
    PoseLandmark hip,
    PoseLandmark knee,
    PoseLandmark ankle,
  ) {
    // Calculate the angle between hip-knee and knee-ankle vectors
    double hipKneeAngle = math.atan2(knee.y - hip.y, knee.x - hip.x);
    double kneeAnkleAngle = math.atan2(ankle.y - knee.y, ankle.x - knee.x);
    double trackingAngle = (hipKneeAngle - kneeAnkleAngle) * 180 / math.pi;

    return trackingAngle.abs();
  }

  // Calculate heel raise (dorsiflexion)
  static double _calculateHeelRaise(
    PoseLandmark knee,
    PoseLandmark ankle,
    PoseLandmark heel,
  ) {
    // Calculate ankle angle to detect heel raise
    double ankleAngle = _calculateAngle(knee, ankle, heel);
    return ankleAngle > 100 ? ankleAngle - 100 : 0; // Excess dorsiflexion
  }

  // Calculate trunk angle
  static double _calculateTrunkAngle(PoseLandmark shoulder, PoseLandmark hip) {
    double angle =
        math.atan2(shoulder.y - hip.y, shoulder.x - hip.x) * 180 / math.pi;
    return (90 - angle.abs()).abs(); // Convert to forward lean angle
  }

  // Calculate squat depth ratio
  static double _calculateSquatDepth(PoseLandmark hip, PoseLandmark knee) {
    // Hip crease position relative to knee
    return hip.y / knee.y;
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

  // Main squat analysis function
  static Map<String, dynamic> analyzeSquatForm(
    Pose pose,
    Function(String, Color) onFeedbackUpdate,
    Function(int) onRepCountUpdate,
  ) {
    final landmarks = pose.landmarks;

    // Create landmark map
    Map<String, PoseLandmark?> landmarkMap = {
      'leftShoulder': landmarks[PoseLandmarkType.leftShoulder],
      'rightShoulder': landmarks[PoseLandmarkType.rightShoulder],
      'leftHip': landmarks[PoseLandmarkType.leftHip],
      'rightHip': landmarks[PoseLandmarkType.rightHip],
      'leftKnee': landmarks[PoseLandmarkType.leftKnee],
      'rightKnee': landmarks[PoseLandmarkType.rightKnee],
      'leftAnkle': landmarks[PoseLandmarkType.leftAnkle],
      'rightAnkle': landmarks[PoseLandmarkType.rightAnkle],
      'leftHeel': landmarks[PoseLandmarkType.leftHeel],
      'rightHeel': landmarks[PoseLandmarkType.rightHeel],
      'leftFootIndex': landmarks[PoseLandmarkType.leftFootIndex],
      'rightFootIndex': landmarks[PoseLandmarkType.rightFootIndex],
      'nose': landmarks[PoseLandmarkType.nose],
    };

    // Check if person is in squat position
    if (!_isInSquatPosition(landmarkMap)) {
      if (_currentPhase != PHASE_STANDING) {
        _currentPhase = PHASE_STANDING;
        _kneeAngleHistory.clear();
        _hipAngleHistory.clear();
        _ankleAngleHistory.clear();
        _trunkAngleHistory.clear();
      }

      return {
        'phase': PHASE_STANDING,
        'repCount': _repCount,
        'formScore': 0,
        'bodyType': getBodyTypeName(_detectedBodyType),
        'humanPresent': false,
      };
    }

    // Check for critical landmarks
    List<String> criticalLandmarks = [
      'leftHip',
      'rightHip',
      'leftKnee',
      'rightKnee',
      'leftAnkle',
      'rightAnkle',
      'leftShoulder',
      'rightShoulder',
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

    // Smooth angle tracking
    _kneeAngleHistory.add(avgKneeAngle);
    _hipAngleHistory.add(avgHipAngle);

    if (_kneeAngleHistory.length > 6) {
      _kneeAngleHistory.removeAt(0);
    }
    if (_hipAngleHistory.length > 6) {
      _hipAngleHistory.removeAt(0);
    }

    double smoothedKneeAngle =
        _kneeAngleHistory.reduce((a, b) => a + b) / _kneeAngleHistory.length;
    double smoothedHipAngle =
        _hipAngleHistory.reduce((a, b) => a + b) / _hipAngleHistory.length;

    // Stance width analysis
    double stanceWidth = _calculateDistance(
      validLandmarks['leftAnkle']!,
      validLandmarks['rightAnkle']!,
    );
    double shoulderWidth = _calculateDistance(
      validLandmarks['leftShoulder']!,
      validLandmarks['rightShoulder']!,
    );
    double stanceRatio = stanceWidth / shoulderWidth;

    // Knee tracking analysis
    double leftKneeTracking = _calculateKneeTracking(
      validLandmarks['leftHip']!,
      validLandmarks['leftKnee']!,
      validLandmarks['leftAnkle']!,
    );
    double rightKneeTracking = _calculateKneeTracking(
      validLandmarks['rightHip']!,
      validLandmarks['rightKnee']!,
      validLandmarks['rightAnkle']!,
    );
    double avgKneeTracking = (leftKneeTracking + rightKneeTracking) / 2;

    // Trunk angle analysis
    double trunkAngle = _calculateTrunkAngle(
      validLandmarks['leftShoulder']!,
      validLandmarks['leftHip']!,
    );

    // Squat depth analysis
    double squatDepth = _calculateSquatDepth(
      validLandmarks['leftHip']!,
      validLandmarks['leftKnee']!,
    );

    // Heel raise detection
    double leftHeelRaise = validLandmarks['leftHeel'] != null
        ? _calculateHeelRaise(
            validLandmarks['leftKnee']!,
            validLandmarks['leftAnkle']!,
            validLandmarks['leftHeel']!,
          )
        : 0.0;
    double rightHeelRaise = validLandmarks['rightHeel'] != null
        ? _calculateHeelRaise(
            validLandmarks['rightKnee']!,
            validLandmarks['rightAnkle']!,
            validLandmarks['rightHeel']!,
          )
        : 0.0;
    double avgHeelRaise = (leftHeelRaise + rightHeelRaise) / 2;

    // Phase detection based on knee angle changes
    DateTime now = DateTime.now();
    int previousPhase = _currentPhase;

    if (smoothedKneeAngle > 150 && _currentPhase != PHASE_STANDING) {
      _currentPhase = PHASE_STANDING;
      if (previousPhase == PHASE_ASCENT) {
        _repCount++;
        onRepCountUpdate(_repCount);
        _announceRepCount(_repCount);
      }
    } else if (smoothedKneeAngle < 140 &&
        smoothedKneeAngle > 100 &&
        _currentPhase == PHASE_STANDING) {
      _currentPhase = PHASE_DESCENT;
    } else if (smoothedKneeAngle <= 100 &&
        smoothedKneeAngle > ranges['kneeAngleMin']! &&
        _currentPhase == PHASE_DESCENT) {
      _currentPhase = PHASE_BOTTOM;
    } else if (smoothedKneeAngle > ranges['kneeAngleMin']! &&
        smoothedKneeAngle < 130 &&
        _currentPhase == PHASE_BOTTOM) {
      _currentPhase = PHASE_ASCENT;
    }

    // Phase change timing
    if (previousPhase != _currentPhase) {
      _lastPhaseChange = now;
    }

    // Form analysis and feedback
    String feedback = '';
    Color feedbackColor = Colors.blue;
    int formScore = 100;

    // Critical safety checks first
    if (avgKneeTracking > ranges['kneeTrackingTolerance']!) {
      feedback = 'Knees caving in! Push them out';
      feedbackColor = Colors.red;
      formScore -= 25;
    } else if (avgHeelRaise > HEEL_RAISE_THRESHOLD) {
      feedback = 'Keep heels down! No heel raise';
      feedbackColor = Colors.red;
      formScore -= 20;
    } else if (trunkAngle > ranges['trunkAngleMax']! + 10) {
      feedback = 'Excessive forward lean! More upright';
      feedbackColor = Colors.red;
      formScore -= 20;
    }
    // Stance width feedback
    else if (stanceRatio < ranges['stanceWidthRatio']! - 0.2) {
      feedback =
          _detectedBodyType == LONG_FEMUR || _detectedBodyType == SHORT_TORSO
          ? 'Stance too narrow for your build'
          : 'Feet shoulder-width apart! Check stance';
      feedbackColor = Colors.orange;
      formScore -= 15;
    } else if (stanceRatio > ranges['stanceWidthRatio']! + 0.3) {
      feedback = 'Stance too wide! Narrow it down';
      feedbackColor = Colors.orange;
      formScore -= 15;
    }
    // Phase-specific feedback
    else {
      switch (_currentPhase) {
        case PHASE_STANDING:
          if (now.difference(_lastPhaseChange).inMilliseconds > 3000) {
            feedback = 'Core engaged! Maintain neutral spine';
            feedbackColor = Colors.blue;
          } else {
            feedback = 'Excellent rep! Reset position';
            feedbackColor = Colors.green;
          }
          break;

        case PHASE_DESCENT:
          if (smoothedKneeAngle - _previousKneeAngle > 5) {
            feedback = 'Control the descent! Slow and steady';
            feedbackColor = Colors.orange;
            formScore -= 10;
          } else if (avgKneeTracking > ranges['kneeTrackingTolerance']! - 5) {
            feedback = 'Knees tracking over toes! Good form';
            feedbackColor = Colors.blue;
          } else {
            feedback = 'Hips back first! Lead with hips';
            feedbackColor = Colors.blue;
          }
          break;

        case PHASE_BOTTOM:
          if (squatDepth < ranges['depthRatio']!) {
            feedback = 'Go deeper! Not quite parallel';
            feedbackColor = Colors.orange;
            formScore -= 15;
          } else if (squatDepth > ranges['depthRatio']! + 0.15) {
            feedback = 'Too deep! Risk of butt wink';
            feedbackColor = Colors.orange;
            formScore -= 10;
          } else if (trunkAngle > ranges['trunkAngleMax']!) {
            feedback = 'Maintain neutral spine! Don\'t round';
            feedbackColor = Colors.orange;
            formScore -= 10;
          } else {
            feedback = 'Perfect depth! Hip crease below knee';
            feedbackColor = Colors.green;
          }
          break;

        case PHASE_ASCENT:
          if (_previousKneeAngle - smoothedKneeAngle > 8) {
            feedback = 'Drive through heels! Push the floor';
            feedbackColor = Colors.blue;
          } else if (avgKneeTracking > ranges['kneeTrackingTolerance']! - 5) {
            feedback = 'Don\'t let knees cave! Stay strong';
            feedbackColor = Colors.orange;
            formScore -= 10;
          } else {
            feedback = 'Hips and chest up together';
            feedbackColor = Colors.blue;
          }
          break;
      }
    }

    // Body type specific encouragement
    if (formScore > 85 && _currentPhase == PHASE_BOTTOM) {
      feedback = 'Perfect squat for your build';
      feedbackColor = Colors.green;
    }

    // Update feedback
    _updateFeedback(feedback, feedbackColor, onFeedbackUpdate);

    // Store previous values
    _previousKneeAngle = smoothedKneeAngle;
    _previousHipAngle = smoothedHipAngle;

    // Return comprehensive analysis
    return {
      'phase': _currentPhase,
      'repCount': _repCount,
      'formScore': formScore,
      'bodyType': getBodyTypeName(_detectedBodyType),
      'humanPresent': true,
      'kneeAngle': smoothedKneeAngle,
      'hipAngle': smoothedHipAngle,
      'ankleAngle': (leftKneeAngle + rightKneeAngle) / 2, // Simplified for demo
      'trunkAngle': trunkAngle,
      'squatDepth': squatDepth,
      'kneeTracking': avgKneeTracking,
      'heelRaise': avgHeelRaise,
      'stanceWidth': stanceRatio,
      'measurements': {
        'femurLength': _femurLength,
        'torsoLength': _torsoLength,
        'ankleMobility': _ankleMobility,
        'hipMobility': _hipMobility,
      },
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
    _currentPhase = PHASE_STANDING;
    _repCount = 0;
    _previousKneeAngle = 170.0;
    _previousHipAngle = 180.0;
    _previousAnkleAngle = 90.0;
    _kneeAngleHistory.clear();
    _hipAngleHistory.clear();
    _ankleAngleHistory.clear();
    _trunkAngleHistory.clear();
    _lastPhaseChange = DateTime.now();
    _lastFeedbackChange = DateTime.now();
    _lastFeedback = '';
    _lastFeedbackColor = Colors.blue;
    _detectedBodyType = AVERAGE_BUILD;
    _bodyTypeCalibrated = false;
    _femurLength = 0.0;
    _tibiaLength = 0.0;
    _torsoLength = 0.0;
    _ankleMobility = 0.0;
    _hipMobility = 0.0;
    _anthropometricHistory.clear();
    _kneeTrackingHistory.clear();
    _heelRaiseHistory.clear();
    _lastSpokenText = '';
  }

  // Get current session statistics
  static Map<String, dynamic> getSessionStats() {
    return {
      'totalReps': _repCount,
      'currentPhase': _currentPhase,
      'bodyType': getBodyTypeName(_detectedBodyType),
      'sessionDuration': DateTime.now().difference(_lastPhaseChange).inSeconds,
      'isCalibrated': _bodyTypeCalibrated,
      'measurements': {
        'femurLength': _femurLength,
        'torsoLength': _torsoLength,
        'averageFormScore': _repCount > 0 ? 85 : 0, // Simplified calculation
      },
    };
  }

  // Voice control methods
  static void enableVoiceFeedback() {
    _isVoiceEnabled = true;
  }

  static void disableVoiceFeedback() {
    _isVoiceEnabled = false;
    if (_flutterTts != null && _isSpeaking) {
      _flutterTts!.stop();
      _isSpeaking = false;
    }
  }

  static bool isVoiceEnabled() {
    return _isVoiceEnabled;
  }

  // Dispose resources
  static void dispose() {
    if (_flutterTts != null) {
      _flutterTts!.stop();
      _flutterTts = null;
    }
    resetSession();
  }

  // Get phase name for UI display
  static String getPhaseName(int phase) {
    switch (phase) {
      case PHASE_STANDING:
        return 'Standing';
      case PHASE_DESCENT:
        return 'Descent';
      case PHASE_BOTTOM:
        return 'Bottom';
      case PHASE_ASCENT:
        return 'Ascent';
      case PHASE_LOCKOUT:
        return 'Lockout';
      default:
        return 'Unknown';
    }
  }

  // Get body type recommendations
  static Map<String, dynamic> getBodyTypeRecommendations(int bodyType) {
    Map<String, double> ranges =
        bodyTypeRanges[bodyType] ?? bodyTypeRanges[AVERAGE_BUILD]!;

    return {
      'stanceWidth':
          '${ranges['stanceWidthRatio']!.toStringAsFixed(1)}x shoulder width',
      'toeAngle': '${ranges['toeOutAngle']!.toInt()}° outward',
      'depthTarget': ranges['depthRatio']! > 1.0
          ? 'Below parallel'
          : 'Parallel',
      'keyFocus': _getKeyFocusForBodyType(bodyType),
      'commonIssues': _getCommonIssuesForBodyType(bodyType),
    };
  }

  static String _getKeyFocusForBodyType(int bodyType) {
    switch (bodyType) {
      case LONG_FEMUR:
        return 'Wider stance, more forward lean acceptable';
      case SHORT_FEMUR:
        return 'Narrower stance, stay more upright';
      case LONG_TORSO:
        return 'Minimize forward lean, focus on hip mobility';
      case SHORT_TORSO:
        return 'Wider stance, work on ankle mobility';
      case ANKLE_MOBILITY_LIMITED:
        return 'Raised heels, limit depth, work on mobility';
      case HIP_MOBILITY_LIMITED:
        return 'Wider stance, higher foot angle, gradual depth';
      default:
        return 'Balanced approach, standard form cues';
    }
  }

  static List<String> _getCommonIssuesForBodyType(int bodyType) {
    switch (bodyType) {
      case LONG_FEMUR:
        return ['Knee valgus', 'Excessive forward lean', 'Depth challenges'];
      case SHORT_FEMUR:
        return ['Butt wink', 'Over-squatting', 'Heel raise'];
      case LONG_TORSO:
        return ['Forward lean', 'Hip impingement', 'Ankle stiffness'];
      case SHORT_TORSO:
        return ['Knee tracking', 'Ankle mobility', 'Balance issues'];
      case ANKLE_MOBILITY_LIMITED:
        return ['Heel raise', 'Forward lean', 'Depth limitation'];
      case HIP_MOBILITY_LIMITED:
        return ['Knee valgus', 'Butt wink', 'Depth challenges'];
      default:
        return [
          'General form maintenance',
          'Consistency',
          'Progressive overload',
        ];
    }
  }

  // Advanced analytics for trainer/coach view
  static Map<String, dynamic> getAdvancedAnalytics() {
    return {
      'anthropometrics': {
        'femurToTibiaRatio': _femurLength,
        'torsoToFemurRatio': _torsoLength,
        'ankleMobilityScore': _ankleMobility,
        'hipMobilityScore': _hipMobility,
      },
      'movementPatterns': {
        'kneeTrackingConsistency': _kneeTrackingHistory.isNotEmpty
            ? _kneeTrackingHistory.reduce((a, b) => a + b) /
                  _kneeTrackingHistory.length
            : 0.0,
        'heelRaiseFrequency': _heelRaiseHistory.isNotEmpty
            ? _heelRaiseHistory.where((x) => x > HEEL_RAISE_THRESHOLD).length /
                  _heelRaiseHistory.length
            : 0.0,
      },
      'recommendations': getBodyTypeRecommendations(_detectedBodyType),
      'calibrationStatus': _bodyTypeCalibrated,
      'sessionQuality': _repCount > 0 ? 'Good' : 'Needs more data',
    };
  }
}
