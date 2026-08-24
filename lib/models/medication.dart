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
    this.dose,
  });

  final String id;
  final String name;
  final String? dose;
  final bool morning;
  final bool lunch;
  final bool evening;
  final bool bedtime;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasAnyTimeSlot => morning || lunch || evening || bedtime;

  List<MedicationTimeSlot> get timeSlots {
    return [
      if (morning) MedicationTimeSlot.morning,
      if (lunch) MedicationTimeSlot.lunch,
      if (evening) MedicationTimeSlot.evening,
      if (bedtime) MedicationTimeSlot.bedtime,
    ];
  }

  bool isScheduledFor(MedicationTimeSlot slot) {
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
    String? dose,
    bool clearDose = false,
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
      dose: clearDose ? null : dose ?? this.dose,
      morning: morning ?? this.morning,
      lunch: lunch ?? this.lunch,
      evening: evening ?? this.evening,
      bedtime: bedtime ?? this.bedtime,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'dose': dose,
      'morning': morning ? 1 : 0,
      'lunch': lunch ? 1 : 0,
      'evening': evening ? 1 : 0,
      'bedtime': bedtime ? 1 : 0,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Medication.fromMap(Map<String, Object?> map) {
    return Medication(
      id: map['id'] as String,
      name: map['name'] as String,
      dose: map['dose'] as String?,
      morning: (map['morning'] as num).toInt() == 1,
      lunch: (map['lunch'] as num).toInt() == 1,
      evening: (map['evening'] as num).toInt() == 1,
      bedtime: (map['bedtime'] as num).toInt() == 1,
      isActive: (map['isActive'] as num).toInt() == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
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

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'medicationId': medicationId,
      'date': dateKey,
      'timeSlot': timeSlot.value,
      'isTaken': isTaken ? 1 : 0,
      'takenAt': takenAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MedicationLog.fromMap(Map<String, Object?> map) {
    return MedicationLog(
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
  }

  static String formatDateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
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
