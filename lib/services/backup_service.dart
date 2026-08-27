import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/health_record.dart';
import '../models/lab_result.dart';
import '../models/medication.dart';
import '../models/symptom.dart';
import 'app_database.dart';

class BackupValidationException implements Exception {
  const BackupValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackupSnapshot {
  const BackupSnapshot({
    required this.healthRecords,
    required this.medications,
    required this.medicationLogs,
    required this.labResults,
    this.prnMedicationLogs = const [],
    this.medicationDoseHistory = const [],
    this.symptomDefinitions = const [],
    this.symptomRecords = const [],
    this.prnSymptomLinks = const [],
  });

  final List<HealthRecord> healthRecords;
  final List<Medication> medications;
  final List<MedicationLog> medicationLogs;
  final List<PrnMedicationLog> prnMedicationLogs;
  final List<MedicationDoseHistory> medicationDoseHistory;
  final List<SymptomDefinition> symptomDefinitions;
  final List<SymptomRecord> symptomRecords;
  final List<PrnSymptomLink> prnSymptomLinks;
  final List<LabResult> labResults;

  Map<String, Object?> toJson() {
    return {
      'healthRecords': healthRecords.map((record) => record.toMap()).toList(),
      'medications': medications
          .map((medication) => medication.toMap())
          .toList(),
      'medicationLogs': medicationLogs.map((log) => log.toMap()).toList(),
      'prnMedicationLogs': prnMedicationLogs.map((log) => log.toMap()).toList(),
      'medicationDoseHistory': medicationDoseHistory
          .map((item) => item.toMap())
          .toList(),
      'symptomDefinitions': symptomDefinitions
          .map((definition) => definition.toMap())
          .toList(),
      'symptomRecords': symptomRecords.map((record) => record.toMap()).toList(),
      'prnSymptomLinks': prnSymptomLinks.map((link) => link.toMap()).toList(),
      'labResults': labResults.map((result) => result.toMap()).toList(),
    };
  }

  factory BackupSnapshot.fromJson(
    Map<String, Object?> json, {
    required int backupVersion,
  }) {
    final healthRecords = _readCollection(
      json,
      'healthRecords',
      HealthRecord.fromMap,
    );
    final medications = _readCollection(
      json,
      'medications',
      Medication.fromMap,
    );
    final medicationLogs = _readCollection(
      json,
      'medicationLogs',
      MedicationLog.fromMap,
    );
    final prnMedicationLogs = _readOptionalCollection(
      json,
      'prnMedicationLogs',
      PrnMedicationLog.fromMap,
    );
    final medicationDoseHistory = _readOptionalCollection(
      json,
      'medicationDoseHistory',
      MedicationDoseHistory.fromMap,
    );
    final symptomDefinitions = _readVersionedCollection(
      json,
      'symptomDefinitions',
      SymptomDefinition.fromMap,
      isRequired: backupVersion >= 4,
    );
    final symptomRecords = _readVersionedCollection(
      json,
      'symptomRecords',
      SymptomRecord.fromMap,
      isRequired: backupVersion >= 4,
    );
    final prnSymptomLinks = _readVersionedCollection(
      json,
      'prnSymptomLinks',
      PrnSymptomLink.fromMap,
      isRequired: backupVersion >= 4,
    );
    final labResults = _readCollection(json, 'labResults', LabResult.fromMap);

    final medicationIds = medications.map((item) => item.id).toSet();
    final prnLogIds = prnMedicationLogs.map((item) => item.id).toSet();
    final symptomDefinitionIds = symptomDefinitions
        .map((item) => item.id)
        .toSet();
    if (medicationLogs.any(
          (log) => !medicationIds.contains(log.medicationId),
        ) ||
        prnMedicationLogs.any(
          (log) => !medicationIds.contains(log.medicationId),
        ) ||
        medicationDoseHistory.any(
          (item) => !medicationIds.contains(item.medicationId),
        ) ||
        symptomRecords.any(
          (record) =>
              !symptomDefinitionIds.contains(record.symptomDefinitionId),
        ) ||
        prnSymptomLinks.any(
          (link) =>
              !prnLogIds.contains(link.prnMedicationLogId) ||
              !symptomDefinitionIds.contains(link.symptomDefinitionId),
        )) {
      throw const BackupValidationException('백업 데이터가 손상되어 복원할 수 없습니다.');
    }

    return BackupSnapshot(
      healthRecords: healthRecords,
      medications: medications,
      medicationLogs: medicationLogs,
      prnMedicationLogs: prnMedicationLogs,
      medicationDoseHistory: medicationDoseHistory,
      symptomDefinitions: symptomDefinitions,
      symptomRecords: symptomRecords,
      prnSymptomLinks: prnSymptomLinks,
      labResults: labResults,
    );
  }

  static List<T> _readCollection<T>(
    Map<String, Object?> json,
    String key,
    T Function(Map<String, Object?> map) parse,
  ) {
    final value = json[key];
    if (value is! List) {
      throw const BackupValidationException('백업 데이터가 손상되어 복원할 수 없습니다.');
    }
    return _parseCollection(value, parse);
  }

  static List<T> _readOptionalCollection<T>(
    Map<String, Object?> json,
    String key,
    T Function(Map<String, Object?> map) parse,
  ) {
    final value = json[key];
    if (value == null) return [];
    if (value is! List) {
      throw const BackupValidationException('백업 데이터가 손상되어 복원할 수 없습니다.');
    }
    return _parseCollection(value, parse);
  }

  static List<T> _readVersionedCollection<T>(
    Map<String, Object?> json,
    String key,
    T Function(Map<String, Object?> map) parse, {
    required bool isRequired,
  }) {
    if (isRequired) {
      return _readCollection(json, key, parse);
    }
    return _readOptionalCollection(json, key, parse);
  }

  static List<T> _parseCollection<T>(
    List<Object?> value,
    T Function(Map<String, Object?> map) parse,
  ) {
    try {
      return [
        for (final item in value)
          if (item is Map<String, Object?>)
            parse(item)
          else if (item is Map)
            parse(Map<String, Object?>.from(item))
          else
            throw const BackupValidationException('백업 데이터가 손상되어 복원할 수 없습니다.'),
      ];
    } on BackupValidationException {
      rethrow;
    } catch (_) {
      throw const BackupValidationException('백업 데이터가 손상되어 복원할 수 없습니다.');
    }
  }
}

class BackupDocument {
  const BackupDocument({
    required this.createdAt,
    required this.appVersion,
    required this.snapshot,
  });

