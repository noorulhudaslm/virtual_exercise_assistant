import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

class VideoFrameExtractor {
  static const int defaultTargetFPS = 3;
  static const int maxFrameWidth = 640;
  static const int maxFrameHeight = 480;
  static const int maxFramesPerBatch = 50; // Process frames in batches

  /// Extract frames from video with optimized settings
  static Future<List<String>> extractFrames({
    required String videoPath,
    int targetFPS = defaultTargetFPS,
    int maxWidth = maxFrameWidth,
    int maxHeight = maxFrameHeight,
    Function(String)? onProgress,
    Function(int)? onFrameExtracted,
  }) async {
    try {
      onProgress?.call('Analyzing video...');

      // Get video information first
      final videoInfo = await getVideoInfo(videoPath);
      final duration = videoInfo['duration'] as double;
      final fps = videoInfo['fps'] as double;

      onProgress?.call(
        'Video: ${duration.toStringAsFixed(1)}s, ${fps.toStringAsFixed(1)} FPS',
      );

      // Calculate total frames to extract
      final totalFrames = (duration * targetFPS).round();
      onProgress?.call('Extracting $totalFrames frames...');

      // Create temporary directory for frames
      final tempDir = await getTemporaryDirectory();
      final framesDir = Directory(
        '${tempDir.path}/video_frames_${DateTime.now().millisecondsSinceEpoch}',
      );
      await framesDir.create(recursive: true);

      // Extract frames using FFmpeg with optimized settings
      final framePaths = await _extractFramesWithFFmpeg(
        videoPath: videoPath,
        outputDir: framesDir.path,
        targetFPS: targetFPS,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        onProgress: onProgress,
        onFrameExtracted: onFrameExtracted,
      );

      onProgress?.call('Successfully extracted ${framePaths.length} frames');
      return framePaths;
    } catch (e) {
      onProgress?.call('Error extracting frames: $e');
      rethrow;
    }
  }

