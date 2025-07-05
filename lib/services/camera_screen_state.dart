import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:virtual_exercise_assistant/screens/simple_camera_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/exercise_form_detector.dart';
import '../../utils/pushup_analyzer.dart';
import '../../utils/pullup_analyzer.dart';
import '../../utils/benchpress_analyzer.dart';
import '../utils/camera_utils.dart';
import 'camera_overlays.dart';
import 'tts_service.dart';
import 'dart:async';

abstract class CameraScreenState extends State<SimpleCameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isInitialized = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<CameraDescription> _availableCameras = [];
  int _currentCameraIndex = 0;
  bool _isSwitchingCamera = false;
  DateTime? _sessionStartTime;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late ExerciseFormDetector _formDetector;
  String _currentFeedback = 'Position yourself in frame';
  Color _feedbackColor = Colors.blue;
  int _repCount = 0;
  int _lastRepCount = 0;
  bool _isAnalyzing = false;
  bool _isInDownPhase = false;
  bool _isPaused = false;

  late PoseDetector _poseDetector;
  bool _isPushUpExercise = false;
  bool _isPullUpExercise = false;
  bool _isBenchPressExercise = false;

  late TtsService _ttsService;

  String? _sessionId;
  List<Map<String, dynamic>> _sessionReps = [];

  // Add timer for progress tracking
  Timer? _progressTimer;
  Duration _sessionDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePoseDetector();
    _ttsService = TtsService();
    _initializeFormDetector();
    _initializeAnimations();
    _sessionId = widget.sessionId;
    _sessionStartTime = DateTime.now();
    _startProgressTimer();
    _requestPermissions().then((_) {
      _initializeCameras();
    });
  }

  void _initializePoseDetector() {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.accurate,
      ),
    );

    final exerciseName = widget.exerciseName?.toLowerCase() ?? '';
    _isPushUpExercise =
        exerciseName.contains('push') || exerciseName.contains('pushup');
    _isPullUpExercise =
        exerciseName.contains('pull') || exerciseName.contains('pullup');
    _isBenchPressExercise =
        exerciseName.contains('bench') || exerciseName.contains('benchpress');

    if (_isPushUpExercise) {
      PushUpAnalyzer.resetSession();
    } else if (_isPullUpExercise) {
      PullUpAnalyzer.resetSession();
    } else if (_isBenchPressExercise) {
      BenchPressAnalyzer.resetSession();
    }
  }

  void _initializeFormDetector() {
    _formDetector = ExerciseFormDetector(
      onFeedbackUpdate: _updateFeedback,
      onRepCountUpdate: _onRepCountUpdate,
      initialExercise: widget.exerciseName ?? 'Push Ups',
    );
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.camera.request();
    if (status.isDenied && mounted) {
      _showErrorDialog(
        'Permission Required',
        'Camera permission is required to use this feature.',
      );
    }
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

  @override
  void dispose() {
    _saveSessionData();
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    _poseDetector.close();
    _ttsService.dispose();
    _stopProgressTimer();

    if (_cameraController != null) {
      try {
        if (_cameraController!.value.isStreamingImages) {
          _cameraController!.stopImageStream();
        }
      } catch (e) {
        print('Error stopping image stream on dispose: $e');
      }
      _cameraController?.dispose();
    }

    _formDetector.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    switch (state) {
      case AppLifecycleState.paused:
        _saveSessionData();
        _pauseSession();
        _ttsService.stop();
        try {
          if (cameraController.value.isStreamingImages) {
            cameraController.stopImageStream();
          }
          cameraController.dispose();
        } catch (e) {
          print('Error disposing camera on pause: $e');
        }
        if (mounted) setState(() => _isInitialized = false);
        break;
      case AppLifecycleState.resumed:
        _resumeSession();
        _initializeCamera();
        break;
      default:
        break;
    }
  }

  Future<void> _initializeCameras() async {
    try {
      _availableCameras = await availableCameras();

      if (_availableCameras.isEmpty) {
        throw Exception('No cameras available on this device');
      }

      _currentCameraIndex = _availableCameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      if (_currentCameraIndex == -1) {
        _currentCameraIndex = _availableCameras.indexWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
        );
      }

      if (_currentCameraIndex == -1) _currentCameraIndex = 0;
      await _initializeCamera();
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Camera Error', 'Failed to initialize cameras: $e');
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      if (_availableCameras.isEmpty) throw Exception('No cameras available');

      if (_cameraController != null) {
        try {
          if (_cameraController!.value.isStreamingImages) {
            await _cameraController!.stopImageStream();
          }
        } catch (e) {
          print('Error stopping image stream: $e');
        }
        await _cameraController?.dispose();
        _cameraController = null;
      }

      final selectedCamera = _availableCameras[_currentCameraIndex];
      final imageFormat = CameraUtils.getImageFormat();
      final resolution = CameraUtils.getResolution(selectedCamera);

      _cameraController = CameraController(
        selectedCamera,
        resolution,
        enableAudio: false,
        imageFormatGroup: imageFormat,
      );

      await _cameraController!.initialize();

      if (!_cameraController!.value.isInitialized) {
        throw Exception('Camera failed to initialize properly');
      }

      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted || _cameraController == null) return;

      try {
        await _cameraController!.startImageStream((CameraImage image) {
          if (!_isAnalyzing &&
              mounted &&
              _cameraController != null &&
              !_isPaused) {
            _isAnalyzing = true;
            _processImage(image)
                .then((_) {
                  if (mounted) _isAnalyzing = false;
                })
                .catchError((error) {
                  if (mounted) _isAnalyzing = false;
                  print('Error in image processing: $error');
                });
          }
        });
      } catch (e) {
        print('Error starting image stream: $e');
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _currentFeedback = 'Ready - Begin exercise!';
          _feedbackColor = Colors.green;
        });

        _ttsService.speak(
          "Camera ready. Begin your ${widget.exerciseName ?? 'exercise'}",
        );
      }
    } catch (e) {
      print('Camera initialization error: $e');
      if (mounted) {
        _showErrorDialog('Camera Error', 'Failed to initialize camera: $e');
      }
    }
  }

  Future<void> _processImage(CameraImage image) async {
    try {
      final inputImage = CameraUtils.inputImageFromCameraImage(
        image,
        _availableCameras,
        _currentCameraIndex,
      );

      if (inputImage != null && mounted) {
        if (_isPushUpExercise) {
          await _processPushUpImage(inputImage);
        } else if (_isPullUpExercise) {
          await _processPullUpImage(inputImage);
        } else if (_isBenchPressExercise) {
          await _processBenchPressImage(inputImage);
        } else {
          await _formDetector.processImage(
            inputImage,
            widget.exerciseName ?? 'Push Ups',
          );
        }
      }
    } catch (e) {
      print('Error processing image: $e');
    }
  }

  Future<void> _processPushUpImage(InputImage inputImage) async {
    try {
      final List<Pose> poses = await _poseDetector.processImage(inputImage);

      if (poses.isNotEmpty && mounted) {
        final pose = poses.first;
        final analysisResult = PushUpAnalyzer.analyzePushUpForm(
          pose,
          _updateFeedback,
          _onRepCountUpdate,
        );
      }
    } catch (e) {
      print('Error in push-up analysis: $e');
    }
  }

  Future<void> _processPullUpImage(InputImage inputImage) async {
    try {
      final List<Pose> poses = await _poseDetector.processImage(inputImage);

      if (poses.isNotEmpty && mounted) {
        final pose = poses.first;
        final analysisResult = PullUpAnalyzer.analyzePullUpForm(
          pose,
          _updateFeedback,
          _onRepCountUpdate,
        );
      }
    } catch (e) {
      print('Error in pull-up analysis: $e');
    }
  }

  Future<void> _processBenchPressImage(InputImage inputImage) async {
    try {
      final List<Pose> poses = await _poseDetector.processImage(inputImage);

      if (poses.isNotEmpty && mounted) {
        final pose = poses.first;
        final analysisResult = BenchPressAnalyzer.analyzeBenchPressForm(
          pose,
          _updateFeedback,
          _onRepCountUpdate,
        );
      }
    } catch (e) {
      print('Error in bench-press analysis: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length <= 1 || _isSwitchingCamera) return;
    setState(() => _isSwitchingCamera = true);

    try {
      if (_cameraController != null &&
          _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }

      _currentCameraIndex =
          (_currentCameraIndex + 1) % _availableCameras.length;
      setState(() => _isInitialized = false);
      await _initializeCamera();

      if (mounted) {
        final cameraType =
            _availableCameras[_currentCameraIndex].lensDirection ==
                CameraLensDirection.front
            ? 'Front'
            : 'Back';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to $cameraType Camera'),
            duration: const Duration(seconds: 1),
            backgroundColor: const Color(0xFF5494DD),
          ),
        );

        _ttsService.speak("Switched to $cameraType camera");
      }
    } catch (e) {
      print('Camera switch error: $e');
      if (mounted) {
        _showErrorDialog('Camera Switch Error', 'Failed to switch camera: $e');
      }
    } finally {
      if (mounted) setState(() => _isSwitchingCamera = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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

  // Fixed: Added the missing _onRepCountUpdate method
  void _onRepCountUpdate(int newCount) {
    if (mounted && newCount != _repCount) {
      setState(() {
        _lastRepCount = _repCount;
        _repCount = newCount;
      });

      // Log the rep for session tracking
      _sessionReps.add({
        'repNumber': newCount,
        'timestamp': DateTime.now().toIso8601String(),
        'sessionDuration': _sessionDuration.inSeconds,
      });

      // Provide audio feedback for milestones
      if (newCount > 0 && newCount % 5 == 0) {
        _saveSessionData();
        _ttsService.speak("$newCount reps completed! Keep going!");
      }
    }
  }

  // Fixed: Added the missing _navigateBack method
  Future<void> _navigateBack() async {
    // Save session data before navigating back
    await _saveSessionData();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveSessionData() async {
    try {
      final user = _auth.currentUser;
      if (user != null && _sessionId != null) {
        final sessionData = {
          'userId': user.uid,
          'exerciseName': widget.exerciseName,
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
            .update(sessionData);
      }
    } catch (e) {
      print('Error saving session data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getUserExerciseHistory() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final querySnapshot = await _firestore
            .collection('exercise_sessions')
            .where('userId', isEqualTo: user.uid)
            .where('exerciseName', isEqualTo: widget.exerciseName)
            .orderBy('endTime', descending: true)
            .limit(10)
            .get();

        return querySnapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      }
    } catch (e) {
      print('Error fetching exercise history: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> _getPersonalBest() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final querySnapshot = await _firestore
            .collection('exercise_sessions')
            .where('userId', isEqualTo: user.uid)
            .where('exerciseName', isEqualTo: widget.exerciseName)
            .orderBy('totalReps', descending: true)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          return querySnapshot.docs.first.data() as Map<String, dynamic>;
        }
      }
    } catch (e) {
      print('Error fetching personal best: $e');
    }
    return null;
  }

  void updateExercise(String newExercise) {
    final exerciseName = newExercise.toLowerCase();
    _isPushUpExercise =
        exerciseName.contains('push') || exerciseName.contains('pushup');
    _isPullUpExercise =
        exerciseName.contains('pull') || exerciseName.contains('pullup');
    _isBenchPressExercise =
        exerciseName.contains('bench') || exerciseName.contains('benchpress');
    resetCounter();
    _ttsService.speak("Starting $newExercise");
  }

  void resetCounter() {
    _repCount = 0;
    _lastRepCount = 0;
    _isInDownPhase = false;
    _sessionReps.clear();
    _ttsService.speak("Counter reset");
  }

  Widget _buildCameraPreview() {
    if (!_isInitialized || _cameraController == null || _isSwitchingCamera) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5494DD)),
              ),
              const SizedBox(height: 16),
              Text(
                _isSwitchingCamera
                    ? 'Switching Camera...'
                    : 'Initializing Camera...',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize!.height,
          height: _cameraController!.value.previewSize!.width,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildCameraPreview(),
          CameraOverlays(
            isInitialized: _isInitialized,
            isSwitchingCamera: _isSwitchingCamera,
            availableCameras: _availableCameras,
            currentCameraIndex: _currentCameraIndex,
            exerciseName: widget.exerciseName,
            currentFeedback: _currentFeedback,
            feedbackColor: _feedbackColor,
            repCount: _repCount,
            isAnalyzing: _isAnalyzing,
            isVoiceEnabled: _ttsService.isEnabled,
            sessionStartTime: _sessionStartTime,
            fadeAnimation: _fadeAnimation,
            onBackPressed: _navigateBack,
            onSwitchCamera: _switchCamera,
            onToggleVoice: () {
              setState(() {
                _ttsService.toggleVoice();
              });
            },
            // onPausePressed: _pauseSession,
            // onResumePressed: _resumeSession,
            // onResetPressed: _resetSession,
            // onStatsPressed: _showSessionStats,
            // isPaused: _isPaused,
            // sessionDuration: _sessionDuration,
          ),
        ],
      ),
    );
  }

  Future<void> _showSessionStats() async {
    final history = await _getUserExerciseHistory();
    final personalBest = await _getPersonalBest();

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${widget.exerciseName} Stats'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Session: $_repCount reps'),
              Text('Session Duration: ${_formatDuration(_sessionDuration)}'),
              const SizedBox(height: 8),
              if (personalBest != null)
                Text('Personal Best: ${personalBest['totalReps']} reps'),
              const SizedBox(height: 8),
              Text('Total Sessions: ${history.length}'),
              if (history.isNotEmpty)
                Text('Last Session: ${history.first['totalReps']} reps'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds % 60);
    return '$minutes:$seconds';
  }

  void _pauseSession() {
    setState(() {
      _isPaused = true;
    });
    _stopProgressTimer();
    _ttsService.speak("Session paused");
  }

  void _resumeSession() {
    setState(() {
      _isPaused = false;
    });
    _startProgressTimer();
    _ttsService.speak("Session resumed");
  }

  void _resetSession() {
    setState(() {
      _repCount = 0;
      _lastRepCount = 0;
      _sessionReps.clear();
      _sessionStartTime = DateTime.now();
      _sessionDuration = Duration.zero;
    });

    // Reset analyzer states
    if (_isPushUpExercise) {
      PushUpAnalyzer.resetSession();
    } else if (_isPullUpExercise) {
      PullUpAnalyzer.resetSession();
    } else if (_isBenchPressExercise) {
      BenchPressAnalyzer.resetSession();
    }

    _ttsService.speak("Session reset");
  }
}
