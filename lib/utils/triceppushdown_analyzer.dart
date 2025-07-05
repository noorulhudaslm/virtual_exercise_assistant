import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TricepPushdownAnalyzer {
  // Body type classifications for tricep pushdown optimization
  static const int SHORT_ARMS = 0;
  static const int AVERAGE = 1;
  static const int LONG_ARMS = 2;
  static const int BROAD_SHOULDERS = 3;
  static const int NARROW_SHOULDERS = 4;

  // Voice feedback instance
  static FlutterTts? _flutterTts;
  static bool _isVoiceEnabled = true;
  static DateTime _lastVoiceFeedback = DateTime.now();
  static String _lastSpokenText = '';
  static bool _isSpeaking = false;

  // Tricep pushdown specific ranges based on biomechanics research
  static Map<int, Map<String, double>> bodyTypeRanges = {
    SHORT_ARMS: {
      'startElbowAngle': 90.0, // Starting position angle
      'endElbowAngle': 160.0, // Full extension angle
      'elbowFlareMax': 15.0, // Maximum elbow flare from body
      'shoulderStabilityMin': 10.0, // Minimum shoulder retraction
      'gripWidthMin': 0.8, // Narrower grip suits shorter arms
      'gripWidthMax': 1.1,
      'torsoLeanMax': 5.0, // Less forward lean needed
      'wristDeviationMax': 10.0, // Wrist alignment tolerance
    },
    AVERAGE: {
      'startElbowAngle': 90.0,
      'endElbowAngle': 165.0,
      'elbowFlareMax': 12.0,
      'shoulderStabilityMin': 15.0,
      'gripWidthMin': 0.9,
      'gripWidthMax': 1.3,
      'torsoLeanMax': 8.0,
      'wristDeviationMax': 8.0,
    },
    LONG_ARMS: {
      'startElbowAngle': 85.0, // Slightly more bent start
      'endElbowAngle': 170.0, // Fuller extension possible
      'elbowFlareMax': 18.0, // More flare tendency
      'shoulderStabilityMin': 20.0, // Need more shoulder stability
      'gripWidthMin': 1.0, // Wider grip for longer arms
      'gripWidthMax': 1.4,
      'torsoLeanMax': 12.0, // More lean for better angle
      'wristDeviationMax': 12.0,
    },
    BROAD_SHOULDERS: {
      'startElbowAngle': 90.0,
      'endElbowAngle': 160.0,
      'elbowFlareMax': 20.0, // More flare acceptable
      'shoulderStabilityMin': 18.0,
      'gripWidthMin': 1.1, // Wider grip needed
      'gripWidthMax': 1.5,
      'torsoLeanMax': 6.0, // Less lean needed
      'wristDeviationMax': 10.0,
    },
    NARROW_SHOULDERS: {
      'startElbowAngle': 90.0,
      'endElbowAngle': 165.0,
      'elbowFlareMax': 10.0, // Keep elbows closer
      'shoulderStabilityMin': 12.0,
      'gripWidthMin': 0.8, // Narrower grip suits frame
      'gripWidthMax': 1.1,
      'torsoLeanMax': 10.0, // May need more lean
      'wristDeviationMax': 8.0,
    },
  };

  static const List<String> bodyTypeNames = [
    'shortArms',
    'average',
    'longArms',
    'broadShoulders',
    'narrowShoulders',
  ];

  // Tricep pushdown specific constants
  static const double STARTING_POSITION_ANGLE = 90.0; // Elbow at 90 degrees
  static const double FULL_EXTENSION_ANGLE = 165.0; // Nearly straight arms
  static const double ELBOW_STABILITY_THRESHOLD = 15.0; // Max elbow movement
  static const double PROPER_GRIP_HEIGHT = 0.15; // Chest to grip ratio

  // Movement phases for tricep pushdowns
  static const int PHASE_SETUP = 0;
  static const int PHASE_STARTING_POSITION = 1;
  static const int PHASE_PUSHING_DOWN = 2;
  static const int PHASE_FULL_EXTENSION = 3;
  static const int PHASE_RETURNING = 4;

  // Session tracking with stabilization
  static int _currentPhase = PHASE_SETUP;
  static int _repCount = 0;
  static double _previousElbowAngle = 90.0;
  static List<double> _elbowAngleHistory = [];
  static List<double> _elbowPositionHistory = [];
  static DateTime _lastPhaseChange = DateTime.now();
  static DateTime _lastFeedbackChange = DateTime.now();
  static String _lastFeedback = '';
  static Color _lastFeedbackColor = Colors.blue;
  static int _detectedBodyType = AVERAGE;
  static bool _bodyTypeCalibrated = false;

  // Tricep pushdown specific tracking
  static double _startingElbowHeight = 0.0;
  static double _currentElbowHeight = 0.0;
  static bool _startingPositionCalibrated = false;
  static double _shoulderStabilityBaseline = 0.0;
  static double _gripWidth = 0.0;

  // Anthropometric measurements for body type detection
  static double _armLength = 0.0;
  static double _shoulderWidth = 0.0;
  static double _armToShoulderRatio = 0.0;
  static List<double> _anthropometricHistory = [];

  // Voice feedback configuration for tricep pushdowns
  static Map<String, String> _voiceFeedbackMap = {
    // Setup and grip feedback
    'Position yourself at the cable machine': 'Position at cable machine',
    'Grip the attachment with both hands': 'Grip with both hands',
    'Step back to create tension in the cable': 'Step back, create tension',
    'Establish starting position with elbows at 90 degrees':
        'Elbows at 90 degrees',
    'Keep your elbows tucked to your sides': 'Keep elbows tucked',

    // Movement execution feedback
    'Push down by extending your elbows': 'Push down, extend elbows',
    'Squeeze your triceps at the bottom': 'Squeeze triceps at bottom',
    'Control the weight back up': 'Control the weight up',
    'Don\'t let the weight pull you up': 'Don\'t let weight pull you',
    'Maintain elbow position throughout': 'Maintain elbow position',
    'Full extension - great rep!': 'Full extension, great rep',
    'Smooth return to starting position': 'Smooth return up',

    // Form corrections
    'Elbows are flaring out! Keep them tucked': 'Elbows flaring, tuck them',
    'Too much shoulder movement! Stabilize': 'Too much shoulder movement',
    'Partial rep! Get full extension': 'Partial rep, full extension',
    'Using too much weight! Reduce load': 'Too much weight, reduce',
    'Leaning too far forward! Stand upright': 'Leaning forward, stand up',
    'Wrists are bent! Keep them straight': 'Wrists bent, keep straight',
    'Control the negative! Don\'t let it snap back':
        'Control negative, don\'t snap',
    'Engage your core for stability': 'Engage core for stability',

    // Body type specific cues
    'Perfect range for your arm length!': 'Perfect range for you',
    'Adjust grip width for your shoulders': 'Adjust grip for shoulders',
    'Your build allows deeper extension': 'You can extend deeper',
    'Narrow grip suits your frame': 'Narrow grip suits you',

    // Tempo and rhythm
    'Slow and controlled movement': 'Slow and controlled',
    'Pause at the bottom': 'Pause at bottom',
    'Focus on the tricep contraction': 'Focus on tricep squeeze',
  };

  // Initialize voice feedback
  static Future<void> initializeVoiceFeedback() async {
    _flutterTts = FlutterTts();

    await _flutterTts!.setLanguage("en-US");
    await _flutterTts!.setSpeechRate(0.6);
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

  // Speak feedback with intelligent filtering
  static Future<void> _speakFeedback(
    String text, {
    bool isUrgent = false,
  }) async {
    if (!_isVoiceEnabled || _flutterTts == null) return;

    DateTime now = DateTime.now();
    String voiceText = _voiceFeedbackMap[text] ?? text;
    int minInterval = isUrgent ? 1500 : 3500;

    if (!isUrgent &&
        _lastSpokenText == voiceText &&
        now.difference(_lastVoiceFeedback).inMilliseconds < minInterval) {
      return;
    }

    if (_isSpeaking && !isUrgent) {
      return;
    }

    if (isUrgent && _isSpeaking) {
      await _flutterTts!.stop();
    }

    _isSpeaking = true;
    _lastSpokenText = voiceText;
    _lastVoiceFeedback = now;

    try {
      await _flutterTts!.speak(voiceText);
    } catch (e) {
      _isSpeaking = false;
      print("TTS Speak Error: $e");
    }
  }

  // Rep count announcements
  static Future<void> _announceRepCount(int count) async {
    List<String> motivationalPhrases = [
      "rep $count complete",
      "$count reps done",
      "tricep pushdown $count",
      "$count extensions",
    ];

    if (count == 1) {
      await _speakFeedback("First rep! Good form", isUrgent: false);
    } else if (count == 5) {
      await _speakFeedback("5 reps! Keep it up", isUrgent: false);
    } else if (count == 10) {
      await _speakFeedback("10 reps! Strong triceps", isUrgent: false);
    } else if (count % 10 == 0 && count > 10) {
      await _speakFeedback("$count reps! Excellent endurance", isUrgent: false);
    } else if (count <= 3) {
      await _speakFeedback(
        motivationalPhrases[count % motivationalPhrases.length],
        isUrgent: false,
      );
    }
  }

  // Voice settings control
  static void setVoiceEnabled(bool enabled) {
    _isVoiceEnabled = enabled;
    if (!enabled && _isSpeaking) {
      _flutterTts?.stop();
      _isSpeaking = false;
    }
  }

  static bool get isVoiceEnabled => _isVoiceEnabled;

  static Future<void> setVoiceSettings({
    double? speechRate,
    double? volume,
    double? pitch,
    String? language,
  }) async {
    if (_flutterTts == null) return;

    if (speechRate != null) await _flutterTts!.setSpeechRate(speechRate);
    if (volume != null) await _flutterTts!.setVolume(volume);
    if (pitch != null) await _flutterTts!.setPitch(pitch);
    if (language != null) await _flutterTts!.setLanguage(language);
  }

  // Helper method to get body type name
  static String getBodyTypeName(int bodyType) {
    if (bodyType >= 0 && bodyType < bodyTypeNames.length) {
      return bodyTypeNames[bodyType];
    }
    return 'unknown';
  }

  // Calculate angle between three points (vertex at point2)
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

  // Detect body type based on anthropometric measurements
  static int _detectBodyType(Map<String, PoseLandmark> landmarks) {
    final leftShoulder = landmarks['leftShoulder']!;
    final rightShoulder = landmarks['rightShoulder']!;
    final leftElbow = landmarks['leftElbow']!;
    final rightElbow = landmarks['rightElbow']!;
    final leftWrist = landmarks['leftWrist']!;
    final rightWrist = landmarks['rightWrist']!;

    // Calculate arm length (shoulder to wrist)
    double leftArmLength = _calculateDistance(leftShoulder, leftWrist);
    double rightArmLength = _calculateDistance(rightShoulder, rightWrist);
    _armLength = (leftArmLength + rightArmLength) / 2;

    // Calculate shoulder width
    _shoulderWidth = _calculateDistance(leftShoulder, rightShoulder);

    // Calculate arm to shoulder ratio
    _armToShoulderRatio = _armLength / _shoulderWidth;

    // Add to history for stability
    _anthropometricHistory.add(_armToShoulderRatio);
    if (_anthropometricHistory.length > 10) {
      _anthropometricHistory.removeAt(0);
    }

    if (_anthropometricHistory.length < 5) {
      return AVERAGE;
    }

    double avgRatio =
        _anthropometricHistory.reduce((a, b) => a + b) /
        _anthropometricHistory.length;

    // Classification for tricep pushdown specific considerations
    if (_shoulderWidth > 120) {
      // Pixel threshold for broad shoulders
      return BROAD_SHOULDERS;
    } else if (_shoulderWidth < 80) {
      // Pixel threshold for narrow shoulders
      return NARROW_SHOULDERS;
    } else if (avgRatio < 1.3) {
      return SHORT_ARMS;
    } else if (avgRatio > 1.7) {
      return LONG_ARMS;
    } else {
      return AVERAGE;
    }
  }

  // Calculate elbow flare (deviation from body centerline)
  static double _calculateElbowFlare(
    PoseLandmark shoulder,
    PoseLandmark elbow,
    PoseLandmark centerline,
  ) {
    // Calculate angle between shoulder-elbow line and vertical centerline
    double shoulderElbowAngle = math.atan2(
      elbow.y - shoulder.y,
      elbow.x - shoulder.x,
    );

    double verticalAngle = math.atan2(
      centerline.y - shoulder.y,
      centerline.x - shoulder.x,
    );

    double flareAngle = (shoulderElbowAngle - verticalAngle) * 180 / math.pi;
    return flareAngle.abs();
  }

  // Calculate shoulder stability (movement from baseline)
  static double _calculateShoulderStability(
    PoseLandmark leftShoulder,
    PoseLandmark rightShoulder,
  ) {
    double currentShoulderLine = math.atan2(
      rightShoulder.y - leftShoulder.y,
      rightShoulder.x - leftShoulder.x,
    );

    if (_shoulderStabilityBaseline == 0.0) {
      _shoulderStabilityBaseline = currentShoulderLine;
    }

    double deviation =
        (currentShoulderLine - _shoulderStabilityBaseline) * 180 / math.pi;
    return deviation.abs();
  }

  // Calculate torso lean
  static double _calculateTorsoLean(PoseLandmark shoulder, PoseLandmark hip) {
    double leanAngle = math.atan2(hip.y - shoulder.y, hip.x - shoulder.x);

    // Convert to degrees from vertical (90 degrees = vertical)
    double leanFromVertical = (leanAngle * 180 / math.pi) - 90;
    return leanFromVertical.abs();
  }

  // Calculate wrist deviation
  static double _calculateWristDeviation(
    PoseLandmark elbow,
    PoseLandmark wrist,
  ) {
    double wristAngle = math.atan2(wrist.y - elbow.y, wrist.x - elbow.x);

    // Ideal wrist position should be straight extension from elbow
    double idealAngle = math.pi / 2; // 90 degrees down
    double deviation = (wristAngle - idealAngle) * 180 / math.pi;
    return deviation.abs();
  }

  // Calibrate starting position
  static void _calibrateStartingPosition(
    PoseLandmark leftElbow,
    PoseLandmark rightElbow,
  ) {
    if (!_startingPositionCalibrated) {
      _startingElbowHeight = (leftElbow.y + rightElbow.y) / 2;
      _startingPositionCalibrated = true;
    }
  }

  // Stabilized feedback system with voice integration
  static void _updateFeedback(
    String feedback,
    Color color,
    Function(String, Color) onFeedbackUpdate,
  ) {
    DateTime now = DateTime.now();
    bool isUrgent = color == Colors.red;

    if (feedback != _lastFeedback &&
        now.difference(_lastFeedbackChange).inMilliseconds > 1500) {
      _lastFeedback = feedback;
      _lastFeedbackColor = color;
      _lastFeedbackChange = now;
      onFeedbackUpdate(feedback, color);

      _speakFeedback(feedback, isUrgent: isUrgent);
    } else if (_lastFeedback.isNotEmpty) {
      onFeedbackUpdate(_lastFeedback, _lastFeedbackColor);
    }
  }

  // Main analysis function for tricep pushdowns
  static Map<String, dynamic> analyzeTricepPushdownForm(
    Pose pose,
    Function(String, Color) onFeedbackUpdate,
    Function(int) onRepCountUpdate,
  ) {
    final landmarks = pose.landmarks;

    // Create landmark map for easier access
    Map<String, PoseLandmark?> landmarkMap = {
      'leftShoulder': landmarks[PoseLandmarkType.leftShoulder],
      'rightShoulder': landmarks[PoseLandmarkType.rightShoulder],
      'leftElbow': landmarks[PoseLandmarkType.leftElbow],
      'rightElbow': landmarks[PoseLandmarkType.rightElbow],
      'leftWrist': landmarks[PoseLandmarkType.leftWrist],
      'rightWrist': landmarks[PoseLandmarkType.rightWrist],
      'leftHip': landmarks[PoseLandmarkType.leftHip],
      'rightHip': landmarks[PoseLandmarkType.rightHip],
      'nose': landmarks[PoseLandmarkType.nose],
    };

    // Check critical landmarks for tricep pushdowns
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
          'Position yourself at the cable machine',
          Colors.blue,
          onFeedbackUpdate,
        );
        return {
          'phase': _currentPhase,
          'repCount': _repCount,
          'formScore': 0,
          'bodyType': getBodyTypeName(_detectedBodyType),
        };
      }
    }

    // Create non-null map for calculations
    Map<String, PoseLandmark> validLandmarks = {};
    landmarkMap.forEach((key, value) {
      if (value != null) validLandmarks[key] = value;
    });

    // Calibrate starting position
    _calibrateStartingPosition(
      validLandmarks['leftElbow']!,
      validLandmarks['rightElbow']!,
    );

    // Detect and adapt to body type
    if (!_bodyTypeCalibrated || _repCount % 5 == 0) {
      int previousBodyType = _detectedBodyType;
      _detectedBodyType = _detectBodyType(validLandmarks);

      if (!_bodyTypeCalibrated && _detectedBodyType != AVERAGE) {
        String bodyTypeName = getBodyTypeName(_detectedBodyType);
        _speakFeedback(
          "Detected $bodyTypeName build for pushdowns",
          isUrgent: false,
        );
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

    // Smooth angle history
    _elbowAngleHistory.add(avgElbowAngle);
    if (_elbowAngleHistory.length > 5) {
      _elbowAngleHistory.removeAt(0);
    }
    double smoothedElbowAngle =
        _elbowAngleHistory.reduce((a, b) => a + b) / _elbowAngleHistory.length;

    // Calculate elbow position stability
    _currentElbowHeight =
        (validLandmarks['leftElbow']!.y + validLandmarks['rightElbow']!.y) / 2;
    double elbowHeightDeviation = (_currentElbowHeight - _startingElbowHeight)
        .abs();

    _elbowPositionHistory.add(elbowHeightDeviation);
    if (_elbowPositionHistory.length > 5) {
      _elbowPositionHistory.removeAt(0);
    }

    // Grip width analysis
    _gripWidth = _calculateDistance(
      validLandmarks['leftWrist']!,
      validLandmarks['rightWrist']!,
    );
    double gripToShoulderRatio = _gripWidth / _shoulderWidth;

    // Elbow flare analysis
    PoseLandmark centerline = PoseLandmark(
      type: PoseLandmarkType.nose,
      x:
          (validLandmarks['leftShoulder']!.x +
              validLandmarks['rightShoulder']!.x) /
          2,
      y:
          (validLandmarks['leftShoulder']!.y +
              validLandmarks['rightShoulder']!.y) /
          2,
      z: 0,
      likelihood: 1.0,
    );

    double leftElbowFlare = _calculateElbowFlare(
      validLandmarks['leftShoulder']!,
      validLandmarks['leftElbow']!,
      centerline,
    );
    double rightElbowFlare = _calculateElbowFlare(
      validLandmarks['rightShoulder']!,
      validLandmarks['rightElbow']!,
      centerline,
    );
    double avgElbowFlare = (leftElbowFlare + rightElbowFlare) / 2;

    // Shoulder stability
    double shoulderStability = _calculateShoulderStability(
      validLandmarks['leftShoulder']!,
      validLandmarks['rightShoulder']!,
    );

    // Torso lean
    double torsoLean = _calculateTorsoLean(
      validLandmarks['leftShoulder']!,
      validLandmarks['leftHip']!,
    );

    // Wrist deviation
    double leftWristDeviation = _calculateWristDeviation(
      validLandmarks['leftElbow']!,
      validLandmarks['leftWrist']!,
    );
    double rightWristDeviation = _calculateWristDeviation(
      validLandmarks['rightElbow']!,
      validLandmarks['rightWrist']!,
    );
    double avgWristDeviation = (leftWristDeviation + rightWristDeviation) / 2;

    // Form assessment with body type specific ranges
    String feedback = '';
    Color feedbackColor = Colors.green;
    int formScore = 100;

    // Priority form checks
    if (avgElbowFlare > ranges['elbowFlareMax']!) {
      feedback = 'Elbows are flaring out! Keep them tucked';
      feedbackColor = Colors.red;
      formScore -= 35;
    } else if (shoulderStability > ranges['shoulderStabilityMin']!) {
      feedback = 'Too much shoulder movement! Stabilize';
      feedbackColor = Colors.red;
      formScore -= 30;
    } else if (avgWristDeviation > ranges['wristDeviationMax']!) {
      feedback = 'Wrists are bent! Keep them straight';
      feedbackColor = Colors.orange;
      formScore -= 25;
    } else if (torsoLean > ranges['torsoLeanMax']!) {
      feedback = 'Leaning too far forward! Stand upright';
      feedbackColor = Colors.orange;
      formScore -= 20;
    } else if (gripToShoulderRatio < ranges['gripWidthMin']!) {
      feedback = 'Grip too narrow for your build! Widen hands';
      feedbackColor = Colors.orange;
      formScore -= 15;
    } else if (gripToShoulderRatio > ranges['gripWidthMax']!) {
      feedback = 'Grip too wide! Move hands closer';
      feedbackColor = Colors.orange;
      formScore -= 15;
    }

    // Phase detection
    int newPhase = _detectTricepPushdownPhase(
      smoothedElbowAngle,
      elbowHeightDeviation,
      _currentPhase,
      ranges,
    );

    if (newPhase != _currentPhase) {
      DateTime now = DateTime.now();
      if (now.difference(_lastPhaseChange).inMilliseconds > 500) {
        _currentPhase = newPhase;
        _lastPhaseChange = now;

        if (_currentPhase == PHASE_STARTING_POSITION &&
            _previousElbowAngle < ranges['endElbowAngle']!) {
          _repCount++;
          onRepCountUpdate(_repCount);
          _announceRepCount(_repCount);
        }
      }
    }

    // Phase-specific feedback
    if (feedback.isEmpty) {
      switch (_currentPhase) {
        case PHASE_SETUP:
          feedback = 'Establish starting position with elbows at 90 degrees';
          feedbackColor = Colors.blue;
          break;

        case PHASE_STARTING_POSITION:
          feedback = 'Keep your elbows tucked to your sides';
          feedbackColor = Colors.green;
          break;

        case PHASE_PUSHING_DOWN:
          feedback = 'Push down by extending your elbows';
          feedbackColor = Colors.blue;
          break;

        case PHASE_FULL_EXTENSION:
          if (smoothedElbowAngle < ranges['endElbowAngle']!) {
            feedback = 'Partial rep! Get full extension';
            feedbackColor = Colors.orange;
            formScore -= 20;
          } else {
            feedback = 'Squeeze your triceps at the bottom';
            feedbackColor = Colors.green;
          }
          break;

        case PHASE_RETURNING:
          if (smoothedElbowAngle > ranges['startElbowAngle']! + 20) {
            feedback = 'Don\'t let the weight pull you up';
            feedbackColor = Colors.orange;
            formScore -= 15;
          } else {
            feedback = 'Control the weight back up';
            feedbackColor = Colors.green;
          }
          break;

        default:
          if (formScore > 85) {
            feedback = 'Perfect form for your build!';
            feedbackColor = Colors.green;
          } else {
            feedback = 'Maintain elbow position throughout';
            feedbackColor = Colors.blue;
          }
      }
    }

    // Use stabilized feedback update
    _updateFeedback(feedback, feedbackColor, onFeedbackUpdate);
    _previousElbowAngle = smoothedElbowAngle;

    // Completion of the return statement from analyzeTricepPushdownForm
    return {
      'phase': _currentPhase,
      'repCount': _repCount,
      'formScore': formScore,
      'elbowAngle': smoothedElbowAngle,
      'elbowFlare': avgElbowFlare,
      'shoulderStability': shoulderStability,
      'torsoLean': torsoLean,
      'wristDeviation': avgWristDeviation,
      'gripWidth': gripToShoulderRatio,
      'bodyType': getBodyTypeName(_detectedBodyType),
      'armLength': _armLength,
      'shoulderWidth': _shoulderWidth,
      'feedback': feedback,
      'feedbackColor': feedbackColor,
    };
  }

  // Phase detection for tricep pushdowns
  static int _detectTricepPushdownPhase(
    double elbowAngle,
    double elbowHeightDeviation,
    int currentPhase,
    Map<String, double> ranges,
  ) {
    // Phase transition thresholds
    const double PHASE_TRANSITION_THRESHOLD = 10.0;
    const double ELBOW_STABILITY_THRESHOLD = 8.0;

    // Setup phase - getting into position
    if (elbowAngle < ranges['startElbowAngle']! - 20 ||
        elbowHeightDeviation > ELBOW_STABILITY_THRESHOLD * 2) {
      return PHASE_SETUP;
    }

    // Starting position - elbows at 90 degrees
    if (elbowAngle >= ranges['startElbowAngle']! - 10 &&
        elbowAngle <= ranges['startElbowAngle']! + 10) {
      return PHASE_STARTING_POSITION;
    }

    // Pushing down phase
    if (elbowAngle > ranges['startElbowAngle']! + PHASE_TRANSITION_THRESHOLD &&
        elbowAngle < ranges['endElbowAngle']! - PHASE_TRANSITION_THRESHOLD) {
      return PHASE_PUSHING_DOWN;
    }

    // Full extension phase
    if (elbowAngle >= ranges['endElbowAngle']! - PHASE_TRANSITION_THRESHOLD) {
      return PHASE_FULL_EXTENSION;
    }

    // Returning phase - controlled return to start
    if (currentPhase == PHASE_FULL_EXTENSION &&
        elbowAngle < ranges['endElbowAngle']! - PHASE_TRANSITION_THRESHOLD) {
      return PHASE_RETURNING;
    }

    return currentPhase;
  }

  // Reset session data
  static void resetSession() {
    _currentPhase = PHASE_SETUP;
    _repCount = 0;
    _previousElbowAngle = 90.0;
    _elbowAngleHistory.clear();
    _elbowPositionHistory.clear();
    _lastPhaseChange = DateTime.now();
    _lastFeedbackChange = DateTime.now();
    _lastFeedback = '';
    _lastFeedbackColor = Colors.blue;
    _detectedBodyType = AVERAGE;
    _bodyTypeCalibrated = false;
    _startingElbowHeight = 0.0;
    _currentElbowHeight = 0.0;
    _startingPositionCalibrated = false;
    _shoulderStabilityBaseline = 0.0;
    _gripWidth = 0.0;
    _armLength = 0.0;
    _shoulderWidth = 0.0;
    _armToShoulderRatio = 0.0;
    _anthropometricHistory.clear();
    _lastVoiceFeedback = DateTime.now();
    _lastSpokenText = '';
    _isSpeaking = false;
  }

  // Get current session statistics
  static Map<String, dynamic> getSessionStats() {
    return {
      'repCount': _repCount,
      'bodyType': getBodyTypeName(_detectedBodyType),
      'currentPhase': _currentPhase,
      'armLength': _armLength,
      'shoulderWidth': _shoulderWidth,
      'isCalibrated': _bodyTypeCalibrated,
      'voiceEnabled': _isVoiceEnabled,
    };
  }

  // Set rep count manually (for testing or adjustment)
  static void setRepCount(int count) {
    _repCount = count;
  }

  // Get phase name for display
  static String getPhaseName(int phase) {
    switch (phase) {
      case PHASE_SETUP:
        return 'Setup';
      case PHASE_STARTING_POSITION:
        return 'Starting Position';
      case PHASE_PUSHING_DOWN:
        return 'Pushing Down';
      case PHASE_FULL_EXTENSION:
        return 'Full Extension';
      case PHASE_RETURNING:
        return 'Returning';
      default:
        return 'Unknown';
    }
  }

  // Get form score description
  static String getFormScoreDescription(int score) {
    if (score >= 95) return 'Perfect Form';
    if (score >= 85) return 'Excellent Form';
    if (score >= 75) return 'Good Form';
    if (score >= 65) return 'Fair Form';
    if (score >= 50) return 'Needs Improvement';
    return 'Poor Form';
  }

  // Dispose resources
  static void dispose() {
    _flutterTts?.stop();
    _flutterTts = null;
    _isSpeaking = false;
  }
}
