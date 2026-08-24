enum MedicationTimeSlot {
  morning('morning', '아침'),
  lunch('lunch', '점심'),
  evening('evening', '저녁'),
  bedtime('bedtime', '취침 전');

  const MedicationTimeSlot(this.value, this.label);

  final String value;
  final String label;

  static MedicationTimeSlot fromValue(String value) {
    return MedicationTimeSlot.values.firstWhere((slot) => slot.value == value);
  }
}

enum MedicationType {
  scheduled('scheduled', '정기 복용'),
  prn('prn', '필요 시(PRN)');

  const MedicationType(this.value, this.label);

  final String value;
  final String label;

  static MedicationType fromValue(Object? value) {
    if (value is String) {
      for (final type in MedicationType.values) {
        if (type.value == value) return type;
      }
    }
    return MedicationType.scheduled;
  }
}

enum MedicationDoseUnit {
  tablet('tablet', '정'),
  mg('mg', 'mg'),
  ml('ml', 'ml');

  const MedicationDoseUnit(this.value, this.label);

  final String value;
  final String label;

  static MedicationDoseUnit? fromValueOrNull(Object? value) {
    if (value is String) {
      for (final unit in MedicationDoseUnit.values) {
        if (unit.value == value) return unit;
      }
    }
    return null;
  }
}

