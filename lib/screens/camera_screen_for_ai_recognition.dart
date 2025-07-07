import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import '../../utils/pushup_analyzer.dart';
import '../../utils/pullup_analyzer.dart';
import '../../utils/benchpress_analyzer.dart';
import '../../utils/bicepcurl_analyzer.dart';
import '../../utils/deadlift_analyzer.dart';
import '../../utils/latpulldown_analyzer.dart';
import '../../utils/squat_analyzer.dart';
import '../../utils/triceppushdown_analyzer.dart';
import '../utils/camera_utils.dart';
import '../services/tts_service.dart';
// import 'camera_overlays.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  // Original camera and server logic
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _exerciseLocked = false;
  String? _lockedExercise;
  
  // Server configuration
  static const String serverUrl = 'http://192.168.1.195:8000';
  
  // Prediction state
  String _currentPrediction = 'No prediction yet';
  double _confidence = 0.0;
  DateTime? _lastPredictionTime;
  
  // Exercise detection tracking
  Map<String, int> _exerciseDetectionCount = {};
  Map<String, DateTime> _lastExerciseDetection = {};
  Timer? _exerciseStabilityTimer;
  static const int requiredDetections = 3;
  static const int stabilityWindowSeconds = 2;
  
  // Available exercises
  static const List<String> exerciseNames = [
    "Push-up",
    "Pull-up",
    "Squat",
    "Deadlift",
    "Bench Press",
    "Lat Pulldown",
    "Bicep Curl",
    "Tricep Pushdown",
  ];
  
  // Performance optimization
  Timer? _frameTimer;
  int _frameSkipCount = 0;
  static const int frameSkipInterval = 1;
  static const int requestTimeoutMs = 5000;
  
  // Error handling
  String _errorMessage = '';
  int _consecutiveErrors = 0;
  static const int maxConsecutiveErrors = 3;
  
  // Connection status
  bool _serverConnected = false;
  Timer? _healthCheckTimer;

  // NEW: Exercise analyzer integration from CameraScreenState
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late PoseDetector _poseDetector;
  late TtsService _ttsService;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Exercise state
  String _currentFeedback = 'Position yourself in frame';
  Color _feedbackColor = Colors.blue;
  int _repCount = 0;
  int _lastRepCount = 0;
  bool _isAnalyzing = false;
  bool _isInDownPhase = false;
  bool _isPaused = false;
  
  // Exercise type flags
  bool _isPushUpExercise = false;
  bool _isPullUpExercise = false;
  bool _isBenchPressExercise = false;
  bool _isBicepCurlExercise = false;
  bool _isDeadliftExercise = false;
  bool _isLatPulldownExercise = false;
  bool _isSquatExercise = false;
  bool _isTricepPushdownExercise = false;
  
  // Session tracking
  String? _sessionId;
  List<Map<String, dynamic>> _sessionReps = [];
  Timer? _progressTimer;
  Duration _sessionDuration = Duration.zero;
  DateTime? _sessionStartTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePoseDetector();
    _ttsService = TtsService();
    _initializeAnimations();
    _initializeCamera();
    _startHealthCheck();
    _startProgressTimer();
    _sessionStartTime = DateTime.now();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  }

  void _initializePoseDetector() {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.accurate,
      ),
    );
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isPaused) {
        setState(() {
          _sessionDuration = Duration(seconds: _sessionDuration.inSeconds + 1);
        });
      }
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
  }

 Future<void> _initializeCamera() async {
  try {
    _cameras = await availableCameras();
    if (_cameras!.isEmpty) {
      setState(() {
        _errorMessage = 'No cameras available';
      });
      return;
    }

    // Default to back camera (first camera is usually back camera)
    CameraDescription selectedCamera = _cameras![0];
    
    // Look for back camera specifically
    for (final camera in _cameras!) {
      if (camera.lensDirection == CameraLensDirection.back) {
        selectedCamera = camera;
        break;
      }
    }

    _controller = CameraController(
      selectedCamera,
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.jpeg,
      enableAudio: false,
    );

    await _controller!.initialize();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
      await _checkServerHealth();
      _startFrameCapture();
    }
  } catch (e) {
    setState(() {
      _errorMessage = 'Failed to initialize camera: $e';
    });
  }
}

  void _startHealthCheck() {
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkServerHealth();
    });
  }

  Future<void> _checkServerHealth() async {
    try {
      final response = await http
          .get(
            Uri.parse('$serverUrl/health'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          _serverConnected = true;
          if (_errorMessage.contains('Server')) {
            _errorMessage = '';
          }
        });

        if (_isInitialized && (_frameTimer == null || !_frameTimer!.isActive)) {
          _startFrameCapture();
        }
      } else {
        setState(() {
          _serverConnected = false;
        });
      }
    } catch (e) {
      setState(() {
        _serverConnected = false;
      });
    }
  }

  void _startFrameCapture() {
    _frameTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isProcessing &&
          _controller != null &&
          _controller!.value.isInitialized &&
          _serverConnected) {
        _captureAndSendFrame();
      }
    });
  }

  Future<void> _captureAndSendFrame() async {
    if (_isProcessing ||
        _controller == null ||
        !_controller!.value.isInitialized ||
        !_serverConnected) {
      return;
    }

    _frameSkipCount++;
    if (_frameSkipCount % frameSkipInterval != 0) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile image = await _controller!.takePicture();
      final Uint8List imageBytes = await image.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      // Send to server for prediction
      await _sendFrameToServer(base64Image);
      
      // If exercise is locked, also process with local analyzers
      if (_exerciseLocked && _lockedExercise != null) {
        await _processFrameWithLocalAnalyzers(imageBytes);
      }
      
      _consecutiveErrors = 0;
    } catch (e) {
      _handleError('Frame capture error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _sendFrameToServer(String base64Image) async {
    try {
      final response = await http
          .post(
            Uri.parse('$serverUrl/predict_single_frame'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'frame': base64Image,
              'timestamp': DateTime.now().millisecondsSinceEpoch / 1000.0,
            }),
          )
          .timeout(const Duration(milliseconds: requestTimeoutMs));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        _handleServerResponse(responseData);
      } else {
        _handleError('Server error: ${response.statusCode} - ${response.body}');
      }
    } on TimeoutException {
      _handleError('Request timeout - server may be overloaded');
    } catch (e) {
      _handleError('Unexpected error: $e');
    }
  }

  void _handleServerResponse(Map<String, dynamic> responseData) {
    if (!mounted) return;

    setState(() {
      if (responseData.containsKey('error')) {
        _currentPrediction = 'Error: ${responseData['error']}';
        _confidence = 0.0;
      } else if (responseData.containsKey('exercise_class') &&
          responseData.containsKey('exercise_label')) {
        String exerciseLabel = responseData['exercise_label'];

        // Lock in the first valid prediction
        if (!_exerciseLocked &&
            exerciseNames.contains(exerciseLabel) &&
            (responseData['confidence'] ?? 0.0) > 0.6) {
          _lockExercise(exerciseLabel);
        }

        // Update prediction if exercise matches locked exercise
        if (_exerciseLocked && exerciseLabel == _lockedExercise) {
          _currentPrediction = exerciseLabel;
          _confidence = (responseData['confidence'] ?? 0.0).toDouble();
          _lastPredictionTime = DateTime.now();
        } else if (!_exerciseLocked) {
          _currentPrediction = 'Detecting exercise...';
          _confidence = (responseData['confidence'] ?? 0.0).toDouble();
          _lastPredictionTime = DateTime.now();
        }
      } else {
        if (!_exerciseLocked) {
          _currentPrediction = 'No pose detected - Please ensure you are visible';
          _confidence = 0.0;
        }
      }
    });
  }

  void _lockExercise(String exerciseLabel) {
    _exerciseLocked = true;
    _lockedExercise = exerciseLabel;
    _initializeExerciseAnalyzers(exerciseLabel);
    
    setState(() {
      _currentFeedback = 'Exercise detected: $exerciseLabel. Begin your workout!';
      _feedbackColor = Colors.green;
    });
    
    _ttsService.speak("$exerciseLabel detected. Begin your workout!");
  }

  void _initializeExerciseAnalyzers(String exerciseLabel) {
    final exerciseName = exerciseLabel.toLowerCase();
    
    // Reset all flags
    _isPushUpExercise = false;
    _isPullUpExercise = false;
    _isBenchPressExercise = false;
    _isBicepCurlExercise = false;
    _isDeadliftExercise = false;
    _isLatPulldownExercise = false;
    _isSquatExercise = false;
    _isTricepPushdownExercise = false;
    
    // Set appropriate flag and reset analyzer
    if (exerciseName.contains('push')) {
      _isPushUpExercise = true;
      PushUpAnalyzer.resetSession();
    } else if (exerciseName.contains('pull-up') || exerciseName.contains('pullup')) {
      _isPullUpExercise = true;
      PullUpAnalyzer.resetSession();
    } else if (exerciseName.contains('bench')) {
      _isBenchPressExercise = true;
      BenchPressAnalyzer.resetSession();
    } else if (exerciseName.contains('bicep')) {
      _isBicepCurlExercise = true;
      BicepCurlAnalyzer.resetSession();
    } else if (exerciseName.contains('deadlift')) {
      _isDeadliftExercise = true;
      DeadliftAnalyzer.resetSession();
    } else if (exerciseName.contains('lat') || exerciseName.contains('pulldown')) {
      _isLatPulldownExercise = true;
      LatPulldownAnalyzer.resetSession();
    } else if (exerciseName.contains('squat')) {
      _isSquatExercise = true;
      SquatAnalyzer.resetSession();
    } else if (exerciseName.contains('tricep')) {
      _isTricepPushdownExercise = true;
      TricepPushdownAnalyzer.resetSession();
    }
  }

  // NEW: Process frame with local exercise analyzers
  Future<void> _processFrameWithLocalAnalyzers(Uint8List imageBytes) async {
    if (!_exerciseLocked || _lockedExercise == null) return;

    try {
      // Convert image to InputImage format
      final inputImage = CameraUtils.inputImageFromCameraImage(
        // You'll need to adapt this based on your CameraUtils implementation
        // For now, using a simplified approach
        await _convertToInputImage(imageBytes),
        _cameras!,
        0, // Camera index
      );

      if (inputImage != null) {
        final List<Pose> poses = await _poseDetector.processImage(inputImage);
        
        if (poses.isNotEmpty) {
          final pose = poses.first;
          
          // Process with appropriate analyzer
          if (_isPushUpExercise) {
            PushUpAnalyzer.analyzePushUpForm(pose, _updateFeedback, _onRepCountUpdate);
          } else if (_isPullUpExercise) {
            PullUpAnalyzer.analyzePullUpForm(pose, _updateFeedback, _onRepCountUpdate);
          } else if (_isBenchPressExercise) {
            BenchPressAnalyzer.analyzeBenchPressForm(pose, _updateFeedback, _onRepCountUpdate);
          } else if (_isBicepCurlExercise) {
            BicepCurlAnalyzer.analyzeBicepCurlForm(pose, _updateFeedback, _onRepCountUpdate);
          } else if (_isDeadliftExercise) {
            DeadliftAnalyzer.analyzeDeadliftForm(pose, _updateFeedback, _onRepCountUpdate);
          } else if (_isLatPulldownExercise) {
            LatPulldownAnalyzer.analyzeLatPulldownForm(pose, _updateFeedback, _onRepCountUpdate);
          } else if (_isSquatExercise) {
            SquatAnalyzer.analyzeSquatForm(pose, _updateFeedback, _onRepCountUpdate);
          } else if (_isTricepPushdownExercise) {
            TricepPushdownAnalyzer.analyzeTricepPushdownForm(pose, _updateFeedback, _onRepCountUpdate);
          }
        }
      }
    } catch (e) {
      print('Error in local analyzer processing: $e');
    }
  }

  // Helper method to convert image bytes to InputImage
  Future<dynamic> _convertToInputImage(Uint8List imageBytes) async {
    // This is a simplified conversion - you'll need to implement proper conversion
    // based on your camera setup and CameraUtils
    return null; // Placeholder 
  }

  void _updateFeedback(String message, Color color) {
    if (mounted) {
      setState(() {
        _currentFeedback = message;
        _feedbackColor = color;
      });
    }

    if (_shouldSpeak(message, color)) {
      _ttsService.speak(message);
    }
  }

  bool _shouldSpeak(String message, Color color) {
    return color == Colors.red ||
        color == Colors.orange ||
        message.contains('rep') ||
        message.contains('Rep') ||
        (color == Colors.green && _repCount != _lastRepCount);
  }

  void _onRepCountUpdate(int newCount) {
    if (mounted && newCount != _repCount) {
      setState(() {
        _lastRepCount = _repCount;
        _repCount = newCount;
      });

      _sessionReps.add({
        'repNumber': newCount,
        'timestamp': DateTime.now().toIso8601String(),
        'sessionDuration': _sessionDuration.inSeconds,
      });

      if (newCount > 0 && newCount % 5 == 0) {
        _saveSessionData();
        _ttsService.speak("$newCount reps completed! Keep going!");
      }
    }
  }

  Future<void> _saveSessionData() async {
    try {
      final user = _auth.currentUser;
      if (user != null && _sessionId != null) {
        final sessionData = {
          'userId': user.uid,
          'exerciseName': _lockedExercise,
          'totalReps': _repCount,
          'sessionDuration': _sessionDuration.inSeconds,
          'startTime': _sessionStartTime?.toIso8601String(),
          'endTime': DateTime.now().toIso8601String(),
          'reps': _sessionReps,
          'feedback': _currentFeedback,
        };

        await _firestore
            .collection('exercise_sessions')
            .doc(_sessionId)
            .set(sessionData);
      }
    } catch (e) {
      print('Error saving session data: $e');
    }
  }

  void _handleError(String error) {
    print('Error: $error');
    _consecutiveErrors++;
    
    if (_consecutiveErrors >= maxConsecutiveErrors) {
      setState(() {
        _errorMessage = 'Multiple errors occurred. Please restart the app.';
      });
    } else {
      setState(() {
        _errorMessage = error;
      });
    }
  }

  @override
  void dispose() {
    _saveSessionData();
    WidgetsBinding.instance.removeObserver(this);
    _healthCheckTimer?.cancel();
    _frameTimer?.cancel();
    _exerciseStabilityTimer?.cancel();
    _progressTimer?.cancel();
    _controller?.dispose();
    _poseDetector.close();
    _ttsService.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          _buildCameraPreview(),
          
          // Exercise information overlay
          if (_exerciseLocked)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Exercise: ${_lockedExercise ?? 'Unknown'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reps: $_repCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Feedback overlay
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _feedbackColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _currentFeedback,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          // Server status indicator
          Positioned(
            top: 50,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _serverConnected ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _serverConnected ? 'Connected' : 'Disconnected',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          
          // Error message
          if (_errorMessage.isNotEmpty)
            Positioned(
              top: 150,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          
          // Back button
          Positioned(
            top: 50,
            left: 16,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5494DD)),
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.previewSize!.height,
          height: _controller!.value.previewSize!.width,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }
}