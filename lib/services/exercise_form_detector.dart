import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:math' as math;

class ExerciseFormDetector {
  final Function(String, Color) onFeedbackUpdate;
  final Function(int) onRepCountUpdate;
  int _repCount = 0;
  String _currentExercise;
  int _lastRepCount = 0;
  bool _isInDownPhase = false;
  PoseDetector? _poseDetector;

  ExerciseFormDetector({
    required this.onFeedbackUpdate,
    required this.onRepCountUpdate,
    required String initialExercise,
  }) : _currentExercise = initialExercise {
    _initializePoseDetector();
  }

  void _initializePoseDetector() {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
      ),
    );
  }

  void updateExercise(String newExercise) {
    _currentExercise = newExercise;
    resetCounter();
  }

  void resetCounter() {
    _repCount = 0;
    _lastRepCount = 0;
    _isInDownPhase = false;
    onRepCountUpdate(0);
  }

  Future<void> processImage(InputImage inputImage, String exerciseName) async {
    if (_poseDetector == null) return;
    
    try {
      final poses = await _poseDetector!.processImage(inputImage);
      if (poses.isNotEmpty) {
        _analyzePose(poses.first, exerciseName);
      } else {
        onFeedbackUpdate('Position yourself in frame', Colors.blue);
      }
    } catch (e) {
      print('Error processing pose: $e');
      onFeedbackUpdate('Error analyzing pose', Colors.red);
    }
  }

  void _analyzePose(Pose pose, String exerciseName) {
    switch (exerciseName) {
      case 'Push Ups':
        _analyzePushUps(pose);
        break;
      case 'Pull Ups':
        _analyzePullUps(pose);
        break;
      case 'Tricep Pushdowns':
        _analyzeTricepPushdowns(pose);
        break;
      case 'Squats':
        _analyzeSquats(pose);
        break;
      case 'Bicep Curls':
        _analyzeBicepCurls(pose);
        break;
      case 'Bench Press':
        _analyzeBenchPress(pose);
        break;
      case 'Deadlifts':
        _analyzeDeadlift(pose);
        break;
      case 'Lat Pulldowns':
        _analyzeLatPulldowns(pose);
        break;
      default:
        onFeedbackUpdate('Exercise analysis not available', Colors.amber);
    }
  }

  // Calculate angle between three points
  double _calculateAngle(
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
  double _calculateDistance(PoseLandmark point1, PoseLandmark point2) {
    return math.sqrt(
      math.pow(point1.x - point2.x, 2) + math.pow(point1.y - point2.y, 2),
    );
  }

  void _analyzePushUps(Pose pose) {
    final landmarks = pose.landmarks;

    // Key points for push-ups
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final nose = landmarks[PoseLandmarkType.nose];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null ||
        leftWrist == null ||
        rightWrist == null ||
        leftHip == null ||
        rightHip == null) {
      onFeedbackUpdate('Position yourself in frame', Colors.blue);
      return;
    }

    // Calculate angles and distances
    double leftElbowAngle = _calculateAngle(leftShoulder, leftElbow, leftWrist);
    double rightElbowAngle = _calculateAngle(rightShoulder, rightElbow, rightWrist);
    double avgElbowAngle = (leftElbowAngle + rightElbowAngle) / 2;

    double handDistance = _calculateDistance(leftWrist, rightWrist);
    double shoulderDistance = _calculateDistance(leftShoulder, rightShoulder);
    double handToShoulderRatio = handDistance / shoulderDistance;

    // Form checks
    if (handToShoulderRatio > 1.8) {
      onFeedbackUpdate('Hands too wide! Move them closer', Colors.red);
      return;
    }
    if (handToShoulderRatio < 0.8) {
      onFeedbackUpdate('Hands too narrow! Spread them wider', Colors.red);
      return;
    }

    // Hip alignment check
    double hipLevel = (leftHip.y + rightHip.y) / 2;
    double shoulderLevel = (leftShoulder.y + rightShoulder.y) / 2;
    
    if (hipLevel > shoulderLevel + 50) {
      onFeedbackUpdate('Keep hips up! Maintain straight plank', Colors.red);
      return;
    }

    // Head position check
    if (nose != null && nose.y < shoulderLevel - 80) {
      onFeedbackUpdate('Keep head neutral! Look down', Colors.red);
      return;
    }

    // Rep counting logic with state machine
    if (avgElbowAngle < 90 && !_isInDownPhase) {
      _isInDownPhase = true;
    } else if (avgElbowAngle > 160 && _isInDownPhase) {
      _repCount++;
      onRepCountUpdate(_repCount);
      _isInDownPhase = false;
    }

    // Depth feedback
    if (avgElbowAngle > 120) {
      onFeedbackUpdate('Go lower! Bend elbows more', Colors.orange);
      return;
    }

    onFeedbackUpdate('Good form! Keep it up!', Colors.green);
  }

  void _analyzePullUps(Pose pose) {
    final landmarks = pose.landmarks;

    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null ||
        leftWrist == null ||
        rightWrist == null) {
      onFeedbackUpdate('Position yourself in frame', Colors.blue);
      return;
    }

    double shoulderLevel = (leftShoulder.y + rightShoulder.y) / 2;
    double wristLevel = (leftWrist.y + rightWrist.y) / 2;
    double handDistance = _calculateDistance(leftWrist, rightWrist);
    double shoulderDistance = _calculateDistance(leftShoulder, rightShoulder);
    double handToShoulderRatio = handDistance / shoulderDistance;

    // Grip width check
    if (handToShoulderRatio > 2.0) {
      onFeedbackUpdate('Grip too wide! Move hands closer', Colors.red);
      return;
    }
    if (handToShoulderRatio < 1.0) {
      onFeedbackUpdate('Grip too narrow! Widen grip', Colors.red);
      return;
    }

    // Body stability check
    if (leftHip != null && rightHip != null) {
      double hipLevel = (leftHip.y + rightHip.y) / 2;
      double hipToShoulderDistance = (hipLevel - shoulderLevel).abs();

      if (hipToShoulderDistance < 100) {
        onFeedbackUpdate('Stop swinging! Keep body straight', Colors.red);
        return;
      }
    }

    // Range of motion check
    double leftElbowAngle = _calculateAngle(leftShoulder, leftElbow, leftWrist);
    double rightElbowAngle = _calculateAngle(rightShoulder, rightElbow, rightWrist);
    double avgElbowAngle = (leftElbowAngle + rightElbowAngle) / 2;

    if (wristLevel > shoulderLevel && avgElbowAngle < 150) {
      onFeedbackUpdate('Extend arms fully at bottom', Colors.orange);
      return;
    }

    // Rep counting
    if (shoulderLevel > wristLevel + 30 && !_isInDownPhase) {
      _repCount++;
      onRepCountUpdate(_repCount);
      _isInDownPhase = true;
    } else if (wristLevel > shoulderLevel) {
      _isInDownPhase = false;
    }

    // Height check
    if (shoulderLevel > wristLevel + 30) {
      onFeedbackUpdate('Pull higher! Chin over bar', Colors.orange);
      return;
    }

    onFeedbackUpdate('Excellent pull-up form!', Colors.green);
  }

  void _analyzeSquats(Pose pose) {
    final landmarks = pose.landmarks;

    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];

    if (leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      onFeedbackUpdate('Position yourself in frame', Colors.blue);
      return;
    }

    double hipLevel = (leftHip.y + rightHip.y) / 2;
    double kneeLevel = (leftKnee.y + rightKnee.y) / 2;
    double kneeDistance = _calculateDistance(leftKnee, rightKnee);
    double hipDistance = _calculateDistance(leftHip, rightHip);

    // Depth check and rep counting
    if (hipLevel < kneeLevel - 20 && !_isInDownPhase) {
      _isInDownPhase = true;
    } else if (hipLevel > kneeLevel + 20 && _isInDownPhase) {
      _repCount++;
      onRepCountUpdate(_repCount);
      _isInDownPhase = false;
    }

    // Knee tracking
    if (kneeDistance < hipDistance * 0.7) {
      onFeedbackUpdate('Keep knees out! Don\'t let them cave inward', Colors.red);
      return;
    }

    // Forward lean check
    if (leftShoulder != null && rightShoulder != null) {
      double shoulderHipDistance = (((leftShoulder.x + rightShoulder.x) / 2) -
              ((leftHip.x + rightHip.x) / 2)).abs();

      if (shoulderHipDistance > 50) {
        onFeedbackUpdate('Keep your chest up! Don\'t lean forward', Colors.red);
        return;
      }
    }

    // Depth feedback
    if (hipLevel > kneeLevel - 10) {
      onFeedbackUpdate('Squat deeper! Hips should go below knees', Colors.orange);
      return;
    }

    onFeedbackUpdate('Perfect squat form!', Colors.green);
  }

  void _analyzeBicepCurls(Pose pose) {
    final landmarks = pose.landmarks;

    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null ||
        leftWrist == null ||
        rightWrist == null) {
      onFeedbackUpdate('Position yourself in frame', Colors.blue);
      return;
    }

    double shoulderLevel = (leftShoulder.y + rightShoulder.y) / 2;
    double elbowLevel = (leftElbow.y + rightElbow.y) / 2;
    double leftElbowAngle = _calculateAngle(leftShoulder, leftElbow, leftWrist);
    double rightElbowAngle = _calculateAngle(rightShoulder, rightElbow, rightWrist);
    double avgElbowAngle = (leftElbowAngle + rightElbowAngle) / 2;

    // Elbow stability check
    if ((shoulderLevel - elbowLevel).abs() > 80) {
      onFeedbackUpdate('Keep elbows stable! Don\'t swing', Colors.red);
      return;
    }

    // Elbow position check
    double leftElbowDistance = (leftElbow.x - leftShoulder.x).abs();
    double rightElbowDistance = (rightElbow.x - rightShoulder.x).abs();

    if (leftElbowDistance > 60 || rightElbowDistance > 60) {
      onFeedbackUpdate('Keep elbows close to your sides', Colors.red);
      return;
    }

    // Rep counting
    if (avgElbowAngle < 60 && !_isInDownPhase) {
      _isInDownPhase = true;
    } else if (avgElbowAngle > 160 && _isInDownPhase) {
      _repCount++;
      onRepCountUpdate(_repCount);
      _isInDownPhase = false;
    }

    // Range of motion feedback
    if (avgElbowAngle > 160) {
      onFeedbackUpdate('Extend arms fully at the bottom', Colors.orange);
      return;
    }
    if (avgElbowAngle > 90) {
      onFeedbackUpdate('Curl higher! Squeeze your biceps', Colors.orange);
      return;
    }

    onFeedbackUpdate('Great bicep curl form!', Colors.green);
  }

  void _analyzeTricepPushdowns(Pose pose) {
    onFeedbackUpdate('Tricep pushdown analysis in development', Colors.amber);
  }

  void _analyzeBenchPress(Pose pose) {
    onFeedbackUpdate('Bench press analysis in development', Colors.amber);
  }

  void _analyzeDeadlift(Pose pose) {
    onFeedbackUpdate('Deadlift analysis in development', Colors.amber);
  }

  void _analyzeLatPulldowns(Pose pose) {
    onFeedbackUpdate('Lat pulldown analysis in development', Colors.amber);
  }

  void dispose() {
    _poseDetector?.close();
  }
}