import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../services/exercise_form_detector.dart';
import '../utils/pushup_analyzer.dart'; 
import '../utils/pullup_analyzer.dart';
import 'package:flutter_tts/flutter_tts.dart';


class SimpleCameraScreen extends StatefulWidget {
  final CameraDescription? camera;
  final String? exerciseName;

  const SimpleCameraScreen({super.key, this.camera, this.exerciseName});

  @override
  _SimpleCameraScreenState createState() => _SimpleCameraScreenState();
}

class _SimpleCameraScreenState extends State<SimpleCameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isInitialized = false;
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
  int _lastRepCount = 0; // Added missing variable
  bool _isAnalyzing = false;
  bool _isInDownPhase = false; // Added missing variable
  
  // Add pose detector for direct push-up analysis
  late PoseDetector _poseDetector;
  bool _isPushUpExercise = false;
  bool _isPullUpExercise = false;

  // Voice feedback components
  FlutterTts? _flutterTts;
  bool _isVoiceEnabled = true;
  String _lastSpokenMessage = '';
  DateTime _lastSpeechTime = DateTime.now();

  // Speech rate limiting (prevent spam)
  static const Duration _speechCooldown = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePoseDetector();
    _initializeTextToSpeech(); // Initialize TTS on init
    _initializeFormDetector();
    _initializeAnimations();
    _requestPermissions().then((_) {
      _initializeCameras();
    });
  }

  void _initializePoseDetector() {
    // Initialize pose detector for push-up analysis
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.accurate,
      ),
    );
    
    // Check if this is a push-up exercise
    final exerciseName = widget.exerciseName?.toLowerCase() ?? '';
    _isPushUpExercise = exerciseName.contains('push') || exerciseName.contains('pushup');
    _isPullUpExercise = exerciseName.contains('pull') || exerciseName.contains('pullup');
    
    // Reset push-up analyzer for new session
    if (_isPushUpExercise) {
      PushUpAnalyzer.resetSession();
    }
    else if (_isPullUpExercise) {
      PullUpAnalyzer.resetSession();
    }
  }

  Future<void> _initializeTextToSpeech() async {
    if (!_isVoiceEnabled) return;
    
    try {
      _flutterTts = FlutterTts();
      
      // Configure TTS settings
      await _flutterTts?.setLanguage("en-US");
      await _flutterTts?.setSpeechRate(0.6); // Slightly slower for clarity
      await _flutterTts?.setVolume(0.8);
      await _flutterTts?.setPitch(1.0);
      
      // Set up completion handler
      _flutterTts?.setCompletionHandler(() {
        print("TTS completed");
      });

      // Set up error handler
      _flutterTts?.setErrorHandler((message) {
        print("TTS Error: $message");
      });

      print("TTS initialized successfully");
    } catch (e) {
      print("Failed to initialize TTS: $e");
    }
  }

  // Voice feedback control methods
  void enableVoice() {
    _isVoiceEnabled = true;
    if (_flutterTts == null) {
      _initializeTextToSpeech();
    }
  }

  void disableVoice() {
    _isVoiceEnabled = false;
    _flutterTts?.stop();
  }

  bool get isVoiceEnabled => _isVoiceEnabled;

  Future<void> _speakFeedback(String message) async {
    if (!_isVoiceEnabled || _flutterTts == null) return;
    
    // Rate limiting: don't repeat the same message too frequently
    final now = DateTime.now();
    if (_lastSpokenMessage == message && 
        now.difference(_lastSpeechTime) < _speechCooldown) {
      return;
    }
    
    _lastSpokenMessage = message;
    _lastSpeechTime = now;
    
    try {
      // Stop any ongoing speech before starting new one
      await _flutterTts?.stop();
      await _flutterTts?.speak(message);
      print("Speaking: $message");
    } catch (e) {
      print('TTS Error: $e');
    }
  }

  void _updateFeedback(String message, Color color) {
    if (mounted) {
      setState(() {
        _currentFeedback = message;
        _feedbackColor = color;
      });
    }
    
    // Only speak certain types of feedback to avoid spam
    if (_shouldSpeak(message, color)) {
      _speakFeedback(message);
    }
  }

  bool _shouldSpeak(String message, Color color) {
    // Speak error corrections (red), warnings (orange), and rep counts
    // Don't spam "good form" messages
    return color == Colors.red || 
           color == Colors.orange || 
           message.contains('rep') ||
           message.contains('Rep') ||
           (color == Colors.green && _repCount != _lastRepCount);
  }

  void updateExercise(String newExercise) {
    final exerciseName = newExercise.toLowerCase();
    _isPushUpExercise = exerciseName.contains('push') || exerciseName.contains('pushup');
    _isPushUpExercise = exerciseName.contains('pull') || exerciseName.contains('pullup');
    resetCounter();
    _speakFeedback("Starting $newExercise");
  }

  void resetCounter() {
    _repCount = 0;
    _lastRepCount = 0;
    _isInDownPhase = false;
    _speakFeedback("Counter reset");
  }

  void _initializeFormDetector() {
    _formDetector = ExerciseFormDetector(
      onFeedbackUpdate: _updateFeedback, // Use the centralized feedback method
      onRepCountUpdate: (count) {
        if (mounted && count != _repCount) {
          setState(() {
            _lastRepCount = _repCount;
            _repCount = count;
          });
          
          // Speak rep count updates
          if (count > _lastRepCount) {
            _speakFeedback("Rep $count");
          }
        }
      },
      initialExercise: widget.exerciseName ?? 'Push Ups',
      
    );
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.camera.request();
    if (status.isDenied) {
      if (mounted) {
        _showErrorDialog(
          'Permission Required',
          'Camera permission is required to use this feature.',
        );
      }
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    _poseDetector.close(); // Dispose pose detector
    
    // Dispose TTS
    _flutterTts?.stop();

    // Safely dispose camera controller
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
        // Stop TTS when app is paused
        _flutterTts?.stop();
        try {
          if (cameraController.value.isStreamingImages) {
            cameraController.stopImageStream();
          }
          cameraController.dispose();
        } catch (e) {
          print('Error disposing camera on pause: $e');
        }
        if (mounted) {
          setState(() => _isInitialized = false);
        }
        break;
      case AppLifecycleState.resumed:
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

      // Find front camera first, fallback to back camera
      _currentCameraIndex = _availableCameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      // If no front camera, use back camera
      if (_currentCameraIndex == -1) {
        _currentCameraIndex = _availableCameras.indexWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
        );
      }

      // Use first camera if neither front nor back found
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
      if (_availableCameras.isEmpty) {
        throw Exception('No cameras available');
      }

      // Safely dispose previous controller
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

      // Get the selected camera
      final selectedCamera = _availableCameras[_currentCameraIndex];

      // Use different image format based on camera and platform
      ImageFormatGroup imageFormat = ImageFormatGroup.yuv420;
      ResolutionPreset resolution = ResolutionPreset.medium;

      if (defaultTargetPlatform == TargetPlatform.android) {
        imageFormat = ImageFormatGroup.nv21;
        // Use lower resolution for back camera to reduce processing load
        if (selectedCamera.lensDirection == CameraLensDirection.back) {
          resolution = ResolutionPreset.low;
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        imageFormat = ImageFormatGroup.bgra8888;
      }

      _cameraController = CameraController(
        selectedCamera,
        resolution,
        enableAudio: false,
        imageFormatGroup: imageFormat,
      );

      await _cameraController!.initialize();

      // Ensure camera is ready before starting stream
      if (!_cameraController!.value.isInitialized) {
        throw Exception('Camera failed to initialize properly');
      }

      // Add delay and check if still mounted
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted || _cameraController == null) {
        return;
      }

      // Start image stream for pose detection with error handling
      try {
        await _cameraController!.startImageStream((CameraImage image) {
          if (!_isAnalyzing && mounted && _cameraController != null) {
            _isAnalyzing = true;
            _processImage(image)
                .then((_) {
                  if (mounted) {
                    _isAnalyzing = false;
                  }
                })
                .catchError((error) {
                  if (mounted) {
                    _isAnalyzing = false;
                  }
                  print('Error in image processing: $error');
                });
          }
        });
      } catch (e) {
        print('Error starting image stream: $e');
        // Continue without image stream if it fails
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _sessionStartTime = DateTime.now();
          _currentFeedback = 'Ready - Begin exercise!';
          _feedbackColor = Colors.green;
        });
        
        // Speak welcome message
        _speakFeedback("Camera ready. Begin your ${widget.exerciseName ?? 'exercise'}");
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
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage != null && mounted) {
        // Use direct push-up analysis for push-up exercises
        if (_isPushUpExercise) {
          await _processPushUpImage(inputImage);
        } else {
          // Use form detector for other exercises
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

  // New method for direct push-up analysis
  Future<void> _processPushUpImage(InputImage inputImage) async {
    try {
      final List<Pose> poses = await _poseDetector.processImage(inputImage);
      
      if (poses.isNotEmpty && mounted) {
        final pose = poses.first;
        
        // Use PushUpAnalyzer directly
        final analysisResult = PushUpAnalyzer.analyzePushUpForm(
          pose,
          _updateFeedback, // Use centralized feedback method
          (count) {
            if (mounted && count != _repCount) {
              setState(() {
                _lastRepCount = _repCount;
                _repCount = count;
              });
              
              // Speak rep count updates
              if (count > _lastRepCount) {
                _speakFeedback("Rep $count");
              }
            }
          },
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
        
        // Use PushUpAnalyzer directly
        final analysisResult = PullUpAnalyzer.analyzePullUpForm(
          pose,
          _updateFeedback, // Use centralized feedback method
          (count) {
            if (mounted && count != _repCount) {
              setState(() {
                _lastRepCount = _repCount;
                _repCount = count;
              });
              
              // Speak rep count updates
              if (count > _lastRepCount) {
                _speakFeedback("Rep $count");
              }
            }
          },
        );
        
        
      }
    } catch (e) {
      print('Error in pull-up analysis: $e');
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    try {
      if (_currentCameraIndex >= _availableCameras.length) {
        return null;
      }

      final camera = _availableCameras[_currentCameraIndex];
      final sensorOrientation = camera.sensorOrientation;
      InputImageRotation rotation;

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        rotation =
            InputImageRotationValue.fromRawValue(sensorOrientation) ??
            InputImageRotation.rotation0deg;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        var rotationCompensation = _orientations[camera.lensDirection];
        if (rotationCompensation == null) return null;

        if (camera.lensDirection == CameraLensDirection.front) {
          rotationCompensation =
              (sensorOrientation + rotationCompensation) % 360;
        } else {
          rotationCompensation =
              (sensorOrientation - rotationCompensation + 360) % 360;
        }

        rotation =
            InputImageRotationValue.fromRawValue(rotationCompensation) ??
            InputImageRotation.rotation0deg;
      } else {
        rotation = InputImageRotation.rotation0deg;
      }

      // Get image format - more flexible handling
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) {
        return null;
      }

      // For iOS, ensure we have the right format
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          format != InputImageFormat.bgra8888) {
        return null;
      }

      // Handle different plane configurations
      if (image.planes.isEmpty) {
        return null;
      }

      // For single plane images (like NV21)
      if (image.planes.length == 1) {
        final plane = image.planes.first;
        return InputImage.fromBytes(
          bytes: plane.bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: format,
            bytesPerRow: plane.bytesPerRow,
          ),
        );
      }

      // For multi-plane images (like YUV420)
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
    }
  }

  // Updated orientation mappings
  final Map<CameraLensDirection, int> _orientations = {
    CameraLensDirection.back: 90,
    CameraLensDirection.front: 270,
    CameraLensDirection.external: 90,
  };

  Future<void> _switchCamera() async {
    if (_availableCameras.length <= 1 || _isSwitchingCamera) return;

    setState(() => _isSwitchingCamera = true);

    try {
      // Safely stop image stream before switching
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
        
        // Announce camera switch
        _speakFeedback("Switched to $cameraType camera");
      }
    } catch (e) {
      print('Camera switch error: $e');
      if (mounted) {
        _showErrorDialog('Camera Switch Error', 'Failed to switch camera: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSwitchingCamera = false);
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;

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

  Widget _buildOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.6),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.6),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildTopOverlay(),
            const Spacer(),
            _buildFeedbackOverlay(),
            _buildBottomOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopOverlay() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.5),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.exerciseName ?? 'Exercise Camera',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                // Add indicator for push-up mode
                if (_isPushUpExercise)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    
                  ),
              ],
            ),
          ),
          Row(
            children: [
              // Voice toggle button
              IconButton(
                onPressed: () {
                  setState(() {
                    if (_isVoiceEnabled) {
                      disableVoice();
                    } else {
                      enableVoice();
                    }
                  });
                },
                icon: Icon(
                  _isVoiceEnabled ? Icons.volume_up : Icons.volume_off,
                  color: _isVoiceEnabled ? Colors.white : Colors.grey,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.5),
                ),
                tooltip: _isVoiceEnabled ? 'Disable Voice' : 'Enable Voice',
              ),
              const SizedBox(width: 8),
              if (_availableCameras.length > 1)
                IconButton(
                  onPressed: _isSwitchingCamera ? null : _switchCamera,
                  icon: Icon(
                    Icons.flip_camera_ios,
                    color: _isSwitchingCamera ? Colors.grey : Colors.white,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.5),
                  ),
                  tooltip: 'Switch Camera',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackOverlay() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _feedbackColor.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _feedbackColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _currentFeedback,
                        style: TextStyle(
                          color: _feedbackColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Voice indicator
                    if (_isVoiceEnabled)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.volume_up,
                          color: Colors.green,
                          size: 16,
                        ),
                      ),
                  ],
                ),
                const Divider(color: Colors.white30, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildInfoChip('Reps', '$_repCount', Icons.repeat),
                    _buildInfoChip(
                      'Exercise',
                      _getShortExerciseName(),
                      Icons.fitness_center,
                    ),
                    _buildInfoChip(
                      'Voice',
                      _isVoiceEnabled ? 'On' : 'Off',
                      _isVoiceEnabled ? Icons.volume_up : Icons.volume_off,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getShortExerciseName() {
    final name = widget.exerciseName ?? 'N/A';
    return name.length > 8 ? '${name.substring(0, 8)}...' : name;
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomOverlay() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatCard('Time', _getSessionDuration(), Icons.timer),
            _buildStatCard(
              'Camera',
              _availableCameras.isNotEmpty
                  ? (_availableCameras[_currentCameraIndex].lensDirection ==
                            CameraLensDirection.front
                        ? 'Front'
                        : 'Back')
                  : 'N/A',
              Icons.camera,
            ),
            _buildStatCard(
              'Status',
              _isAnalyzing ? 'Active' : 'Ready',
              _isAnalyzing ? Icons.radio_button_checked : Icons.check_circle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: _isAnalyzing && label == 'Status'
              ? Colors.orange
              : Colors.white,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: _isAnalyzing && label == 'Status'
                ? Colors.orange
                : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  String _getSessionDuration() {
    if (_sessionStartTime == null) return '0:00';
    final duration = DateTime.now().difference(_sessionStartTime!);
    return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [_buildCameraPreview(), _buildOverlay()]),
    );
  }
}