import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:camera/camera.dart';
import 'package:collection/collection.dart';

class ExerciseClassifier {
  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  // Exercise class names (match your training classes)
  final List<String> exerciseNames = [
    "Push-up",
    "Pull-up",
    "Squat",
    "Deadlift",
    "Bench Press",
    "Lat Pulldown",
    "Bicep Curl",
    "Tricep Pushdown",
  ];

  // Pose detector
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.accurate,
      mode: PoseDetectionMode.stream,
    ),
  );

  // Keypoint buffer for sequence creation
  final List<List<double>> _keypointBuffer = [];
  final List<List<double>> _enhancedFeatureBuffer = [];
  final int _sequenceLength = 30;
  final int _maxBufferSize = 100;

  Future<bool> loadModel({
    String modelPath = 'assets/models/exercise_classification_model.tflite',
  }) async {
    try {
      _interpreter = await Interpreter.fromAsset(modelPath);
      _isModelLoaded = true;
      print('Model loaded successfully');
      return true;
    } catch (e) {
      print('Error loading model: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> classifyFromImage(InputImage image) async {
    if (!_isModelLoaded) {
      print('Model not loaded');
      return null;
    }

    try {
      // Detect pose
      final List<Pose> poses = await _poseDetector.processImage(image);

      if (poses.isEmpty) {
        print('No pose detected');
        return null;
      }

      // Extract keypoints from the first pose
      final Pose pose = poses.first;
      final List<double> keypoints = _extractKeypoints(pose);
      final List<double> enhancedFeatures = _calculateEnhancedFeatures(
        keypoints,
      );

      // Add to buffer
      _keypointBuffer.add(keypoints);
      _enhancedFeatureBuffer.add(enhancedFeatures);

      // Maintain buffer size
      if (_keypointBuffer.length > _maxBufferSize) {
        _keypointBuffer.removeAt(0);
        _enhancedFeatureBuffer.removeAt(0);
      }

      // Check if we have enough frames for prediction
      if (_keypointBuffer.length >= _sequenceLength) {
        return _makePrediction();
      }

      return null;
    } catch (e) {
      print('Error in classification: $e');
      return null;
    }
  }

  List<double> _extractKeypoints(Pose pose) {
    final List<double> keypoints = [];

    // MediaPipe pose landmark order (33 landmarks)
    final List<PoseLandmarkType> landmarkOrder = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftEyeInner,
      PoseLandmarkType.leftEye,
      PoseLandmarkType.leftEyeOuter,
      PoseLandmarkType.rightEyeInner,
      PoseLandmarkType.rightEye,
      PoseLandmarkType.rightEyeOuter,
      PoseLandmarkType.leftEar,
      PoseLandmarkType.rightEar,
      PoseLandmarkType.leftMouth,
      PoseLandmarkType.rightMouth,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftPinky,
      PoseLandmarkType.rightPinky,
      PoseLandmarkType.leftIndex,
      PoseLandmarkType.rightIndex,
      PoseLandmarkType.leftThumb,
      PoseLandmarkType.rightThumb,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.leftHeel,
      PoseLandmarkType.rightHeel,
      PoseLandmarkType.leftFootIndex,
      PoseLandmarkType.rightFootIndex,
    ];

    for (PoseLandmarkType landmarkType in landmarkOrder) {
      final PoseLandmark? landmark = pose.landmarks[landmarkType];
      if (landmark != null) {
        keypoints.addAll([
          landmark.x,
          landmark.y,
          1.0,
        ]); // Using 1.0 as visibility
      } else {
        keypoints.addAll([
          0.0,
          0.0,
          0.0,
        ]); // Default values if landmark not found
      }
    }

    return keypoints;
  }

  List<double> _calculateEnhancedFeatures(List<double> keypoints) {
    final List<double> features = [];

    // Joint indices for MediaPipe pose
    final Map<String, int> joints = {
      'nose': 0,
      'leftEye': 1,
      'rightEye': 2,
      'leftEar': 3,
      'rightEar': 4,
      'leftShoulder': 11,
      'rightShoulder': 12,
      'leftElbow': 13,
      'rightElbow': 14,
      'leftWrist': 15,
      'rightWrist': 16,
      'leftHip': 23,
      'rightHip': 24,
      'leftKnee': 25,
      'rightKnee': 26,
      'leftAnkle': 27,
      'rightAnkle': 28,
    };

    // Helper functions
    double getAngle(List<double> p1, List<double> p2, List<double> p3) {
      try {
        final double v1x = p1[0] - p2[0];
        final double v1y = p1[1] - p2[1];
        final double v2x = p3[0] - p2[0];
        final double v2y = p3[1] - p2[1];

        final double dotProduct = v1x * v2x + v1y * v2y;
        final double norm1 = sqrt(v1x * v1x + v1y * v1y);
        final double norm2 = sqrt(v2x * v2x + v2y * v2y);

        if (norm1 < 1e-6 || norm2 < 1e-6) return 0.0;

        final double cosAngle = dotProduct / (norm1 * norm2);
        final double clampedCos = cosAngle.clamp(-1.0, 1.0);
        final double angle = acos(clampedCos);

        return angle * 180.0 / pi; // Convert to degrees
      } catch (e) {
        return 0.0;
      }
    }

    double getDistance(List<double> p1, List<double> p2) {
      return sqrt(pow(p1[0] - p2[0], 2) + pow(p1[1] - p2[1], 2));
    }

    List<double> getCoords(String joint) {
      final int idx = joints[joint]!;
      return [
        keypoints[idx * 3],
        keypoints[idx * 3 + 1],
        keypoints[idx * 3 + 2],
      ];
    }

    try {
      // Extract coordinates
      final Map<String, List<double>> coords = {};
      joints.forEach((joint, _) {
        coords[joint] = getCoords(joint);
      });

      // Visibility score
      final List<String> keyJoints = [
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

      final double visibilityScore =
          keyJoints.map((joint) => coords[joint]![2]).reduce((a, b) => a + b) /
          keyJoints.length;
      features.add(visibilityScore);

      // Elbow angles
      final double leftElbowAngle = getAngle(
        coords['leftShoulder']!,
        coords['leftElbow']!,
        coords['leftWrist']!,
      );
      final double rightElbowAngle = getAngle(
        coords['rightShoulder']!,
        coords['rightElbow']!,
        coords['rightWrist']!,
      );
      features.addAll([leftElbowAngle, rightElbowAngle]);

      // Shoulder angles
      final double leftShoulderAngle = getAngle(
        coords['leftElbow']!,
        coords['leftShoulder']!,
        coords['leftHip']!,
      );
      final double rightShoulderAngle = getAngle(
        coords['rightElbow']!,
        coords['rightShoulder']!,
        coords['rightHip']!,
      );
      features.addAll([leftShoulderAngle, rightShoulderAngle]);

      // Body centers
      final List<double> shoulderCenter = [
        (coords['leftShoulder']![0] + coords['rightShoulder']![0]) / 2,
        (coords['leftShoulder']![1] + coords['rightShoulder']![1]) / 2,
      ];
      final List<double> hipCenter = [
        (coords['leftHip']![0] + coords['rightHip']![0]) / 2,
        (coords['leftHip']![1] + coords['rightHip']![1]) / 2,
      ];

      // Wrist positions relative to shoulders
      final double leftWristShoulderHeight =
          coords['leftWrist']![1] - coords['leftShoulder']![1];
      final double rightWristShoulderHeight =
          coords['rightWrist']![1] - coords['rightShoulder']![1];
      features.addAll([leftWristShoulderHeight, rightWristShoulderHeight]);

      // Wrist lateral positions
      final double leftWristLateral =
          (coords['leftWrist']![0] - shoulderCenter[0]).abs();
      final double rightWristLateral =
          (coords['rightWrist']![0] - shoulderCenter[0]).abs();
      features.addAll([leftWristLateral, rightWristLateral]);

      // Torso angle
      final double torsoAngle = getAngle(
        [hipCenter[0], hipCenter[1] - 0.1],
        hipCenter,
        shoulderCenter,
      );
      features.add(torsoAngle);

      // Body lean
      final double bodyLean = shoulderCenter[0] - hipCenter[0];
      features.add(bodyLean);

      // Knee angles
      final double leftKneeAngle = getAngle(
        coords['leftHip']!,
        coords['leftKnee']!,
        coords['leftAnkle']!,
      );
      final double rightKneeAngle = getAngle(
        coords['rightHip']!,
        coords['rightKnee']!,
        coords['rightAnkle']!,
      );
      features.addAll([leftKneeAngle, rightKneeAngle]);

      // Hip angles
      final double leftHipAngle = getAngle(
        coords['leftShoulder']!,
        coords['leftHip']!,
        coords['leftKnee']!,
      );
      final double rightHipAngle = getAngle(
        coords['rightShoulder']!,
        coords['rightHip']!,
        coords['rightKnee']!,
      );
      features.addAll([leftHipAngle, rightHipAngle]);

      // Arm span ratio
      final double armSpan = getDistance(
        coords['leftWrist']!,
        coords['rightWrist']!,
      );
      final double shoulderWidth = getDistance(
        coords['leftShoulder']!,
        coords['rightShoulder']!,
      );
      final double armSpanRatio = armSpan / (shoulderWidth + 1e-6);
      features.add(armSpanRatio);

      // Stance ratio
      final double stanceWidth = getDistance(
        coords['leftAnkle']!,
        coords['rightAnkle']!,
      );
      final double hipWidth = getDistance(
        coords['leftHip']!,
        coords['rightHip']!,
      );
      final double stanceRatio = stanceWidth / (hipWidth + 1e-6);
      features.add(stanceRatio);

      // Elbow-shoulder distances
      final double leftElbowShoulderDist = getDistance(
        coords['leftElbow']!,
        coords['leftShoulder']!,
      );
      final double rightElbowShoulderDist = getDistance(
        coords['rightElbow']!,
        coords['rightShoulder']!,
      );
      features.addAll([leftElbowShoulderDist, rightElbowShoulderDist]);

      // Wrist-elbow angles
      final double leftWristElbowAngle = getAngle(
        [coords['leftElbow']![0], coords['leftElbow']![1] - 0.1],
        coords['leftElbow']!,
        coords['leftWrist']!,
      );
      final double rightWristElbowAngle = getAngle(
        [coords['rightElbow']![0], coords['rightElbow']![1] - 0.1],
        coords['rightElbow']!,
        coords['rightWrist']!,
      );
      features.addAll([leftWristElbowAngle, rightWristElbowAngle]);

      // Symmetry features
      final double armAngleDiff = (leftElbowAngle - rightElbowAngle).abs();
      final double legAngleDiff = (leftKneeAngle - rightKneeAngle).abs();
      features.addAll([armAngleDiff, legAngleDiff]);

      // Pull-up indicator
      final int handsAboveShoulders =
          (coords['leftWrist']![1] < coords['leftShoulder']![1] &&
              coords['rightWrist']![1] < coords['rightShoulder']![1])
          ? 1
          : 0;
      features.add(handsAboveShoulders.toDouble());

      // Lying position indicator
      final int lyingPosition =
          ((coords['leftShoulder']![1] - coords['leftHip']![1]).abs() < 0.1)
          ? 1
          : 0;
      features.add(lyingPosition.toDouble());

      // Head tilt
      final double headTilt = coords['nose']![1] - shoulderCenter[1];
      features.add(headTilt);

      // Knee forward positions
      final double leftKneeForward =
          coords['leftKnee']![0] - coords['leftHip']![0];
      final double rightKneeForward =
          coords['rightKnee']![0] - coords['rightHip']![0];
      features.addAll([leftKneeForward, rightKneeForward]);

      // Ankle angles (simplified)
      final double leftAnkleAngle = getAngle(
        coords['leftKnee']!,
        coords['leftAnkle']!,
        [coords['leftAnkle']![0], coords['leftAnkle']![1] + 0.1],
      );
      final double rightAnkleAngle = getAngle(
        coords['rightKnee']!,
        coords['rightAnkle']!,
        [coords['rightAnkle']![0], coords['rightAnkle']![1] + 0.1],
      );
      features.addAll([leftAnkleAngle, rightAnkleAngle]);
    } catch (e) {
      print('Error in enhanced feature calculation: $e');
      // Return zeros if calculation fails
      return List.filled(32, 0.0);
    }

    // Ensure exactly 32 features
    while (features.length < 32) {
      features.add(0.0);
    }

    return features.take(32).toList();
  }

  List<double> _normalizeSequence(List<List<double>> sequence) {
    final List<double> normalizedSequence = [];

    for (int frameIdx = 0; frameIdx < sequence.length; frameIdx++) {
      final List<double> frame = List.from(sequence[frameIdx]);

      try {
        // Get shoulder and hip centers for normalization
        final double shoulderCenterX = (frame[11 * 3] + frame[12 * 3]) / 2;
        final double shoulderCenterY =
            (frame[11 * 3 + 1] + frame[12 * 3 + 1]) / 2;
        final double hipCenterX = (frame[23 * 3] + frame[24 * 3]) / 2;
        final double hipCenterY = (frame[23 * 3 + 1] + frame[24 * 3 + 1]) / 2;

        // Calculate torso length for scaling
        final double torsoLength = max(
          0.1,
          sqrt(
            pow(shoulderCenterX - hipCenterX, 2) +
                pow(shoulderCenterY - hipCenterY, 2),
          ),
        );

        // Normalize all keypoints
        for (int i = 0; i < 33; i++) {
          frame[i * 3] = (frame[i * 3] - hipCenterX) / torsoLength;
          frame[i * 3 + 1] = (frame[i * 3 + 1] - hipCenterY) / torsoLength;
          // Keep visibility as is
        }
      } catch (e) {
        print('Normalization error: $e');
      }

      normalizedSequence.addAll(frame);
    }

    return normalizedSequence;
  }

  List<double> _calculateTemporalFeatures(
    List<List<double>> keypoints,
    List<List<double>> enhanced,
  ) {
    final List<double> temporalFeatures = [];

    // Key joints for movement analysis
    final List<int> keyJoints = [11, 12, 13, 14, 15, 16, 23, 24, 25, 26];

    // Calculate movement statistics for each joint
    for (int jointIdx in keyJoints) {
      final List<double> xCoords = keypoints
          .map((frame) => frame[jointIdx * 3])
          .toList();
      final List<double> yCoords = keypoints
          .map((frame) => frame[jointIdx * 3 + 1])
          .toList();

      // Movement range
      final double xRange = xCoords.reduce(max) - xCoords.reduce(min);
      final double yRange = yCoords.reduce(max) - yCoords.reduce(min);

      // Movement velocity
      final double xVelocity = _calculateMeanAbsDiff(xCoords);
      final double yVelocity = _calculateMeanAbsDiff(yCoords);

      // Movement acceleration
      final double xAccel = _calculateMeanAbsSecondDiff(xCoords);
      final double yAccel = _calculateMeanAbsSecondDiff(yCoords);

      temporalFeatures.addAll([
        xRange,
        yRange,
        xVelocity,
        yVelocity,
        xAccel,
        yAccel,
      ]);
    }

    // Enhanced feature temporal analysis
    for (
      int featureIdx = 0;
      featureIdx < min(16, enhanced.first.length);
      featureIdx++
    ) {
      final List<double> featureSeries = enhanced
          .map((frame) => frame[featureIdx])
          .toList();

      final double featureMean =
          featureSeries.reduce((a, b) => a + b) / featureSeries.length;
      final double featureStd = _calculateStandardDeviation(featureSeries);
      final double featureRange =
          featureSeries.reduce(max) - featureSeries.reduce(min);

      temporalFeatures.addAll([featureMean, featureStd, featureRange]);
    }

    return temporalFeatures;
  }

  double _calculateMeanAbsDiff(List<double> values) {
    if (values.length < 2) return 0.0;
    double sum = 0.0;
    for (int i = 1; i < values.length; i++) {
      sum += (values[i] - values[i - 1]).abs();
    }
    return sum / (values.length - 1);
  }

  double _calculateMeanAbsSecondDiff(List<double> values) {
    if (values.length < 3) return 0.0;
    double sum = 0.0;
    for (int i = 2; i < values.length; i++) {
      sum += (values[i] - 2 * values[i - 1] + values[i - 2]).abs();
    }
    return sum / (values.length - 2);
  }

  double _calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;
    final double mean = values.reduce((a, b) => a + b) / values.length;
    final double variance =
        values.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) /
        values.length;
    return sqrt(variance);
  }

  Map<String, dynamic> _makePrediction() {
    try {
      // Get the last sequence_length frames
      final List<List<double>> recentKeypoints = _keypointBuffer.sublist(
        _keypointBuffer.length - _sequenceLength,
      );
      final List<List<double>> recentEnhanced = _enhancedFeatureBuffer.sublist(
        _enhancedFeatureBuffer.length - _sequenceLength,
      );

      // Normalize keypoints
      final List<double> normalizedKeypoints = _normalizeSequence(
        recentKeypoints,
      );

      // Calculate temporal features
      final List<double> temporalFeatures = _calculateTemporalFeatures(
        recentKeypoints,
        recentEnhanced,
      );

      // Prepare inputs
      final Float32List keypointsInput = Float32List.fromList(
        normalizedKeypoints,
      );
      final Float32List enhancedInput = Float32List.fromList(
        recentEnhanced.expand((x) => x).toList(),
      );
      final Float32List temporalInput = Float32List.fromList(temporalFeatures);

      // Reshape inputs for the model
      final keypointsData = keypointsInput.buffer.asFloat32List().reshape([
        1,
        _sequenceLength,
        99,
      ]); // 33 joints * 3 values
      final enhancedData = enhancedInput.buffer.asFloat32List().reshape([
        1,
        _sequenceLength,
        32,
      ]);
      final temporalData = temporalInput.buffer.asFloat32List().reshape([
        1,
        temporalFeatures.length,
      ]);

      // Prepare output
      final output = Float32List(
        exerciseNames.length,
      ).reshape([1, exerciseNames.length]);

      // Run inference
      _interpreter!.runForMultipleInputs(
        [keypointsData, enhancedData, temporalData],
        {0: output},
      );

      // Process results
      final List<double> predictions = output[0];
      final int predictedClass = predictions.indexOf(predictions.reduce(max));
      final double confidence = predictions[predictedClass];

      return {
        'predictedClass': predictedClass,
        'predictedLabel': exerciseNames[predictedClass],
        'confidence': confidence,
        'allPredictions': predictions,
      };
    } catch (e) {
      print('Prediction error: $e');
      return {};
    }
  }

  void clearBuffer() {
    _keypointBuffer.clear();
    _enhancedFeatureBuffer.clear();
  }

  void dispose() {
    _interpreter?.close();
    _poseDetector.close();
  }
}
