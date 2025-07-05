import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraOverlays extends StatelessWidget {
  final bool isInitialized;
  final bool isSwitchingCamera;
  final List<CameraDescription> availableCameras;
  final int currentCameraIndex;
  final String? exerciseName;
  final String currentFeedback;
  final Color feedbackColor;
  final int repCount;
  final bool isAnalyzing;
  final bool isVoiceEnabled;
  final DateTime? sessionStartTime;
  final Animation<double> fadeAnimation;
  final VoidCallback onBackPressed;
  final VoidCallback onSwitchCamera;
  final VoidCallback onToggleVoice;

  const CameraOverlays({
    super.key,
    required this.isInitialized,
    required this.isSwitchingCamera,
    required this.availableCameras,
    required this.currentCameraIndex,
    required this.exerciseName,
    required this.currentFeedback,
    required this.feedbackColor,
    required this.repCount,
    required this.isAnalyzing,
    required this.isVoiceEnabled,
    required this.sessionStartTime,
    required this.fadeAnimation,
    required this.onBackPressed,
    required this.onSwitchCamera,
    required this.onToggleVoice,
  });

  @override
  Widget build(BuildContext context) {
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
            onPressed: onBackPressed,
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
                  exerciseName ?? 'Exercise Camera',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: onToggleVoice,
                icon: Icon(
                  isVoiceEnabled ? Icons.volume_up : Icons.volume_off,
                  color: isVoiceEnabled ? Colors.white : Colors.grey,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.5),
                ),
                tooltip: isVoiceEnabled ? 'Disable Voice' : 'Enable Voice',
              ),
              const SizedBox(width: 8),
              if (availableCameras.length > 1)
                IconButton(
                  onPressed: isSwitchingCamera ? null : onSwitchCamera,
                  icon: Icon(
                    Icons.flip_camera_ios,
                    color: isSwitchingCamera ? Colors.grey : Colors.white,
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
      animation: fadeAnimation,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: feedbackColor.withOpacity(0.5),
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
                        color: feedbackColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        currentFeedback,
                        style: TextStyle(
                          color: feedbackColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (isVoiceEnabled)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        child: const Icon(
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
                    _buildInfoChip('Reps', '$repCount', Icons.repeat),
                    _buildInfoChip(
                      'Exercise',
                      _getShortExerciseName(),
                      Icons.fitness_center,
                    ),
                    _buildInfoChip(
                      'Voice',
                      isVoiceEnabled ? 'On' : 'Off',
                      isVoiceEnabled ? Icons.volume_up : Icons.volume_off,
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
    final name = exerciseName ?? 'N/A';
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
              availableCameras.isNotEmpty
                  ? (availableCameras[currentCameraIndex].lensDirection ==
                            CameraLensDirection.front
                        ? 'Front'
                        : 'Back')
                  : 'N/A',
              Icons.camera,
            ),
            _buildStatCard(
              'Status',
              isAnalyzing ? 'Active' : 'Ready',
              isAnalyzing ? Icons.radio_button_checked : Icons.check_circle,
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
          color: isAnalyzing && label == 'Status'
              ? Colors.orange
              : Colors.white,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isAnalyzing && label == 'Status'
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
    if (sessionStartTime == null) return '0:00';
    final duration = DateTime.now().difference(sessionStartTime!);
    return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}