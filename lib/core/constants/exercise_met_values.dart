import '../../models/exercise_record.dart';

class ExerciseMetValues {
  const ExerciseMetValues._();

  static const Map<ExerciseType, Map<ExerciseIntensity, double>> values = {
    ExerciseType.walking: {
      ExerciseIntensity.light: 2.8,
      ExerciseIntensity.moderate: 3.8,
      ExerciseIntensity.vigorous: 4.8,
    },
    ExerciseType.running: {
      ExerciseIntensity.light: 6.5,
      ExerciseIntensity.moderate: 9.3,
      ExerciseIntensity.vigorous: 11.0,
    },
    ExerciseType.cycling: {
      ExerciseIntensity.light: 4.3,
      ExerciseIntensity.moderate: 7.0,
      ExerciseIntensity.vigorous: 9.0,
    },
    ExerciseType.hiking: {
      ExerciseIntensity.light: 5.0,
      ExerciseIntensity.moderate: 5.3,
      ExerciseIntensity.vigorous: 7.8,
    },
    ExerciseType.swimming: {
      ExerciseIntensity.light: 5.8,
      ExerciseIntensity.moderate: 6.0,
      ExerciseIntensity.vigorous: 9.8,
    },
    ExerciseType.strengthTraining: {
      ExerciseIntensity.light: 3.5,
      ExerciseIntensity.moderate: 5.0,
      ExerciseIntensity.vigorous: 6.0,
    },
    ExerciseType.stationaryBike: {
      ExerciseIntensity.light: 3.5,
      ExerciseIntensity.moderate: 6.0,
      ExerciseIntensity.vigorous: 10.8,
    },
    ExerciseType.treadmill: {
      ExerciseIntensity.light: 3.5,
      ExerciseIntensity.moderate: 5.8,
      ExerciseIntensity.vigorous: 8.3,
    },
    ExerciseType.elliptical: {
      ExerciseIntensity.light: 5.0,
      ExerciseIntensity.moderate: 5.0,
      ExerciseIntensity.vigorous: 9.0,
    },
    ExerciseType.stairs: {
      ExerciseIntensity.light: 4.5,
      ExerciseIntensity.moderate: 6.8,
      ExerciseIntensity.vigorous: 9.3,
    },
    ExerciseType.yogaStretching: {
      ExerciseIntensity.light: 2.3,
      ExerciseIntensity.moderate: 2.7,
      ExerciseIntensity.vigorous: 4.0,
    },
    ExerciseType.other: {
      ExerciseIntensity.light: 2.5,
      ExerciseIntensity.moderate: 4.0,
      ExerciseIntensity.vigorous: 6.0,
    },
  };

  static double metFor(ExerciseType type, ExerciseIntensity intensity) {
    return values[type]![intensity]!;
  }

  static double? estimatedCalories({
    required double met,
    required double? weight,
    required int durationMinutes,
  }) {
    if (weight == null) {
      return null;
    }
    return met * weight * durationMinutes / 60;
  }
}
