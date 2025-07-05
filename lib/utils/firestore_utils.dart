// lib/services/firestore_utils.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreUtils {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Collection references
  static CollectionReference get exerciseSessions =>
      _firestore.collection('exercise_sessions');

  static CollectionReference get userExerciseStats =>
      _firestore.collection('user_exercise_stats');

  static CollectionReference get userDailyStats =>
      _firestore.collection('user_daily_stats');

  // Helper method to check if user is authenticated
  static bool get isAuthenticated => _auth.currentUser != null;

  // Helper method to get user-specific daily stats collection
  static CollectionReference? getUserDailyStatsCollection() {
    final user = currentUser;
    if (user == null) return null;

    return userDailyStats.doc(user.uid).collection('daily');
  }

  // Helper method to format date for Firestore
  static String formatDateForFirestore(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Helper method to get date range query
  static Query getDateRangeQuery(
    CollectionReference collection,
    String field,
    DateTime start,
    DateTime end,
  ) {
    return collection
        .where(field, isGreaterThanOrEqualTo: start)
        .where(field, isLessThanOrEqualTo: end);
  }

  // Helper method to safely get data from document
  static T? safeGet<T>(
    Map<String, dynamic>? data,
    String key, [
    T? defaultValue,
  ]) {
    if (data == null || !data.containsKey(key)) return defaultValue;

    final value = data[key];
    if (value is T) return value;

    return defaultValue;
  }

  // Helper method to batch update multiple documents
  static Future<void> batchUpdate(
    Map<DocumentReference, Map<String, dynamic>> updates,
  ) async {
    if (!isAuthenticated) {
      throw Exception('User must be authenticated to perform batch updates');
    }

    final batch = _firestore.batch();

    for (final entry in updates.entries) {
      batch.update(entry.key, entry.value);
    }

    try {
      await batch.commit();
    } catch (e) {
      debugPrint('Error in batch update: $e');
      rethrow;
    }
  }

  // Create or update exercise session
  static Future<String?> createExerciseSession({
    required String exerciseName,
    String? sessionId,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to create exercise session');
      return null;
    }

    try {
      final user = currentUser!;
      final sessionData = {
        'userId': user.uid,
        'exerciseName': exerciseName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'totalReps': 0,
        'sessionDuration': 0,
        ...?additionalData,
      };

      DocumentReference sessionRef;
      if (sessionId != null) {
        sessionRef = exerciseSessions.doc(sessionId);
        await sessionRef.set(sessionData, SetOptions(merge: true));
      } else {
        sessionRef = await exerciseSessions.add(sessionData);
      }

      debugPrint('Exercise session created/updated: ${sessionRef.id}');
      return sessionRef.id;
    } catch (e) {
      debugPrint('Error creating exercise session: $e');
      return null;
    }
  }

  // Update exercise session
  static Future<bool> updateExerciseSession(
    String sessionId,
    Map<String, dynamic> updateData,
  ) async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to update exercise session');
      return false;
    }

    try {
      final user = currentUser!;
      final sessionData = {
        ...updateData,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await exerciseSessions.doc(sessionId).update(sessionData);
      debugPrint('Exercise session updated: $sessionId');
      return true;
    } catch (e) {
      debugPrint('Error updating exercise session: $e');
      return false;
    }
  }

  // Complete exercise session
  static Future<bool> completeExerciseSession(
    String sessionId,
    Map<String, dynamic> finalData,
  ) async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to complete exercise session');
      return false;
    }

    try {
      final user = currentUser!;
      final sessionData = {
        ...finalData,
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await exerciseSessions.doc(sessionId).update(sessionData);
      debugPrint('Exercise session completed: $sessionId');
      return true;
    } catch (e) {
      debugPrint('Error completing exercise session: $e');
      return false;
    }
  }

  // Helper method to get user's exercise preferences
  static Future<Map<String, dynamic>?> getUserPreferences() async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to get preferences');
      return null;
    }

    try {
      final user = currentUser!;
      final doc = await _firestore
          .collection('user_preferences')
          .doc(user.uid)
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('Error getting user preferences: $e');
      return null;
    }
  }

  // Helper method to save user preferences
  static Future<bool> saveUserPreferences(
    Map<String, dynamic> preferences,
  ) async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to save preferences');
      return false;
    }

    try {
      final user = currentUser!;
      await _firestore.collection('user_preferences').doc(user.uid).set({
        ...preferences,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('User preferences saved successfully');
      return true;
    } catch (e) {
      debugPrint('Error saving user preferences: $e');
      return false;
    }
  }

  // Helper method to get exercise leaderboard
  static Future<List<Map<String, dynamic>>> getExerciseLeaderboard(
    String exerciseName, {
    int limit = 10,
  }) async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to view leaderboard');
      return [];
    }

    try {
      final query = await exerciseSessions
          .where('exerciseName', isEqualTo: exerciseName)
          .where('status', isEqualTo: 'completed')
          .orderBy('totalReps', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      debugPrint('Error getting leaderboard: $e');
      return [];
    }
  }

  // Helper method to check if user has completed exercise today
  static Future<bool> hasCompletedExerciseToday(String exerciseName) async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to check daily completion');
      return false;
    }

    try {
      final user = currentUser!;
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final query = await exerciseSessions
          .where('userId', isEqualTo: user.uid)
          .where('exerciseName', isEqualTo: exerciseName)
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
          .where('createdAt', isLessThan: endOfDay)
          .where('status', isEqualTo: 'completed')
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking daily completion: $e');
      return false;
    }
  }

  // Helper method to get user's exercise history
  static Future<List<Map<String, dynamic>>> getUserExerciseHistory(
    String exerciseName, {
    int limit = 10,
  }) async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to view exercise history');
      return [];
    }

    try {
      final user = currentUser!;
      final query = await exerciseSessions
          .where('userId', isEqualTo: user.uid)
          .where('exerciseName', isEqualTo: exerciseName)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      debugPrint('Error getting exercise history: $e');
      return [];
    }
  }

  // Helper method to get user's personal best
  static Future<Map<String, dynamic>?> getUserPersonalBest(
    String exerciseName,
  ) async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to view personal best');
      return null;
    }

    try {
      final user = currentUser!;
      final query = await exerciseSessions
          .where('userId', isEqualTo: user.uid)
          .where('exerciseName', isEqualTo: exerciseName)
          .where('status', isEqualTo: 'completed')
          .orderBy('totalReps', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return {
          'id': query.docs.first.id,
          ...query.docs.first.data() as Map<String, dynamic>,
        };
      }

      return null;
    } catch (e) {
      debugPrint('Error getting personal best: $e');
      return null;
    }
  }

  // Helper method to get user's achievements
  static Future<List<String>> getUserAchievements() async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to view achievements');
      return [];
    }

    try {
      final user = currentUser!;
      final doc = await _firestore
          .collection('user_achievements')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return List<String>.from(data['achievements'] ?? []);
      }

      return [];
    } catch (e) {
      debugPrint('Error getting user achievements: $e');
      return [];
    }
  }

  // Helper method to add achievement
  static Future<bool> addAchievement(String achievementId) async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to add achievement');
      return false;
    }

    try {
      final user = currentUser!;
      await _firestore.collection('user_achievements').doc(user.uid).set({
        'achievements': FieldValue.arrayUnion([achievementId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Achievement added: $achievementId');
      return true;
    } catch (e) {
      debugPrint('Error adding achievement: $e');
      return false;
    }
  }

  // Helper method to update daily stats
  static Future<bool> updateDailyStats(Map<String, dynamic> stats) async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to update daily stats');
      return false;
    }

    try {
      final user = currentUser!;
      final today = formatDateForFirestore(DateTime.now());

      await userDailyStats.doc(user.uid).collection('daily').doc(today).set({
        ...stats,
        'date': today,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Daily stats updated for: $today');
      return true;
    } catch (e) {
      debugPrint('Error updating daily stats: $e');
      return false;
    }
  }

  // Helper method to get user's daily stats
  static Future<Map<String, dynamic>?> getDailyStats([DateTime? date]) async {
    if (!isAuthenticated) {
      debugPrint('User must be authenticated to view daily stats');
      return null;
    }

    try {
      final user = currentUser!;
      final targetDate = formatDateForFirestore(date ?? DateTime.now());

      final doc = await userDailyStats
          .doc(user.uid)
          .collection('daily')
          .doc(targetDate)
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('Error getting daily stats: $e');
      return null;
    }
  }
}
