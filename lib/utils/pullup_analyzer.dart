import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class PullUpAnalyzer {
  // Anthropometric body type classifications using class constants
  static const int SHORT_LIMBS = 0;
  static const int AVERAGE = 1;
  static const int LONG_LIMBS = 2;
  static const int STOCKY = 3;
  static const int TALL_LEAN = 4;

  // Voice feedback instance
  static FlutterTts? _flutterTts;
  static bool _isVoiceEnabled = true;
  static DateTime _lastVoiceFeedback = DateTime.now();
  static String _lastSpokenText = '';
  static bool _isSpeaking = false;

  // Adaptive ranges based on body type research for pull-ups
  static Map<int, Map<String, double>> bodyTypeRanges = {
    SHORT_LIMBS: {
      'elbowAngleMin': 45.0,         // Deeper bend at top
      'elbowAngleMax': 65.0,
      'gripWidthMin': 0.9,           // Narrower grip suits shorter arms
      'gripWidthMax': 1.2,
      'shoulderFlexionOptimal': 140.0, // Less shoulder flexion needed
      'scapularRetractionMin': 15.0,
      'bodySwingTolerance': 8.0,     // Less swing due to shorter limbs
    },
    AVERAGE: {
      'elbowAngleMin': 40.0,
      'elbowAngleMax': 60.0,
      'gripWidthMin': 1.0,
      'gripWidthMax': 1.4,
      'shoulderFlexionOptimal': 150.0,
      'scapularRetractionMin': 20.0,
      'bodySwingTolerance': 10.0,
    },
    LONG_LIMBS: {
      'elbowAngleMin': 35.0,         // Can achieve deeper bend
      'elbowAngleMax': 55.0,
      'gripWidthMin': 1.1,           // Wider grip for longer arms
      'gripWidthMax': 1.6,
      'shoulderFlexionOptimal': 160.0, // More shoulder flexion available
      'scapularRetractionMin': 25.0,
      'bodySwingTolerance': 15.0,    // More swing tendency
    },
    STOCKY: {
      'elbowAngleMin': 45.0,
      'elbowAngleMax': 70.0,         // May have limited shoulder mobility
      'gripWidthMin': 1.0,
      'gripWidthMax': 1.3,
      'shoulderFlexionOptimal': 135.0,
      'scapularRetractionMin': 18.0,
      'bodySwingTolerance': 8.0,
    },
    TALL_LEAN: {
      'elbowAngleMin': 35.0,
      'elbowAngleMax': 55.0,
      'gripWidthMin': 1.2,
      'gripWidthMax': 1.7,
      'shoulderFlexionOptimal': 165.0,
      'scapularRetractionMin': 25.0,
      'bodySwingTolerance': 18.0,
    },
  };

  static const List<String> bodyTypeNames = [
    'shortLimbs',
    'average',
    'longLimbs', 
    'stocky',
    'tallLean'
  ];

  // Pull-up specific constants
  static const double DEAD_HANG_ELBOW_ANGLE = 170.0;  // Nearly straight arms
  static const double CHIN_OVER_BAR_THRESHOLD = 10.0; // Chin clearance in pixels
  static const double HOLLOW_BODY_THRESHOLD = 15.0;   // Core engagement angle

  // Movement phases for pull-ups
  static const int PHASE_DEAD_HANG = 0;
  static const int PHASE_INITIAL_PULL = 1;
  static const int PHASE_PULLING = 2;
  static const int PHASE_TOP_POSITION = 3;
  static const int PHASE_LOWERING = 4;

  // Session tracking with stabilization
  static int _currentPhase = PHASE_DEAD_HANG;
  static int _repCount = 0;
  static double _previousElbowAngle = 180.0;
  static List<double> _elbowAngleHistory = [];
  static List<double> _chinHeightHistory = [];
  static DateTime _lastPhaseChange = DateTime.now();
  static DateTime _lastFeedbackChange = DateTime.now();
  static String _lastFeedback = '';
  static Color _lastFeedbackColor = Colors.blue;
  static int _detectedBodyType = AVERAGE;
  static bool _bodyTypeCalibrated = false;

  // Pull-up specific tracking
  static double _barPosition = 0.0;
  static bool _barPositionCalibrated = false;
  static double _chinPosition = 0.0;
  static double _peakChinHeight = 0.0;

  // Anthropometric measurements for body type detection
  static double _armToTorsoRatio = 0.0;
  static double _shoulderToHipRatio = 0.0;
  static List<double> _anthropometricHistory = [];

  // Voice feedback configuration maps for pull-ups
  static Map<String, String> _voiceFeedbackMap = {
    // Grip and setup feedback
    'Grip too narrow for your build! Widen your hands': 'Grip too narrow, widen your hands',
    'Grip too wide! Move hands closer together': 'Grip too wide, move hands closer',
    'Establish dead hang position first': 'Get into dead hang position',
    'Engage your lats and pull shoulder blades down': 'Engage lats, pull shoulders down',
    
    // Movement phase feedback
    'Start pulling! Engage your back muscles': 'Start pulling, engage your back',
    'Good initiation! Keep pulling up': 'Good start, keep pulling',
    'Drive your elbows down and back': 'Elbows down and back',
    'Pull chest toward the bar': 'Pull chest to bar',
    'Almost there! Get chin over bar': 'Almost there, chin over bar',
    'Perfect! Chin cleared the bar': 'Perfect, chin cleared',
    'Great rep! Control the descent': 'Great rep, control down',
    'Too fast on the way down! Control it': 'Too fast down, control it',
    'Smooth descent - maintain tension': 'Good descent, keep tension',
    
    // Form corrections
    'Stop swinging! Engage your core': 'Stop swinging, engage core',
    'Shoulders forward! Pull them back': 'Pull shoulders back',
    'Partial rep! Get chin over the bar': 'Partial rep, chin over bar',
    'Hollow body position - engage core': 'Hollow body, engage core',
    'Elbows drifting forward! Pull them back': 'Elbows back, not forward',
    'Full range of motion! Go to dead hang': 'Full range, dead hang',
    
    // Body type specific cues
    'Perfect depth for your build!': 'Perfect depth for you',
    'Adjust grip width for your arm length': 'Adjust grip for your arms',
    'Your body type allows deeper pull': 'You can pull deeper',
    
    // General positioning
    'Position yourself under the bar': 'Position under the bar',
    'Hang from the bar to begin': 'Hang from the bar',
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
  static Future<void> _speakFeedback(String text, {bool isUrgent = false}) async {
    if (!_isVoiceEnabled || _flutterTts == null) return;
    
    DateTime now = DateTime.now();
    String voiceText = _voiceFeedbackMap[text] ?? text;
    int minInterval = isUrgent ? 2000 : 4000;
    
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

  // Count announcements for motivation
  static Future<void> _announceRepCount(int count) async {
    List<String> motivationalPhrases = [
      "pull-up $count",
      "$count reps complete",
      "rep $count done",
      "$count pull-ups",
    ];
    
    if (count == 1) {
      await _speakFeedback("First pull-up! Great job", isUrgent: false);
    } else if (count == 5) {
      await _speakFeedback("5 pull-ups! Strong work", isUrgent: false);
    } else if (count == 10) {
      await _speakFeedback("10 pull-ups! Incredible strength", isUrgent: false);
    } else if (count % 5 == 0 && count > 10) {
      await _speakFeedback("$count pull-ups! You're a machine", isUrgent: false);
    } else if (count <= 3) {
      await _speakFeedback(motivationalPhrases[count % motivationalPhrases.length], isUrgent: false);
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
    final leftHip = landmarks['leftHip']!;
    final rightHip = landmarks['rightHip']!;

    // Calculate arm length (shoulder to wrist)
    double leftArmLength = _calculateDistance(leftShoulder, leftWrist);
    double rightArmLength = _calculateDistance(rightShoulder, rightWrist);
    double avgArmLength = (leftArmLength + rightArmLength) / 2;

    // Calculate torso length (shoulder to hip)
    double leftTorsoLength = _calculateDistance(leftShoulder, leftHip);
    double rightTorsoLength = _calculateDistance(rightShoulder, rightHip);
    double avgTorsoLength = (leftTorsoLength + rightTorsoLength) / 2;

    // Calculate shoulder and hip widths
    double shoulderWidth = _calculateDistance(leftShoulder, rightShoulder);
    double hipWidth = _calculateDistance(leftHip, rightHip);

    // Calculate ratios
    _armToTorsoRatio = avgArmLength / avgTorsoLength;
    _shoulderToHipRatio = shoulderWidth / hipWidth;

    // Add to history for stability
    _anthropometricHistory.add(_armToTorsoRatio);
    if (_anthropometricHistory.length > 10) {
      _anthropometricHistory.removeAt(0);
    }

    if (_anthropometricHistory.length < 5) {
      return AVERAGE;
    }

    double avgRatio = _anthropometricHistory.reduce((a, b) => a + b) / 
                     _anthropometricHistory.length;

    // Classification for pull-up specific considerations
    if (avgRatio < 1.1 && _shoulderToHipRatio > 1.15) {
      return STOCKY;
    } else if (avgRatio < 1.2) {
      return SHORT_LIMBS;
    } else if (avgRatio > 1.4) {
      if (_shoulderToHipRatio < 1.1) {
        return TALL_LEAN;
      } else {
        return LONG_LIMBS;
      }
    } else {
      return AVERAGE;
    }
  }

  // Calculate scapular retraction angle
  static double _calculateScapularRetraction(
    PoseLandmark leftShoulder,
    PoseLandmark rightShoulder,
    PoseLandmark leftElbow,
    PoseLandmark rightElbow,
  ) {
    // Calculate the angle between shoulder line and elbow positions
    double shoulderAngle = math.atan2(
      rightShoulder.y - leftShoulder.y, 
      rightShoulder.x - leftShoulder.x
    );
    
    double leftElbowAngle = math.atan2(
      leftElbow.y - leftShoulder.y, 
      leftElbow.x - leftShoulder.x
    );
    
    double rightElbowAngle = math.atan2(
      rightElbow.y - rightShoulder.y, 
      rightElbow.x - rightShoulder.x
    );
    
    // Calculate retraction based on elbow position relative to shoulders
    double leftRetraction = (leftElbowAngle - shoulderAngle) * 180 / math.pi;
    double rightRetraction = (rightElbowAngle - shoulderAngle) * 180 / math.pi;
    
    return (leftRetraction.abs() + rightRetraction.abs()) / 2;
  }

  // Calculate body swing/hollow body position
  static double _calculateBodySwing(
    PoseLandmark shoulder,
    PoseLandmark hip,
    PoseLandmark knee,
  ) {
    double hipAngle = _calculateAngle(shoulder, hip, knee);
    return (180 - hipAngle).abs();
  }

  // Calibrate bar position from wrist positions when in dead hang
  static void _calibrateBarPosition(PoseLandmark leftWrist, PoseLandmark rightWrist) {
    if (!_barPositionCalibrated) {
      _barPosition = (leftWrist.y + rightWrist.y) / 2;
      _barPositionCalibrated = true;
    }
  }

  // Calculate chin height relative to bar
  static double _calculateChinHeight(PoseLandmark nose) {
    if (!_barPositionCalibrated) return 0.0;
    
    // Approximate chin position from nose (chin is typically 10-15 pixels below nose)
    _chinPosition = nose.y + 12; // Estimated chin position
    
    // Calculate height relative to bar (negative means above bar)
    double relativeHeight = _barPosition - _chinPosition;
    
    // Track peak height for rep validation
    if (relativeHeight > _peakChinHeight) {
      _peakChinHeight = relativeHeight;
    }
    
    return relativeHeight;
  }

  // Stabilized feedback system with voice integration
  static void _updateFeedback(String feedback, Color color, Function(String, Color) onFeedbackUpdate) {
    DateTime now = DateTime.now();
    bool isUrgent = color == Colors.red;
    
    if (feedback != _lastFeedback && 
        now.difference(_lastFeedbackChange).inMilliseconds > 2000) {
      _lastFeedback = feedback;
      _lastFeedbackColor = color;
      _lastFeedbackChange = now;
      onFeedbackUpdate(feedback, color);
      
      _speakFeedback(feedback, isUrgent: isUrgent);
    } else if (_lastFeedback.isNotEmpty) {
      onFeedbackUpdate(_lastFeedback, _lastFeedbackColor);
    }
  }

  // Main analysis function for pull-ups
  static Map<String, dynamic> analyzePullUpForm(
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
      'leftKnee': landmarks[PoseLandmarkType.leftKnee],
      'rightKnee': landmarks[PoseLandmarkType.rightKnee],
      'nose': landmarks[PoseLandmarkType.nose],
    };

    // Check critical landmarks for pull-ups
    List<String> criticalLandmarks = [
      'leftShoulder', 'rightShoulder', 'leftElbow', 'rightElbow',
      'leftWrist', 'rightWrist', 'leftHip', 'rightHip', 'nose'
    ];

    for (String landmark in criticalLandmarks) {
      if (landmarkMap[landmark] == null) {
        _updateFeedback('Position yourself under the bar', Colors.blue, onFeedbackUpdate);
        return {'phase': _currentPhase, 'repCount': _repCount, 'formScore': 0, 'bodyType': getBodyTypeName(_detectedBodyType)};
      }
    }

    // Create non-null map for calculations
    Map<String, PoseLandmark> validLandmarks = {};
    landmarkMap.forEach((key, value) {
      if (value != null) validLandmarks[key] = value;
    });

    // Calibrate bar position
    _calibrateBarPosition(validLandmarks['leftWrist']!, validLandmarks['rightWrist']!);

    // Detect and adapt to body type
    if (!_bodyTypeCalibrated || _repCount % 3 == 0) { // Recalibrate every 3 reps
      int previousBodyType = _detectedBodyType;
      _detectedBodyType = _detectBodyType(validLandmarks);
      
      if (!_bodyTypeCalibrated && _detectedBodyType != AVERAGE) {
        String bodyTypeName = getBodyTypeName(_detectedBodyType);
        _speakFeedback("Detected $bodyTypeName body type for pull-ups", isUrgent: false);
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
    double smoothedElbowAngle = _elbowAngleHistory.reduce((a, b) => a + b) / _elbowAngleHistory.length;

    // Grip width analysis
    double gripWidth = _calculateDistance(validLandmarks['leftWrist']!, validLandmarks['rightWrist']!);
    double shoulderWidth = _calculateDistance(validLandmarks['leftShoulder']!, validLandmarks['rightShoulder']!);
    double gripToShoulderRatio = gripWidth / shoulderWidth;

    // Scapular retraction
    double scapularRetraction = _calculateScapularRetraction(
      validLandmarks['leftShoulder']!,
      validLandmarks['rightShoulder']!,
      validLandmarks['leftElbow']!,
      validLandmarks['rightElbow']!,
    );

    // Body swing analysis
    double bodySwing = 0;
    if (validLandmarks['leftKnee'] != null) {
      bodySwing = _calculateBodySwing(
        validLandmarks['leftShoulder']!,
        validLandmarks['leftHip']!,
        validLandmarks['leftKnee']!,
      );
    }

    // Chin height tracking
    double chinHeight = _calculateChinHeight(validLandmarks['nose']!);
    _chinHeightHistory.add(chinHeight);
    if (_chinHeightHistory.length > 5) {
      _chinHeightHistory.removeAt(0);
    }

    // Form assessment with body type specific ranges
    String feedback = '';
    Color feedbackColor = Colors.green;
    int formScore = 100;

    // Priority form checks
    if (gripToShoulderRatio > ranges['gripWidthMax']!) {
      feedback = 'Grip too wide! Move hands closer together';
      feedbackColor = Colors.red;
      formScore -= 30;
    } else if (gripToShoulderRatio < ranges['gripWidthMin']!) {
      feedback = 'Grip too narrow for your build! Widen your hands';
      feedbackColor = Colors.red;
      formScore -= 25;
    } else if (bodySwing > ranges['bodySwingTolerance']!) {
      feedback = 'Stop swinging! Engage your core';
      feedbackColor = Colors.red;
      formScore -= 35;
    } else if (scapularRetraction < ranges['scapularRetractionMin']!) {
      feedback = 'Shoulders forward! Pull them back';
      feedbackColor = Colors.orange;
      formScore -= 25;
    }

    // Phase detection with enhanced stability
    int newPhase = _detectPullUpPhase(smoothedElbowAngle, chinHeight, _currentPhase, ranges);

    if (newPhase != _currentPhase) {
      DateTime now = DateTime.now();
      if (now.difference(_lastPhaseChange).inMilliseconds > 600) {
        _currentPhase = newPhase;
        _lastPhaseChange = now;

        if (_currentPhase == PHASE_DEAD_HANG && _peakChinHeight > CHIN_OVER_BAR_THRESHOLD) {
          _repCount++;
          onRepCountUpdate(_repCount);
          _announceRepCount(_repCount);
          _peakChinHeight = 0.0; // Reset for next rep
        }
      }
    }

    // Phase-specific feedback with body type consideration
    if (feedback.isEmpty) {
      switch (_currentPhase) {
        case PHASE_DEAD_HANG:
          if (smoothedElbowAngle < DEAD_HANG_ELBOW_ANGLE - 20) {
            feedback = 'Establish dead hang position first';
            feedbackColor = Colors.blue;
          } else {
            feedback = 'Hang from the bar to begin';
            feedbackColor = Colors.green;
          }
          break;

        case PHASE_INITIAL_PULL:
          feedback = 'Start pulling! Engage your back muscles';
          feedbackColor = Colors.blue;
          break;

        case PHASE_PULLING:
          if (smoothedElbowAngle > 90) {
            feedback = 'Good initiation! Keep pulling up';
            feedbackColor = Colors.green;
          } else {
            feedback = 'Drive your elbows down and back';
            feedbackColor = Colors.blue;
          }
          break;

        case PHASE_TOP_POSITION:
          if (chinHeight > CHIN_OVER_BAR_THRESHOLD) {
            feedback = 'Almost there! Get chin over bar';
            feedbackColor = Colors.orange;
            formScore -= 15;
          } else {
            feedback = 'Perfect! Chin cleared the bar';
            feedbackColor = Colors.green;
          }
          break;

        case PHASE_LOWERING:
          if (smoothedElbowAngle < 120) {
            feedback = 'Too fast on the way down! Control it';
            feedbackColor = Colors.orange;
            formScore -= 10;
          } else {
            feedback = 'Smooth descent - maintain tension';
            feedbackColor = Colors.green;
          }
          break;

        default:
          if (formScore > 90) {
            feedback = 'Perfect form for your body type!';
            feedbackColor = Colors.green;
          } else {
            feedback = 'Engage your lats and pull shoulder blades down';
            feedbackColor = Colors.blue;
          }
      }
    }

    // Use stabilized feedback update
    _updateFeedback(feedback, feedbackColor, onFeedbackUpdate);
    _previousElbowAngle = smoothedElbowAngle;

    return {
      'phase': _currentPhase,
      'repCount': _repCount,
      'formScore': formScore,
      'elbowAngle': smoothedElbowAngle,
      'gripWidth': gripToShoulderRatio,
      'scapularRetraction': scapularRetraction,
      'bodySwing': bodySwing,
      'chinHeight': chinHeight,
      'bodyType': getBodyTypeName(_detectedBodyType),
      'armToTorsoRatio': _armToTorsoRatio,
    };
  }

  // Enhanced phase detection for pull-ups (continued)
  static int _detectPullUpPhase(double currentAngle, double chinHeight, int currentPhase, Map<String, double> ranges) {
    switch (currentPhase) {
      case PHASE_DEAD_HANG:
        if (currentAngle < DEAD_HANG_ELBOW_ANGLE - 15) {
          return PHASE_INITIAL_PULL;
        }
        break;

      case PHASE_INITIAL_PULL:
        if (currentAngle < 120) {
          return PHASE_PULLING;
        }
        break;

      case PHASE_PULLING:
        if (currentAngle < ranges['elbowAngleMax']! || chinHeight <= CHIN_OVER_BAR_THRESHOLD) {
          return PHASE_TOP_POSITION;
        }
        break;

      case PHASE_TOP_POSITION:
        if (currentAngle > ranges['elbowAngleMax']! + 10) {
          return PHASE_LOWERING;
        }
        break;

      case PHASE_LOWERING:
        if (currentAngle > DEAD_HANG_ELBOW_ANGLE - 20) {
          return PHASE_DEAD_HANG;
        }
        break;
    }
    return currentPhase;
  }

  // Reset session data
  static void resetSession() {
    _currentPhase = PHASE_DEAD_HANG;
    _repCount = 0;
    _previousElbowAngle = 180.0;
    _elbowAngleHistory.clear();
    _chinHeightHistory.clear();
    _lastPhaseChange = DateTime.now();
    _lastFeedbackChange = DateTime.now();
    _lastFeedback = '';
    _lastFeedbackColor = Colors.blue;
    _barPositionCalibrated = false;
    _barPosition = 0.0;
    _chinPosition = 0.0;
    _peakChinHeight = 0.0;
    _bodyTypeCalibrated = false;
    _anthropometricHistory.clear();
    _lastVoiceFeedback = DateTime.now();
    _lastSpokenText = '';
    
    if (_isSpeaking) {
      _flutterTts?.stop();
      _isSpeaking = false;
    }
  }

  // Get current session statistics
  static Map<String, dynamic> getSessionStats() {
    return {
      'repCount': _repCount,
      'currentPhase': _currentPhase,
      'bodyType': getBodyTypeName(_detectedBodyType),
      'armToTorsoRatio': _armToTorsoRatio,
      'shoulderToHipRatio': _shoulderToHipRatio,
      'barCalibrated': _barPositionCalibrated,
      'bodyTypeCalibrated': _bodyTypeCalibrated,
    };
  }

  // Get phase name for debugging/display
  static String getPhaseName(int phase) {
    switch (phase) {
      case PHASE_DEAD_HANG:
        return 'Dead Hang';
      case PHASE_INITIAL_PULL:
        return 'Initial Pull';
      case PHASE_PULLING:
        return 'Pulling Up';
      case PHASE_TOP_POSITION:
        return 'Top Position';
      case PHASE_LOWERING:
        return 'Lowering';
      default:
        return 'Unknown';
    }
  }

  // Get form recommendations based on body type
  static List<String> getFormRecommendations(int bodyType) {
    switch (bodyType) {
      case SHORT_LIMBS:
        return [
          'Use a slightly narrower grip (0.9-1.2x shoulder width)',
          'Focus on deeper elbow flexion at the top',
          'Your shorter limbs allow for more efficient pulling',
          'Engage lats strongly throughout the movement',
        ];
      
      case LONG_LIMBS:
        return [
          'Use a wider grip (1.1-1.6x shoulder width)',
          'Focus on full shoulder flexion',
          'Control body swing with core engagement',
          'May need more time to build strength due to longer lever arms',
        ];
      
      case STOCKY:
        return [
          'Standard grip width works well',
          'Focus on shoulder blade retraction',
          'May have limited shoulder mobility - work on flexibility',
          'Strong base for pull-up development',
        ];
      
      case TALL_LEAN:
        return [
          'Use wider grip for better mechanical advantage',
          'Focus on controlling body swing',
          'Build core strength to stabilize long frame',
          'Work on lat strength for better pulling power',
        ];
      
      default: // AVERAGE
        return [
          'Standard grip width (1.0-1.4x shoulder width)',
          'Focus on full range of motion',
          'Maintain hollow body position',
          'Build consistent form before adding volume',
        ];
    }
  }

  // Dispose of resources
  static Future<void> dispose() async {
    if (_isSpeaking) {
      await _flutterTts?.stop();
    }
    _flutterTts = null;
    _isSpeaking = false;
    resetSession();
  }

  // Emergency stop for voice feedback
  static Future<void> emergencyStopVoice() async {
    _isVoiceEnabled = false;
    if (_isSpeaking && _flutterTts != null) {
      await _flutterTts!.stop();
      _isSpeaking = false;
    }
  }

  // Get current body type ranges for debugging
  static Map<String, double> getCurrentBodyTypeRanges() {
    return Map<String, double>.from(bodyTypeRanges[_detectedBodyType]!);
  }

  // Calculate pull-up efficiency score based on form metrics
  static double calculateEfficiencyScore(Map<String, dynamic> analysisResult) {
    double baseScore = analysisResult['formScore']?.toDouble() ?? 0.0;
    double elbowAngle = analysisResult['elbowAngle']?.toDouble() ?? 180.0;
    double gripWidth = analysisResult['gripWidth']?.toDouble() ?? 1.0;
    double bodySwing = analysisResult['bodySwing']?.toDouble() ?? 0.0;
    
    Map<String, double> ranges = bodyTypeRanges[_detectedBodyType]!;
    
    // Bonus points for optimal ranges
    double gripBonus = 0.0;
    if (gripWidth >= ranges['gripWidthMin']! && gripWidth <= ranges['gripWidthMax']!) {
      gripBonus = 10.0;
    }
    
    double swingPenalty = math.max(0, bodySwing - ranges['bodySwingTolerance']!) * 2;
    
    double totalScore = baseScore + gripBonus - swingPenalty;
    return math.max(0, math.min(100, totalScore));
  }

  // Provide progressive difficulty suggestions
  static List<String> getProgressionSuggestions(int repCount, double averageFormScore) {
    List<String> suggestions = [];
    
    if (repCount < 3) {
      suggestions.addAll([
        'Focus on dead hang holds to build grip strength',
        'Practice negative pull-ups (jumping up, slow descent)',
        'Use resistance bands for assistance',
        'Work on scapular pull-ups (shoulder blade squeezes)',
      ]);
    } else if (repCount < 8) {
      suggestions.addAll([
        'Add pause reps at the top position',
        'Work on tempo control (3 seconds up, 3 seconds down)',
        'Practice L-sit pull-ups for core engagement',
        'Focus on perfect form over quantity',
      ]);
    } else if (repCount < 15) {
      suggestions.addAll([
        'Try weighted pull-ups for strength gains',
        'Practice different grip variations',
        'Add archer pull-ups for unilateral strength',
        'Work on muscle-ups progression',
      ]);
    } else {
      suggestions.addAll([
        'Master advanced variations (one-arm, weighted)',
        'Focus on endurance with high-rep sets',
        'Try explosive pull-ups for power development',
        'Incorporate pull-ups into complex movements',
      ]);
    }
    
    if (averageFormScore < 80) {
      suggestions.insert(0, 'Prioritize form quality over rep quantity');
    }
    
    return suggestions;
  }
}