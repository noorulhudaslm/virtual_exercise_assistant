// lib/services/exercise_history_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../utils/firestore_utils.dart';

class ExerciseHistoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  // Get exercise history with optional date filtering
  Stream<QuerySnapshot> getExerciseHistory({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    if (!isAuthenticated) {
      return const Stream.empty();
    }

    final user = _auth.currentUser!;
    Query query = FirestoreUtils.exerciseSessions
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true); // Changed to createdAt

    // Apply date filters if provided
    if (startDate != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: startDate); // Changed to createdAt
    }
    if (endDate != null) {
      query = query.where('createdAt', isLessThanOrEqualTo: endDate); // Changed to createdAt
    }

    // Apply limit if provided
    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots();
  }

  // Add a new exercise session
  Future<bool> addExerciseSession({
    required String exerciseName,
    int? reps,
    int? sets,
    double? duration,
    String? notes,
  }) async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to add exercise session');
      return false;
    }

    try {
      final user = _auth.currentUser!;
      final sessionData = {
        'userId': user.uid,
        'exerciseName': exerciseName,
        'totalReps': reps ?? 0, // Changed from 'reps' to 'totalReps'
        'sets': sets,
        'sessionDuration': duration ?? 0, // Changed from 'duration' to 'sessionDuration'
        'notes': notes,
        'createdAt': FieldValue.serverTimestamp(), // Primary timestamp
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'completed',
      };

      await FirestoreUtils.exerciseSessions.add(sessionData);
      debugPrint('Exercise session added successfully');
      return true;
    } catch (e) {
      debugPrint('Error adding exercise session: $e');
      return false;
    }
  }

  // Update an existing exercise session
  Future<bool> updateExerciseSession({
    required String sessionId,
    String? exerciseName,
    int? reps,
    int? sets,
    double? duration,
    String? notes,
  }) async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to update exercise session');
      return false;
    }

    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (exerciseName != null) updateData['exerciseName'] = exerciseName;
      if (reps != null) updateData['totalReps'] = reps; // Changed to totalReps
      if (sets != null) updateData['sets'] = sets;
      if (duration != null) updateData['sessionDuration'] = duration; // Changed to sessionDuration
      if (notes != null) updateData['notes'] = notes;

      await FirestoreUtils.exerciseSessions.doc(sessionId).update(updateData);
      debugPrint('Exercise session updated successfully');
      return true;
    } catch (e) {
      debugPrint('Error updating exercise session: $e');
      return false;
    }
  }

  // Delete an exercise session
  Future<bool> deleteExerciseSession(String sessionId) async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to delete exercise session');
      return false;
    }

    try {
      await FirestoreUtils.exerciseSessions.doc(sessionId).delete();
      debugPrint('Exercise session deleted successfully');
      return true;
    } catch (e) {
      debugPrint('Error deleting exercise session: $e');
      return false;
    }
  }

  // Get exercise streak (consecutive days with at least one exercise)
  Future<int> getExerciseStreak() async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to get exercise streak');
      return 0;
    }

    try {
      final user = _auth.currentUser!;
      final now = DateTime.now();
      int streak = 0;

      // Check each day going backwards from today
      for (int i = 0; i < 365; i++) {
        final checkDate = now.subtract(Duration(days: i));
        final startOfDay = DateTime(checkDate.year, checkDate.month, checkDate.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        final query = await FirestoreUtils.exerciseSessions
            .where('userId', isEqualTo: user.uid)
            .where('createdAt', isGreaterThanOrEqualTo: startOfDay) // Changed to createdAt
            .where('createdAt', isLessThan: endOfDay) // Changed to createdAt
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          streak++;
        } else {
          // If this is the first day (today) and no exercises, streak is 0
          // Otherwise, break the streak count
          if (i == 0) {
            streak = 0;
          }
          break;
        }
      }

      return streak;
    } catch (e) {
      debugPrint('Error getting exercise streak: $e');
      return 0;
    }
  }

  // Get weekly exercise summary
  Future<Map<String, int>> getWeeklyExerciseSummary() async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to get weekly summary');
      return {};
    }

    try {
      final user = _auth.currentUser!;
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      final endOfWeek = startOfWeekDate.add(const Duration(days: 7));

      final query = await FirestoreUtils.exerciseSessions
          .where('userId', isEqualTo: user.uid)
          .where('createdAt', isGreaterThanOrEqualTo: startOfWeekDate) // Changed to createdAt
          .where('createdAt', isLessThan: endOfWeek) // Changed to createdAt
          .get();

      final summary = <String, int>{};
      for (final doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final exerciseName = data['exerciseName'] as String? ?? 'Unknown';
        summary[exerciseName] = (summary[exerciseName] ?? 0) + 1;
      }

      return summary;
    } catch (e) {
      debugPrint('Error getting weekly exercise summary: $e');
      return {};
    }
  }

  // Get total exercise count for a specific exercise
  Future<int> getExerciseCount(String exerciseName) async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to get exercise count');
      return 0;
    }

    try {
      final user = _auth.currentUser!;
      final query = await FirestoreUtils.exerciseSessions
          .where('userId', isEqualTo: user.uid)
          .where('exerciseName', isEqualTo: exerciseName)
          .get();

      return query.docs.length;
    } catch (e) {
      debugPrint('Error getting exercise count: $e');
      return 0;
    }
  }

  // Get personal best for a specific exercise
  Future<Map<String, dynamic>?> getPersonalBest(String exerciseName) async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to get personal best');
      return null;
    }

    try {
      final user = _auth.currentUser!;
      
      // Get best by reps
      final repsQuery = await FirestoreUtils.exerciseSessions
          .where('userId', isEqualTo: user.uid)
          .where('exerciseName', isEqualTo: exerciseName)
          .where('totalReps', isGreaterThan: 0) // Changed to totalReps
          .orderBy('totalReps', descending: true) // Changed to totalReps
          .limit(1)
          .get();

      // Get best by duration
      final durationQuery = await FirestoreUtils.exerciseSessions
          .where('userId', isEqualTo: user.uid)
          .where('exerciseName', isEqualTo: exerciseName)
          .where('sessionDuration', isGreaterThan: 0) // Changed to sessionDuration
          .orderBy('sessionDuration', descending: true) // Changed to sessionDuration
          .limit(1)
          .get();

      Map<String, dynamic>? bestReps;
      Map<String, dynamic>? bestDuration;

      if (repsQuery.docs.isNotEmpty) {
        bestReps = repsQuery.docs.first.data() as Map<String, dynamic>;
      }

      if (durationQuery.docs.isNotEmpty) {
        bestDuration = durationQuery.docs.first.data() as Map<String, dynamic>;
      }

      return {
        'bestReps': bestReps,
        'bestDuration': bestDuration,
      };
    } catch (e) {
      debugPrint('Error getting personal best: $e');
      return null;
    }
  }

  // Get exercise statistics for a specific time period
  Future<Map<String, dynamic>> getExerciseStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to get exercise stats');
      return {};
    }

    try {
      final user = _auth.currentUser!;
      Query query = FirestoreUtils.exerciseSessions
          .where('userId', isEqualTo: user.uid);

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: startDate); // Changed to createdAt
      }
      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: endDate); // Changed to createdAt
      }

      final querySnapshot = await query.get();
      final exercises = querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      int totalSessions = exercises.length;
      int totalReps = 0;
      int totalSets = 0;
      double totalDuration = 0;
      Map<String, int> exerciseFrequency = {};

      for (final exercise in exercises) {
        totalReps += (exercise['totalReps'] as int? ?? 0); // Changed to totalReps
        totalSets += (exercise['sets'] as int? ?? 0);
        totalDuration += (exercise['sessionDuration'] as double? ?? 0); // Changed to sessionDuration
        
        final exerciseName = exercise['exerciseName'] as String? ?? 'Unknown';
        exerciseFrequency[exerciseName] = (exerciseFrequency[exerciseName] ?? 0) + 1;
      }

      return {
        'totalSessions': totalSessions,
        'totalReps': totalReps,
        'totalSets': totalSets,
        'totalDuration': totalDuration,
        'exerciseFrequency': exerciseFrequency,
        'averageRepsPerSession': totalSessions > 0 ? totalReps / totalSessions : 0,
        'averageDurationPerSession': totalSessions > 0 ? totalDuration / totalSessions : 0,
      };
    } catch (e) {
      debugPrint('Error getting exercise stats: $e');
      return {};
    }
  }

  // Get exercises for a specific date
  Future<List<Map<String, dynamic>>> getExercisesForDate(DateTime date) async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to get exercises for date');
      return [];
    }

    try {
      final user = _auth.currentUser!;
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final query = await FirestoreUtils.exerciseSessions
          .where('userId', isEqualTo: user.uid)
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay) // Changed to createdAt
          .where('createdAt', isLessThan: endOfDay) // Changed to createdAt
          .orderBy('createdAt', descending: true) // Changed to createdAt
          .get();

      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
    } catch (e) {
      debugPrint('Error getting exercises for date: $e');
      return [];
    }
  }
}