# Video Processing for Exercise Analysis

This document explains how to use the video processing functionality to analyze exercise videos using FFmpeg and your existing pose detection and exercise classification system.

## Overview

The video processing system allows you to:
1. Select videos from the device gallery
2. Extract frames using FFmpeg
3. Process each frame through pose detection and send to backend for exercise classification
4. Display results in a scrollable list with confidence scores and form feedback
5. Fallback to local pose-based detection if backend is unavailable

## Features

- **Frame Extraction**: Uses FFmpeg to extract frames at configurable FPS (default: 3 FPS)
- **Pose Detection**: Processes each frame through Google ML Kit pose detection
- **Exercise Classification**: Sends frames to your backend API for exercise recognition
- **Fallback Detection**: Uses local pose analysis when backend is unavailable
- **Form Analysis**: Optional form detection for detailed feedback
- **Real-time Progress**: Shows processing progress and status updates
- **Results Summary**: Provides exercise statistics and confidence scores
- **Performance Optimized**: Processes frames in batches to avoid memory issues

## Setup

### 1. Dependencies

Add these dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  ffmpeg_kit_flutter: ^6.0.3
  image_picker: ^1.0.7
  video_thumbnail: ^0.5.3
  image: ^4.1.7
```

### 2. Backend Configuration

Update the backend URLs in `lib/config/backend_config.dart`:

```dart
class BackendConfig {
  // Update these with your actual backend endpoints
  static const String baseUrl = 'http://your-backend-url:port';
  static const String predictEndpoint = '$baseUrl/predict';
  static const String healthEndpoint = '$baseUrl/health';
  
  // WebSocket URL (if using WebSocket for real-time processing)
  static const String wsUrl = 'ws://your-websocket-url:port';
}
```

### 3. Permissions

Add these permissions to your Android manifest (`android/app/src/main/AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.INTERNET" />
```

For iOS, add to `ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to photo library to select exercise videos.</string>
```

## Usage

### Basic Usage

1. **Navigate to Video Analysis**: 
   - Go to the exercise list screen
   - Tap on "Video Analysis" option

2. **Select Video**:
   - Tap "Select Video" button
   - Choose a video from your gallery
   - Videos are limited to 10 minutes for performance

3. **Start Analysis**:
   - Tap "Analyze" button
   - Watch the progress indicator
   - View real-time results as they appear

4. **View Results**:
   - Scroll through the list of processed frames
   - Each result shows:
     - Frame number
     - Detected exercise
     - Confidence score
     - Form feedback (if enabled)
     - Color-coded confidence levels

### Programmatic Usage

```dart
import 'package:your_app/services/video_processor.dart';

// Initialize the processor (checks backend availability)
final processor = VideoProcessor();
await processor.initialize();

// Process a video
final results = await processor.processVideoFromPath(
  '/path/to/video.mp4',
  onStatusUpdate: (status) {
    print('Status: $status');
  },
  useFormDetection: true,
);

// Get exercise summary
final summary = processor.getExerciseSummary(results);
print('Summary: $summary');

// Clean up
await processor.cleanup();
```

**Backend Integration:**
- Frames are sent to your backend API for exercise classification
- If backend is unavailable, falls back to local pose-based detection
- Supports both HTTP POST and WebSocket communication

### Advanced Configuration

#### Custom Frame Extraction

```dart
import 'package:your_app/utils/video_frame_extractor.dart';

final framePaths = await VideoFrameExtractor.extractFrames(
  videoPath: '/path/to/video.mp4',
  targetFPS: 5, // Extract 5 frames per second
  maxWidth: 480, // Resize to 480px width
  maxHeight: 360, // Resize to 360px height
  onProgress: (status) {
    print('Extraction: $status');
  },
);
```

#### Real-time Results Streaming

```dart
// Listen to results as they come in
processor.resultsStream.listen((result) {
  print('Frame ${result.frameNumber}: ${result.exerciseName}');
  print('Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%');
  if (result.formFeedback != null) {
    print('Form: ${result.formFeedback}');
  }
});

// Listen to progress updates
processor.progressStream.listen((progress) {
  print('Progress: ${(progress * 100).toStringAsFixed(1)}%');
});
```

#### Cancellable Processing

```dart
// Start processing
final processingFuture = processor.processVideoFromPath(videoPath);

// Cancel after some time
await Future.delayed(const Duration(seconds: 5));
processor.cancelProcessing();