  static const appName = 'My Health Log';
  static const backupVersion = 4;
  static const supportedBackupVersions = {1, 2, 3, 4};

  final DateTime createdAt;
  final String appVersion;
  final BackupSnapshot snapshot;

  int get totalCount {
    return snapshot.healthRecords.length +
        snapshot.medications.length +
        snapshot.medicationLogs.length +
        snapshot.prnMedicationLogs.length +
        snapshot.medicationDoseHistory.length +
        snapshot.symptomDefinitions.length +
        snapshot.symptomRecords.length +
        snapshot.prnSymptomLinks.length +
        snapshot.labResults.length;
  }

  Map<String, Object?> toJson() {
    return {
      'app': appName,
      'backupVersion': backupVersion,
      'createdAt': createdAt.toIso8601String(),
      'appVersion': appVersion,
      'data': snapshot.toJson(),
    };
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  factory BackupDocument.fromJsonString(String text) {
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw const BackupValidationException('백업 파일을 읽을 수 없습니다.');
    }
    if (decoded is! Map) {
      throw const BackupValidationException('My Health Log 백업 파일이 아닙니다.');
    }
    final json = Map<String, Object?>.from(decoded);
    if (json['app'] != appName) {
      throw const BackupValidationException('My Health Log 백업 파일이 아닙니다.');
    }
    if (!json.containsKey('backupVersion')) {
      throw const BackupValidationException('백업 데이터가 손상되어 복원할 수 없습니다.');
    }
    final version = json['backupVersion'];
    if (version is! int || !supportedBackupVersions.contains(version)) {
      throw const BackupValidationException('지원하지 않는 백업 버전입니다.');
    }
    final data = json['data'];
    if (data is! Map) {
      throw const BackupValidationException('백업 데이터가 손상되어 복원할 수 없습니다.');
    }

    try {
      return BackupDocument(
        createdAt: DateTime.parse(json['createdAt'] as String),
        appVersion: json['appVersion'] as String,
        snapshot: BackupSnapshot.fromJson(
          Map<String, Object?>.from(data),
          backupVersion: version,
        ),
      );
    } on BackupValidationException {
      rethrow;
    } catch (_) {
      throw const BackupValidationException('백업 데이터가 손상되어 복원할 수 없습니다.');
    }
  }
}

abstract class BackupRepository {
  Future<BackupSnapshot> fetchSnapshot();
  Future<void> replaceWith(BackupSnapshot snapshot);
}

class SqfliteBackupRepository implements BackupRepository {
  static const _healthRecordsTable = 'health_records';
  static const _medicationsTable = 'medications';
  static const _medicationLogsTable = 'medication_logs';
  static const _prnMedicationLogsTable = 'prn_medication_logs';
  static const _doseHistoryTable = 'medication_dose_history';
  static const _symptomDefinitionsTable = 'symptom_definitions';
  static const _symptomRecordsTable = 'symptom_records';
  static const _prnSymptomLinksTable = 'prn_symptom_links';
  static const _labResultsTable = 'lab_results';

