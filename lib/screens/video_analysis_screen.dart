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
      // Listen to progress updates with proper type conversion
      _videoProcessor.progressStream.listen((progress) {
        if (mounted) {
          setState(() {
            // Safe conversion to double
            _progress = _toDouble(progress);
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

      // Generate summary with safe type conversion
      final summary = _videoProcessor.getExerciseSummary(results);
      final safeSummary = _convertSummaryTypes(summary);

      if (mounted) {
        setState(() {
          _exerciseSummary = safeSummary;
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

  // Helper method to safely convert numbers to double
  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  // Helper method to safely convert summary data types
  Map<String, dynamic> _convertSummaryTypes(Map<String, dynamic> summary) {
    Map<String, dynamic> safeSummary = {};
    
    for (var entry in summary.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is Map<String, dynamic>) {
        Map<String, dynamic> safeValue = {};
        for (var innerEntry in value.entries) {
          final innerKey = innerEntry.key;
          final innerValue = innerEntry.value;
          
          if (innerKey == 'count') {
            // Count should be an int
            safeValue[innerKey] = _toInt(innerValue);
          } else if (innerKey == 'averageConfidence') {
            // Confidence should be a double
            safeValue[innerKey] = _toDouble(innerValue);
          } else {
            safeValue[innerKey] = innerValue;
          }
        }
        safeSummary[key] = safeValue;
      } else {
        safeSummary[key] = value;
      }
    }
    
    return safeSummary;
  }

  // Helper method to safely convert numbers to int
  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        try {
          return double.parse(value).round();
        } catch (e) {
          return 0;
        }
      }
    }
    return 0;
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2E3192), // Deep purple
              Color(0xFF1BFFFF), // Cyan
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildControlPanel(),
                        const SizedBox(height: 20),
                        if (_isProcessing) _buildProgressCard(),
                        if (_exerciseSummary.isNotEmpty) _buildSummaryCard(),
                        if (_results.isNotEmpty) _buildResultsCard(),
                        if (_results.isEmpty && !_isProcessing) _buildEmptyState(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Video Exercise Analysis',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_results.isNotEmpty)
            IconButton(
              onPressed: _clearResults,
              icon: const Icon(
                Icons.refresh,
                color: Colors.white,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x40FFFFFF),
            Color(0x20FFFFFF),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            _status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (_selectedVideoName != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0x30FFFFFF),
                    Color(0x10FFFFFF),
                  ],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.video_file,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedVideoName!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.video_library,
                  label: 'Select Video',
                  onPressed: _isProcessing ? null : _selectVideo,
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: _isProcessing ? Icons.stop : Icons.play_arrow,
                  label: _isProcessing ? 'Cancel' : 'Analyze',
                  onPressed: (_isProcessing ||
                          _selectedVideoPath == null ||
                          !_isInitialized)
                      ? null
                      : _isProcessing
                          ? _cancelAnalysis
                          : _analyzeVideo,
                  isPrimary: false,
                  isDestructive: _isProcessing,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isPrimary = false,
    bool isDestructive = false,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? null
            : isDestructive
                ? const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF5252)],
                  )
                : isPrimary
                    ? const LinearGradient(
                        colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF66BB6A), Color(0xFF4CAF50)],
                      ),
        color: onPressed == null ? Colors.white.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: onPressed == null
                    ? Colors.white.withOpacity(0.5)
                    : Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: onPressed == null
                        ? Colors.white.withOpacity(0.5)
                        : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x40FFFFFF),
            Color(0x20FFFFFF),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Processing Video',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${(_progress * 100).toStringAsFixed(1)}% Complete',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x40FFFFFF),
            Color(0x20FFFFFF),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Exercise Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...(_exerciseSummary.entries.map((entry) {
            final exercise = entry.key;
            final data = entry.value as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0x20FFFFFF),
                    Color(0x10FFFFFF),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      exercise,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${_toInt(data['count'])}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    '${(_toDouble(data['averageConfidence']) * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
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

  Widget _buildResultsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x40FFFFFF),
            Color(0x20FFFFFF),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.list,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Results (${_results.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                return _buildResultItem(result, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(VideoProcessingResult result, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x20FFFFFF),
            Color(0x10FFFFFF),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Frame ${_toInt(result.frameNumber) + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                result.timestamp.toString().substring(11, 19),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (result.exerciseName != null)
            Text(
              'Exercise: ${result.exerciseName}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Confidence: ${(_toDouble(result.confidence) * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: Colors.white.withOpacity(0.3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _toDouble(result.confidence),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.white,
                      ),
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
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x40FFFFFF),
            Color(0x20FFFFFF),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.video_library,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No results yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a video and start analysis to see results',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}