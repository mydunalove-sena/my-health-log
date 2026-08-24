class LabResult {
  const LabResult({
    required this.id,
    required this.date,
    required this.testName,
    required this.value,
    required this.createdAt,
    required this.updatedAt,
    this.unit,
  });

  final String id;
  final DateTime date;
  final String testName;
  final double value;
  final String? unit;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get dateKey => formatDateKey(date);
  String get displayValue {
    final valueText = formatValue(value);
    final unitText = unit?.trim();
    if (unitText == null || unitText.isEmpty) {
      return valueText;
    }
    return '$valueText $unitText';
  }

  LabResult copyWith({
    String? id,
    DateTime? date,
    String? testName,
    double? value,
    String? unit,
    bool clearUnit = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LabResult(
      id: id ?? this.id,
      date: date ?? this.date,
      testName: testName ?? this.testName,
      value: value ?? this.value,
      unit: clearUnit ? null : unit ?? this.unit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'date': dateKey,
      'testName': testName,
      'value': value,
      'unit': unit,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory LabResult.fromMap(Map<String, Object?> map) {
    return LabResult(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      testName: map['testName'] as String,
      value: (map['value'] as num).toDouble(),
      unit: map['unit'] as String?,
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

  static String formatValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    var text = value.toStringAsFixed(3);
    while (text.contains('.') && text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith('.')) {
      text = text.substring(0, text.length - 1);
    }
    return text;
  }
}

class LabResultDateGroup {
  const LabResultDateGroup({required this.date, required this.results});

  final DateTime date;
  final List<LabResult> results;

  String get dateKey => LabResult.formatDateKey(date);
}
