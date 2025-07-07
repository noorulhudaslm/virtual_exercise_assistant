import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/exercise_history_service.dart';
import '../utils/firestore_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExerciseHistoryScreen extends StatefulWidget {
  const ExerciseHistoryScreen({super.key});

  @override
  State<ExerciseHistoryScreen> createState() => _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends State<ExerciseHistoryScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _iconController;
  late Animation<double> _titleAnimation;
  late Animation<double> _listAnimation;
  //  static final FirebaseAuth _auth = FirebaseAuth.instance;

  final ExerciseHistoryService _exerciseService = ExerciseHistoryService();

  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Today',
    'This Week',
    'This Month',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkAuthentication();
  }

  void _checkAuthentication() {
    if (!_exerciseService.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAuthenticationError();
      });
    }
  }

  void _showAuthenticationError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E3192),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Authentication Required',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Please log in to view your exercise history.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text('OK', style: TextStyle(color: Color(0xFF00E5FF))),
          ),
        ],
      ),
    );
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

  @override
  void dispose() {
    _controller.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _getExerciseHistory() {
    if (!_exerciseService.isAuthenticated) {
      return const Stream.empty();
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    Query query = FirebaseFirestore.instance
        .collection('exercise_sessions')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true);

    if (_selectedFilter != 'All') {
      DateTime now = DateTime.now();
      DateTime? startDate;
      DateTime? endDate;

      switch (_selectedFilter) {
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'This Week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
      }

      if (startDate != null && endDate != null) {
        query = query
            .where('createdAt', isGreaterThanOrEqualTo: startDate)
            .where('createdAt', isLessThanOrEqualTo: endDate);
      }
    }

    return query.limit(100).snapshots();
  }

  Future<void> addExerciseToHistory(
    String exerciseName, {
    int? reps,
    int? sets,
    double? duration,
    String? notes,
  }) async {
    if (!_exerciseService.isAuthenticated) {
      _showSnackBar('Please log in to add exercises', Colors.red);
      return;
    }

    final success = await _exerciseService.addExerciseSession(
      exerciseName: exerciseName,
      reps: reps,
      sets: sets,
      duration: duration,
      notes: notes,
    );

    if (success) {
      _showSnackBar('Exercise added successfully!', Colors.green);
    } else {
      _showSnackBar('Failed to add exercise', Colors.red);
    }
  }

  Future<void> _deleteExercise(String docId) async {
    if (!_exerciseService.isAuthenticated) {
      _showSnackBar('Please log in to delete exercises', Colors.red);
      return;
    }

    final success = await _exerciseService.deleteExerciseSession(docId);

    if (success) {
      _showSnackBar('Exercise deleted successfully', Colors.green);
    } else {
      _showSnackBar('Error deleting exercise', Colors.red);
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
            colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              _buildAppBar(),
              _buildFilterBar(),
              if (_exerciseService.isAuthenticated) _buildStatsSection(),
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
                  child: _buildExerciseHistoryList(),
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
                      'EXERCISE HISTORY',
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

  Widget _buildFilterBar() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filterOptions.length,
        itemBuilder: (context, index) {
          final option = _filterOptions[index];
          final isSelected = _selectedFilter == option;

          return Container(
            margin: const EdgeInsets.only(right: 10),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(25),
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: () {
                  setState(() {
                    _selectedFilter = option;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: isSelected
                        ? const Color(0xFF00E5FF).withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00E5FF)
                          : Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      option,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: IntrinsicHeight(
        // This makes both cards same height
        child: Row(
          children: [
            Expanded(
              child: FutureBuilder<int>(
                future: _exerciseService.getExerciseStreak(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildStatCard(
                      'Streak',
                      '...',
                      Icons.local_fire_department,
                    );
                  }
                  return _buildStatCard(
                    'Streak',
                    '${snapshot.data ?? 0} days',
                    Icons.local_fire_department,
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FutureBuilder<Map<String, int>>(
                future: _exerciseService.getWeeklyExerciseSummary(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildStatCard(
                      'This Week',
                      '...',
                      Icons.calendar_today,
                    );
                  }
                  final totalWeekly =
                      snapshot.data?.values.fold(0, (a, b) => a + b) ?? 0;
                  return _buildStatCard(
                    'This Week',
                    '$totalWeekly workouts',
                    Icons.calendar_today,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // Center the content
        mainAxisSize: MainAxisSize.min, // Take minimum space needed
        children: [
          Icon(icon, color: const Color(0xFF00E5FF), size: 20), // Smaller icon
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14, // Smaller font
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10, // Smaller font
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseHistoryList() {
    if (!_exerciseService.isAuthenticated) {
      return _buildAuthenticationRequired();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _getExerciseHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.white.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading history',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please check your internet connection and try again',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Trigger rebuild
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final exercises = snapshot.data!.docs;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              final data = exercise.data() as Map<String, dynamic>;
              return _buildExerciseHistoryCard(exercise.id, data);
            },
          ),
        );
      },
    );
  }

  Widget _buildAuthenticationRequired() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'Authentication Required',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Please log in to view your exercise history',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text(
            'No Exercise History',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _selectedFilter == 'All'
                ? 'Start exercising to see your history here'
                : 'No exercises found for $_selectedFilter',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseHistoryCard(String docId, Map<String, dynamic> data) {
    final timestamp = data['createdAt'] as Timestamp?; // Keep as createdAt
    final date = timestamp?.toDate() ?? DateTime.now();
    final exerciseName = data['exerciseName'] as String? ?? 'Unknown Exercise';
    final reps = data['totalReps'] as int?; // Changed to totalReps
    final sets = data['sets'] as int?;
    final duration = (data['sessionDuration'] as num?)?.toDouble();
    final notes = data['notes'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Container(
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
                color: const Color(0xFF00E5FF).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
                spreadRadius: 1,
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildExerciseIcon(exerciseName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exerciseName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM dd, yyyy - hh:mm a').format(date),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Colors.white70,
                        size: 20,
                      ),
                      color: const Color(0xFF2E3192),
                      onSelected: (value) {
                        if (value == 'delete') {
                          _showDeleteConfirmation(docId, exerciseName);
                        } else if (value == 'edit') {
                          _showEditDialog(docId, data);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.white70, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Edit',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (reps != null || sets != null || duration != null) ...[
                  const SizedBox(height: 12),
                  _buildExerciseStats(reps, sets, duration),
                ],
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      notes,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseIcon(String exerciseName) {
    IconData iconData;
    switch (exerciseName.toLowerCase()) {
      case 'push ups':
        iconData = Icons.accessibility_new;
        break;
      case 'pull ups':
        iconData = Icons.fitness_center;
        break;
      case 'squats':
        iconData = Icons.directions_run;
        break;
      case 'bicep curls':
        iconData = Icons.fitness_center;
        break;
      case 'tricep pushdowns':
        iconData = Icons.fitness_center;
        break;
      case 'lat pulldowns':
        iconData = Icons.fitness_center;
        break;
      case 'deadlifts':
        iconData = Icons.fitness_center;
        break;
      case 'bench press':
        iconData = Icons.fitness_center;
        break;
      default:
        iconData = Icons.sports_gymnastics;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.15),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Icon(iconData, size: 20, color: const Color(0xFF00E5FF)),
    );
  }

  Widget _buildExerciseStats(int? reps, int? sets, double? duration) {
    return Row(
      children: [
        if (sets != null) ...[
          _buildStatChip('Sets', sets.toString()),
          const SizedBox(width: 8),
        ],
        if (reps != null) ...[
          _buildStatChip('Reps', reps.toString()),
          const SizedBox(width: 8),
        ],
        if (duration != null) ...[
          _buildStatChip('Duration', '${duration.toStringAsFixed(1)}s'),
        ],
      ],
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String docId, String exerciseName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E3192),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Exercise',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this $exerciseName session?',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteExercise(docId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(String docId, Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['exerciseName']);
    final repsController = TextEditingController(
      text: data['totalReps']?.toString() ?? '', // Changed to totalReps
    );
    final setsController = TextEditingController(
      text: data['sets']?.toString() ?? '',
    );
    final durationController = TextEditingController(
      text:
          data['sessionDuration']?.toString() ??
          '', // Changed to sessionDuration
    );
    final notesController = TextEditingController(text: data['notes'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E3192),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit Exercise',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Exercise Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                ),
              ),
              TextField(
                controller: repsController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Reps',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                ),
              ),
              TextField(
                controller: setsController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sets',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                ),
              ),
              TextField(
                controller: durationController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (seconds)',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                ),
              ),
              TextField(
                controller: notesController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          TextButton(
            onPressed: () async {
              final success = await _exerciseService.updateExerciseSession(
                sessionId: docId,
                exerciseName: nameController.text.isNotEmpty
                    ? nameController.text
                    : null,
                reps: repsController.text.isNotEmpty
                    ? int.tryParse(repsController.text)
                    : null,
                sets: setsController.text.isNotEmpty
                    ? int.tryParse(setsController.text)
                    : null,
                duration: durationController.text.isNotEmpty
                    ? double.tryParse(durationController.text)
                    : null,
                notes: notesController.text.isNotEmpty
                    ? notesController.text
                    : null,
              );

              Navigator.pop(context);

              if (success) {
                _showSnackBar('Exercise updated successfully!', Colors.green);
              } else {
                _showSnackBar('Failed to update exercise', Colors.red);
              }
            },
            child: const Text(
              'Update',
              style: TextStyle(color: Color(0xFF00E5FF)),
            ),
          ),
        ],
      ),
    );
  }
}
