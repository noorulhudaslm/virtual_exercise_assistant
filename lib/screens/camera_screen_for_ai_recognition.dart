import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:uuid/uuid.dart';

class CameraScreen extends StatefulWidget {
  final CameraDescription? camera;
  final String? exerciseName;

  const CameraScreen({super.key, this.camera, this.exerciseName});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isProcessing = false;

  // Camera switching
  List<CameraDescription> _availableCameras = [];
  int _currentCameraIndex = 0;
  bool _isSwitchingCamera = false;

  // FastAPI WebSocket configuration
  static const String serverUrl = 'http://192.168.1.5:5000/predict'; // Updated to port 8000
  static const String wsUrl = 'ws://192.168.1.195:8000'; // WebSocket URL
  WebSocketChannel? _channel;
  String _clientId = '';
  Timer? _captureTimer;
  bool _isServerReady = false;
  bool _isConnected = false;

  // Classification results
  String _currentExercise = 'No exercise detected';
  double _confidence = 0.0;
  String _status = 'Connecting...';
  int _exerciseClass = -1;

  // UI State
  int _frameCount = 0;
  int _repCount = 0;
  String _lastExercise = '';
  DateTime? _lastPredictionTime;

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Exercise session tracking
  DateTime? _sessionStartTime;
  Map<String, int> _exerciseCounts = {};

  // Prediction smoothing
  List<Map<String, dynamic>> _predictionHistory = [];
  static const int maxHistoryLength = 5;

  // Frame processing optimization
  int _currentFPS = 3; // Start with 3 FPS for WebSocket
  static const int minFPS = 1;
  static const int maxFPS = 5;
  bool _isCapturing = false;

