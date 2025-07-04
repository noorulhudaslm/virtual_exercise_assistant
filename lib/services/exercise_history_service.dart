import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class ExerciseHistoryService {
  static final ExerciseHistoryService _instance = ExerciseHistoryService._internal();
  factory ExerciseHistoryService() => _instance;
  ExerciseHistoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Add an exercise session to the user's history
  Future<bool> addExerciseSession({
    required String exerciseName,
    int? reps,
    int? sets,
    double? duration,
    String? notes,
    DateTime? customDate,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('No user logged in');
        return false;
      }

      final sessionData = {
        'exerciseName': exerciseName,
        'reps': reps,
        'sets': sets,
        'duration': duration,
        'notes': notes,
        'timestamp': customDate != null 
            ? Timestamp.fromDate(customDate)
            : FieldValue.serverTimestamp(),
        'date': DateFormat('yyyy-MM-dd').format(customDate ?? DateTime.now()),
        'userId': user.uid,
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('exercise_history')
          .add(sessionData);

      debugPrint('Exercise session added successfully: $exerciseName');
      return true;
    } catch (e) {
      debugPrint('Error adding exercise session: $e');
      return false;
    }
  }

  /// Get exercise history for the current user
  Stream<QuerySnapshot> getExerciseHistory({
    String? exerciseFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    Query query = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('exercise_history')
        .orderBy('timestamp', descending: true);

    // Apply exercise name filter
    if (exerciseFilter != null && exerciseFilter.isNotEmpty) {
      query = query.where('exerciseName', isEqualTo: exerciseFilter);
    }

    // Apply date range filter
    if (startDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
    }
    if (endDate != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: endDate);
    }

    // Apply limit
    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots();
  }

  /// Get exercise statistics for a specific exercise
  Future<Map<String, dynamic>> getExerciseStats(String exerciseName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('exercise_history')
          .where('exerciseName', isEqualTo: exerciseName)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return {
          'totalSessions': 0,
          'totalReps': 0,
          'totalSets': 0,
          'totalDuration': 0.0,
          'averageReps': 0.0,
          'averageSets': 0.0,
          'averageDuration': 0.0,
        };
      }

      int totalSessions = querySnapshot.docs.length;
      int totalReps = 0;
      int totalSets = 0;
      double totalDuration = 0.0;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        totalReps += (data['reps'] as int?) ?? 0;
        totalSets += (data['sets'] as int?) ?? 0;
        totalDuration += (data['duration'] as double?) ?? 0.0;
      }

      return {
        'totalSessions': totalSessions,
        'totalReps': totalReps,
        'totalSets': totalSets,
        'totalDuration': totalDuration,
        'averageReps': totalSessions > 0 ? totalReps / totalSessions : 0.0,
        'averageSets': totalSessions > 0 ? totalSets / totalSessions : 0.0,
        'averageDuration': totalSessions > 0 ? totalDuration / totalSessions : 0.0,
      };
    } catch (e) {
      debugPrint('Error getting exercise stats: $e');
      return {};
    }
  }

  /// Delete an exercise session
  Future<bool> deleteExerciseSession(String sessionId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('exercise_history')
          .doc(sessionId)
          .delete();

      return true;
    } catch (e) {
      debugPrint('Error deleting exercise session: $e');
      return false;
    }
  }

  /// Update an exercise session
  Future<bool> updateExerciseSession({
    required String sessionId,
    String? exerciseName,
    int? reps,
    int? sets,
    double? duration,
    String? notes,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      Map<String, dynamic> updates = {};
      if (exerciseName != null) updates['exerciseName'] = exerciseName;
      if (reps != null) updates['reps'] = reps;
      if (sets != null) updates['sets'] = sets;
      if (duration != null) updates['duration'] = duration;
      if (notes != null) updates['notes'] = notes;

      if (updates.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('exercise_history')
            .doc(sessionId)
            .update(updates);
      }

      return true;
    } catch (e) {
      debugPrint('Error updating exercise session: $e');
      return false;
    }
  }

  /// Get today's exercise sessions
  Stream<QuerySnapshot> getTodaysExercises() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('exercise_history')
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('timestamp', isLessThanOrEqualTo: endOfDay)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Get exercise streak (consecutive days with exercises)
  Future<int> getExerciseStreak() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final now = DateTime.now();
      int streak = 0;
      DateTime currentDate = DateTime(now.year, now.month, now.day);

      while (true) {
        final startOfDay = currentDate;
        final endOfDay = DateTime(currentDate.year, currentDate.month, currentDate.day, 23, 59, 59);

        final querySnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('exercise_history')
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .where('timestamp', isLessThanOrEqualTo: endOfDay)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          streak++;
          currentDate = currentDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      return streak;
    } catch (e) {
      debugPrint('Error calculating exercise streak: $e');
      return 0;
    }
  }

  /// Get weekly exercise summary
  Future<Map<String, int>> getWeeklyExerciseSummary() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('exercise_history')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .get();

      Map<String, int> summary = {};

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final exerciseName = data['exerciseName'] as String;
        summary[exerciseName] = (summary[exerciseName] ?? 0) + 1;
      }

      return summary;
    } catch (e) {
      debugPrint('Error getting weekly exercise summary: $e');
      return {};
    }
  }
}