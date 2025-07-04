import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class PushUpAnalyzer {
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

  // Adaptive ranges based on body type research
  static Map<int, Map<String, double>> bodyTypeRanges = {
    SHORT_LIMBS: {
      'elbowAngleMin': 65.0,
      'elbowAngleMax': 85.0,
      'handRatioMin': 0.9,
      'handRatioMax': 1.3,
      'elbowTorsoOptimal': 40.0,
      'plankTolerance': 12.0,
    },
    AVERAGE: {
      'elbowAngleMin': 70.0,
      'elbowAngleMax': 90.0,
      'handRatioMin': 1.0,
      'handRatioMax': 1.5,
      'elbowTorsoOptimal': 45.0,
      'plankTolerance': 15.0,
    },
    LONG_LIMBS: {
      'elbowAngleMin': 75.0,
      'elbowAngleMax': 95.0,
      'handRatioMin': 1.1,
      'handRatioMax': 1.7,
      'elbowTorsoOptimal': 50.0,
      'plankTolerance': 18.0,
    },
    STOCKY: {
      'elbowAngleMin': 70.0,
      'elbowAngleMax': 85.0,
      'handRatioMin': 1.0,
      'handRatioMax': 1.4,
      'elbowTorsoOptimal': 42.0,
      'plankTolerance': 12.0,
    },
    TALL_LEAN: {
      'elbowAngleMin': 75.0,
      'elbowAngleMax': 95.0,
      'handRatioMin': 1.1,
      'handRatioMax': 1.6,
      'elbowTorsoOptimal': 48.0,
      'plankTolerance': 20.0,
    },
  };

  static const List<String> bodyTypeNames = [
    'shortLimbs',
    'average',
    'longLimbs', 
    'stocky',
    'tallLean'
  ];

  // Extended elbow angle and phase constants  
  static const double EXTENDED_ELBOW_ANGLE = 170.0;
  static const double HEAD_ALIGNMENT_THRESHOLD = 30.0;

  // Movement phases
  static const int PHASE_STARTING = 0;
  static const int PHASE_DESCENDING = 1;
  static const int PHASE_BOTTOM = 2;
  static const int PHASE_ASCENDING = 3;
  static const int PHASE_TOP = 4;

  // Session tracking with stabilization
  static int _currentPhase = PHASE_STARTING;
  static int _repCount = 0;
  static double _previousElbowAngle = 180.0;
  static List<double> _elbowAngleHistory = [];
  static DateTime _lastPhaseChange = DateTime.now();
  static DateTime _lastFeedbackChange = DateTime.now();
  static String _lastFeedback = '';
  static Color _lastFeedbackColor = Colors.blue;
  static int _detectedBodyType = AVERAGE;
  static bool _bodyTypeCalibrated = false;

  // Anthropometric measurements for body type detection
  static double _armToTorsoRatio = 0.0;
  static double _shoulderToHipRatio = 0.0;
  static List<double> _anthropometricHistory = [];

  // Voice feedback configuration maps
  static Map<String, String> _voiceFeedbackMap = {
    // Form corrections
    'Hands too wide for your build! Move closer together': 'Hands too wide, move them closer together',
    'Hands too narrow! Spread wider for your frame': 'Hands too narrow, spread them wider',
    'Elbows flared too wide! Keep closer to body': 'Elbows too wide, keep them closer to your body',
    'Elbows too close! Allow natural angle': 'Elbows too close, allow natural angle',
    'Hips too high! Lower into plank': 'Lower your hips into plank position',
    'Hips sagging! Engage core': 'Engage your core, hips are sagging',
    
    // Phase feedback
    'Keep descending - aim for your optimal depth': 'Keep going down',
    'Good descent! Control the movement': 'Good descent, control it',
    'Go deeper for your body type!': 'Go deeper',
    'Perfect depth for your build!': 'Perfect depth',
    'Great depth! Push back up': 'Great depth, push up',
    'Push up strong! Extend those arms': 'Push up strong',
    'Excellent rep! Ready for next one': 'Excellent rep',
    'Perfect form for your body type!': 'Perfect form',
    'Good position - ready to start': 'Good position, ready to start',
    
    // General positioning
    'Position yourself fully in frame': 'Position yourself fully in the camera frame',
  };

  // Initialize voice feedback
  static Future<void> initializeVoiceFeedback() async {
    _flutterTts = FlutterTts();
    
    await _flutterTts!.setLanguage("en-US");
    await _flutterTts!.setSpeechRate(0.6); // Slightly slower for exercise clarity
    await _flutterTts!.setVolume(0.8);
    await _flutterTts!.setPitch(1.0);
    
    // Set completion handler
    _flutterTts!.setCompletionHandler(() {
      _isSpeaking = false;
    });

    // Set error handler
    _flutterTts!.setErrorHandler((msg) {
      _isSpeaking = false;
      print("TTS Error: $msg");
    });
  }

  // Speak feedback with intelligent filtering
  static Future<void> _speakFeedback(String text, {bool isUrgent = false}) async {
    if (!_isVoiceEnabled || _flutterTts == null) return;
    
    DateTime now = DateTime.now();
    
    // Get voice-optimized text
    String voiceText = _voiceFeedbackMap[text] ?? text;
    
    // Intelligent timing rules
    int minInterval = isUrgent ? 2000 : 4000; // Urgent feedback has shorter interval
    
    // Skip if same message spoken recently (unless urgent)
    if (!isUrgent && 
        _lastSpokenText == voiceText && 
        now.difference(_lastVoiceFeedback).inMilliseconds < minInterval) {
      return;
    }
    
    // Skip if currently speaking (unless urgent)
    if (_isSpeaking && !isUrgent) {
      return;
    }
    
    // Stop current speech if urgent
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
      "rep $count",
      "$count reps done",
      "rep $count complete",
      "$count down",
    ];
    
    // Special milestones
    if (count == 5) {
      await _speakFeedback("5 reps! Keep it up", isUrgent: false);
    } else if (count == 10) {
      await _speakFeedback("10 reps! Great work", isUrgent: false);
    } else if (count % 5 == 0 && count > 10) {
      await _speakFeedback("$count reps! You're crushing it", isUrgent: false);
    } else if (count <= 3) {
      // Announce first few reps
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

    // Calculate shoulder width
    double shoulderWidth = _calculateDistance(leftShoulder, rightShoulder);
    
    // Calculate hip width
    double hipWidth = _calculateDistance(leftHip, rightHip);

    // Calculate ratios
    _armToTorsoRatio = avgArmLength / avgTorsoLength;
    _shoulderToHipRatio = shoulderWidth / hipWidth;

    // Add to history for stability
    _anthropometricHistory.add(_armToTorsoRatio);
    if (_anthropometricHistory.length > 10) {
      _anthropometricHistory.removeAt(0);
    }

    // Only classify after sufficient data
    if (_anthropometricHistory.length < 5) {
      return AVERAGE;
    }

    double avgRatio = _anthropometricHistory.reduce((a, b) => a + b) / 
                     _anthropometricHistory.length;

    // Classification based on research-backed anthropometric ranges
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

  // Calculate elbow-torso angle with body type consideration
  static double _calculateElbowTorsoAngle(
    PoseLandmark shoulder,
    PoseLandmark elbow,
    PoseLandmark hip,
  ) {
    double torsoAngle = math.atan2(hip.y - shoulder.y, hip.x - shoulder.x);
    double elbowAngle = math.atan2(elbow.y - shoulder.y, elbow.x - shoulder.x);
    double angle = (elbowAngle - torsoAngle) * 180 / math.pi;
    return angle.abs() > 180 ? 360 - angle.abs() : angle.abs();
  }

  // Enhanced plank alignment calculation
  static double _calculatePlankAlignment(
    PoseLandmark shoulder,
    PoseLandmark hip,
    PoseLandmark knee,
    PoseLandmark ankle,
  ) {
    double hipAngle = _calculateAngle(shoulder, hip, knee);
    return (180 - hipAngle).abs();
  }

  // Stabilized feedback system with voice integration
  static void _updateFeedback(String feedback, Color color, Function(String, Color) onFeedbackUpdate) {
    DateTime now = DateTime.now();
    
    // Determine if feedback is urgent (form corrections)
    bool isUrgent = color == Colors.red;
    
    // Only update feedback if enough time has passed or it's significantly different
    if (feedback != _lastFeedback && 
        now.difference(_lastFeedbackChange).inMilliseconds > 2000) { // 2 second minimum
      _lastFeedback = feedback;
      _lastFeedbackColor = color;
      _lastFeedbackChange = now;
      onFeedbackUpdate(feedback, color);
      
      // Trigger voice feedback
      _speakFeedback(feedback, isUrgent: isUrgent);
    } else if (_lastFeedback.isNotEmpty) {
      // Keep showing the last stable feedback
      onFeedbackUpdate(_lastFeedback, _lastFeedbackColor);
    }
  }

  // Main analysis function with body type adaptation
  static Map<String, dynamic> analyzePushUpForm(
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
      'leftAnkle': landmarks[PoseLandmarkType.leftAnkle],
      'rightAnkle': landmarks[PoseLandmarkType.rightAnkle],
      'nose': landmarks[PoseLandmarkType.nose],
    };

    // Check critical landmarks
    List<String> criticalLandmarks = [
      'leftShoulder', 'rightShoulder', 'leftElbow', 'rightElbow',
      'leftWrist', 'rightWrist', 'leftHip', 'rightHip'
    ];

    for (String landmark in criticalLandmarks) {
      if (landmarkMap[landmark] == null) {
        _updateFeedback('Position yourself fully in frame', Colors.blue, onFeedbackUpdate);
        return {'phase': _currentPhase, 'repCount': _repCount, 'formScore': 0, 'bodyType': getBodyTypeName(_detectedBodyType)};
      }
    }

    // Create non-null map for body type detection
    Map<String, PoseLandmark> validLandmarks = {};
    landmarkMap.forEach((key, value) {
      if (value != null) validLandmarks[key] = value;
    });

    // Detect and adapt to body type
    if (!_bodyTypeCalibrated || _repCount % 5 == 0) { // Recalibrate every 5 reps
      int previousBodyType = _detectedBodyType;
      _detectedBodyType = _detectBodyType(validLandmarks);
      
      // Announce body type detection only once or when it changes
      if (!_bodyTypeCalibrated && _detectedBodyType != AVERAGE) {
        String bodyTypeName = getBodyTypeName(_detectedBodyType);
        _speakFeedback("Detected $bodyTypeName body type, adapting form guidance", isUrgent: false);
      }
      
      _bodyTypeCalibrated = true;
    }

    // Get body type specific ranges
    Map<String, double> ranges = bodyTypeRanges[_detectedBodyType]!;

    // Calculate measurements
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
    if (_elbowAngleHistory.length > 7) { // Increased smoothing
      _elbowAngleHistory.removeAt(0);
    }
    double smoothedElbowAngle = _elbowAngleHistory.reduce((a, b) => a + b) / _elbowAngleHistory.length;

    // Hand positioning with body type adaptation
    double handDistance = _calculateDistance(validLandmarks['leftWrist']!, validLandmarks['rightWrist']!);
    double shoulderDistance = _calculateDistance(validLandmarks['leftShoulder']!, validLandmarks['rightShoulder']!);
    double handToShoulderRatio = handDistance / shoulderDistance;

    // Elbow flare analysis
    double leftElbowTorsoAngle = _calculateElbowTorsoAngle(
      validLandmarks['leftShoulder']!,
      validLandmarks['leftElbow']!,
      validLandmarks['leftHip']!,
    );
    double rightElbowTorsoAngle = _calculateElbowTorsoAngle(
      validLandmarks['rightShoulder']!,
      validLandmarks['rightElbow']!,
      validLandmarks['rightHip']!,
    );
    double avgElbowTorsoAngle = (leftElbowTorsoAngle + rightElbowTorsoAngle) / 2;

    // Body alignment
    double avgPlankAlignment = 0;
    if (validLandmarks['leftKnee'] != null && validLandmarks['leftAnkle'] != null &&
        validLandmarks['rightKnee'] != null && validLandmarks['rightAnkle'] != null) {
      double leftPlankAlignment = _calculatePlankAlignment(
        validLandmarks['leftShoulder']!,
        validLandmarks['leftHip']!,
        validLandmarks['leftKnee']!,
        validLandmarks['leftAnkle']!,
      );
      double rightPlankAlignment = _calculatePlankAlignment(
        validLandmarks['rightShoulder']!,
        validLandmarks['rightHip']!,
        validLandmarks['rightKnee']!,
        validLandmarks['rightAnkle']!,
      );
      avgPlankAlignment = (leftPlankAlignment + rightPlankAlignment) / 2;
    }

    // Form assessment with body type specific ranges
    String feedback = '';
    Color feedbackColor = Colors.green;
    int formScore = 100;

    // Priority form checks adapted to body type
    if (handToShoulderRatio > ranges['handRatioMax']!) {
      feedback = 'Hands too wide for your build! Move closer together';
      feedbackColor = Colors.red;
      formScore -= 30;
    } else if (handToShoulderRatio < ranges['handRatioMin']!) {
      feedback = 'Hands too narrow! Spread wider for your frame';
      feedbackColor = Colors.red;
      formScore -= 25;
    } else if (avgElbowTorsoAngle > ranges['elbowTorsoOptimal']! + 25) {
      feedback = 'Elbows flared too wide! Keep closer to body';
      feedbackColor = Colors.red;
      formScore -= 35;
    } else if (avgElbowTorsoAngle < ranges['elbowTorsoOptimal']! - 20) {
      feedback = 'Elbows too close! Allow natural angle';
      feedbackColor = Colors.orange;
      formScore -= 20;
    } else if (avgPlankAlignment > ranges['plankTolerance']!) {
      if (validLandmarks['leftHip']!.y > validLandmarks['leftShoulder']!.y + 30) {
        feedback = 'Hips too high! Lower into plank';
        feedbackColor = Colors.red;
        formScore -= 25;
      } else {
        feedback = 'Hips sagging! Engage core';
        feedbackColor = Colors.red;
        formScore -= 30;
      }
    }

    // Phase detection with enhanced stability
    int newPhase = _detectPhase(smoothedElbowAngle, _currentPhase, ranges);

    if (newPhase != _currentPhase) {
      DateTime now = DateTime.now();
      if (now.difference(_lastPhaseChange).inMilliseconds > 500) { // Increased debounce
        _currentPhase = newPhase;
        _lastPhaseChange = now;

        if (_currentPhase == PHASE_TOP) {
          _repCount++;
          onRepCountUpdate(_repCount);
          
          // Voice announcement for rep completion
          _announceRepCount(_repCount);
        }
      }
    }

    // Phase-specific feedback with body type consideration
    if (feedback.isEmpty) {
      switch (_currentPhase) {
        case PHASE_DESCENDING:
          if (smoothedElbowAngle > 120) {
            feedback = 'Keep descending - aim for your optimal depth';
            feedbackColor = Colors.blue;
          } else {
            feedback = 'Good descent! Control the movement';
            feedbackColor = Colors.green;
          }
          break;

        case PHASE_BOTTOM:
          if (smoothedElbowAngle > ranges['elbowAngleMax']! + 15) {
            feedback = 'Go deeper for your body type!';
            feedbackColor = Colors.orange;
            formScore -= 20;
          } else if (smoothedElbowAngle >= ranges['elbowAngleMin']! && 
                     smoothedElbowAngle <= ranges['elbowAngleMax']!) {
            feedback = 'Perfect depth for your build!';
            feedbackColor = Colors.green;
          } else {
            feedback = 'Great depth! Push back up';
            feedbackColor = Colors.green;
          }
          break;

        case PHASE_ASCENDING:
          feedback = 'Push up strong! Extend those arms';
          feedbackColor = Colors.blue;
          break;

        case PHASE_TOP:
          feedback = 'Excellent rep! Ready for next one';
          feedbackColor = Colors.green;
          break;

        default:
          if (formScore > 90) {
            feedback = 'Perfect form for your body type!';
            feedbackColor = Colors.green;
          } else {
            feedback = 'Good position - ready to start';
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
      'handSpacing': handToShoulderRatio,
      'elbowFlare': avgElbowTorsoAngle,
      'bodyAlignment': avgPlankAlignment,
      'bodyType': getBodyTypeName(_detectedBodyType),
      'armToTorsoRatio': _armToTorsoRatio,
    };
  }

  // Enhanced phase detection with body type specific ranges
  static int _detectPhase(double currentAngle, int currentPhase, Map<String, double> ranges) {
    switch (currentPhase) {
      case PHASE_STARTING:
      case PHASE_TOP:
        if (currentAngle < 140) {
          return PHASE_DESCENDING;
        }
        break;

      case PHASE_DESCENDING:
        if (currentAngle < ranges['elbowAngleMax']! + 5) {
          return PHASE_BOTTOM;
        }
        break;

      case PHASE_BOTTOM:
        if (currentAngle > ranges['elbowAngleMax']! + 20) {
          return PHASE_ASCENDING;
        }
        break;

      case PHASE_ASCENDING:
        if (currentAngle > EXTENDED_ELBOW_ANGLE - 10) {
          return PHASE_TOP;
        }
        break;
    }

    return currentPhase;
  }

  // Reset with body type preservation
  static void resetSession() {
    _currentPhase = PHASE_STARTING;
    _repCount = 0;
    _previousElbowAngle = 180.0;
    _elbowAngleHistory.clear();
    _lastPhaseChange = DateTime.now();
    _lastFeedbackChange = DateTime.now();
    _lastFeedback = '';
    _lastFeedbackColor = Colors.blue;
    _lastSpokenText = '';
    _lastVoiceFeedback = DateTime.now();
    // Keep body type calibration unless explicitly reset
  }

  // Force body type recalibration
  static void recalibrateBodyType() {
    _bodyTypeCalibrated = false;
    _anthropometricHistory.clear();
    _detectedBodyType = AVERAGE;
  }

  // Enhanced statistics with body type info
  static Map<String, dynamic> getSessionStats() {
    String phaseName;
    switch (_currentPhase) {
      case PHASE_STARTING: phaseName = 'starting'; break;
      case PHASE_DESCENDING: phaseName = 'descending'; break;
      case PHASE_BOTTOM: phaseName = 'bottom'; break;
      case PHASE_ASCENDING: phaseName = 'ascending'; break;
      case PHASE_TOP: phaseName = 'top'; break;
      default: phaseName = 'unknown';
    }

    return {
      'totalReps': _repCount,
      'currentPhase': phaseName,
      'avgElbowAngle': _elbowAngleHistory.isNotEmpty
          ? _elbowAngleHistory.reduce((a, b) => a + b) / _elbowAngleHistory.length
          : 0,
      'detectedBodyType': getBodyTypeName(_detectedBodyType),
      'armToTorsoRatio': _armToTorsoRatio,
      'shoulderToHipRatio': _shoulderToHipRatio,
      'bodyTypeCalibrated': _bodyTypeCalibrated,
      'voiceEnabled': _isVoiceEnabled,
    };
  }

  // Get body type specific recommendations
  static Map<String, String> getBodyTypeRecommendations() {
    switch (_detectedBodyType) {
      case SHORT_LIMBS:
        return {
          'handPlacement': 'Slightly narrower than shoulder-width works well for you',
          'elbowAngle': 'Aim for 65-85° at the bottom - you have good leverage',
          'tempo': 'You can handle faster tempo due to shorter range of motion',
        };
      case LONG_LIMBS:
        return {
          'handPlacement': 'Wider hand placement (1.5x shoulders) will feel more natural',
          'elbowAngle': 'Aim for 75-95° - don\'t force deeper angles',
          'tempo': 'Slower, controlled movement - you have longer range of motion',
        };
      case STOCKY:
        return {
          'handPlacement': 'Standard shoulder-width, focus on stability',
          'elbowAngle': 'Slightly shallower angles (70-85°) are fine for your build',
          'tempo': 'Powerful explosive movement suits your body type',
        };
      case TALL_LEAN:
        return {
          'handPlacement': 'Wider placement for stability, watch elbow flare',
          'elbowAngle': 'Full range 75-95° - flexibility is your advantage',
          'tempo': 'Controlled movement, focus on stability',
        };
      default:
        return {
          'handPlacement': 'Standard shoulder-width placement',
          'elbowAngle': 'Standard 70-90° range at bottom',
          'tempo': 'Moderate, controlled tempo',
        };
    }
  }

  // Workout session voice guidance
  static Future<void> startWorkoutSession({int? targetReps}) async {
    if (targetReps != null) {
      await _speakFeedback("Starting push-up session. Target: $targetReps reps. Get into position", isUrgent: false);
    } else {
      await _speakFeedback("Starting push-up session. Get into position", isUrgent: false);
    }
  }

  static Future<void> endWorkoutSession() async {
    Map<String, dynamic> stats = getSessionStats();
    int totalReps = stats['totalReps'];
    
    if (totalReps > 0) {
      String message = "Workout complete! You did $totalReps push-ups. Great job!";
      await _speakFeedback(message, isUrgent: false);
    } else {
      await _speakFeedback("Session ended. Keep practicing!", isUrgent: false);
    }
  }

  // Voice coaching for specific improvements
  static Future<void> provideFormCoaching() async {
    Map<String, String> recommendations = getBodyTypeRecommendations();
    String bodyType = getBodyTypeName(_detectedBodyType);
    
    await _speakFeedback("Form coaching for $bodyType body type", isUrgent: false);
    
    // Wait between coaching tips
    await Future.delayed(Duration(seconds: 2));
    await _speakFeedback(recommendations['handPlacement']!, isUrgent: false);
    
    await Future.delayed(Duration(seconds: 3));
    await _speakFeedback(recommendations['elbowAngle']!, isUrgent: false);
    
    await Future.delayed(Duration(seconds: 3));
    await _speakFeedback(recommendations['tempo']!, isUrgent: false);
  }

  // Emergency stop for voice
  static Future<void> stopVoiceFeedback() async {
    if (_flutterTts != null) {
      await _flutterTts!.stop();
      _isSpeaking = false;
    }
  }

  // Test voice functionality
  static Future<void> testVoice() async {
    await _speakFeedback("Voice feedback is working. Ready for your workout!", isUrgent: false);
  }

  // Dispose voice resources
  static void disposeVoice() {
    _flutterTts?.stop();
    _flutterTts = null;
    _isSpeaking = false;
  }
}