  // Available exercise names (matching FastAPI)
  final List<String> _exerciseNames = [
    "Push-up", "Pull-up", "Squat", "Deadlift", 
    "Bench Press", "Lat Pulldown", "Bicep Curl", "Tricep Pushdown"
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clientId = const Uuid().v4();
    _initializeAnimations();
    _requestPermissions().then((_) {
      _initializeCameras();
    });
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera].request();
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
    _disconnectWebSocket();
    _captureTimer?.cancel();
    _fadeController.dispose();
    _cameraController?.dispose();
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
        _stopExerciseRecognition();
        _disconnectWebSocket();
        cameraController.dispose();
        setState(() => _isInitialized = false);
        break;
      case AppLifecycleState.resumed:
        _initializeCamera();
        break;
      case AppLifecycleState.inactive:
        _stopExerciseRecognition();
        break;
      default:
        break;
    }
  }

  Future<void> _initializeCameras() async {
    try {
      _availableCameras = await availableCameras();

      // Find the front camera by default
      _currentCameraIndex = _availableCameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      if (_currentCameraIndex == -1) {
        _currentCameraIndex = 0;
      }

      await _initializeCamera();
    } catch (e) {
      print('Failed to initialize cameras: $e');
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

      await _cameraController?.dispose();

      _cameraController = CameraController(
        _availableCameras[_currentCameraIndex],
        ResolutionPreset.medium, // Medium resolution for better quality
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
        _checkServerHealth().then((_) {
          if (_isServerReady) {
            _connectWebSocket();
          }
        });
      }
    } catch (e) {
      print('Camera initialization error: $e');
      if (mounted) {
        _showErrorDialog('Camera Error', 'Failed to initialize camera: $e');
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length <= 1 || _isSwitchingCamera) return;

    setState(() {
      _isSwitchingCamera = true;
    });

    try {
      _stopExerciseRecognition();
      _currentCameraIndex = (_currentCameraIndex + 1) % _availableCameras.length;
      
      setState(() {
        _isInitialized = false;
      });

      await _initializeCamera();

      if (mounted) {
        final cameraType = _availableCameras[_currentCameraIndex].lensDirection ==
                CameraLensDirection.front ? 'Front' : 'Back';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to $cameraType Camera'),
            duration: const Duration(seconds: 1),
            backgroundColor: const Color(0xFF5494DD),
          ),
        );
      }
    } catch (e) {
      print('Camera switch error: $e');
      if (mounted) {
        _showErrorDialog('Camera Switch Error', 'Failed to switch camera: $e');
      }
    } finally {
      setState(() {
        _isSwitchingCamera = false;
      });
    }
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
        final data = json.decode(response.body);
        setState(() {
          _isServerReady = data['status'] == 'healthy';
          _status = _isServerReady ? 'Server ready' : 'Server not ready';
        });
      } else {
        setState(() {
          _isServerReady = false;
          _status = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isServerReady = false;
        _status = 'Server unavailable: $e';
      });
      // Schedule a retry
      Future.delayed(const Duration(seconds: 5), _checkServerHealth);
    }
  }

  Future<void> _connectWebSocket() async {
    try {
      setState(() {
        _status = 'Connecting to WebSocket...';
      });

      _channel = IOWebSocketChannel.connect(
        Uri.parse('$wsUrl/ws/$_clientId'),
        headers: {},
      );

      // Listen for messages
      _channel!.stream.listen(
        (message) {
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          print('WebSocket error: $error');
          setState(() {
            _isConnected = false;
            _status = 'WebSocket error: $error';
          });
          _reconnectWebSocket();
        },
        onDone: () {
          print('WebSocket connection closed');
          setState(() {
            _isConnected = false;
            _status = 'Connection closed';
          });
        },
      );

      setState(() {
        _isConnected = true;
        _status = 'Connected to WebSocket';
      });

      // Start frame capture after connection
      _startFrameCapture();

    } catch (e) {
      print('WebSocket connection error: $e');
      setState(() {
        _isConnected = false;
        _status = 'Connection failed: $e';
      });
      _reconnectWebSocket();
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = json.decode(message);
      
      if (data['type'] == 'prediction') {
        final predictionData = data['data'];
        
        setState(() {
          _exerciseClass = predictionData['class'];
          _currentExercise = predictionData['label'];
          _confidence = predictionData['confidence'];
          _lastPredictionTime = DateTime.now();
          
          // Update status with confidence
          if (_confidence > 0.8) {
            _status = 'High confidence detection';
          } else if (_confidence > 0.6) {
            _status = 'Moderate confidence detection';
          } else {
            _status = 'Low confidence detection';
          }
        });

        // Update exercise stats
        _updateExerciseStats(_currentExercise, _confidence);
        
        // Add to prediction history for smoothing
        _predictionHistory.add({
          'exercise': _currentExercise,
          'confidence': _confidence,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        
        if (_predictionHistory.length > maxHistoryLength) {
          _predictionHistory.removeAt(0);
        }
      }
    } catch (e) {
      print('Error parsing WebSocket message: $e');
    }
  }

  void _reconnectWebSocket() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isServerReady && !_isConnected) {
        _connectWebSocket();
      }
    });
  }

  void _disconnectWebSocket() {
    _channel?.sink.close();
    _channel = null;
    setState(() {
      _isConnected = false;
    });
  }

  Future<void> _startFrameCapture() async {
    if (!_isConnected || _isCapturing) return;

    setState(() {
      _frameCount = 0;
      _sessionStartTime = DateTime.now();
      _status = 'Starting frame capture...';
    });

    _captureTimer = Timer.periodic(
      Duration(milliseconds: (1000 / _currentFPS).round()),
      (timer) => _captureAndSendFrame(),
    );

    _isCapturing = true;
  }

  Future<void> _captureAndSendFrame() async {
    if (!_isInitialized || 
        _cameraController == null || 
        !_isConnected || 
        _isProcessing) return;

    _isProcessing = true;

    try {
      final XFile image = await _cameraController!.takePicture();
      final Uint8List imageBytes = await image.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      // Send frame via WebSocket
      final frameData = {
        'frame': base64Image,
        'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
      };

      _channel?.sink.add(json.encode(frameData));

      setState(() {
        _frameCount++;
      });

    } catch (e) {
      print('Frame capture error: $e');
      setState(() {
        _status = 'Frame capture error: $e';
      });
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _stopExerciseRecognition() async {
    _captureTimer?.cancel();
    _isCapturing = false;
    setState(() {
      _status = 'Stopped';
    });
  }

  void _updateExerciseStats(String exercise, double confidence) {
    // Count reps when exercise changes with good confidence
    if (confidence > 0.7 &&
        exercise != _lastExercise &&
        exercise != 'No exercise detected' &&
        exercise.isNotEmpty) {
      
      setState(() {
        _repCount++;
        _exerciseCounts[exercise] = (_exerciseCounts[exercise] ?? 0) + 1;
      });
      
      _lastExercise = exercise;
      
      // Show rep count feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$exercise Rep #$_repCount'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // UI Building Methods
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
            _buildBottomOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopOverlay() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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
                child: Center(
                  child: Text(
                    widget.exerciseName ?? 'Exercise Recognition',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isConnected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isConnected ? Icons.wifi : Icons.wifi_off,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildExerciseInfo(),
        ],
      ),
    );
  }

  Widget _buildExerciseInfo() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _confidence > 0.8 ? Colors.green : Colors.white30,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isCapturing ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_lastPredictionTime != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Live',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const Divider(color: Colors.white30),
                Row(
                  children: [
                    const Icon(
                      Icons.fitness_center,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentExercise,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (_confidence > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Confidence: ${(_confidence * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 60,
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: Colors.white30,
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _confidence,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: _confidence > 0.8
                                  ? Colors.green
                                  : _confidence > 0.6
                                      ? Colors.orange
                                      : Colors.red,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('Reps', _repCount.toString(), Icons.fitness_center),
                _buildStatCard('Time', _getSessionDuration(), Icons.timer),
                _buildStatCard('FPS', _currentFPS.toString(), Icons.speed),
                _buildStatCard('Frames', _frameCount.toString(), Icons.camera),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnected && !_isCapturing 
                        ? _startFrameCapture 
                        : _isCapturing 
                            ? _stopExerciseRecognition 
                            : null,
                    icon: Icon(_isCapturing ? Icons.stop : Icons.play_arrow),
                    label: Text(_isCapturing ? 'Stop' : 'Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCapturing ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnected ? null : _connectWebSocket,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reconnect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5494DD),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
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
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
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
      body: Stack(
        children: [
          _buildCameraPreview(),
          _buildOverlay(),
        ],
      ),
    );
  }
}