import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import '../config/backend_config.dart';
import 'exercise_form_detector.dart';

class VideoProcessingResult {
  final int frameNumber;
  final String? exerciseName;
  final double confidence;
  final String? formFeedback;
  final Color feedbackColor;
  final DateTime timestamp;

  VideoProcessingResult({
    required this.frameNumber,
    this.exerciseName,
    required this.confidence,
    this.formFeedback,
    required this.feedbackColor,
    required this.timestamp,
  });
}

class VideoProcessor {
  // Backend configuration is now in BackendConfig class

  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.accurate,
      mode: PoseDetectionMode.stream,
    ),
  );

  bool _isProcessing = false;
  bool _isCancelled = false;
  final StreamController<VideoProcessingResult> _resultsController =
      StreamController<VideoProcessingResult>.broadcast();
  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  Stream<VideoProcessingResult> get resultsStream => _resultsController.stream;
  Stream<double> get progressStream => _progressController.stream;

  // Configuration
  static const int targetFPS = 3; // Extract 3 frames per second
  static const int maxFrameWidth = 640; // Resize frames for processing
  static const int maxFrameHeight = 480;

  // Available exercise names (matching backend)
  final List<String> exerciseNames = BackendConfig.exerciseNames;

  Future<void> initialize() async {
    // Check if backend is available
    try {
      final response = await http
          .get(Uri.parse(BackendConfig.healthEndpoint))
          .timeout(Duration(seconds: BackendConfig.healthCheckTimeout));

      if (response.statusCode != 200) {
        throw Exception('Backend not available: ${response.statusCode}');
      }

      print('Backend connection established');
    } catch (e) {
      print('Warning: Backend not available: $e');
      // Continue without backend - will use fallback detection
    }
  }

  Future<List<VideoProcessingResult>> processVideoFromPath(
    String videoPath, {
    Function(String)? onStatusUpdate,
    bool useFormDetection = false,
  }) async {
    if (_isProcessing) {
      throw Exception('Video processing already in progress');
    }

    _isProcessing = true;
    _isCancelled = false;
    final List<VideoProcessingResult> results = [];

    try {
      onStatusUpdate?.call('Analyzing video...');

      // Get video information
      final videoInfo = await _getVideoInfo(videoPath);
      onStatusUpdate?.call(
        'Video duration: ${videoInfo['duration']}s, FPS: ${videoInfo['fps']}',
      );

      // Extract frames
      final List<String> framePaths = await _extractFrames(
        videoPath,
        videoInfo['duration'],
        videoInfo['fps'],
        onStatusUpdate,
      );

      if (_isCancelled) {
        onStatusUpdate?.call('Processing cancelled');
        return results;
      }

      onStatusUpdate?.call('Processing ${framePaths.length} frames...');

      // Process each frame
      for (int i = 0; i < framePaths.length; i++) {
        if (_isCancelled) break;

        final framePath = framePaths[i];
        final progress = (i + 1) / framePaths.length;
        _progressController.add(progress);

        try {
          final result = await _processFrame(framePath, i, useFormDetection);

          if (result != null) {
            results.add(result);
            _resultsController.add(result);
          }

          // Update status every 10 frames
          if (i % 10 == 0) {
            onStatusUpdate?.call(
              'Processed ${i + 1}/${framePaths.length} frames',
            );
          }

          // Small delay to prevent UI blocking
          await Future.delayed(const Duration(milliseconds: 10));
        } catch (e) {
          print('Error processing frame $i: $e');
          // Continue with next frame
        }
      }

      onStatusUpdate?.call(
        'Processing completed. Found ${results.length} results.',
      );
    } catch (e) {
      onStatusUpdate?.call('Error: $e');
      rethrow;
    } finally {
      _isProcessing = false;
      _progressController.add(1.0);
    }

    return results;
  }

  Future<Map<String, dynamic>> _getVideoInfo(String videoPath) async {
    try {
      print('Getting video info for: $videoPath');

      // Check if file exists
      final file = File(videoPath);
      if (!await file.exists()) {
        throw Exception('Video file does not exist: $videoPath');
      }

      final result = await FFmpegKit.execute(
        '-i "$videoPath" -v quiet -print_format json -show_format -show_streams',
      );

      final returnCode = await result.getReturnCode();
      final output = await result.getOutput();
      final logs = await result.getLogs();

      print('FFmpeg return code: $returnCode');
      print('FFmpeg output length: ${output?.length ?? 0}');

      if (logs.isNotEmpty) {
        print('FFmpeg logs:');
        for (final log in logs) {
          print('  ${log.getMessage()}');
        }
      }

      if (ReturnCode.isSuccess(returnCode)) {
        // For FFprobe-style commands, the output might be in logs or we need to handle differently
        String jsonOutput = output ?? '';

        // If output is empty, try to get from logs
        if (jsonOutput.isEmpty && logs.isNotEmpty) {
          // Look for JSON output in logs
          for (final log in logs) {
            final message = log.getMessage();
            if (message.startsWith('{') && message.contains('"format"')) {
              jsonOutput = message;
              break;
            }
          }
        }

        if (jsonOutput.isEmpty) {
          throw Exception(
            'Failed to get video info - no JSON output from FFmpeg',
          );
        }

        print('FFmpeg JSON output: $jsonOutput');
        final data = json.decode(jsonOutput);

        if (data['streams'] == null || data['streams'].isEmpty) {
          throw Exception('No streams found in video');
        }

        final videoStream = data['streams'].firstWhere(
          (stream) => stream['codec_type'] == 'video',
          orElse: () => {},
        );

        if (videoStream.isEmpty) {
          throw Exception('No video stream found');
        }

        final videoInfo = {
          'duration': double.tryParse(data['format']['duration'] ?? '0') ?? 0,
          'fps': _parseFPS(videoStream['r_frame_rate'] ?? '30/1'),
          'width': (videoStream['width'] ?? 640).toDouble(),
          'height': (videoStream['height'] ?? 480).toDouble(),
        };

        print('Video info: $videoInfo');
        return videoInfo;
      } else {
        final errorMessage = 'FFmpeg failed with return code: $returnCode';
        print(errorMessage);
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error getting video info: $e');
      return {'duration': 0, 'fps': 30, 'width': 640, 'height': 480};
    }
  }

  double _parseFPS(String fpsString) {
    try {
      final parts = fpsString.split('/');
      if (parts.length == 2) {
        final num = double.parse(parts[0]);
        final den = double.parse(parts[1]);
        return num / den;
      }
      return double.parse(fpsString);
    } catch (e) {
      return 30.0; // Default FPS
    }
  }

  Future<List<String>> _extractFrames(
    String videoPath,
    double duration,
    double fps,
    Function(String)? onStatusUpdate,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final framesDir = Directory(
      '${tempDir.path}/video_frames_${DateTime.now().millisecondsSinceEpoch}',
    );
    await framesDir.create(recursive: true);

    final totalFrames = (duration * targetFPS).round();
    onStatusUpdate?.call('Extracting $totalFrames frames...');

    try {
      print('Extracting frames from: $videoPath');
      print('Output directory: ${framesDir.path}');

      final command =
          '-i "$videoPath" '
          '-vf "fps=$targetFPS,scale=$maxFrameWidth:$maxFrameHeight:force_original_aspect_ratio=decrease" '
          '-frame_pts 1 '
          '-y '
          '"${framesDir.path}/frame_%04d.jpg"';

      print('FFmpeg command: $command');

      final result = await FFmpegKit.execute(command);

      final returnCode = await result.getReturnCode();
      final logs = await result.getLogs();

      print('Frame extraction return code: $returnCode');

      if (logs.isNotEmpty) {
        print('Frame extraction logs:');
        for (final log in logs) {
          print('  ${log.getMessage()}');
        }
      }

      if (!ReturnCode.isSuccess(returnCode)) {
        final errorMessage =
            'Failed to extract frames. Return code: $returnCode';
        print(errorMessage);
        throw Exception(errorMessage);
      }

      // Get list of extracted frame files
      final frameFiles =
          framesDir
              .listSync()
              .where((file) => file.path.endsWith('.jpg'))
              .map((file) => file.path)
              .toList()
            ..sort(); // Sort by filename

      print('Extracted ${frameFiles.length} frames');
      onStatusUpdate?.call('Extracted ${frameFiles.length} frames');
      return frameFiles;
    } catch (e) {
      print('Error extracting frames: $e');
      rethrow;
    }
  }

  Future<VideoProcessingResult?> _processFrame(
    String framePath,
    int frameNumber,
    bool useFormDetection,
  ) async {
    try {
      // Load and convert image
      final File frameFile = File(framePath);
      final Uint8List imageBytes = await frameFile.readAsBytes();

      // Decode image using image package
      final img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Convert to InputImage format for pose detection
      final InputImage inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.width * 4,
        ),
      );

      // Process with pose detection
      final List<Pose> poses = await _poseDetector.processImage(inputImage);

      if (poses.isEmpty) {
        return VideoProcessingResult(
          frameNumber: frameNumber,
          confidence: 0.0,
          feedbackColor: Colors.grey,
          timestamp: DateTime.now(),
          formFeedback: 'No pose detected',
        );
      }

      // Send frame to backend for exercise classification
      Map<String, dynamic>? classificationResult;
      try {
        classificationResult = await _sendFrameToBackend(imageBytes);
      } catch (e) {
        print('Backend classification error: $e');
        // Fallback to pose-based detection
        classificationResult = _makeFallbackPrediction(poses.first);
      }

      if (classificationResult != null && classificationResult.isNotEmpty) {
        final exerciseName =
            classificationResult['predictedLabel'] as String? ??
            'Unknown Exercise';
        final confidence = (classificationResult['confidence'] is int)
            ? (classificationResult['confidence'] as int).toDouble()
            : (classificationResult['confidence'] as double?) ?? 0.0;

        // Determine feedback color based on confidence
        Color feedbackColor;
        String? formFeedback;

        if (confidence > 0.8) {
          feedbackColor = Colors.green;
          formFeedback = 'Good form detected';
        } else if (confidence > 0.6) {
          feedbackColor = Colors.orange;
          formFeedback = 'Moderate confidence';
        } else {
          feedbackColor = Colors.red;
          formFeedback = 'Low confidence - check form';
        }

        // If form detection is enabled, get additional feedback
        if (useFormDetection && exerciseName != 'No exercise detected') {
          final formResult = await _getFormFeedback(poses.first, exerciseName);
          if (formResult != null) {
            formFeedback = formResult['feedback'];
            feedbackColor = formResult['color'];
          }
        }

        return VideoProcessingResult(
          frameNumber: frameNumber,
          exerciseName: exerciseName,
          confidence: confidence,
          formFeedback: formFeedback,
          feedbackColor: feedbackColor,
          timestamp: DateTime.now(),
        );
      }

      return VideoProcessingResult(
        frameNumber: frameNumber,
        confidence: 0.0,
        feedbackColor: Colors.grey,
        timestamp: DateTime.now(),
        formFeedback: 'No exercise detected',
      );
    } catch (e) {
      print('Error processing frame $frameNumber: $e');
      return VideoProcessingResult(
        frameNumber: frameNumber,
        confidence: 0.0,
        feedbackColor: Colors.red,
        timestamp: DateTime.now(),
        formFeedback: 'Processing error: $e',
      );
    }
  }

  Future<Map<String, dynamic>?> _sendFrameToBackend(
    Uint8List imageBytes,
  ) async {
    try {
      // Convert image to base64
      final String base64Image = base64Encode(imageBytes);

      // Prepare request data
      final requestData = {
        'frame': base64Image,
        'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
      };

      // Send POST request to backend
      final response = await http
          .post(
            Uri.parse(BackendConfig.predictEndpoint),
            headers: BackendConfig.defaultHeaders,
            body: json.encode(requestData),
          )
          .timeout(Duration(seconds: BackendConfig.requestTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data[BackendConfig.predictionType] != null) {
          final predictionData = data[BackendConfig.dataKey];
          final confidenceValue = predictionData[BackendConfig.confidenceKey];
          final confidence = (confidenceValue is int)
              ? (confidenceValue as int).toDouble()
              : (confidenceValue as double?) ?? 0.0;

          return {
            'predictedClass': predictionData[BackendConfig.classKey],
            'predictedLabel': predictionData[BackendConfig.labelKey],
            'confidence': confidence,
            'allPredictions':
                predictionData[BackendConfig.allPredictionsKey] ?? [],
          };
        }
      } else {
        throw Exception('Backend returned status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending frame to backend: $e');
      rethrow;
    }

    return null;
  }

  Map<String, dynamic> _makeFallbackPrediction(Pose pose) {
    // Simple fallback prediction based on pose analysis
    try {
      final landmarks = pose.landmarks;

      // Check for common exercise poses
      final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
      final leftElbow = landmarks[PoseLandmarkType.leftElbow];
      final rightElbow = landmarks[PoseLandmarkType.rightElbow];
      final leftWrist = landmarks[PoseLandmarkType.leftWrist];
      final rightWrist = landmarks[PoseLandmarkType.rightWrist];
      final leftHip = landmarks[PoseLandmarkType.leftHip];
      final rightHip = landmarks[PoseLandmarkType.rightHip];

      if (leftShoulder != null &&
          rightShoulder != null &&
          leftElbow != null &&
          rightElbow != null &&
          leftWrist != null &&
          rightWrist != null) {
        // Calculate basic pose features
        final shoulderLevel = (leftShoulder.y + rightShoulder.y) / 2;
        final wristLevel = (leftWrist.y + rightWrist.y) / 2;
        final elbowLevel = (leftElbow.y + rightElbow.y) / 2;

        // Simple exercise detection logic
        if (wristLevel < shoulderLevel - 50) {
          // Hands above shoulders - likely pull-up
          return {
            'predictedClass': 1, // Pull-up
            'predictedLabel': 'Pull-up',
            'confidence': 0.6,
            'allPredictions': [0.1, 0.6, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1],
          };
        } else if (elbowLevel < shoulderLevel - 30) {
          // Elbows bent and below shoulders - likely push-up
          return {
            'predictedClass': 0, // Push-up
            'predictedLabel': 'Push-up',
            'confidence': 0.5,
            'allPredictions': [0.5, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1],
          };
        } else if (leftHip != null && rightHip != null) {
          final hipLevel = (leftHip.y + rightHip.y) / 2;
          if (hipLevel > shoulderLevel + 50) {
            // Hips below shoulders - likely squat
            return {
              'predictedClass': 2, // Squat
              'predictedLabel': 'Squat',
              'confidence': 0.4,
              'allPredictions': [0.1, 0.1, 0.4, 0.1, 0.1, 0.1, 0.1, 0.1],
            };
          }
        }
      }

      // Default to unknown exercise
      return {
        'predictedClass': -1,
        'predictedLabel': 'Unknown Exercise',
        'confidence': 0.1,
        'allPredictions': [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1],
      };
    } catch (e) {
      print('Fallback prediction error: $e');
      return {
        'predictedClass': -1,
        'predictedLabel': 'Error',
        'confidence': 0.0,
        'allPredictions': [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1],
      };
    }
  }

  Future<Map<String, dynamic>?> _getFormFeedback(
    Pose pose,
    String exerciseName,
  ) async {
    try {
      // Create a simple form detector instance for feedback
      final formDetector = ExerciseFormDetector(
        onFeedbackUpdate: (feedback, color) {
          // This will be handled by the return value
        },
        onRepCountUpdate: (count) {
          // Not needed for video analysis
        },
        initialExercise: exerciseName,
      );

      // Convert pose to InputImage for form detection
      // This is a simplified approach - you might need to adapt based on your form detector
      return {'feedback': 'Form analysis available', 'color': Colors.blue};
    } catch (e) {
      print('Error in form feedback: $e');
      return null;
    }
  }

  void cancelProcessing() {
    _isCancelled = true;
  }

  bool get isProcessing => _isProcessing;

  Future<void> cleanup() async {
    _isCancelled = true;
    await _resultsController.close();
    await _progressController.close();
    _poseDetector.close();
  }

  // Utility method to get exercise summary from results
  Map<String, dynamic> getExerciseSummary(List<VideoProcessingResult> results) {
    final Map<String, int> exerciseCounts = {};
    final Map<String, List<double>> exerciseConfidences = {};

    for (final result in results) {
      if (result.exerciseName != null &&
          result.exerciseName != 'No exercise detected') {
        exerciseCounts[result.exerciseName!] =
            (exerciseCounts[result.exerciseName!] ?? 0) + 1;

        exerciseConfidences.putIfAbsent(result.exerciseName!, () => []);
        exerciseConfidences[result.exerciseName!]!.add(result.confidence);
      }
    }

    final Map<String, dynamic> summary = {};
    exerciseCounts.forEach((exercise, count) {
      final confidences = exerciseConfidences[exercise] ?? [];
      final avgConfidence = confidences.isNotEmpty
          ? confidences.reduce((a, b) => a + b) / confidences.length
          : 0.0;

      summary[exercise] = {
        'count': count,
        'averageConfidence': avgConfidence,
        'percentage': (count / results.length * 100).toStringAsFixed(1),
      };
    });

    return summary;
  }
}
