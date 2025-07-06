import 'muscle_groups.dart';

// Re-export existing types for convenience
export 'muscle_groups.dart';

// Extension to add display names to existing enums
extension ExerciseMuscleGroupExtension on ExerciseMuscleGroup {
  String get displayName {
    switch (this) {
      case ExerciseMuscleGroup.abdominals:
        return 'Abdominals';
      case ExerciseMuscleGroup.abductors:
        return 'Abductors';
      case ExerciseMuscleGroup.adductors:
        return 'Adductors';
      case ExerciseMuscleGroup.biceps:
        return 'Biceps';
      case ExerciseMuscleGroup.calves:
        return 'Calves';
      case ExerciseMuscleGroup.chest:
        return 'Chest';
      case ExerciseMuscleGroup.forearms:
        return 'Forearms';
      case ExerciseMuscleGroup.glutes:
        return 'Glutes';
      case ExerciseMuscleGroup.hamstrings:
        return 'Hamstrings';
      case ExerciseMuscleGroup.lats:
        return 'Lats';
      case ExerciseMuscleGroup.lower_back:
        return 'Lower Back';
      case ExerciseMuscleGroup.middle_back:
        return 'Middle Back';
      case ExerciseMuscleGroup.neck:
        return 'Neck';
      case ExerciseMuscleGroup.quadriceps:
        return 'Quadriceps';
      case ExerciseMuscleGroup.traps:
        return 'Traps';
      case ExerciseMuscleGroup.triceps:
        return 'Triceps';
    }
  }
}

extension ExerciseTypeExtension on ExerciseType {
  String get displayName {
    switch (this) {
      case ExerciseType.cardio:
        return 'Cardio';
      case ExerciseType.olympic_weightlifting:
        return 'Olympic Weightlifting';
      case ExerciseType.plyometrics:
        return 'Plyometrics';
      case ExerciseType.powerlifting:
        return 'Powerlifting';
      case ExerciseType.strength:
        return 'Strength';
      case ExerciseType.stretching:
        return 'Stretching';
      case ExerciseType.strongman:
        return 'Strongman';
    }
  }
}

extension ExerciseDifficultyExtension on ExerciseDifficulty {
  String get displayName {
    switch (this) {
      case ExerciseDifficulty.beginner:
        return 'Beginner';
      case ExerciseDifficulty.intermediate:
        return 'Intermediate';
      case ExerciseDifficulty.expert:
        return 'Expert';
    }
  }
}
