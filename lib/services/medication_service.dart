import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/medication.dart';
import 'app_database.dart';

class EmptyMedicationNameException implements Exception {
  const EmptyMedicationNameException();
}

class EmptyMedicationTimeSlotException implements Exception {
  const EmptyMedicationTimeSlotException();
}

class DuplicateMedicationLogException implements Exception {
  const DuplicateMedicationLogException();
}

abstract class MedicationStorage {
  Future<List<Medication>> fetchActiveMedications();
  Future<List<MedicationLog>> fetchLogsForDate(DateTime date);
  Future<List<MedicationLog>> fetchAllLogs();
  Future<void> insertMedication(Medication medication);
  Future<void> updateMedication(Medication medication);
  Future<void> updateMedicationActive(
    String id,
    bool isActive,
    DateTime updatedAt,
  );
  Future<void> upsertMedicationLog(MedicationLog log);
}

class MedicationService extends ChangeNotifier {
  MedicationService(this._storage);

  final MedicationStorage _storage;
  final List<Medication> _activeMedications = [];
  final Map<String, MedicationLog> _logsByKey = {};
  DateTime _loadedDate = _today();

  List<Medication> get activeMedications =>
      List.unmodifiable(_activeMedications);

  Future<void> load({DateTime? date}) async {
    _loadedDate = _normalize(date ?? DateTime.now());
    _activeMedications
      ..clear()
      ..addAll(await _storage.fetchActiveMedications());
    _logsByKey
      ..clear()
      ..addEntries(
        (await _storage.fetchLogsForDate(_loadedDate))
            .map((log) => MapEntry(log.uniqueKey, log)),
      );
    notifyListeners();
  }

  List<MedicationDoseItem> doseItemsForDate(DateTime date) {
    final dateKey = MedicationLog.formatDateKey(date);
    return [
      for (final medication in _activeMedications)
        for (final slot in MedicationTimeSlot.values)
          if (medication.isScheduledFor(slot))
            MedicationDoseItem(
              medication: medication,
              timeSlot: slot,
              log: _logsByKey['${medication.id}|$dateKey|${slot.value}'],
            ),
    ];
  }

  List<MedicationDoseItem> get todayDoseItems => doseItemsForDate(_loadedDate);

  MedicationLog? logFor(
    String medicationId,
    DateTime date,
    MedicationTimeSlot slot,
  ) {
    final key =
        '$medicationId|${MedicationLog.formatDateKey(date)}|${slot.value}';
    return _logsByKey[key];
  }

  Future<void> saveMedication(Medication medication) async {
    final name = medication.name.trim();
    if (name.isEmpty) {
      throw const EmptyMedicationNameException();
    }
    if (!medication.hasAnyTimeSlot) {
      throw const EmptyMedicationTimeSlotException();
    }

    final normalized = medication.copyWith(
      name: name,
      dose: medication.dose?.trim().isEmpty == true
          ? null
          : medication.dose?.trim(),
      clearDose: medication.dose?.trim().isEmpty == true,
    );
    final index = _activeMedications.indexWhere(
      (item) => item.id == normalized.id,
    );
    if (index == -1) {
      await _storage.insertMedication(normalized);
      if (normalized.isActive) {
        _activeMedications.add(normalized);
      }
    } else {
      await _storage.updateMedication(normalized);
      if (normalized.isActive) {
        _activeMedications[index] = normalized;
      } else {
        _activeMedications.removeAt(index);
      }
    }
    notifyListeners();
  }

  Future<void> softDeleteMedication(Medication medication) async {
    final now = DateTime.now();
    await _storage.updateMedicationActive(medication.id, false, now);
    _activeMedications.removeWhere((item) => item.id == medication.id);
    notifyListeners();
  }

  Future<void> toggleTaken({
    required Medication medication,
    required MedicationTimeSlot timeSlot,
    DateTime? date,
    DateTime? now,
  }) async {
    final currentDate = _normalize(date ?? _loadedDate);
    final currentNow = now ?? DateTime.now();
    final key =
        '${medication.id}|${MedicationLog.formatDateKey(currentDate)}|${timeSlot.value}';
    final existing = _logsByKey[key];
    final next = existing == null
        ? MedicationLog(
            id: 'medlog-${currentNow.microsecondsSinceEpoch}',
            medicationId: medication.id,
            date: currentDate,
            timeSlot: timeSlot,
            isTaken: true,
            takenAt: currentNow,
            createdAt: currentNow,
            updatedAt: currentNow,
          )
        : existing.copyWith(
            isTaken: !existing.isTaken,
            takenAt: existing.isTaken ? null : currentNow,
            clearTakenAt: existing.isTaken,
            updatedAt: currentNow,
          );

    await _storage.upsertMedicationLog(next);
    _logsByKey[key] = next;
    notifyListeners();
  }

