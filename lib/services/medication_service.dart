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

class InvalidMedicationDoseException implements Exception {
  const InvalidMedicationDoseException();
}

class InvalidPrnMedicationException implements Exception {
  const InvalidPrnMedicationException();
}

class FuturePrnMedicationDateException implements Exception {
  const FuturePrnMedicationDateException();
}

class FuturePrnMedicationTimeException implements Exception {
  const FuturePrnMedicationTimeException();
}

class DuplicateMedicationLogException implements Exception {
  const DuplicateMedicationLogException();
}

abstract class MedicationStorage {
  Future<List<Medication>> fetchActiveMedications();
  Future<List<Medication>> fetchAllMedications();
  Future<List<MedicationLog>> fetchLogsForDate(DateTime date);
  Future<List<MedicationLog>> fetchAllLogs();
  Future<List<PrnMedicationLog>> fetchPrnLogsForDate(DateTime date);
  Future<List<PrnMedicationLog>> fetchAllPrnLogs();
  Future<List<PrnSymptomLink>> fetchAllPrnSymptomLinks();
  Future<List<MedicationDoseHistory>> fetchDoseHistory(String medicationId);
  Future<List<MedicationDoseHistory>> fetchAllDoseHistory();
  Future<void> insertMedication(Medication medication);
  Future<void> updateMedication(Medication medication);
  Future<void> updateMedicationWithDoseHistory(
    Medication medication,
    MedicationDoseHistory? history,
  );
  Future<void> updateMedicationActive(
    String id,
    bool isActive,
    DateTime updatedAt,
  );
  Future<void> upsertMedicationLog(MedicationLog log);
  Future<void> insertPrnMedicationLog(
    PrnMedicationLog log, {
    List<PrnSymptomLink> symptomLinks = const [],
  });
  Future<void> updatePrnMedicationLog(
    PrnMedicationLog log, {
    List<PrnSymptomLink> symptomLinks = const [],
  });
  Future<void> deletePrnMedicationLog(String id);
}

class MedicationService extends ChangeNotifier {
  MedicationService(this._storage);

  final MedicationStorage _storage;
  final List<Medication> _activeMedications = [];
  final Map<String, MedicationLog> _logsByKey = {};
  final List<PrnMedicationLog> _prnLogsForLoadedDate = [];
  final List<PrnSymptomLink> _prnSymptomLinks = [];
  DateTime _loadedDate = _today();

  List<Medication> get activeMedications =>
      List.unmodifiable(_activeMedications);

  List<Medication> get activeScheduledMedications => List.unmodifiable(
    _activeMedications.where((medication) => medication.isScheduled),
  );