// Wait for completion (will be cancelled)
final results = await processingFuture;
```

## Performance Tips

### 1. Frame Rate Optimization

- **Default**: 3 FPS is good for most exercises
- **High-speed exercises**: Use 5-10 FPS
- **Slow exercises**: Use 1-2 FPS
- **Memory constrained**: Use 1 FPS

### 2. Frame Size Optimization

- **Default**: 640x480 is balanced for speed and accuracy
- **Fast processing**: Use 320x240
- **High accuracy**: Use 1280x720
- **Memory constrained**: Use 320x240

### 3. Batch Processing

The system automatically processes frames in batches to prevent memory issues:

```dart
// Process frames in batches of 20
final frames = await VideoFrameExtractor.loadFramesInBatches(
  framePaths: framePaths,
  batchSize: 20,
);
```

### 4. Video Length Limits

- **Recommended**: 1-5 minutes for best performance
- **Maximum**: 10 minutes (enforced by UI)
- **Very long videos**: Consider splitting into segments

## Error Handling

### Common Issues

1. **FFmpeg not available**:
   - Ensure `ffmpeg_kit_flutter` is properly installed
   - Check platform-specific setup

2. **Permission denied**:
   - Request storage permissions before selecting video
   - Handle permission denial gracefully

3. **Video format not supported**:
   - Supported formats: MP4, AVI, MOV, MKV, WMV, FLV, WebM
   - Convert unsupported formats using FFmpeg

4. **Memory issues**:
   - Reduce frame rate or frame size
   - Process shorter videos
   - Use batch processing

### Error Recovery

```dart
try {
  final results = await processor.processVideoFromPath(videoPath);
  // Handle success
} catch (e) {
  if (e.toString().contains('FFmpeg')) {
    // Handle FFmpeg errors
    print('FFmpeg error: $e');
  } else if (e.toString().contains('permission')) {
    // Handle permission errors
    print('Permission error: $e');
  } else {
    // Handle other errors
    print('General error: $e');
  }
}
```

## Integration with Existing Code

### Using with Exercise Classifier

The video processor uses your existing `ExerciseClassifier`:

```dart
// The processor automatically initializes the classifier
final processor = VideoProcessor();
await processor.initialize(); // This loads your TFLite model
```

### Using with Form Detector

Enable form detection for detailed feedback:

```dart
final results = await processor.processVideoFromPath(
  videoPath,
  useFormDetection: true, // Enable form analysis
);
```

### Custom Exercise Names

The processor uses the same exercise names as your classifier:

```dart
// These are the supported exercises
final exerciseNames = [
  "Push-up", "Pull-up", "Squat", "Deadlift", 
  "Bench Press", "Lat Pulldown", "Bicep Curl", "Tricep Pushdown"
];
```

## File Structure

```
lib/
├── services/
│   ├── video_processor.dart          # Main video processing service
│   ├── exercise_classifier.dart      # Your existing classifier
│   └── exercise_form_detector.dart   # Your existing form detector
├── utils/
│   └── video_frame_extractor.dart    # Frame extraction utilities
├── screens/
│   ├── video_analysis_screen.dart    # Video analysis UI
│   └── exercise_list.dart           # Updated with video analysis option
└── examples/
    └── video_processing_example.dart # Usage examples
```

## Testing

### Test with Sample Videos

1. Record short exercise videos (30 seconds to 2 minutes)
2. Test with different exercises
3. Verify frame extraction quality
4. Check processing speed and accuracy

### Performance Testing

```dart
// Test processing time
final stopwatch = Stopwatch()..start();
final results = await processor.processVideoFromPath(videoPath);
stopwatch.stop();
print('Processing time: ${stopwatch.elapsed.inSeconds} seconds');
print('Frames processed: ${results.length}');
print('FPS: ${results.length / (stopwatch.elapsed.inMilliseconds / 1000)}');
```

## Troubleshooting

### FFmpeg Issues

1. **Check FFmpeg installation**:
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Platform-specific issues**:
   - Android: Check NDK compatibility
   - iOS: Check minimum deployment target

### Memory Issues

1. **Reduce frame rate**:
   ```dart
   targetFPS: 1, // Extract 1 frame per second
   ```

2. **Reduce frame size**:
   ```dart
   maxWidth: 320,
   maxHeight: 240,
   ```

3. **Process shorter videos**:
   - Split long videos into segments
   - Use video editing tools to trim

### Accuracy Issues

1. **Increase frame rate** for fast movements
2. **Increase frame size** for better pose detection
3. **Check lighting** in the video
4. **Ensure person is clearly visible** in the frame

## Future Enhancements

1. **Background Processing**: Process videos in background
2. **Cloud Processing**: Upload videos for server-side processing
3. **Batch Processing**: Process multiple videos
4. **Export Results**: Save analysis results to file
5. **Video Editing**: Trim videos before processing
6. **Real-time Preview**: Show video preview during selection

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review error messages in the console
3. Test with different video formats and lengths
4. Verify all dependencies are properly installed 