  Future<List<MedicationLog>> allLogsForTest() => _storage.fetchAllLogs();

  static DateTime _today() => _normalize(DateTime.now());

  static DateTime _normalize(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class SqfliteMedicationStorage implements MedicationStorage {
  static const _medicationsTable = 'medications';
  static const _logsTable = 'medication_logs';

  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }
    final database = await AppDatabase.open();
    _database = database;
    return database;
  }

  @override
  Future<List<Medication>> fetchActiveMedications() async {
    final db = await _db;
    final rows = await db.query(
      _medicationsTable,
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'createdAt ASC',
    );
    return rows.map(Medication.fromMap).toList();
  }

  @override
  Future<List<MedicationLog>> fetchLogsForDate(DateTime date) async {
    final db = await _db;
    final rows = await db.query(
      _logsTable,
      where: 'date = ?',
      whereArgs: [MedicationLog.formatDateKey(date)],
    );
    return rows.map(MedicationLog.fromMap).toList();
  }

  @override
  Future<List<MedicationLog>> fetchAllLogs() async {
    final db = await _db;
    final rows = await db.query(_logsTable, orderBy: 'date ASC, timeSlot ASC');
    return rows.map(MedicationLog.fromMap).toList();
  }

  @override
  Future<void> insertMedication(Medication medication) async {
    final db = await _db;
    await db.insert(_medicationsTable, medication.toMap());
  }

  @override
  Future<void> updateMedication(Medication medication) async {
    final db = await _db;
    await db.update(
      _medicationsTable,
      medication.toMap(),
      where: 'id = ?',
      whereArgs: [medication.id],
    );
  }

  @override
  Future<void> updateMedicationActive(
    String id,
    bool isActive,
    DateTime updatedAt,
  ) async {
    final db = await _db;
    await db.update(
      _medicationsTable,
      {'isActive': isActive ? 1 : 0, 'updatedAt': updatedAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> upsertMedicationLog(MedicationLog log) async {
    final db = await _db;
    try {
      await db.insert(
        _logsTable,
        log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw const DuplicateMedicationLogException();
      }
      rethrow;
    }
  }
}

class InMemoryMedicationStorage implements MedicationStorage {
  InMemoryMedicationStorage({
    List<Medication>? medications,
    List<MedicationLog>? logs,
  }) : _medications = List.of(medications ?? const []),
       _logs = List.of(logs ?? const []);

  final List<Medication> _medications;
  final List<MedicationLog> _logs;

  @override
  Future<List<Medication>> fetchActiveMedications() async {
    return _medications.where((item) => item.isActive).toList();
  }

  @override
  Future<List<MedicationLog>> fetchLogsForDate(DateTime date) async {
    final key = MedicationLog.formatDateKey(date);
    return _logs.where((log) => log.dateKey == key).toList();
  }

  @override
  Future<List<MedicationLog>> fetchAllLogs() async => List.of(_logs);

  @override
  Future<void> insertMedication(Medication medication) async {
    _medications.add(medication);
  }

  @override
  Future<void> updateMedication(Medication medication) async {
    final index = _medications.indexWhere((item) => item.id == medication.id);
    if (index == -1) {
      _medications.add(medication);
    } else {
      _medications[index] = medication;
    }
  }

  @override
  Future<void> updateMedicationActive(
    String id,
    bool isActive,
    DateTime updatedAt,
  ) async {
    final index = _medications.indexWhere((item) => item.id == id);
    if (index != -1) {
      _medications[index] = _medications[index].copyWith(
        isActive: isActive,
        updatedAt: updatedAt,
      );
    }
  }

  @override
  Future<void> upsertMedicationLog(MedicationLog log) async {
    final duplicateCount = _logs
        .where((item) => item.uniqueKey == log.uniqueKey)
        .length;
    final index = _logs.indexWhere((item) => item.uniqueKey == log.uniqueKey);
    if (duplicateCount > 1) {
      throw const DuplicateMedicationLogException();
    }
    if (index == -1) {
      _logs.add(log);
    } else {
      _logs[index] = log;
    }
  }
}
