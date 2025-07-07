import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
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

      // Validate video file first
      if (!await isValidVideoFile(videoPath)) {
        throw Exception('Invalid video file: $videoPath');
      }

      // Get video information
      final videoInfo = await getVideoInfo(videoPath);
      final duration = videoInfo['duration'] as double;
      final fps = videoInfo['fps'] as double;

      if (duration <= 0) {
        throw Exception('Invalid video duration: $duration');
      }

      onProgress?.call(
        'Video: ${duration.toStringAsFixed(1)}s, ${fps.toStringAsFixed(1)} FPS',
      );

      // Calculate total frames to extract
      final totalFrames = (duration * targetFPS).round();
      if (totalFrames <= 0) {
        throw Exception('No frames to extract');
      }
      
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

  /// Get video information using FFprobe (fixed version)
  static Future<Map<String, dynamic>> getVideoInfo(String videoPath) async {
    try {
      print('Getting video info for: $videoPath');
      
      // Use FFprobe instead of FFmpeg for getting video information
      final result = await FFprobeKit.execute(
        '-v quiet -print_format json -show_format -show_streams "$videoPath"',
      );

      final returnCode = await result.getReturnCode();
      print('FFprobe return code: $returnCode');

      if (ReturnCode.isSuccess(returnCode)) {
        final output = await result.getOutput();
        print('FFprobe output length: ${output?.length ?? 0}');
        
        if (output == null || output.isEmpty) {
          throw Exception('Failed to get video info - no output from FFprobe');
        }

        try {
          final data = json.decode(output);
          
          // Find video stream
          final streams = data['streams'] as List?;
          if (streams == null || streams.isEmpty) {
            throw Exception('No streams found in video');
          }

          final videoStream = streams.firstWhere(
            (stream) => stream['codec_type'] == 'video',
            orElse: () => null,
          );

          if (videoStream == null) {
            throw Exception('No video stream found');
          }

          final format = data['format'] as Map<String, dynamic>?;
          if (format == null) {
            throw Exception('No format information found');
          }

          final duration = double.tryParse(format['duration']?.toString() ?? '0') ?? 0;
          final fps = _parseFPS(videoStream['r_frame_rate']?.toString() ?? '30/1');

          return {
            'duration': duration,
            'fps': fps,
            'width': (videoStream['width'] ?? 640).toDouble(),
            'height': (videoStream['height'] ?? 480).toDouble(),
            'bitrate': format['bit_rate']?.toString() ?? '0',
            'codec': videoStream['codec_name']?.toString() ?? 'unknown',
          };
        } catch (e) {
          print('Error parsing FFprobe output: $e');
          throw Exception('Failed to parse video information: $e');
        }
      } else {
        // Get error logs
        final logs = await result.getLogs();
        final errorMessages = logs
            .where((log) => log.getLevel() == 'error')
            .map((log) => log.getMessage())
            .join(', ');
        
        print('FFprobe failed with return code: $returnCode');
        print('FFprobe errors: $errorMessages');
        
        throw Exception('FFprobe failed: $errorMessages');
      }
    } catch (e) {
      print('Error getting video info: $e');
      
      // Return default values as fallback
      return {
        'duration': 30.0, // Default 30 seconds
        'fps': 30.0,
        'width': 640.0,
        'height': 480.0,
        'bitrate': '0',
        'codec': 'unknown',
      };
    }
  }

  /// Parse FPS string (e.g., "30/1" -> 30.0)
  static double _parseFPS(String fpsString) {
    try {
      if (fpsString.contains('/')) {
        final parts = fpsString.split('/');
        if (parts.length == 2) {
          final num = double.parse(parts[0]);
          final den = double.parse(parts[1]);
          if (den != 0) {
            return num / den;
          }
        }
      }
      return double.parse(fpsString);
    } catch (e) {
      print('Error parsing FPS: $fpsString, error: $e');
      return 30.0; // Default FPS
    }
  }

  /// Extract frames using FFmpeg with optimized settings (fixed version)
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
      // Ensure output directory exists
      final dir = Directory(outputDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      onProgress?.call('Running FFmpeg extraction...');

      // Build FFmpeg command with proper escaping
      final outputPattern = '$outputDir/frame_%04d.jpg';
      
      final command = [
        '-i', videoPath,
        '-vf', 'fps=$targetFPS,scale=$maxWidth:$maxHeight:force_original_aspect_ratio=decrease',
        '-q:v', '2', // High quality
        '-y', // Overwrite output files
        outputPattern,
      ];

      print('FFmpeg command: ${command.join(' ')}');

      final result = await FFmpegKit.executeWithArguments(command);
      final returnCode = await result.getReturnCode();

      print('FFmpeg extraction return code: $returnCode');

      if (!ReturnCode.isSuccess(returnCode)) {
        final logs = await result.getLogs();
        final errorLogs = logs
            .where((log) => log.getLevel() == 'error')
            .map((log) => log.getMessage())
            .toList();
        
        print('FFmpeg extraction errors: ${errorLogs.join(', ')}');
        throw Exception('FFmpeg extraction failed: ${errorLogs.join(', ')}');
      }

      // Get list of extracted frame files
      final frameFiles = await _getExtractedFrames(outputDir);
      
      // Notify about extracted frames
      for (int i = 0; i < frameFiles.length; i++) {
        onFrameExtracted?.call(i + 1);
      }

      onProgress?.call('Extracted ${frameFiles.length} frames successfully');
      return frameFiles;
    } catch (e) {
      onProgress?.call('FFmpeg extraction error: $e');
      rethrow;
    }
  }

  /// Get list of extracted frame files
  static Future<List<String>> _getExtractedFrames(String outputDir) async {
    try {
      final directory = Directory(outputDir);
      if (!await directory.exists()) {
        return [];
      }

      final files = await directory.list().toList();
      final frameFiles = files
          .where((file) => file is File && file.path.endsWith('.jpg'))
          .map((file) => file.path)
          .toList();

      // Sort by filename to maintain order
      frameFiles.sort((a, b) {
        final aNum = _extractFrameNumber(a);
        final bNum = _extractFrameNumber(b);
        return aNum.compareTo(bNum);
      });

      return frameFiles;
    } catch (e) {
      print('Error getting extracted frames: $e');
      return [];
    }
  }

  /// Extract frame number from filename for sorting
  static int _extractFrameNumber(String filename) {
    try {
      final RegExp regExp = RegExp(r'frame_(\d+)\.jpg');
      final match = regExp.firstMatch(filename);
      if (match != null) {
        return int.parse(match.group(1)!);
      }
    } catch (e) {
      print('Error extracting frame number from $filename: $e');
    }
    return 0;
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
          
          // Validate that it's a valid image
          if (bytes.isNotEmpty) {
            frames.add(bytes);
          } else {
            print('Warning: Empty frame file: $path');
          }
        } else {
          print('Warning: Frame file not found: $path');
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
    // Rough estimate: 150ms per frame for processing (including extraction and analysis)
    final processingTimeMs = totalFrames * 150;
    return Duration(milliseconds: processingTimeMs);
  }

  /// Validate video file (improved version)
  static Future<bool> isValidVideoFile(String videoPath) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        print('Video file does not exist: $videoPath');
        return false;
      }

      final stat = await file.stat();
      if (stat.size == 0) {
        print('Video file is empty: $videoPath');
        return false;
      }

      // Check file size (minimum 1KB)
      if (stat.size < 1024) {
        print('Video file too small: ${stat.size} bytes');
        return false;
      }

      // Check if it's a video file by extension
      final extension = videoPath.split('.').last.toLowerCase();
      const videoExtensions = [
        'mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv', 'webm', 'm4v', '3gp',
      ];

      if (!videoExtensions.contains(extension)) {
        print('Unsupported video extension: $extension');
        return false;
      }

      return true;
    } catch (e) {
      print('Error validating video file: $e');
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
      print('Error getting video file size: $e');
      return 0.0;
    }
  }

  /// Test FFmpeg installation
  static Future<bool> testFFmpegInstallation() async {
    try {
      final result = await FFmpegKit.execute('-version');
      final returnCode = await result.getReturnCode();
      return ReturnCode.isSuccess(returnCode);
    } catch (e) {
      print('Error testing FFmpeg installation: $e');
      return false;
    }
  }

  /// Get FFmpeg version info
  static Future<String> getFFmpegVersion() async {
    try {
      final result = await FFmpegKit.execute('-version');
      final output = await result.getOutput();
      if (output != null && output.isNotEmpty) {
        final lines = output.split('\n');
        if (lines.isNotEmpty) {
          return lines.first;
        }
      }
      return 'Unknown version';
    } catch (e) {
      print('Error getting FFmpeg version: $e');
      return 'Error getting version';
    }
  }
}