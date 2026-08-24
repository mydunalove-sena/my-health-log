enum HealthCondition {
  veryGood('veryGood', '매우 좋음'),
  good('good', '좋음'),
  normal('normal', '보통'),
  bad('bad', '나쁨'),
  veryBad('veryBad', '매우 나쁨');

  const HealthCondition(this.value, this.label);

  final String value;
  final String label;

  static HealthCondition? fromValue(String? value) {
    for (final condition in HealthCondition.values) {
      if (condition.value == value) {
        return condition;
      }
    }
    return null;
  }
}

class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.weight,
    this.systolicBloodPressure,
    this.diastolicBloodPressure,
    this.waterIntake,
    this.steps,
    this.sleepHours,
    this.condition,
  });

  final String id;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? weight;
  final int? systolicBloodPressure;
  final int? diastolicBloodPressure;
  final int? waterIntake;
  final int? steps;
  final double? sleepHours;
  final HealthCondition? condition;

  bool get hasAnyHealthValue {
    return weight != null ||
        systolicBloodPressure != null ||
        diastolicBloodPressure != null ||
        waterIntake != null ||
        steps != null ||
        sleepHours != null ||
        condition != null;
  }

  String get dateKey => formatDateKey(date);

  HealthRecord copyWith({
    String? id,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? weight,
    int? systolicBloodPressure,
    int? diastolicBloodPressure,
    int? waterIntake,
    int? steps,
    double? sleepHours,
    HealthCondition? condition,
    bool clearWeight = false,
    bool clearSystolicBloodPressure = false,
    bool clearDiastolicBloodPressure = false,
    bool clearWaterIntake = false,
    bool clearSteps = false,
    bool clearSleepHours = false,
    bool clearCondition = false,
  }) {
    return HealthRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      weight: clearWeight ? null : weight ?? this.weight,
      systolicBloodPressure: clearSystolicBloodPressure
          ? null
          : systolicBloodPressure ?? this.systolicBloodPressure,
      diastolicBloodPressure: clearDiastolicBloodPressure
          ? null
          : diastolicBloodPressure ?? this.diastolicBloodPressure,
      waterIntake: clearWaterIntake ? null : waterIntake ?? this.waterIntake,
      steps: clearSteps ? null : steps ?? this.steps,
      sleepHours: clearSleepHours ? null : sleepHours ?? this.sleepHours,
      condition: clearCondition ? null : condition ?? this.condition,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'date': dateKey,
      'weight': weight,
      'systolicBloodPressure': systolicBloodPressure,
      'diastolicBloodPressure': diastolicBloodPressure,
      'waterIntake': waterIntake,
      'steps': steps,
      'sleepHours': sleepHours,
      'condition': condition?.value,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory HealthRecord.fromMap(Map<String, Object?> map) {
    return HealthRecord(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      weight: (map['weight'] as num?)?.toDouble(),
      systolicBloodPressure: (map['systolicBloodPressure'] as num?)?.toInt(),
      diastolicBloodPressure: (map['diastolicBloodPressure'] as num?)?.toInt(),
      waterIntake: (map['waterIntake'] as num?)?.toInt(),
      steps: (map['steps'] as num?)?.toInt(),
      sleepHours: (map['sleepHours'] as num?)?.toDouble(),
      condition: HealthCondition.fromValue(map['condition'] as String?),
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
