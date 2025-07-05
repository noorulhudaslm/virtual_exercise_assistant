import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

class CameraScreen extends StatefulWidget {
  final String serverUrl;
  final CameraDescription? camera;
  final String? exerciseName;

  const CameraScreen({
    Key? key,
    this.serverUrl = 'http://192.168.1.200:8000', // Default server URL
    this.camera,
    this.exerciseName,
  }) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  WebSocketChannel? _webSocketChannel;
  bool _isCameraInitialized = false;
  bool _isConnected = false;
  bool _isProcessing = false;

  // Client ID for WebSocket connection
  final String _clientId = const Uuid().v4();

  // Frame processing
  Timer? _frameTimer;
  static const int _frameInterval = 100; // Send frame every 100ms

  // Prediction data
  String _currentExercise = 'No prediction';
  String? _targetExercise;
  double _confidence = 0.0;
  String _connectionStatus = 'Disconnected';
  bool _isTargetExercise = false;

  // Exercise colors for UI
  final Map<String, Color> _exerciseColors = {
    'Push-up': Colors.red,
    'Pull-up': Colors.blue,
    'Squat': Colors.green,
    'Deadlift': Colors.orange,
    'Bench Press': Colors.purple,
    'Lat Pulldown': Colors.teal,
    'Bicep Curl': Colors.indigo,
    'Tricep Pushdown': Colors.pink,
  };

  @override
  void initState() {
    super.initState();
    _targetExercise = widget.exerciseName;
    _initializeCamera();
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _webSocketChannel?.sink.close();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      // Request camera permission
      final permission = await Permission.camera.request();
      if (permission != PermissionStatus.granted) {
        setState(() {
          _connectionStatus = 'Camera permission denied';
        });
        return;
      }

      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _connectionStatus = 'No cameras available';
        });
        return;
      }

      // Use provided camera or default to first camera
      final selectedCamera = widget.camera ?? cameras.first;

      // Initialize camera controller
      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _connectionStatus = 'Camera initialized';
        });

        // Connect to WebSocket
        _connectWebSocket();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionStatus = 'Error initializing camera: $e';
        });
      }
    }
  }

  void _connectWebSocket() {
    try {
      // Fix: Use ws:// directly instead of converting from http://
      final wsUrl = 'ws://192.168.1.200:8000/ws/$_clientId';
      _webSocketChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      setState(() {
        _isConnected = true;
        _connectionStatus = 'Connected to server';
      });

      // Rest of the method remains the same...

      // Listen to WebSocket messages
      _webSocketChannel!.stream.listen(
        (message) {
          if (mounted) {
            _handleServerMessage(message);
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isConnected = false;
              _connectionStatus = 'WebSocket error: $error';
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isConnected = false;
              _connectionStatus = 'Connection closed';
            });
          }
        },
      );

      // Start sending frames
      _startFrameProcessing();
    } catch (e) {
      setState(() {
        _isConnected = false;
        _connectionStatus = 'Failed to connect: $e';
      });
    }
  }

  void _handleServerMessage(dynamic message) {
    if (!mounted) return;

    try {
      final data = json.decode(message);

      if (data['type'] == 'prediction' && data['data'] != null) {
        final predictionData = data['data'];

        setState(() {
          _currentExercise = predictionData['exercise_label'] ?? 'Unknown';
          _confidence = (predictionData['confidence'] ?? 0.0).toDouble();

          // Check if prediction matches target exercise
          if (_targetExercise != null) {
            _isTargetExercise =
                _currentExercise.toLowerCase() ==
                _targetExercise!.toLowerCase();
          }
        });
      }
    } catch (e) {
      print('Error parsing server message: $e');
    }
  }

  void _startFrameProcessing() {
    if (_frameTimer != null) {
      _frameTimer!.cancel();
    }

    _frameTimer = Timer.periodic(Duration(milliseconds: _frameInterval), (
      timer,
    ) {
      if (_isConnected &&
          !_isProcessing &&
          mounted &&
          _cameraController != null &&
          _cameraController!.value.isInitialized) {
        _captureAndSendFrame();
      }
    });
  }

  Future<void> _captureAndSendFrame() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        !mounted) {
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      // Capture image
      final XFile image = await _cameraController!.takePicture();
      final Uint8List imageBytes = await image.readAsBytes();

      // Check if still mounted before proceeding
      if (!mounted) return;

      // Convert to base64
      final String base64Image = base64Encode(imageBytes);

      // Prepare frame data
      final frameData = {
        'type': 'frame',
        'frame': base64Image,
        'timestamp': DateTime.now().millisecondsSinceEpoch / 1000.0,
      };

      // Send to server
      if (_webSocketChannel != null && _isConnected) {
        _webSocketChannel!.sink.add(json.encode(frameData));
      }
    } catch (e) {
      print('Error capturing frame: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _toggleConnection() {
    if (_isConnected) {
      _disconnect();
    } else {
      _connectWebSocket();
    }
  }

  void _disconnect() {
    _frameTimer?.cancel();
    _webSocketChannel?.sink.close();
    setState(() {
      _isConnected = false;
      _connectionStatus = 'Disconnected';
      _currentExercise = 'No prediction';
      _confidence = 0.0;
      _isTargetExercise = false;
    });
  }

  Color _getExerciseColor() {
    if (_targetExercise != null && _isTargetExercise && _confidence > 0.7) {
      return Colors
          .green; // Green when target exercise is detected with high confidence
    } else if (_targetExercise != null && !_isTargetExercise) {
      return Colors.orange; // Orange when wrong exercise is detected
    }
    return _exerciseColors[_currentExercise] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _targetExercise != null
              ? 'Detecting: $_targetExercise'
              : 'Exercise Detection',
        ),
        backgroundColor: _getExerciseColor(),
        actions: [
          IconButton(
            icon: Icon(_isConnected ? Icons.wifi : Icons.wifi_off),
            onPressed: _toggleConnection,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Camera Preview
            Expanded(flex: 3, child: _buildCameraPreview()),

            // Prediction Display
            Flexible(flex: 1, child: _buildPredictionDisplay()),

            // Status and Controls
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Initializing Camera...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height:
                  MediaQuery.of(context).size.width /
                  _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionDisplay() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _getExerciseColor().withOpacity(0.8),
            _getExerciseColor().withOpacity(0.4),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Target exercise display (if specified)
            if (_targetExercise != null) ...[
              Text(
                'Target: $_targetExercise',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
            ],

            // Current prediction
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _currentExercise,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (_targetExercise != null && _isTargetExercise) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, color: Colors.white, size: 24),
                ],
              ],
            ),

            const SizedBox(height: 8),
            Text(
              'Confidence: ${(_confidence * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _confidence,
              backgroundColor: Colors.white30,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isConnected ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.check_circle : Icons.error,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _connectionStatus,
                    style: TextStyle(
                      color: _isConnected
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Control Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton.icon(
                    onPressed: _toggleConnection,
                    icon: Icon(_isConnected ? Icons.stop : Icons.play_arrow),
                    label: Text(_isConnected ? 'Stop' : 'Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isConnected ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ElevatedButton.icon(
                    onPressed:
                        (_isCameraInitialized &&
                            _cameraController != null &&
                            _cameraController!.value.isInitialized)
                        ? _captureAndSendFrame
                        : null,
                    icon: const Icon(Icons.camera),
                    label: const Text('Capture'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Processing indicator
          if (_isProcessing)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Processing...'),
              ],
            ),
        ],
      ),
    );
  }
}
