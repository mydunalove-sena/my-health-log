import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_health_log/models/medication.dart';
import 'package:my_health_log/models/symptom.dart';
import 'package:my_health_log/screens/data_management/data_management_screen.dart';
import 'package:my_health_log/services/backup_service.dart';
import 'package:my_health_log/services/exercise_service.dart';
import 'package:my_health_log/services/health_record_service.dart';
import 'package:my_health_log/services/lab_result_service.dart';
import 'package:my_health_log/services/medication_service.dart';
import 'package:my_health_log/services/symptom_service.dart';

void main() {
  testWidgets('restore refreshes medication and symptom service state', (
    tester,
  ) async {
    final date = DateTime(2026, 8, 26);
    final now = DateTime(2026, 8, 26, 9);
    final definitions = _symptomDefinitions(now);
    final staleSymptomRecords = [
      _symptomRecord(
        id: 'stale-headache',
        symptomDefinitionId: 'symptom-headache',
        date: date,
        severity: SymptomSeverity.severe,
        now: now,
      ),
      _symptomRecord(
        id: 'stale-fatigue',
        symptomDefinitionId: 'symptom-fatigue',
        date: date,
        severity: SymptomSeverity.mild,
        now: now,
      ),
    ];
    final restoredSymptomRecords = [
      _symptomRecord(
        id: 'restored-headache',
        symptomDefinitionId: 'symptom-headache',
        date: date,
        severity: SymptomSeverity.mild,
        now: now,
      ),
      _symptomRecord(
        id: 'restored-fatigue',
        symptomDefinitionId: 'symptom-fatigue',
        date: date,
        severity: SymptomSeverity.severe,
        now: now,
      ),
    ];
    final staleMedication = _medication(id: 'stale-med', name: 'Stale med');
    final restoredMedication = _medication(
      id: 'restored-med',
      name: 'Restored med',
    );

    final medicationStorage = _MutableMedicationStorage(
      medications: [staleMedication],
    );
    final symptomStorage = _MutableSymptomStorage(
      definitions: definitions,
      records: staleSymptomRecords,
    );
    final medicationService = MedicationService(medicationStorage);
    final symptomService = SymptomService(symptomStorage);
    final healthRecordService = HealthRecordService(
      InMemoryHealthRecordStorage(),
    );
    final exerciseService = ExerciseService(
      InMemoryExerciseRecordStorage(),
      healthRecordService,
    );
    await Future.wait([
      healthRecordService.load(),
      medicationService.load(),
      symptomService.load(),
      exerciseService.load(),
    ]);

    expect(
      symptomService.severityForDateAndSymptom(date, 'symptom-headache'),
      SymptomSeverity.severe,
    );
    expect(
      symptomService.severityForDateAndSymptom(date, 'symptom-fatigue'),
      SymptomSeverity.mild,
    );
    expect(medicationService.activeMedications.single.name, 'Stale med');

    final restoredSnapshot = BackupSnapshot(
      healthRecords: const [],
      medications: [restoredMedication],
      medicationLogs: const [],
      labResults: const [],
      symptomDefinitions: definitions,
      symptomRecords: restoredSymptomRecords,
    );
    final backupService = _TestBackupService(
      repository: _MutableBackupRepository(
        medicationStorage: medicationStorage,
        symptomStorage: symptomStorage,
      ),
      document: BackupDocument(
        createdAt: now,
        appVersion: 'test',
        snapshot: restoredSnapshot,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DataManagementScreen(
          backupService: backupService,
          healthRecordService: healthRecordService,
          medicationService: medicationService,
          labResultService: LabResultService(InMemoryLabResultStorage()),
          symptomService: symptomService,
          exerciseService: exerciseService,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.restore));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.byType(FilledButton).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(
      symptomService.severityForDateAndSymptom(date, 'symptom-headache'),
      SymptomSeverity.mild,
    );
    expect(
      symptomService.severityForDateAndSymptom(date, 'symptom-fatigue'),
      SymptomSeverity.severe,
    );
    expect(medicationService.activeMedications.single.name, 'Restored med');
  });
}

class _TestBackupService extends BackupService {
  _TestBackupService({required super.repository, required this.document});

  final BackupDocument document;

  @override
  Future<BackupDocument?> pickAndValidateBackup() async => document;
}

class _MutableBackupRepository implements BackupRepository {
  _MutableBackupRepository({
    required this.medicationStorage,
    required this.symptomStorage,
  });

  final _MutableMedicationStorage medicationStorage;
  final _MutableSymptomStorage symptomStorage;

  @override
  Future<BackupSnapshot> fetchSnapshot() async {
    return BackupSnapshot(
      healthRecords: const [],
      medications: await medicationStorage.fetchActiveMedications(),
      medicationLogs: await medicationStorage.fetchAllLogs(),
      prnMedicationLogs: await medicationStorage.fetchAllPrnLogs(),
      medicationDoseHistory: await medicationStorage.fetchAllDoseHistory(),
      symptomDefinitions: await symptomStorage.fetchDefinitions(),
      symptomRecords: await symptomStorage.fetchRecords(),
      prnSymptomLinks: await medicationStorage.fetchAllPrnSymptomLinks(),
      labResults: const [],
    );
  }

  @override
  Future<void> replaceWith(BackupSnapshot snapshot) async {
    medicationStorage.replaceWith(snapshot);
    symptomStorage.replaceWith(snapshot);
  }
}

class _MutableSymptomStorage implements SymptomStorage {
  _MutableSymptomStorage({
    required List<SymptomDefinition> definitions,
    required List<SymptomRecord> records,
  }) : _definitions = List.of(definitions),
       _records = List.of(records);

  List<SymptomDefinition> _definitions;
  List<SymptomRecord> _records;

  void replaceWith(BackupSnapshot snapshot) {
    _definitions = List.of(snapshot.symptomDefinitions);
    _records = List.of(snapshot.symptomRecords);
  }

  @override
  Future<List<SymptomDefinition>> fetchDefinitions() async {
    return List.of(_definitions);
  }

  @override
  Future<List<SymptomRecord>> fetchRecords() async {
    return List.of(_records);
  }

  @override
  Future<void> insertDefinition(SymptomDefinition definition) async {
    _definitions.add(definition);
  }

  @override
  Future<void> updateDefinition(SymptomDefinition definition) async {
    final index = _definitions.indexWhere((item) => item.id == definition.id);
    if (index == -1) {
      _definitions.add(definition);
    } else {
      _definitions[index] = definition;
    }
  }

  @override
  Future<void> upsertRecord(SymptomRecord record) async {
    final index = _records.indexWhere(
      (item) =>
          item.dateKey == record.dateKey &&
          item.symptomDefinitionId == record.symptomDefinitionId,
    );
    if (index == -1) {
      _records.add(record);
    } else {
      _records[index] = record;
    }
  }
}

class _MutableMedicationStorage implements MedicationStorage {
  _MutableMedicationStorage({required List<Medication> medications})
    : _medications = List.of(medications);

  List<Medication> _medications;
  List<MedicationLog> _logs = [];
  List<PrnMedicationLog> _prnLogs = [];
  List<PrnSymptomLink> _prnSymptomLinks = [];
  List<MedicationDoseHistory> _doseHistory = [];

  void replaceWith(BackupSnapshot snapshot) {
    _medications = List.of(snapshot.medications);
    _logs = List.of(snapshot.medicationLogs);
    _prnLogs = List.of(snapshot.prnMedicationLogs);
    _prnSymptomLinks = List.of(snapshot.prnSymptomLinks);
    _doseHistory = List.of(snapshot.medicationDoseHistory);
  }

  @override
  Future<List<Medication>> fetchActiveMedications() async {
    return _medications.where((item) => item.isActive).toList();
  }

  @override
  Future<List<Medication>> fetchAllMedications() async => List.of(_medications);

  @override
  Future<List<MedicationLog>> fetchLogsForDate(DateTime date) async {
    final dateKey = MedicationLog.formatDateKey(date);
    return _logs.where((item) => item.dateKey == dateKey).toList();
  }

  @override
  Future<List<MedicationLog>> fetchAllLogs() async => List.of(_logs);

  @override
  Future<List<PrnMedicationLog>> fetchPrnLogsForDate(DateTime date) async {
    final dateKey = MedicationLog.formatDateKey(date);
    return _prnLogs.where((item) => item.dateKey == dateKey).toList();
  }

  @override
  Future<List<PrnMedicationLog>> fetchAllPrnLogs() async => List.of(_prnLogs);

  @override
  Future<List<PrnSymptomLink>> fetchAllPrnSymptomLinks() async {
    return List.of(_prnSymptomLinks);
  }

  @override
  Future<List<MedicationDoseHistory>> fetchDoseHistory(
    String medicationId,
  ) async {
    return _doseHistory
        .where((item) => item.medicationId == medicationId)
        .toList();
  }

  @override
  Future<List<MedicationDoseHistory>> fetchAllDoseHistory() async {
    return List.of(_doseHistory);
  }

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
    final index = _logs.indexWhere((item) => item.uniqueKey == log.uniqueKey);
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
    _prnSymptomLinks.addAll(symptomLinks);
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
    _prnSymptomLinks.removeWhere((item) => item.prnMedicationLogId == log.id);
    _prnSymptomLinks.addAll(symptomLinks);
  }

  @override
  Future<void> deletePrnMedicationLog(String id) async {
    _prnSymptomLinks.removeWhere((item) => item.prnMedicationLogId == id);
    _prnLogs.removeWhere((item) => item.id == id);
  }
}

List<SymptomDefinition> _symptomDefinitions(DateTime now) {
  return [
    SymptomDefinition(
      id: 'symptom-headache',
      name: 'Headache',
      isDefault: true,
      isActive: true,
      sortOrder: 10,
      createdAt: now,
      updatedAt: now,
    ),
    SymptomDefinition(
      id: 'symptom-fatigue',
      name: 'Fatigue',
      isDefault: true,
      isActive: true,
      sortOrder: 20,
      createdAt: now,
      updatedAt: now,
    ),
  ];
}

SymptomRecord _symptomRecord({
  required String id,
  required String symptomDefinitionId,
  required DateTime date,
  required SymptomSeverity severity,
  required DateTime now,
}) {
  return SymptomRecord(
    id: id,
    symptomDefinitionId: symptomDefinitionId,
    date: date,
    severity: severity,
    createdAt: now,
    updatedAt: now,
  );
}

Medication _medication({required String id, required String name}) {
  final now = DateTime(2026, 8, 26, 9);
  return Medication(
    id: id,
    name: name,
    morning: true,
    lunch: false,
    evening: false,
    bedtime: false,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}
