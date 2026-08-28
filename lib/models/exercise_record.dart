enum ExerciseIntensity {
  light('light', '가볍게'),
  moderate('moderate', '보통'),
  vigorous('vigorous', '강하게');

  const ExerciseIntensity(this.value, this.label);

  final String value;
  final String label;

  static ExerciseIntensity fromValue(String value) {
    for (final intensity in ExerciseIntensity.values) {
      if (intensity.value == value) {
        return intensity;
      }
    }
    throw ArgumentError('Unknown exercise intensity: $value');
  }
}

enum ExerciseType {
  walking('walking', '걷기'),
  running('running', '달리기'),
  cycling('cycling', '자전거'),
  hiking('hiking', '등산'),
  swimming('swimming', '수영'),
  strengthTraining('strengthTraining', '근력운동'),
  stationaryBike('stationaryBike', '실내자전거'),
  treadmill('treadmill', '러닝머신'),
  elliptical('elliptical', '일립티컬'),
  stairs('stairs', '계단운동'),
  yogaStretching('yogaStretching', '요가·스트레칭'),
  other('other', '기타');

  const ExerciseType(this.value, this.label);

  final String value;
  final String label;

  static ExerciseType fromValue(String value) {
    for (final type in ExerciseType.values) {
      if (type.value == value) {
        return type;
      }
    }
    throw ArgumentError('Unknown exercise type: $value');
  }
}

class ExerciseRecord {
  const ExerciseRecord({
    required this.id,
    required this.date,
    required this.exerciseType,
    required this.durationMinutes,
    required this.intensity,
    required this.weightSnapshot,
    required this.metSnapshot,
    required this.estimatedCalories,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final DateTime date;
  final ExerciseType exerciseType;
  final int durationMinutes;
  final ExerciseIntensity intensity;
  final double? weightSnapshot;
  final double metSnapshot;
  final double? estimatedCalories;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get dateKey => formatDateKey(date);

  ExerciseRecord copyWith({
    String? id,
    DateTime? date,
    ExerciseType? exerciseType,
    int? durationMinutes,
    ExerciseIntensity? intensity,
    double? weightSnapshot,
    double? metSnapshot,
    double? estimatedCalories,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearWeightSnapshot = false,
    bool clearEstimatedCalories = false,
  }) {
    return ExerciseRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      exerciseType: exerciseType ?? this.exerciseType,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      intensity: intensity ?? this.intensity,
      weightSnapshot: clearWeightSnapshot
          ? null
          : weightSnapshot ?? this.weightSnapshot,
      metSnapshot: metSnapshot ?? this.metSnapshot,
      estimatedCalories: clearEstimatedCalories
          ? null
          : estimatedCalories ?? this.estimatedCalories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'date': dateKey,
      'exerciseType': exerciseType.value,
      'durationMinutes': durationMinutes,
      'intensity': intensity.value,
      'weightSnapshot': weightSnapshot,
      'metSnapshot': metSnapshot,
      'estimatedCalories': estimatedCalories,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ExerciseRecord.fromMap(Map<String, Object?> map) {
    return ExerciseRecord(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      exerciseType: ExerciseType.fromValue(map['exerciseType'] as String),
      durationMinutes: (map['durationMinutes'] as num).toInt(),
      intensity: ExerciseIntensity.fromValue(map['intensity'] as String),
      weightSnapshot: (map['weightSnapshot'] as num?)?.toDouble(),
      metSnapshot: (map['metSnapshot'] as num).toDouble(),
      estimatedCalories: (map['estimatedCalories'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  static String formatDateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
