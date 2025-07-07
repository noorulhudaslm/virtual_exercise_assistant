import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'simple_camera_screen.dart';
import '../widgets/exercise_icons.dart';

class ExerciseListScreen extends StatefulWidget {
  const ExerciseListScreen({super.key});

  @override
  State<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _iconController;
  late Animation<double> _titleAnimation;
  late Animation<double> _listAnimation;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  String? _cameraError;

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Move exercises list to a getter to avoid initialization issues
  List<Map<String, dynamic>> get exercises => [
    {
      'name': 'Push Ups',
      'description': 'Chest, shoulders, triceps',
      'color': const Color(0xFF00E5FF),
      'icon': PushUpIcon(controller: _iconController),
    },
    {
      'name': 'Pull Ups',
      'description': 'Back, biceps, lats',
      'color': const Color(0xFF1BFFFF),
      'icon': PullUpIcon(controller: _iconController),
    },
    {
      'name': 'Squats',
      'description': 'Legs, glutes, core',
      'color': const Color(0xFF00E5FF),
      'icon': SquatIcon(controller: _iconController),
    },
    {
      'name': 'Bicep Curls',
      'description': 'Biceps, forearms',
      'color': const Color(0xFF1BFFFF),
      'icon': BicepCurlIcon(controller: _iconController),
    },
    {
      'name': 'Tricep Pushdowns',
      'description': 'Triceps, shoulders',
      'color': const Color(0xFF00E5FF),
      'icon': TricepIcon(controller: _iconController),
    },
    {
      'name': 'Lat Pulldowns',
      'description': 'Lats, rhomboids, biceps',
      'color': const Color(0xFF1BFFFF),
      'icon': LatPulldownIcon(controller: _iconController),
    },
    {
      'name': 'Deadlifts',
      'description': 'Full body, hamstrings',
      'color': const Color(0xFF00E5FF),
      'icon': DeadliftIcon(controller: _iconController),
    },
    {
      'name': 'Bench Press',
      'description': 'Chest, shoulders, triceps',
      'color': const Color(0xFF1BFFFF),
      'icon': BenchPressIcon(controller: _iconController),
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeCamera();
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _titleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _listAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (mounted) {
        setState(() {
          _cameras = cameras;
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = 'Camera initialization failed: $e';
          _isCameraInitialized = false;
        });
      }
      debugPrint('Camera initialization error: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _iconController.dispose();
    super.dispose();
  }

  // Store exercise session in Firestore
  Future<String?> _storeExerciseSession(String exerciseName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showSnackBar('Please log in to track your exercises', Colors.orange);
        return null;
      }

      final sessionData = {
        'userId': user.uid,
        'exerciseName': exerciseName,
        'startTime': FieldValue.serverTimestamp(),
        'status': 'in_progress',
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore
          .collection('exercise_sessions')
          .add(sessionData);

      debugPrint('Exercise session stored with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error storing exercise session: $e');
      _showSnackBar('Failed to save exercise session: $e', Colors.red);
      return null;
    }
  }

  // Update exercise session when completed
  Future<void> _updateExerciseSession(
    String sessionId, {
    int? reps,
    int? sets,
    Duration? duration,
    String? status,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'endTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (reps != null) updateData['reps'] = reps;
      if (sets != null) updateData['sets'] = sets;
      if (duration != null) updateData['duration'] = duration.inSeconds;
      if (status != null) updateData['status'] = status;

      await _firestore
          .collection('exercise_sessions')
          .doc(sessionId)
          .update(updateData);

      debugPrint('Exercise session updated successfully');
    } catch (e) {
      debugPrint('Error updating exercise session: $e');
    }
  }

  // Store user exercise history/statistics
  Future<void> _updateUserExerciseStats(String exerciseName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userStatsRef = _firestore
          .collection('user_exercise_stats')
          .doc(user.uid);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(userStatsRef);

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final exerciseStats =
              data['exercises'] as Map<String, dynamic>? ?? {};

          if (exerciseStats.containsKey(exerciseName)) {
            final currentStats =
                exerciseStats[exerciseName] as Map<String, dynamic>;
            exerciseStats[exerciseName] = {
              'count': (currentStats['count'] ?? 0) + 1,
              'lastPerformed': FieldValue.serverTimestamp(),
              'firstPerformed': currentStats['firstPerformed'],
            };
          } else {
            exerciseStats[exerciseName] = {
              'count': 1,
              'lastPerformed': FieldValue.serverTimestamp(),
              'firstPerformed': FieldValue.serverTimestamp(),
            };
          }

          transaction.update(userStatsRef, {
            'exercises': exerciseStats,
            'totalSessions': (data['totalSessions'] ?? 0) + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(userStatsRef, {
            'userId': user.uid,
            'exercises': {
              exerciseName: {
                'count': 1,
                'lastPerformed': FieldValue.serverTimestamp(),
                'firstPerformed': FieldValue.serverTimestamp(),
              },
            },
            'totalSessions': 1,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      debugPrint('User exercise stats updated successfully');
    } catch (e) {
      debugPrint('Error updating user exercise stats: $e');
    }
  }

  Future<void> _openCamera(String exerciseName) async {
    if (!_isCameraInitialized) {
      _showSnackBar(
        _cameraError ?? 'Camera is not initialized yet. Please wait...',
        Colors.orange,
      );
      return;
    }

    if (_cameras == null || _cameras!.isEmpty) {
      _showSnackBar('No cameras available on this device', Colors.red);
      return;
    }

    // Store exercise session in Firestore
    _showSnackBar('Starting $exerciseName session...', Colors.blue);

    final sessionId = await _storeExerciseSession(exerciseName);
    if (sessionId == null) {
      // If storing session failed, still proceed with camera but show warning
      _showSnackBar(
        'Exercise session not saved, but proceeding...',
        Colors.orange,
      );
    }

    // Update user exercise stats
    await _updateUserExerciseStats(exerciseName);

    // Find front camera, fallback to first available
    CameraDescription? selectedCamera;
    try {
      selectedCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
    } catch (e) {
      selectedCamera = _cameras!.first;
    }

    if (!mounted) return;

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SimpleCameraScreen(
            camera: selectedCamera!,
            exerciseName: exerciseName,
            sessionId: sessionId, // Pass session ID to camera screen
          ),
        ),
      );

      // Update session when returning from camera
      if (sessionId != null && result != null) {
        await _updateExerciseSession(
          sessionId,
          status: result['status'] ?? 'completed',
          reps: result['reps'],
          sets: result['sets'],
          duration: result['duration'],
        );
      }
    } catch (e) {
      _showSnackBar('Failed to open camera: $e', Colors.red);

      // Update session as failed if it was created
      if (sessionId != null) {
        await _updateExerciseSession(sessionId, status: 'failed');
      }
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
              const SizedBox(height: 10),
              _buildAppBar(),
              Expanded(
                child: AnimatedBuilder(
                  animation: _listAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _listAnimation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(_listAnimation),
                        child: child,
                      ),
                    );
                  },
                  child: _buildExerciseList(),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 24,
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _titleAnimation,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _titleAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -1),
                      end: Offset.zero,
                    ).animate(_titleAnimation),
                    child: Text(
                      'CHOOSE EXERCISE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF00E5FF),
                        fontSize: MediaQuery.of(context).size.width * 0.05,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildExerciseList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: exercises.length,
        itemBuilder: (context, index) {
          final exercise = exercises[index];
          return _buildExerciseCard(exercise, index);
        },
      ),
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> exercise, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          splashColor: exercise['color'].withOpacity(0.3),
          highlightColor: exercise['color'].withOpacity(0.1),
          onTap: () => _openCamera(exercise['name']),
          child: Container(
            constraints: const BoxConstraints(minHeight: 80),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color.fromARGB(255, 100, 132, 192).withOpacity(0.8),
                  const Color.fromARGB(255, 100, 132, 192).withOpacity(0.6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: exercise['color'].withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                  spreadRadius: 1,
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildExerciseIcon(exercise),
                  const SizedBox(width: 16),
                  _buildExerciseInfo(exercise),
                  _buildExerciseActions(exercise),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseIcon(Map<String, dynamic> exercise) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.15),
        border: Border.all(color: exercise['color'].withOpacity(0.5), width: 2),
      ),
      child: Center(child: exercise['icon']),
    );
  }

  Widget _buildExerciseInfo(Map<String, dynamic> exercise) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            exercise['name'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            exercise['description'],
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseActions(Map<String, dynamic> exercise) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.camera_alt, size: 18, color: exercise['color']),
        const SizedBox(height: 8),
        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white70),
      ],
    );
  }
}