  /// Get video information using FFprobe
  static Future<Map<String, dynamic>> getVideoInfo(String videoPath) async {
    try {
      final result = await FFmpegKit.execute(
        '-i "$videoPath" -v quiet -print_format json -show_format -show_streams',
      );

      final returnCode = await result.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        final output = await result.getOutput();
        if (output == null || output.isEmpty) {
          throw Exception('Failed to get video info - no output from FFmpeg');
        }
        final data = json.decode(output);

        final videoStream = data['streams'].firstWhere(
          (stream) => stream['codec_type'] == 'video',
          orElse: () => {},
        );

        return {
          'duration': double.tryParse(data['format']['duration'] ?? '0') ?? 0,
          'fps': _parseFPS(videoStream['r_frame_rate'] ?? '30/1'),
          'width': (videoStream['width'] ?? 640).toDouble(),
          'height': (videoStream['height'] ?? 480).toDouble(),
          'bitrate': data['format']['bit_rate'] ?? '0',
        };
      } else {
        throw Exception('Failed to get video info');
      }
    } catch (e) {
      print('Error getting video info: $e');
      return {
        'duration': 0,
        'fps': 30,
        'width': 640,
        'height': 480,
        'bitrate': '0',
      };
    }
  }

  /// Parse FPS string (e.g., "30/1" -> 30.0)
  static double _parseFPS(String fpsString) {
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

  /// Extract frames using FFmpeg with optimized settings
  static Future<List<String>> _extractFramesWithFFmpeg({
    required String videoPath,
    required String outputDir,
    required int targetFPS,
    required int maxWidth,
    required int maxHeight,
    Function(String)? onProgress,
    Function(int)? onFrameExtracted,
  }) async {
    try {
      // Optimized FFmpeg command for frame extraction
      final command = [
        '-i', '"$videoPath"',
        '-vf',
        'fps=$targetFPS,scale=$maxWidth:$maxHeight:force_original_aspect_ratio=decrease',
        '-frame_pts', '1',
        '-q:v', '2', // High quality
        '-y', // Overwrite output files
        '"$outputDir/frame_%04d.jpg"',
      ].join(' ');

      onProgress?.call('Running FFmpeg extraction...');

      final result = await FFmpegKit.execute(command);
      final returnCode = await result.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        final logs = await result.getLogs();
        final errorLogs = logs
            .where((log) => log.getLevel() == 'error')
            .toList();
        throw Exception(
          'FFmpeg failed: ${errorLogs.map((log) => log.getMessage()).join(', ')}',
        );
      }

      // Get list of extracted frame files
      final frameFiles =
          Directory(outputDir)
              .listSync()
              .where((file) => file.path.endsWith('.jpg'))
              .map((file) => file.path)
              .toList()
            ..sort(); // Sort by filename

      onProgress?.call('Extracted ${frameFiles.length} frames successfully');
      return frameFiles;
    } catch (e) {
      onProgress?.call('FFmpeg extraction error: $e');
      rethrow;
    }
  }

  /// Process frames in batches to avoid memory issues
  static Future<List<Uint8List>> loadFramesInBatches({
    required List<String> framePaths,
    int batchSize = maxFramesPerBatch,
    Function(int)? onBatchLoaded,
  }) async {
    final List<Uint8List> allFrames = [];

    for (int i = 0; i < framePaths.length; i += batchSize) {
      final endIndex = (i + batchSize < framePaths.length)
          ? i + batchSize
          : framePaths.length;

      final batchPaths = framePaths.sublist(i, endIndex);
      final batchFrames = await _loadFrameBatch(batchPaths);

      allFrames.addAll(batchFrames);
      onBatchLoaded?.call(allFrames.length);

      // Small delay to prevent UI blocking
      await Future.delayed(const Duration(milliseconds: 10));
    }

    return allFrames;
  }

  /// Load a batch of frames
  static Future<List<Uint8List>> _loadFrameBatch(
    List<String> framePaths,
  ) async {
    final List<Uint8List> frames = [];

    for (final path in framePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          frames.add(bytes);
        }
      } catch (e) {
        print('Error loading frame $path: $e');
        // Continue with next frame
      }
    }

    return frames;
  }

  /// Clean up temporary frame files
  static Future<void> cleanupFrames(List<String> framePaths) async {
    try {
      for (final path in framePaths) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Try to remove the directory if it's empty
      if (framePaths.isNotEmpty) {
        final dir = Directory(framePaths.first).parent;
        if (await dir.exists()) {
          final files = await dir.list().toList();
          if (files.isEmpty) {
            await dir.delete();
          }
        }
      }
    } catch (e) {
      print('Error cleaning up frames: $e');
    }
  }

  /// Get estimated processing time based on video duration
  static Duration estimateProcessingTime(double videoDuration, int targetFPS) {
    final totalFrames = (videoDuration * targetFPS).round();
    // Rough estimate: 100ms per frame for processing
    final processingTimeMs = totalFrames * 100;
    return Duration(milliseconds: processingTimeMs);
  }

  /// Validate video file
  static Future<bool> isValidVideoFile(String videoPath) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        return false;
      }

      final stat = await file.stat();
      if (stat.size == 0) {
        return false;
      }

      // Check if it's a video file by extension
      final extension = videoPath.split('.').last.toLowerCase();
      const videoExtensions = [
        'mp4',
        'avi',
        'mov',
        'mkv',
        'wmv',
        'flv',
        'webm',
      ];

      return videoExtensions.contains(extension);
    } catch (e) {
      return false;
    }
  }

  /// Get video file size in MB
  static Future<double> getVideoFileSize(String videoPath) async {
    try {
      final file = File(videoPath);
      final stat = await file.stat();
      return stat.size / (1024 * 1024); // Convert to MB
    } catch (e) {
      return 0.0;
    }
  }
}