class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.morning,
    required this.lunch,
    required this.evening,
    required this.bedtime,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.type = MedicationType.scheduled,
    this.dose,
    this.doseValue,
    this.doseUnit,
  });

  final String id;
  final String name;
  final String? dose;
  final double? doseValue;
  final MedicationDoseUnit? doseUnit;
  final MedicationType type;
  final bool morning;
  final bool lunch;
  final bool evening;
  final bool bedtime;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isScheduled => type == MedicationType.scheduled;
  bool get isPrn => type == MedicationType.prn;
  bool get hasAnyTimeSlot => morning || lunch || evening || bedtime;

  String? get displayDose {
    final value = doseValue;
    final unit = doseUnit;
    if (value != null && unit != null) {
      return '${formatDoseValue(value)}${unit.label}';
    }
    final legacy = dose?.trim();
    return legacy == null || legacy.isEmpty ? null : legacy;
  }

  List<MedicationTimeSlot> get timeSlots => [
    if (morning) MedicationTimeSlot.morning,
    if (lunch) MedicationTimeSlot.lunch,
    if (evening) MedicationTimeSlot.evening,
    if (bedtime) MedicationTimeSlot.bedtime,
  ];

  bool isScheduledFor(MedicationTimeSlot slot) {
    if (!isScheduled) return false;
    return switch (slot) {
      MedicationTimeSlot.morning => morning,
      MedicationTimeSlot.lunch => lunch,
      MedicationTimeSlot.evening => evening,
      MedicationTimeSlot.bedtime => bedtime,
    };
  }

  Medication copyWith({
    String? id,
    String? name,
    MedicationType? type,
    String? dose,
    bool clearDose = false,
    double? doseValue,
    bool clearDoseValue = false,
    MedicationDoseUnit? doseUnit,
    bool clearDoseUnit = false,
    bool? morning,
    bool? lunch,
    bool? evening,
    bool? bedtime,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      dose: clearDose ? null : dose ?? this.dose,
      doseValue: clearDoseValue ? null : doseValue ?? this.doseValue,
      doseUnit: clearDoseUnit ? null : doseUnit ?? this.doseUnit,
      morning: morning ?? this.morning,
      lunch: lunch ?? this.lunch,
      evening: evening ?? this.evening,
      bedtime: bedtime ?? this.bedtime,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'medicationType': type.value,
    'dose': dose,
    'doseValue': doseValue,
    'doseUnit': doseUnit?.value,
    'morning': morning ? 1 : 0,
    'lunch': lunch ? 1 : 0,
    'evening': evening ? 1 : 0,
    'bedtime': bedtime ? 1 : 0,
    'isActive': isActive ? 1 : 0,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Medication.fromMap(Map<String, Object?> map) {
    final legacyDose = map['dose'] as String?;
    final parsedLegacy = _parseLegacyDose(legacyDose);
    final rawDoseValue = map['doseValue'];
    return Medication(
      id: map['id'] as String,
      name: map['name'] as String,
      type: MedicationType.fromValue(map['medicationType']),
      dose: legacyDose,
      doseValue: rawDoseValue is num
          ? rawDoseValue.toDouble()
          : parsedLegacy?.value,
      doseUnit:
          MedicationDoseUnit.fromValueOrNull(map['doseUnit']) ??
          parsedLegacy?.unit,
      morning: (map['morning'] as num).toInt() == 1,
      lunch: (map['lunch'] as num).toInt() == 1,
      evening: (map['evening'] as num).toInt() == 1,
      bedtime: (map['bedtime'] as num).toInt() == 1,
      isActive: (map['isActive'] as num).toInt() == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  static String formatDoseValue(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value
        .toString()
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static _ParsedDose? _parseLegacyDose(String? text) {
    final value = text?.trim();
    if (value == null || value.isEmpty) return null;
    final match = RegExp(
      r'^(\d+(?:\.\d+)?)\s*(정|mg|ml)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return null;
    final parsed = double.tryParse(match.group(1)!);
    if (parsed == null) return null;
    final unit = switch (match.group(2)!.toLowerCase()) {
      '정' => MedicationDoseUnit.tablet,
      'mg' => MedicationDoseUnit.mg,
      'ml' => MedicationDoseUnit.ml,
      _ => null,
    };
    return unit == null ? null : _ParsedDose(parsed, unit);
  }
}

class _ParsedDose {
  const _ParsedDose(this.value, this.unit);
  final double value;
  final MedicationDoseUnit unit;
}

class MedicationLog {
  const MedicationLog({
    required this.id,
    required this.medicationId,
    required this.date,
    required this.timeSlot,
    required this.isTaken,
    required this.createdAt,
    required this.updatedAt,
    this.takenAt,
  });

  final String id;
  final String medicationId;
  final DateTime date;
  final MedicationTimeSlot timeSlot;
  final bool isTaken;
  final DateTime? takenAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get dateKey => formatDateKey(date);
  String get uniqueKey => '$medicationId|$dateKey|${timeSlot.value}';

  MedicationLog copyWith({
    String? id,
    String? medicationId,
    DateTime? date,
    MedicationTimeSlot? timeSlot,
    bool? isTaken,
    DateTime? takenAt,
    bool clearTakenAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicationLog(
      id: id ?? this.id,
      medicationId: medicationId ?? this.medicationId,
      date: date ?? this.date,
      timeSlot: timeSlot ?? this.timeSlot,
      isTaken: isTaken ?? this.isTaken,
      takenAt: clearTakenAt ? null : takenAt ?? this.takenAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'medicationId': medicationId,
    'date': dateKey,
    'timeSlot': timeSlot.value,
    'isTaken': isTaken ? 1 : 0,
    'takenAt': takenAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory MedicationLog.fromMap(Map<String, Object?> map) => MedicationLog(
    id: map['id'] as String,
    medicationId: map['medicationId'] as String,
    date: DateTime.parse(map['date'] as String),
    timeSlot: MedicationTimeSlot.fromValue(map['timeSlot'] as String),
    isTaken: (map['isTaken'] as num).toInt() == 1,
    takenAt: map['takenAt'] == null
        ? null
        : DateTime.parse(map['takenAt'] as String),
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );

  static String formatDateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class PrnMedicationLog {
  const PrnMedicationLog({
    required this.id,
    required this.medicationId,
    required this.date,
    required this.takenAt,
    required this.createdAt,
    required this.updatedAt,
    this.doseValue,
    this.doseUnit,
    this.note,
  });

  final String id;
  final String medicationId;
  final DateTime date;
  final DateTime takenAt;
  final double? doseValue;
  final MedicationDoseUnit? doseUnit;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get dateKey => MedicationLog.formatDateKey(date);
  String? get displayDose => doseValue == null || doseUnit == null
      ? null
      : '${Medication.formatDoseValue(doseValue!)}${doseUnit!.label}';

  Map<String, Object?> toMap() => {
    'id': id,
    'medicationId': medicationId,
    'date': dateKey,
    'takenAt': takenAt.toIso8601String(),
    'doseValue': doseValue,
    'doseUnit': doseUnit?.value,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory PrnMedicationLog.fromMap(Map<String, Object?> map) {
    final rawDoseValue = map['doseValue'];
    return PrnMedicationLog(
      id: map['id'] as String,
      medicationId: map['medicationId'] as String,
      date: DateTime.parse(map['date'] as String),
      takenAt: DateTime.parse(map['takenAt'] as String),
      doseValue: rawDoseValue is num ? rawDoseValue.toDouble() : null,
      doseUnit: MedicationDoseUnit.fromValueOrNull(map['doseUnit']),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

class MedicationDoseItem {
  const MedicationDoseItem({
    required this.medication,
    required this.timeSlot,
    this.log,
  });
  final Medication medication;
  final MedicationTimeSlot timeSlot;
  final MedicationLog? log;
  bool get isTaken => log?.isTaken ?? false;
}
