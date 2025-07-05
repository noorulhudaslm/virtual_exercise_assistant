import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../services/video_processor.dart';

class VideoAnalysisScreen extends StatefulWidget {
  const VideoAnalysisScreen({super.key});

  @override
  State<VideoAnalysisScreen> createState() => _VideoAnalysisScreenState();
}

class _VideoAnalysisScreenState extends State<VideoAnalysisScreen> {
  final VideoProcessor _videoProcessor = VideoProcessor();
  final ImagePicker _imagePicker = ImagePicker();

  List<VideoProcessingResult> _results = [];
  Map<String, dynamic> _exerciseSummary = {};
  bool _isProcessing = false;
  bool _isInitialized = false;
  double _progress = 0.0;
  String _status = 'Ready to analyze video';
  String? _selectedVideoPath;
  String? _selectedVideoName;

  @override
  void initState() {
    super.initState();
    _initializeProcessor();
  }

  Future<void> _initializeProcessor() async {
    try {
      await _videoProcessor.initialize();
      setState(() {
        _isInitialized = true;
        _status = 'Ready to analyze video';
      });
    } catch (e) {
      setState(() {
        _isInitialized = true; // Still allow processing with fallback
        _status = 'Ready (using fallback detection)';
      });
      // Show warning about backend
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backend not available: $e. Using fallback detection.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _requestPermissions() async {
    // Request storage permissions - try both old and new permissions for compatibility
    List<Permission> permissions = [
      Permission.storage, // For older Android versions
      Permission.videos, // For Android 13+ (API 33+)
      Permission.photos, // For Android 13+ (API 33+)
    ];

    // Request all permissions
    Map<Permission, PermissionStatus> statuses = await permissions.request();

    // Check if we have at least one storage permission granted
    bool hasStoragePermission =
        statuses[Permission.storage] == PermissionStatus.granted ||
        statuses[Permission.videos] == PermissionStatus.granted ||
        statuses[Permission.photos] == PermissionStatus.granted;

    if (!hasStoragePermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Storage permissions are required to select videos. Please grant permission in settings.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: openAppSettings,
            ),
          ),
        );
      }
    }
  }

  Future<void> _selectVideo() async {
    await _requestPermissions();

    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10), // Limit to 10 minutes
      );

      if (video != null) {
        setState(() {
          _selectedVideoPath = video.path;
          _selectedVideoName = video.name;
          _status = 'Video selected: ${video.name}';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _analyzeVideo() async {
    if (_selectedVideoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a video first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _results.clear();
      _exerciseSummary.clear();
      _progress = 0.0;
      _status = 'Starting video analysis...';
    });

    try {
      // Listen to progress updates
      _videoProcessor.progressStream.listen((progress) {
        if (mounted) {
          setState(() {
            _progress = progress;
          });
        }
      });

      // Listen to results as they come in
      _videoProcessor.resultsStream.listen((result) {
        if (mounted) {
          setState(() {
            _results.add(result);
          });
        }
      });

      // Process the video
      final results = await _videoProcessor.processVideoFromPath(
        _selectedVideoPath!,
        onStatusUpdate: (status) {
          if (mounted) {
            setState(() {
              _status = status;
            });
          }
        },
        useFormDetection: true,
      );

      // Generate summary
      final summary = _videoProcessor.getExerciseSummary(results);

      if (mounted) {
        setState(() {
          _exerciseSummary = summary;
          _status = 'Analysis completed! Found ${results.length} results.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _cancelAnalysis() {
    _videoProcessor.cancelProcessing();
    setState(() {
      _isProcessing = false;
      _status = 'Analysis cancelled';
    });
  }

  void _clearResults() {
    setState(() {
      _results.clear();
      _exerciseSummary.clear();
      _selectedVideoPath = null;
      _selectedVideoName = null;
      _status = 'Ready to analyze video';
    });
  }

  @override
  void dispose() {
    _videoProcessor.cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Exercise Analysis'),
        backgroundColor: const Color(0xFF5494DD),
        foregroundColor: Colors.white,
        actions: [
          if (_results.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearResults,
              tooltip: 'Clear Results',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildControlPanel(),
          if (_isProcessing) _buildProgressIndicator(),
          if (_exerciseSummary.isNotEmpty) _buildSummaryCard(),
          Expanded(child: _buildResultsList()),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _status,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (_selectedVideoName != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.video_file, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedVideoName!,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _selectVideo,
                  icon: const Icon(Icons.video_library),
                  label: const Text('Select Video'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5494DD),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      (_isProcessing ||
                          _selectedVideoPath == null ||
                          !_isInitialized)
                      ? null
                      : _isProcessing
                      ? _cancelAnalysis
                      : _analyzeVideo,
                  icon: Icon(_isProcessing ? Icons.stop : Icons.play_arrow),
                  label: Text(_isProcessing ? 'Cancel' : 'Analyze'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isProcessing ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5494DD)),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_progress * 100).toStringAsFixed(1)}% Complete',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Colors.green),
              const SizedBox(width: 8),
              const Text(
                'Exercise Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(_exerciseSummary.entries.map((entry) {
            final exercise = entry.key;
            final data = entry.value as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      exercise,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${data['count']} frames',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${data['percentage']}%',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${(data['averageConfidence'] * 100).toStringAsFixed(1)}%',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: data['averageConfidence'] > 0.8
                            ? Colors.green
                            : data['averageConfidence'] > 0.6
                            ? Colors.orange
                            : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          })),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isProcessing ? Icons.hourglass_empty : Icons.video_library,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _isProcessing
                  ? 'Processing video...'
                  : 'No results yet. Select a video and start analysis.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        return _buildResultCard(result, index);
      },
    );
  }

  Widget _buildResultCard(VideoProcessingResult result, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: result.feedbackColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Frame ${result.frameNumber + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  result.timestamp.toString().substring(11, 19),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (result.exerciseName != null) ...[
              Text(
                'Exercise: ${result.exerciseName}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: result.confidence > 0.8
                          ? Colors.green
                          : result.confidence > 0.6
                          ? Colors.orange
                          : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  width: 60,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: Colors.grey[300],
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: result.confidence,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: result.feedbackColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (result.formFeedback != null) ...[
              const SizedBox(height: 8),
              Text(
                result.formFeedback!,
                style: TextStyle(color: result.feedbackColor, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}