  List<Medication> get activePrnMedications => List.unmodifiable(
    _activeMedications.where((medication) => medication.isPrn),
  );

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
    _prnLogsForLoadedDate
      ..clear()
      ..addAll(await _storage.fetchPrnLogsForDate(_loadedDate));
    _prnSymptomLinks
      ..clear()
      ..addAll(await _storage.fetchAllPrnSymptomLinks());
    _sortPrnLogs();
    notifyListeners();
  }

  List<MedicationDoseItem> doseItemsForDate(DateTime date) {
    final dateKey = MedicationLog.formatDateKey(date);
    return [
      for (final medication in _activeMedications)
        if (medication.isScheduled)
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

  List<PrnMedicationLog> prnLogsForMedication(String medicationId) {
    return List.unmodifiable(
      _prnLogsForLoadedDate.where((log) => log.medicationId == medicationId),
    );
  }

  List<PrnSymptomLink> prnSymptomLinksForLog(String prnMedicationLogId) {
    return List.unmodifiable(
      _prnSymptomLinks.where(
        (link) => link.prnMedicationLogId == prnMedicationLogId,
      ),
    );
  }

  List<String> symptomDefinitionIdsForPrnLog(String prnMedicationLogId) {
    return List.unmodifiable(
      prnSymptomLinksForLog(prnMedicationLogId)
          .map((link) => link.symptomDefinitionId),
    );
  }

  Future<List<MedicationDoseHistory>> doseHistoryForMedication(
    String medicationId,
  ) {
    return _storage.fetchDoseHistory(medicationId);
  }

  Future<MedicationHistoryDay> historyForDate(DateTime date) async {
    final currentDate = _normalize(date);
    final medications = await _storage.fetchAllMedications();
    final medicationsById = {for (final item in medications) item.id: item};
    final scheduledLogs = await _storage.fetchLogsForDate(currentDate);
    final prnLogs = await _storage.fetchPrnLogsForDate(currentDate);
    final prnLinks = await _storage.fetchAllPrnSymptomLinks();

    final scheduledEntries =
        [
          for (final log in scheduledLogs)
            MedicationHistoryScheduledEntry(
              medicationName:
                  medicationsById[log.medicationId]?.name ?? log.medicationId,
              medication: medicationsById[log.medicationId],
              log: log,
            ),
        ]..sort((a, b) {
          final slotCompare = a.log.timeSlot.index.compareTo(
            b.log.timeSlot.index,
          );
          if (slotCompare != 0) return slotCompare;
          return a.medicationName.compareTo(b.medicationName);
        });

    final prnEntries = [
      for (final log in prnLogs)
        MedicationHistoryPrnEntry(
          medicationName:
              medicationsById[log.medicationId]?.name ?? log.medicationId,
          medication: medicationsById[log.medicationId],
          log: log,
          symptomDefinitionIds: [
            for (final link in prnLinks)
              if (link.prnMedicationLogId == log.id) link.symptomDefinitionId,
          ],
        ),
    ];

    return MedicationHistoryDay(
      date: currentDate,
      scheduledEntries: scheduledEntries,
      prnEntries: prnEntries,
    );
  }

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
    if (medication.isScheduled && !medication.hasAnyTimeSlot) {
      throw const EmptyMedicationTimeSlotException();
    }

    final doseValue = medication.doseValue;
    final doseUnit = medication.doseUnit;
    if (doseValue != null &&
        (!doseValue.isFinite || doseValue <= 0 || doseUnit == null)) {
      throw const InvalidMedicationDoseException();
    }

    final legacyDose = medication.dose?.trim();
    final normalizedDose = doseValue != null && doseUnit != null
        ? '${Medication.formatDoseValue(doseValue)}${doseUnit.label}'
        : (legacyDose == null || legacyDose.isEmpty ? null : legacyDose);

    final normalized = medication.copyWith(
      name: name,
      dose: normalizedDose,
      clearDose: normalizedDose == null,
      doseValue: doseValue,
      clearDoseValue: doseValue == null,
      doseUnit: doseValue == null ? null : doseUnit,
      clearDoseUnit: doseValue == null,
      morning: medication.isPrn ? false : medication.morning,
      lunch: medication.isPrn ? false : medication.lunch,
      evening: medication.isPrn ? false : medication.evening,
      bedtime: medication.isPrn ? false : medication.bedtime,
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
      final previous = _activeMedications[index];
      final history = _buildDoseHistory(previous, normalized);
      await _storage.updateMedicationWithDoseHistory(normalized, history);
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
    if (!medication.isScheduled) {
      throw const InvalidPrnMedicationException();
    }

    final currentDate = _normalize(date ?? _loadedDate);
    final currentNow = now ?? DateTime.now();
    final key =
        '${medication.id}|${MedicationLog.formatDateKey(currentDate)}|${timeSlot.value}';
    final existing = _logsByKey[key];

    late final MedicationLog next;
    if (existing == null) {
      next = MedicationLog(
        id: 'medlog-${currentNow.microsecondsSinceEpoch}',
        medicationId: medication.id,
        date: currentDate,
        timeSlot: timeSlot,
        isTaken: true,
        takenAt: currentNow,
        doseSnapshot: medication.dose,
        doseValueSnapshot: medication.doseValue,
        doseUnitSnapshot: medication.doseUnit,
        createdAt: currentNow,
        updatedAt: currentNow,
      );
    } else if (existing.isTaken) {
      next = existing.copyWith(
        isTaken: false,
        clearTakenAt: true,
        clearDoseSnapshot: true,
        clearDoseValueSnapshot: true,
        clearDoseUnitSnapshot: true,
        updatedAt: currentNow,
      );
    } else {
      next = existing.copyWith(
        isTaken: true,
        takenAt: currentNow,
        doseSnapshot: medication.dose,
        clearDoseSnapshot: medication.dose == null,
        doseValueSnapshot: medication.doseValue,
        clearDoseValueSnapshot: medication.doseValue == null,
        doseUnitSnapshot: medication.doseUnit,
        clearDoseUnitSnapshot: medication.doseUnit == null,
        updatedAt: currentNow,
      );
    }

    await _storage.upsertMedicationLog(next);
    _logsByKey[key] = next;
    notifyListeners();
  }

  Future<MedicationLog> saveScheduledCorrection({
    required Medication medication,
    required DateTime date,
    required MedicationTimeSlot timeSlot,
    required bool isTaken,
    DateTime? takenAt,
    DateTime? now,
  }) async {
    if (!medication.isScheduled) {
      throw const InvalidPrnMedicationException();
    }
    if (!medication.isScheduledFor(timeSlot)) {
      throw const EmptyMedicationTimeSlotException();
    }

    final currentNow = now ?? DateTime.now();
    final currentDate = _normalize(currentNow);
    final correctedDate = _normalize(date);
    if (correctedDate.isAfter(currentDate)) {
      throw const FuturePrnMedicationDateException();
    }
    if (isTaken) {
      final actualTakenAt = takenAt;
      if (actualTakenAt == null || _normalize(actualTakenAt) != correctedDate) {
        throw const FuturePrnMedicationTimeException();
      }
      if (actualTakenAt.isAfter(currentNow)) {
        throw const FuturePrnMedicationTimeException();
      }
    }

    final matchingLogs = (await _storage.fetchLogsForDate(correctedDate))
        .where(
          (log) =>
              log.medicationId == medication.id && log.timeSlot == timeSlot,
        )
        .toList();
    final existing = matchingLogs.isEmpty ? null : matchingLogs.first;
    final createdAt = existing?.createdAt ?? currentNow;
    final next = MedicationLog(
      id: existing?.id ?? 'medlog-${currentNow.microsecondsSinceEpoch}',
      medicationId: medication.id,
      date: correctedDate,
      timeSlot: timeSlot,
      isTaken: isTaken,
      takenAt: isTaken ? takenAt : null,
      doseSnapshot: null,
      doseValueSnapshot: null,
      doseUnitSnapshot: null,
      createdAt: createdAt,
      updatedAt: currentNow,
    );

    await _storage.upsertMedicationLog(next);
    if (MedicationLog.formatDateKey(correctedDate) ==
        MedicationLog.formatDateKey(_loadedDate)) {
      _logsByKey[next.uniqueKey] = next;
    }
    notifyListeners();
    return next;
  }

  Future<PrnMedicationLog> recordPrnTaken({
    required Medication medication,
    required DateTime takenAt,
    double? doseValue,
    MedicationDoseUnit? doseUnit,
    String? note,
    List<String> symptomDefinitionIds = const [],
    DateTime? now,
  }) async {
    if (!medication.isPrn) {
      throw const InvalidPrnMedicationException();
    }

    final currentNow = now ?? DateTime.now();
    final currentDate = _normalize(currentNow);
    final takenDate = _normalize(takenAt);
    if (takenDate.isAfter(currentDate)) {
      throw const FuturePrnMedicationDateException();
    }
    if (takenAt.isAfter(currentNow)) {
      throw const FuturePrnMedicationTimeException();
    }
    if (doseValue != null &&
        (!doseValue.isFinite || doseValue <= 0 || doseUnit == null)) {
      throw const InvalidMedicationDoseException();
    }

    final normalizedNote = note?.trim();
    final log = PrnMedicationLog(
      id: 'prnlog-${currentNow.microsecondsSinceEpoch}',
      medicationId: medication.id,
      date: takenDate,
      takenAt: takenAt,
      doseValue: doseValue,
      doseUnit: doseValue == null ? null : doseUnit,
      note: normalizedNote == null || normalizedNote.isEmpty
          ? null
          : normalizedNote,
      createdAt: currentNow,
      updatedAt: currentNow,
    );
    final symptomLinks = _buildPrnSymptomLinks(
      logId: log.id,
      symptomDefinitionIds: symptomDefinitionIds,
      createdAt: currentNow,
    );

    await _storage.insertPrnMedicationLog(log, symptomLinks: symptomLinks);
    if (MedicationLog.formatDateKey(takenDate) ==
        MedicationLog.formatDateKey(_loadedDate)) {
      _prnLogsForLoadedDate.add(log);
      _sortPrnLogs();
    }
    _prnSymptomLinks.addAll(symptomLinks);
    notifyListeners();
    return log;
  }

  Future<PrnMedicationLog> updatePrnLog({
    required Medication medication,
    required PrnMedicationLog existingLog,
    required DateTime takenAt,
    double? doseValue,
    MedicationDoseUnit? doseUnit,
    String? note,
    List<String> symptomDefinitionIds = const [],
    DateTime? now,
  }) async {
    if (!medication.isPrn || existingLog.medicationId != medication.id) {
      throw const InvalidPrnMedicationException();
    }

    final currentNow = now ?? DateTime.now();
    final currentDate = _normalize(currentNow);
    final takenDate = _normalize(takenAt);
    if (takenDate.isAfter(currentDate)) {
      throw const FuturePrnMedicationDateException();
    }
    if (takenAt.isAfter(currentNow)) {
      throw const FuturePrnMedicationTimeException();
    }
    if (doseValue != null &&
        (!doseValue.isFinite || doseValue <= 0 || doseUnit == null)) {
      throw const InvalidMedicationDoseException();
    }

    final normalizedNote = note?.trim();
    final next = existingLog.copyWith(
      date: takenDate,
      takenAt: takenAt,
      doseValue: doseValue,
      clearDoseValue: doseValue == null,
      doseUnit: doseValue == null ? null : doseUnit,
      clearDoseUnit: doseValue == null,
      note: normalizedNote == null || normalizedNote.isEmpty
          ? null
          : normalizedNote,
      clearNote: normalizedNote == null || normalizedNote.isEmpty,
      updatedAt: currentNow,
    );
    final symptomLinks = _buildPrnSymptomLinks(
      logId: next.id,
      symptomDefinitionIds: symptomDefinitionIds,
      createdAt: currentNow,
    );

    await _storage.updatePrnMedicationLog(next, symptomLinks: symptomLinks);
    _prnLogsForLoadedDate.removeWhere((log) => log.id == next.id);
    if (MedicationLog.formatDateKey(takenDate) ==
        MedicationLog.formatDateKey(_loadedDate)) {
      _prnLogsForLoadedDate.add(next);
      _sortPrnLogs();
    }
    _prnSymptomLinks.removeWhere((link) => link.prnMedicationLogId == next.id);
    _prnSymptomLinks.addAll(symptomLinks);
    notifyListeners();
    return next;
  }

  Future<void> deletePrnLog(String id) async {
    await _storage.deletePrnMedicationLog(id);
    _prnLogsForLoadedDate.removeWhere((log) => log.id == id);
    _prnSymptomLinks.removeWhere((link) => link.prnMedicationLogId == id);
    notifyListeners();
  }

  Future<List<MedicationLog>> allLogsForTest() => _storage.fetchAllLogs();

  Future<List<Medication>> allMedicationsForTest() =>
      _storage.fetchAllMedications();

  Future<List<PrnMedicationLog>> allPrnLogsForTest() =>
      _storage.fetchAllPrnLogs();

  Future<List<PrnSymptomLink>> allPrnSymptomLinksForTest() =>
      _storage.fetchAllPrnSymptomLinks();

  Future<List<MedicationDoseHistory>> allDoseHistoryForTest() =>
      _storage.fetchAllDoseHistory();

  MedicationDoseHistory? _buildDoseHistory(
    Medication previous,
    Medication next,
  ) {
    if (!_hasDoseChanged(previous, next)) {
      return null;
    }
    final changedAt = next.updatedAt;
    return MedicationDoseHistory(
      id: 'dosehist-${next.id}-${changedAt.microsecondsSinceEpoch}',
      medicationId: next.id,
      previousDose: previous.dose,
      previousDoseValue: previous.doseValue,
      previousDoseUnit: previous.doseUnit,
      newDose: next.dose,
      newDoseValue: next.doseValue,
      newDoseUnit: next.doseUnit,
      changedAt: changedAt,
      createdAt: changedAt,
    );
  }

  List<PrnSymptomLink> _buildPrnSymptomLinks({
    required String logId,
    required List<String> symptomDefinitionIds,
    required DateTime createdAt,
  }) {
    final uniqueIds = <String>{
      for (final id in symptomDefinitionIds)
        if (id.trim().isNotEmpty) id.trim(),
    }.toList();
    uniqueIds.sort();
    return [
      for (final symptomDefinitionId in uniqueIds)
        PrnSymptomLink(
          id: 'prnsymptom-$logId-$symptomDefinitionId',
          prnMedicationLogId: logId,
          symptomDefinitionId: symptomDefinitionId,
          createdAt: createdAt,
        ),
    ];
  }

  bool _hasDoseChanged(Medication previous, Medication next) {
    final previousStructured =
        previous.doseValue != null && previous.doseUnit != null;
    final nextStructured = next.doseValue != null && next.doseUnit != null;

    if (previousStructured || nextStructured) {
      return previous.doseValue != next.doseValue ||
          previous.doseUnit != next.doseUnit;
    }

    return _normalizedText(previous.dose) != _normalizedText(next.dose);
  }

  String? _normalizedText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  void _sortPrnLogs() {
    _prnLogsForLoadedDate.sort((a, b) => b.takenAt.compareTo(a.takenAt));
  }

  static DateTime _today() => _normalize(DateTime.now());

  static DateTime _normalize(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class MedicationHistoryDay {
  const MedicationHistoryDay({
    required this.date,
    required this.scheduledEntries,
    required this.prnEntries,
  });

  final DateTime date;
  final List<MedicationHistoryScheduledEntry> scheduledEntries;
  final List<MedicationHistoryPrnEntry> prnEntries;

  bool get isEmpty => scheduledEntries.isEmpty && prnEntries.isEmpty;
}

class MedicationHistoryScheduledEntry {
  const MedicationHistoryScheduledEntry({
    required this.medicationName,
    required this.medication,
    required this.log,
  });

  final String medicationName;
  final Medication? medication;
  final MedicationLog log;

  bool get isTaken => log.isTaken;
  bool get hasDoseSnapshot => log.displayDoseSnapshot != null;

  String get statusLabel => log.isTaken
      ? '\uBCF5\uC6A9 \uC644\uB8CC'
      : '\uBBF8\uBCF5\uC6A9 \uAE30\uB85D';

  String get doseLabel {
    if (!log.isTaken) {
      return '\uBCF5\uC6A9\uD558\uC9C0 \uC54A\uC74C';
    }
    return log.displayDoseSnapshot ??
        '\uBCF5\uC6A9\uB7C9 \uAE30\uB85D \uC5C6\uC74C';
  }
}

class MedicationHistoryPrnEntry {
  const MedicationHistoryPrnEntry({
    required this.medicationName,
    required this.medication,
    required this.log,
    required this.symptomDefinitionIds,
  });

  final String medicationName;
  final Medication? medication;
  final PrnMedicationLog log;
  final List<String> symptomDefinitionIds;

  String get doseLabel =>
      log.displayDose ?? '\uBCF5\uC6A9\uB7C9 \uAE30\uB85D \uC5C6\uC74C';
}

class SqfliteMedicationStorage implements MedicationStorage {
  static const _medicationsTable = 'medications';
  static const _logsTable = 'medication_logs';
  static const _prnLogsTable = 'prn_medication_logs';
  static const _prnSymptomLinksTable = 'prn_symptom_links';
  static const _doseHistoryTable = 'medication_dose_history';

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
  Future<List<Medication>> fetchAllMedications() async {
    final db = await _db;
    final rows = await db.query(_medicationsTable, orderBy: 'createdAt ASC');
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
  Future<List<PrnMedicationLog>> fetchPrnLogsForDate(DateTime date) async {
    final db = await _db;
    final rows = await db.query(
      _prnLogsTable,
      where: 'date = ?',
      whereArgs: [MedicationLog.formatDateKey(date)],
      orderBy: 'takenAt DESC',
    );
    return rows.map(PrnMedicationLog.fromMap).toList();
  }

  @override
  Future<List<PrnMedicationLog>> fetchAllPrnLogs() async {
    final db = await _db;
    final rows = await db.query(_prnLogsTable, orderBy: 'takenAt ASC');
    return rows.map(PrnMedicationLog.fromMap).toList();
  }

  @override
  Future<List<PrnSymptomLink>> fetchAllPrnSymptomLinks() async {
    final db = await _db;
    final rows = await db.query(
      _prnSymptomLinksTable,
      orderBy: 'createdAt ASC',
    );
    return rows.map(PrnSymptomLink.fromMap).toList();
  }

  @override
  Future<List<MedicationDoseHistory>> fetchDoseHistory(
    String medicationId,
  ) async {
    final db = await _db;
    final rows = await db.query(
      _doseHistoryTable,
      where: 'medicationId = ?',
      whereArgs: [medicationId],
      orderBy: 'changedAt DESC',
    );
    return rows.map(MedicationDoseHistory.fromMap).toList();
  }

  @override
  Future<List<MedicationDoseHistory>> fetchAllDoseHistory() async {
    final db = await _db;
    final rows = await db.query(_doseHistoryTable, orderBy: 'changedAt ASC');
    return rows.map(MedicationDoseHistory.fromMap).toList();
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
  Future<void> updateMedicationWithDoseHistory(
    Medication medication,
    MedicationDoseHistory? history,
  ) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        _medicationsTable,
        medication.toMap(),
        where: 'id = ?',
        whereArgs: [medication.id],
      );
      if (history != null) {
        await txn.insert(_doseHistoryTable, history.toMap());
      }
    });
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

  @override
  Future<void> insertPrnMedicationLog(
    PrnMedicationLog log, {
    List<PrnSymptomLink> symptomLinks = const [],
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert(_prnLogsTable, log.toMap());
      for (final link in symptomLinks) {
        await txn.insert(
          _prnSymptomLinksTable,
          link.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  @override
  Future<void> updatePrnMedicationLog(
    PrnMedicationLog log, {
    List<PrnSymptomLink> symptomLinks = const [],
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        _prnLogsTable,
        log.toMap(),
        where: 'id = ?',
        whereArgs: [log.id],
      );
      await txn.delete(
        _prnSymptomLinksTable,
        where: 'prnMedicationLogId = ?',
        whereArgs: [log.id],
      );
      for (final link in symptomLinks) {
        await txn.insert(
          _prnSymptomLinksTable,
          link.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  @override
  Future<void> deletePrnMedicationLog(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        _prnSymptomLinksTable,
        where: 'prnMedicationLogId = ?',
        whereArgs: [id],
      );
      await txn.delete(_prnLogsTable, where: 'id = ?', whereArgs: [id]);
    });
  }
}

class InMemoryMedicationStorage implements MedicationStorage {
  InMemoryMedicationStorage({
    List<Medication>? medications,
    List<MedicationLog>? logs,
    List<PrnMedicationLog>? prnLogs,
    List<PrnSymptomLink>? prnSymptomLinks,
    List<MedicationDoseHistory>? doseHistory,
  }) : _medications = List.of(medications ?? const []),
       _logs = List.of(logs ?? const []),
       _prnLogs = List.of(prnLogs ?? const []),
       _prnSymptomLinks = List.of(prnSymptomLinks ?? const []),
       _doseHistory = List.of(doseHistory ?? const []);

  final List<Medication> _medications;
  final List<MedicationLog> _logs;
  final List<PrnMedicationLog> _prnLogs;
  final List<PrnSymptomLink> _prnSymptomLinks;
  final List<MedicationDoseHistory> _doseHistory;

  @override
  Future<List<Medication>> fetchActiveMedications() async {
    return _medications.where((item) => item.isActive).toList();
  }

  @override
  Future<List<Medication>> fetchAllMedications() async => List.of(_medications);

  @override
  Future<List<MedicationLog>> fetchLogsForDate(DateTime date) async {
    final key = MedicationLog.formatDateKey(date);
    return _logs.where((log) => log.dateKey == key).toList();
  }

  @override
  Future<List<MedicationLog>> fetchAllLogs() async => List.of(_logs);

  @override
  Future<List<PrnMedicationLog>> fetchPrnLogsForDate(DateTime date) async {
    final key = MedicationLog.formatDateKey(date);
    final result = _prnLogs.where((log) => log.dateKey == key).toList()
      ..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    return result;
  }

  @override
  Future<List<PrnMedicationLog>> fetchAllPrnLogs() async => List.of(_prnLogs);

  @override
  Future<List<PrnSymptomLink>> fetchAllPrnSymptomLinks() async =>
      List.of(_prnSymptomLinks);

  @override
  Future<List<MedicationDoseHistory>> fetchDoseHistory(
    String medicationId,
  ) async {
    final result =
        _doseHistory.where((item) => item.medicationId == medicationId).toList()
          ..sort((a, b) => b.changedAt.compareTo(a.changedAt));
    return result;
  }

  @override
  Future<List<MedicationDoseHistory>> fetchAllDoseHistory() async =>
      List.of(_doseHistory);

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
  Future<void> updateMedicationWithDoseHistory(
    Medication medication,
    MedicationDoseHistory? history,
  ) async {
    await updateMedication(medication);
    if (history != null) {
      _doseHistory.add(history);
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

  @override
  Future<void> insertPrnMedicationLog(
    PrnMedicationLog log, {
    List<PrnSymptomLink> symptomLinks = const [],
  }) async {
    _prnLogs.add(log);
    for (final link in symptomLinks) {
      final exists = _prnSymptomLinks.any(
        (item) =>
            item.prnMedicationLogId == link.prnMedicationLogId &&
            item.symptomDefinitionId == link.symptomDefinitionId,
      );
      if (!exists) {
        _prnSymptomLinks.add(link);
      }
    }
  }

  @override
  Future<void> updatePrnMedicationLog(
    PrnMedicationLog log, {
    List<PrnSymptomLink> symptomLinks = const [],
  }) async {
    final index = _prnLogs.indexWhere((item) => item.id == log.id);
    if (index == -1) {
      _prnLogs.add(log);
    } else {
      _prnLogs[index] = log;
    }
    _prnSymptomLinks.removeWhere((link) => link.prnMedicationLogId == log.id);
    for (final link in symptomLinks) {
      final exists = _prnSymptomLinks.any(
        (item) =>
            item.prnMedicationLogId == link.prnMedicationLogId &&
            item.symptomDefinitionId == link.symptomDefinitionId,
      );
      if (!exists) {
        _prnSymptomLinks.add(link);
      }
    }
  }

  @override
  Future<void> deletePrnMedicationLog(String id) async {
    _prnSymptomLinks.removeWhere((link) => link.prnMedicationLogId == id);
    _prnLogs.removeWhere((log) => log.id == id);
  }
}