  @override
  Future<BackupSnapshot> fetchSnapshot() async {
    final db = await AppDatabase.open();
    final healthRows = await db.query(
      _healthRecordsTable,
      orderBy: 'date DESC',
    );
    final medicationRows = await db.query(
      _medicationsTable,
      orderBy: 'createdAt ASC',
    );
    final logRows = await db.query(
      _medicationLogsTable,
      orderBy: 'date ASC, timeSlot ASC',
    );
    final prnLogRows = await db.query(
      _prnMedicationLogsTable,
      orderBy: 'takenAt ASC',
    );
    final historyRows = await db.query(
      _doseHistoryTable,
      orderBy: 'changedAt ASC',
    );
    final symptomDefinitionRows = await db.query(
      _symptomDefinitionsTable,
      orderBy: 'sortOrder ASC, name ASC',
    );
    final symptomRecordRows = await db.query(
      _symptomRecordsTable,
      orderBy: 'date DESC, symptomDefinitionId ASC',
    );
    final prnSymptomLinkRows = await db.query(
      _prnSymptomLinksTable,
      orderBy: 'createdAt ASC',
    );
    final labRows = await db.query(_labResultsTable, orderBy: 'date DESC');

    return BackupSnapshot(
      healthRecords: healthRows.map(HealthRecord.fromMap).toList(),
      medications: medicationRows.map(Medication.fromMap).toList(),
      medicationLogs: logRows.map(MedicationLog.fromMap).toList(),
      prnMedicationLogs: prnLogRows.map(PrnMedicationLog.fromMap).toList(),
      medicationDoseHistory: historyRows
          .map(MedicationDoseHistory.fromMap)
          .toList(),
      symptomDefinitions: symptomDefinitionRows
          .map(SymptomDefinition.fromMap)
          .toList(),
      symptomRecords: symptomRecordRows.map(SymptomRecord.fromMap).toList(),
      prnSymptomLinks: prnSymptomLinkRows.map(PrnSymptomLink.fromMap).toList(),
      labResults: labRows.map(LabResult.fromMap).toList(),
    );
  }

