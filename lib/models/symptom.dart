enum SymptomSeverity {
  none('none', '없음'),
  mild('mild', '약함'),
  moderate('moderate', '보통'),
  severe('severe', '심함');

  const SymptomSeverity(this.value, this.label);

  final String value;
  final String label;

  static SymptomSeverity fromValue(String value) {
    for (final severity in SymptomSeverity.values) {
      if (severity.value == value) {
        return severity;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown symptom severity');
  }
}

class SymptomDefinition {
  const SymptomDefinition({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final bool isDefault;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'isDefault': isDefault ? 1 : 0,
      'isActive': isActive ? 1 : 0,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SymptomDefinition.fromMap(Map<String, Object?> map) {
    return SymptomDefinition(
      id: map['id'] as String,
      name: map['name'] as String,
      isDefault: (map['isDefault'] as num?)?.toInt() != 0,
      isActive: (map['isActive'] as num?)?.toInt() != 0,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

class SymptomRecord {
  const SymptomRecord({
    required this.id,
    required this.symptomDefinitionId,
    required this.date,
    required this.severity,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String symptomDefinitionId;
  final DateTime date;
  final SymptomSeverity severity;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get dateKey => formatDateKey(date);

  SymptomRecord copyWith({
    String? id,
    String? symptomDefinitionId,
    DateTime? date,
    SymptomSeverity? severity,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SymptomRecord(
      id: id ?? this.id,
      symptomDefinitionId: symptomDefinitionId ?? this.symptomDefinitionId,
      date: date ?? this.date,
      severity: severity ?? this.severity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'symptomDefinitionId': symptomDefinitionId,
      'date': dateKey,
      'severity': severity.value,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SymptomRecord.fromMap(Map<String, Object?> map) {
    return SymptomRecord(
      id: map['id'] as String,
      symptomDefinitionId: map['symptomDefinitionId'] as String,
      date: DateTime.parse(map['date'] as String),
      severity: SymptomSeverity.fromValue(map['severity'] as String),
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

  static String formatDisplayDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year.$month.$day';
  }
}
