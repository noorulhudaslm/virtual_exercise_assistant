import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_screen_state.dart';

class SimpleCameraScreen extends StatefulWidget {
  final CameraDescription? camera;
  final String? exerciseName;
  final String? sessionId;

  const SimpleCameraScreen({super.key, this.camera, this.exerciseName, this.sessionId,});

  @override
  State<SimpleCameraScreen> createState() => _SimpleCameraScreenState();
}

class _SimpleCameraScreenState extends CameraScreenState {
  // State implementation is now in camera_screen_state.dart
}