  @override
  Future<void> replaceWith(BackupSnapshot snapshot) async {
    final db = await AppDatabase.open();
    await db.transaction((txn) async {
      await txn.delete(_prnSymptomLinksTable);
      await txn.delete(_symptomRecordsTable);
      await txn.delete(_doseHistoryTable);
      await txn.delete(_prnMedicationLogsTable);
      await txn.delete(_medicationLogsTable);
      await txn.delete(_medicationsTable);
      await txn.delete(_symptomDefinitionsTable);
      await txn.delete(_healthRecordsTable);
      await txn.delete(_labResultsTable);

      for (final record in snapshot.healthRecords) {
        await txn.insert(_healthRecordsTable, record.toMap());
      }
      for (final medication in snapshot.medications) {
        await txn.insert(_medicationsTable, medication.toMap());
      }
      for (final definition in snapshot.symptomDefinitions) {
        await txn.insert(_symptomDefinitionsTable, definition.toMap());
      }
      for (final log in snapshot.medicationLogs) {
        await txn.insert(_medicationLogsTable, log.toMap());
      }
      for (final log in snapshot.prnMedicationLogs) {
        await txn.insert(_prnMedicationLogsTable, log.toMap());
      }
      for (final item in snapshot.medicationDoseHistory) {
        await txn.insert(_doseHistoryTable, item.toMap());
      }
      for (final record in snapshot.symptomRecords) {
        await txn.insert(_symptomRecordsTable, record.toMap());
      }
      for (final link in snapshot.prnSymptomLinks) {
        await txn.insert(_prnSymptomLinksTable, link.toMap());
      }
      for (final result in snapshot.labResults) {
        await txn.insert(_labResultsTable, result.toMap());
      }
    });
  }
}

class InMemoryBackupRepository implements BackupRepository {
  InMemoryBackupRepository([BackupSnapshot? snapshot])
    : _snapshot =
          snapshot ??
          const BackupSnapshot(
            healthRecords: [],
            medications: [],
            medicationLogs: [],
            labResults: [],
          );

  BackupSnapshot _snapshot;

  @override
  Future<BackupSnapshot> fetchSnapshot() async => _snapshot;

  @override
  Future<void> replaceWith(BackupSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}

class BackupService {
  BackupService({required this.repository, this.appVersion = '1.0.1+2'});

  final BackupRepository repository;
  final String appVersion;

  Future<BackupDocument> createBackup({DateTime? createdAt}) async {
    return BackupDocument(
      createdAt: createdAt ?? DateTime.now(),
      appVersion: appVersion,
      snapshot: await repository.fetchSnapshot(),
    );
  }

  BackupDocument validateBackup(String text) {
    return BackupDocument.fromJsonString(text);
  }

  Future<void> restoreBackup(BackupDocument document) async {
    final current = await repository.fetchSnapshot();
    try {
      await repository.replaceWith(document.snapshot);
    } catch (_) {
      await repository.replaceWith(current);
      rethrow;
    }
  }

  Future<File> writeBackupFile(BackupDocument document) async {
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/${backupFileName(document.createdAt)}',
    );
    return file.writeAsString(document.toPrettyJson(), flush: true);
  }

  Future<String?> saveBackupFile(BackupDocument document) async {
    final fileName = backupFileName(document.createdAt);
    return FilePicker.platform.saveFile(
      dialogTitle: '백업 파일 저장',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: Uint8List.fromList(utf8.encode(document.toPrettyJson())),
    );
  }

  Future<void> shareBackupFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'My Health Log backup',
      text: 'My Health Log backup',
    );
  }

  Future<BackupDocument?> pickAndValidateBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) {
      throw const BackupValidationException('백업 파일을 읽을 수 없습니다.');
    }
    return validateBackup(await File(path).readAsString());
  }

  String backupFileName(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${date.year}${twoDigits(date.month)}${twoDigits(date.day)}_'
        '${twoDigits(date.hour)}${twoDigits(date.minute)}${twoDigits(date.second)}';
    return 'my_health_log_backup_$stamp.json';
  }
}

@visibleForTesting
String encodeBackupForTest(BackupDocument document) => document.toPrettyJson();
