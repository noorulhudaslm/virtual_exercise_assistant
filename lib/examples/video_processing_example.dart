import 'package:flutter/material.dart';
import '../services/video_processor.dart';
import '../utils/video_frame_extractor.dart';

/// Example usage of the video processing functionality
class VideoProcessingExample {
  /// Example 1: Basic video processing with default settings
  static Future<void> basicVideoProcessing(String videoPath) async {
    final processor = VideoProcessor();

    try {
      await processor.initialize();

      final results = await processor.processVideoFromPath(
        videoPath,
        onStatusUpdate: (status) {
          print('Status: $status');
        },
      );

      print('Processing completed! Found ${results.length} results.');

      // Get exercise summary
      final summary = processor.getExerciseSummary(results);
      print('Exercise Summary: $summary');
    } catch (e) {
      print('Error: $e');
    } finally {
      await processor.cleanup();
    }
  }

  /// Example 2: Video processing with form detection enabled
  static Future<void> videoProcessingWithFormDetection(String videoPath) async {
    final processor = VideoProcessor();

    try {
      await processor.initialize();

      // Listen to real-time results
      processor.resultsStream.listen((result) {
        print(
          'Frame ${result.frameNumber}: ${result.exerciseName} (${(result.confidence * 100).toStringAsFixed(1)}%)',
        );
        if (result.formFeedback != null) {
          print('  Form: ${result.formFeedback}');
        }
      });

      // Listen to progress updates
      processor.progressStream.listen((progress) {
        print('Progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      final results = await processor.processVideoFromPath(
        videoPath,
        useFormDetection: true,
        onStatusUpdate: (status) {
          print('Status: $status');
        },
      );

      print('Processing completed! Found ${results.length} results.');
    } catch (e) {
      print('Error: $e');
    } finally {
      await processor.cleanup();
    }
  }

  /// Example 3: Custom frame extraction with specific settings
  static Future<void> customFrameExtraction(String videoPath) async {
    try {
      // Extract frames with custom settings
      final framePaths = await VideoFrameExtractor.extractFrames(
        videoPath: videoPath,
        targetFPS: 5, // Extract 5 frames per second
        maxWidth: 480, // Smaller frames for faster processing
        maxHeight: 360,
        onProgress: (status) {
          print('Extraction: $status');
        },
        onFrameExtracted: (frameCount) {
          print('Extracted frame $frameCount');
        },
      );

      print('Extracted ${framePaths.length} frames');

      // Process frames in batches
      final frames = await VideoFrameExtractor.loadFramesInBatches(
        framePaths: framePaths,
        batchSize: 20,
        onBatchLoaded: (totalFrames) {
          print('Loaded $totalFrames frames so far');
        },
      );

      print('Loaded ${frames.length} frames total');

      // Clean up temporary files
      await VideoFrameExtractor.cleanupFrames(framePaths);
    } catch (e) {
      print('Error: $e');
    }
  }

  /// Example 4: Video validation and information
  static Future<void> videoValidation(String videoPath) async {
    try {
      // Validate video file
      final isValid = await VideoFrameExtractor.isValidVideoFile(videoPath);
      print('Video is valid: $isValid');

      if (isValid) {
        // Get video file size
        final fileSize = await VideoFrameExtractor.getVideoFileSize(videoPath);
        print('Video file size: ${fileSize.toStringAsFixed(2)} MB');

        // Get video information
        final videoInfo = await VideoFrameExtractor.getVideoInfo(videoPath);
        print('Video info: $videoInfo');

        // Estimate processing time
        final duration = videoInfo['duration'] as double;
        final estimatedTime = VideoFrameExtractor.estimateProcessingTime(
          duration,
          VideoFrameExtractor.defaultTargetFPS,
        );
        print('Estimated processing time: ${estimatedTime.inSeconds} seconds');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  /// Example 5: Processing with cancellation
  static Future<void> cancellableProcessing(String videoPath) async {
    final processor = VideoProcessor();

    try {
      await processor.initialize();

      // Start processing in background
      final processingFuture = processor.processVideoFromPath(
        videoPath,
        onStatusUpdate: (status) {
          print('Status: $status');
        },
      );

      // Simulate cancellation after 5 seconds
      await Future.delayed(const Duration(seconds: 5));

      if (processor.isProcessing) {
        print('Cancelling processing...');
        processor.cancelProcessing();
      }

      // Wait for processing to complete (will be cancelled)
      final results = await processingFuture;
      print('Processing completed with ${results.length} results');
    } catch (e) {
      print('Error: $e');
    } finally {
      await processor.cleanup();
    }
  }
}

/// Example widget that demonstrates video processing UI
class VideoProcessingExampleWidget extends StatefulWidget {
  const VideoProcessingExampleWidget({super.key});

  @override
  State<VideoProcessingExampleWidget> createState() =>
      _VideoProcessingExampleWidgetState();
}

class _VideoProcessingExampleWidgetState
    extends State<VideoProcessingExampleWidget> {
  final List<String> _logMessages = [];
  bool _isProcessing = false;

  void _addLog(String message) {
    setState(() {
      _logMessages.add(
        '${DateTime.now().toString().substring(11, 19)}: $message',
      );
      if (_logMessages.length > 50) {
        _logMessages.removeAt(0);
      }
    });
  }

  Future<void> _runExample(
    String videoPath,
    Future<void> Function(String) example,
  ) async {
    setState(() {
      _isProcessing = true;
      _logMessages.clear();
    });

    try {
      _addLog('Starting example...');
      await example(videoPath);
      _addLog('Example completed successfully');
    } catch (e) {
      _addLog('Error: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Processing Examples'),
        backgroundColor: const Color(0xFF5494DD),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Example buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          // Replace with actual video path
                          _runExample(
                            '/path/to/video.mp4',
                            VideoProcessingExample.basicVideoProcessing,
                          );
                        },
                  child: const Text('Basic Processing'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          _runExample(
                            '/path/to/video.mp4',
                            VideoProcessingExample
                                .videoProcessingWithFormDetection,
                          );
                        },
                  child: const Text('With Form Detection'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          _runExample(
                            '/path/to/video.mp4',
                            VideoProcessingExample.customFrameExtraction,
                          );
                        },
                  child: const Text('Custom Frame Extraction'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          _runExample(
                            '/path/to/video.mp4',
                            VideoProcessingExample.videoValidation,
                          );
                        },
                  child: const Text('Video Validation'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          _runExample(
                            '/path/to/video.mp4',
                            VideoProcessingExample.cancellableProcessing,
                          );
                        },
                  child: const Text('Cancellable Processing'),
                ),
              ],
            ),
          ),

          // Log messages
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Log Messages',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_isProcessing)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _logMessages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _logMessages[index],
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
