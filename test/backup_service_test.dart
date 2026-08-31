import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_health_log/models/exercise_record.dart';
import 'package:my_health_log/models/health_record.dart';
import 'package:my_health_log/models/lab_test_definition.dart';
import 'package:my_health_log/models/lab_result.dart';
import 'package:my_health_log/models/medication.dart';
import 'package:my_health_log/models/symptom.dart';
import 'package:my_health_log/services/backup_service.dart';
import 'package:my_health_log/services/lab_test_settings_service.dart';

void main() {
  group('BackupService', () {
    test('creates a valid empty backup', () async {
      final service = BackupService(
        repository: InMemoryBackupRepository(),
        appVersion: 'test-version',
      );

      final backup = await service.createBackup(createdAt: _dateTime());
      final decoded = service.validateBackup(backup.toPrettyJson());

      expect(decoded.appVersion, 'test-version');
      expect(decoded.totalCount, 0);
      expect(decoded.toJson()['backupVersion'], 6);
      expect(decoded.snapshot.labTestSettings, isNotNull);
      expect(decoded.snapshot.healthRecords, isEmpty);
      expect(decoded.snapshot.medications, isEmpty);
      expect(decoded.snapshot.medicationLogs, isEmpty);
      expect(decoded.snapshot.prnMedicationLogs, isEmpty);
      expect(decoded.snapshot.symptomDefinitions, isEmpty);
      expect(decoded.snapshot.symptomRecords, isEmpty);
      expect(decoded.snapshot.prnSymptomLinks, isEmpty);
      expect(decoded.snapshot.exerciseRecords, isEmpty);
      expect(decoded.snapshot.labResults, isEmpty);
    });

    test('uses stable timestamped JSON backup file name', () {
      final service = BackupService(repository: InMemoryBackupRepository());
      expect(
        service.backupFileName(_dateTime()),
        'my_health_log_backup_20260824_103045.json',
      );
    });

    test('preserves all legacy entity fields in backup JSON', () async {
      final snapshot = _snapshot();
      final service = BackupService(
        repository: InMemoryBackupRepository(snapshot),
      );

      final backup = await service.createBackup(createdAt: _dateTime());
      final decoded = service.validateBackup(backup.toPrettyJson());

      expect(_snapshotJson(decoded.snapshot), _snapshotJson(snapshot));
      expect(decoded.snapshot.healthRecords.single.weight, 0);
      expect(
        decoded.snapshot.healthRecords.single.condition,
        HealthCondition.bad,
      );
      expect(decoded.snapshot.medications.single.dose, '긴 용량 메모 !@# 한글');
      expect(
        decoded.snapshot.medications.single.type,
        MedicationType.scheduled,
      );
      expect(decoded.snapshot.medicationLogs.single.isTaken, isTrue);
      expect(decoded.snapshot.labResults.single.unit, 'mg/dL');
      expect(
        decoded.snapshot.exerciseRecords.single.exerciseType,
        ExerciseType.walking,
      );
      expect(
        decoded.snapshot.exerciseRecords.single.estimatedCalories,
        closeTo(137.28, 0.01),
      );
    });

    test(
      'V3 PRN medication and PRN log round-trip without data loss',
      () async {
        final now = _dateTime();
        final medication = Medication(
          id: 'prn-med',
          name: '편두통약',
          type: MedicationType.prn,
          dose: '0.5정',
          doseValue: 0.5,
          doseUnit: MedicationDoseUnit.tablet,
          morning: false,
          lunch: false,
          evening: false,
          bedtime: false,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );
        final snapshot = BackupSnapshot(
          healthRecords: const [],
          medications: [medication],
          medicationLogs: const [],
          prnMedicationLogs: [
            PrnMedicationLog(
              id: 'prn-log',
              medicationId: medication.id,
              date: DateTime(2026, 8, 24),
              takenAt: DateTime(2026, 8, 24, 14, 20),
              doseValue: 0.5,
              doseUnit: MedicationDoseUnit.tablet,
              note: '두통',
              createdAt: now,
              updatedAt: now,
            ),
          ],
          labResults: const [],
        );
        final service = BackupService(
          repository: InMemoryBackupRepository(snapshot),
        );

        final decoded = service.validateBackup(
          (await service.createBackup(createdAt: now)).toPrettyJson(),
        );

        expect(decoded.snapshot.medications.single.type, MedicationType.prn);
        expect(decoded.snapshot.medications.single.displayDose, '0.5정');
        expect(decoded.snapshot.prnMedicationLogs, hasLength(1));
        expect(decoded.snapshot.prnMedicationLogs.single.displayDose, '0.5정');
        expect(decoded.snapshot.prnMedicationLogs.single.note, '두통');
      },
    );

    test('accepts V2 backupVersion 1 and defaults missing V3 fields', () {
      final service = BackupService(repository: InMemoryBackupRepository());
      final legacy = jsonEncode({
        'app': 'My Health Log',
        'backupVersion': 1,
        'createdAt': '2026-08-24T10:30:45.000',
        'appVersion': '1.0.1+2',
        'data': {
          'healthRecords': <Object?>[],
          'medications': [
            {
              'id': 'legacy-med',
              'name': '기존약',
              'dose': '0.5정',
              'morning': 1,
              'lunch': 0,
              'evening': 0,
              'bedtime': 0,
              'isActive': 1,
              'createdAt': '2026-08-24T09:00:00.000',
              'updatedAt': '2026-08-24T09:00:00.000',
            },
          ],
          'medicationLogs': <Object?>[],
          'labResults': <Object?>[],
        },
      });

      final decoded = service.validateBackup(legacy);

      expect(
        decoded.snapshot.medications.single.type,
        MedicationType.scheduled,
      );
      expect(decoded.snapshot.medications.single.doseValue, 0.5);
      expect(
        decoded.snapshot.medications.single.doseUnit,
        MedicationDoseUnit.tablet,
      );
      expect(decoded.snapshot.prnMedicationLogs, isEmpty);
      expect(decoded.snapshot.symptomDefinitions, isEmpty);
      expect(decoded.snapshot.symptomRecords, isEmpty);
      expect(decoded.snapshot.prnSymptomLinks, isEmpty);
      expect(decoded.snapshot.exerciseRecords, isEmpty);
    });

    test('symptom definitions round-trip through backup restore', () async {
      final original = _symptomSnapshot(idSuffix: 'original');
      final repository = InMemoryBackupRepository(original);
      final service = BackupService(repository: repository);
      final backup = await service.createBackup(createdAt: _dateTime());

      await repository.replaceWith(_symptomSnapshot(idSuffix: 'changed'));
      await service.restoreBackup(
        service.validateBackup(backup.toPrettyJson()),
      );

      final restored = await repository.fetchSnapshot();
      expect(restored.symptomDefinitions, hasLength(1));
      expect(
        restored.symptomDefinitions.single.toMap(),
        original.symptomDefinitions.single.toMap(),
      );
    });

    test('V5 exercise records round-trip and preserve legacy steps', () async {
      final original = _snapshot();
      final repository = InMemoryBackupRepository(original);
      final service = BackupService(repository: repository);
      final backup = await service.createBackup(createdAt: _dateTime());

      await repository.replaceWith(
        const BackupSnapshot(
          healthRecords: [],
          medications: [],
          medicationLogs: [],
          labResults: [],
        ),
      );
      await service.restoreBackup(
        service.validateBackup(backup.toPrettyJson()),
      );

      final restored = await repository.fetchSnapshot();
      expect(restored.exerciseRecords, hasLength(1));
      expect(
        restored.exerciseRecords.single.toMap(),
        original.exerciseRecords.single.toMap(),
      );
      expect(restored.healthRecords.single.steps, 12345);
    });

    test('user-added and renamed symptom definition round-trips with records and PRN links', () async {
      final original = _userSymptomSnapshot();
      final repository = InMemoryBackupRepository(original);
      final service = BackupService(repository: repository);
      final backup = await service.createBackup(createdAt: _dateTime());

      await repository.replaceWith(_symptomSnapshot(idSuffix: 'changed'));
      await service.restoreBackup(
        service.validateBackup(backup.toPrettyJson()),
      );

      final restored = await repository.fetchSnapshot();
      expect(restored.symptomDefinitions, hasLength(1));
      expect(restored.symptomDefinitions.single.toMap(), {
        'id': 'symptom-user-neck-pain',
        'name': '목 통증',
        'isDefault': 0,
        'isActive': 1,
        'sortOrder': 50,
        'createdAt': _dateTime().toIso8601String(),
        'updatedAt': DateTime(2026, 8, 24, 11).toIso8601String(),
      });
      expect(
        restored.symptomRecords.single.symptomDefinitionId,
        'symptom-user-neck-pain',
      );
      expect(restored.symptomRecords.single.severity, SymptomSeverity.severe);
      expect(
        restored.prnSymptomLinks.single.symptomDefinitionId,
        'symptom-user-neck-pain',
      );
      expect(_snapshotJson(restored), _snapshotJson(original));
    });

    test('symptom records round-trip with severity', () async {
      final original = _symptomSnapshot(idSuffix: 'original');
      final repository = InMemoryBackupRepository(original);
      final service = BackupService(repository: repository);
      final backup = await service.createBackup(createdAt: _dateTime());

      await repository.replaceWith(_symptomSnapshot(idSuffix: 'changed'));
      await service.restoreBackup(
        service.validateBackup(backup.toPrettyJson()),
      );

      final restored = await repository.fetchSnapshot();
      expect(restored.symptomRecords, hasLength(1));
      expect(restored.symptomRecords.single.toMap(), {
        'id': 'symptom-record-original',
        'symptomDefinitionId': 'symptom-original',
        'date': '2026-08-24',
        'severity': 'severe',
        'createdAt': _dateTime().toIso8601String(),
        'updatedAt': _dateTime().toIso8601String(),
      });
    });

    test('PRN symptom links round-trip with log and symptom IDs', () async {
      final original = _symptomSnapshot(idSuffix: 'original');
      final repository = InMemoryBackupRepository(original);
      final service = BackupService(repository: repository);
      final backup = await service.createBackup(createdAt: _dateTime());

      await repository.replaceWith(_symptomSnapshot(idSuffix: 'changed'));
      await service.restoreBackup(
        service.validateBackup(backup.toPrettyJson()),
      );

      final restored = await repository.fetchSnapshot();
      expect(restored.prnSymptomLinks, hasLength(1));
      expect(
        restored.prnSymptomLinks.single.prnMedicationLogId,
        'prn-log-original',
      );
      expect(
        restored.prnSymptomLinks.single.symptomDefinitionId,
        'symptom-original',
      );
    });

    test('restore replaces symptom and PRN symptom link data', () async {
      final stale = _symptomSnapshot(idSuffix: 'stale');
      final replacement = _symptomSnapshot(
        idSuffix: 'replacement',
        includeSymptomRecord: false,
        includePrnSymptomLink: false,
      );
      final repository = InMemoryBackupRepository(stale);
      final service = BackupService(repository: repository);

      await service.restoreBackup(
        BackupDocument(
          createdAt: _dateTime(),
          appVersion: '1',
          snapshot: replacement,
        ),
      );

      final restored = await repository.fetchSnapshot();
      expect(restored.symptomDefinitions.map((item) => item.id), [
        'symptom-replacement',
      ]);
      expect(restored.symptomRecords, isEmpty);
      expect(restored.prnSymptomLinks, isEmpty);
    });

    test('legacy backup versions restore with empty symptom and exercise collections', () async {
      for (final version in [1, 2, 3, 4, 5]) {
        final repository = InMemoryBackupRepository(
          _symptomSnapshot(idSuffix: 'stale-$version'),
        );
        final service = BackupService(repository: repository);
        final legacy = jsonEncode({
          'app': 'My Health Log',
          'backupVersion': version,
          'createdAt': '2026-08-24T10:30:45.000',
          'appVersion': '1.0.1+2',
          'data': {
            'healthRecords': <Object?>[],
            'medications': <Object?>[],
            'medicationLogs': <Object?>[],
            if (version >= 2) 'prnMedicationLogs': <Object?>[],
            if (version >= 3) 'medicationDoseHistory': <Object?>[],
            if (version >= 4) 'symptomDefinitions': <Object?>[],
            if (version >= 4) 'symptomRecords': <Object?>[],
            if (version >= 4) 'prnSymptomLinks': <Object?>[],
            if (version >= 5) 'exerciseRecords': <Object?>[],
            'labResults': <Object?>[],
          },
        });

        await service.restoreBackup(service.validateBackup(legacy));

        final restored = await repository.fetchSnapshot();
        expect(restored.symptomDefinitions, isEmpty);
        expect(restored.symptomRecords, isEmpty);
        expect(restored.prnSymptomLinks, isEmpty);
        expect(restored.exerciseRecords, isEmpty);
      }
    });

    test('backup version 4 requires symptom definitions collection', () {
      final service = BackupService(repository: InMemoryBackupRepository());

      expect(
        () => service.validateBackup(
          _version4BackupJson(omitKey: 'symptomDefinitions'),
        ),
        throwsA(isA<BackupValidationException>()),
      );
    });

    test('backup version 4 requires symptom records collection', () {
      final service = BackupService(repository: InMemoryBackupRepository());

      expect(
        () => service.validateBackup(
          _version4BackupJson(omitKey: 'symptomRecords'),
        ),
        throwsA(isA<BackupValidationException>()),
      );
    });

    test('backup version 4 requires PRN symptom links collection', () {
      final service = BackupService(repository: InMemoryBackupRepository());

      expect(
        () => service.validateBackup(
          _version4BackupJson(omitKey: 'prnSymptomLinks'),
        ),
        throwsA(isA<BackupValidationException>()),
      );
    });

    test('backup version 5 requires exercise records collection', () {
      final service = BackupService(repository: InMemoryBackupRepository());

      expect(
        () => service.validateBackup(
          _version5BackupJson(omitKey: 'exerciseRecords'),
        ),
        throwsA(isA<BackupValidationException>()),
      );
    });

    test('lab settings round-trip through backup restore', () async {
      final originalSettings = LabTestSettingsService.inMemory();
      await originalSettings.load();
      await originalSettings.setManagementType(LabManagementType.dialysis);
      final activeCustom = await originalSettings.addCustomDefinition(
        displayName: 'Donor-specific antibody',
        defaultUnit: 'MFI',
      );
      final disabledCustom = await originalSettings.addCustomDefinition(
        displayName: 'No Unit Marker',
      );
      await originalSettings.setEnabledLabTestIds(['ktv', activeCustom.id]);

      final repository = InMemoryBackupRepository(_snapshot());
      final service = BackupService(
        repository: repository,
        labTestSettingsService: originalSettings,
      );
      final backup = await service.createBackup(createdAt: _dateTime());
      final decoded = service.validateBackup(backup.toPrettyJson());

      final settings = decoded.snapshot.labTestSettings!;
      expect(settings.managementType, LabManagementType.dialysis);
      expect(settings.enabledLabTestIds, ['ktv', activeCustom.id]);
      expect(settings.customDefinitions.map((definition) => definition.id), [
        activeCustom.id,
        disabledCustom.id,
      ]);
      expect(
        settings.customDefinitions.first.displayName,
        'Donor-specific antibody',
      );
      expect(settings.customDefinitions.first.defaultUnit, 'MFI');
      expect(settings.customDefinitions.last.displayName, 'No Unit Marker');
      expect(settings.customDefinitions.last.defaultUnit, isNull);

      await originalSettings.setManagementType(LabManagementType.generalHealth);
      await originalSettings.setEnabledLabTestIds(['creatinine']);
      await service.restoreBackup(decoded);

      expect(originalSettings.managementType, LabManagementType.dialysis);
      expect(originalSettings.enabledLabTestIds, ['ktv', activeCustom.id]);
      expect(originalSettings.customDefinitions.last.id, disabledCustom.id);
      expect(
        originalSettings.enabledLabTestIds,
        isNot(contains(disabledCustom.id)),
      );
    });

    test('backup version 6 requires valid lab settings payload', () {
      final service = BackupService(repository: InMemoryBackupRepository());

      expect(
        () =>
            service.validateBackup(_version6BackupJson(omitLabSettings: true)),
        throwsA(isA<BackupValidationException>()),
      );
      expect(
        () => service.validateBackup(
          _version6BackupJson(labSettings: {'managementType': 'dialysis'}),
        ),
        throwsA(isA<BackupValidationException>()),
      );
      expect(
        () => service.validateBackup(
          _version6BackupJson(
            labSettings: {
              'managementType': 'dialysis',
              'enabledLabTestIds': ['custom-missing'],
              'customDefinitions': <Object?>[],
            },
          ),
        ),
        throwsA(isA<BackupValidationException>()),
      );
      expect(
        () => service.validateBackup(
          _version6BackupJson(
            labSettings: {
              'managementType': 'not-real',
              'enabledLabTestIds': <Object?>[],
              'customDefinitions': <Object?>[],
            },
          ),
        ),
        throwsA(isA<BackupValidationException>()),
      );
    });

    test('rejects invalid backup files', () {
      final service = BackupService(repository: InMemoryBackupRepository());

      expect(
        () => service.validateBackup('{'),
        throwsA(isA<BackupValidationException>()),
      );
      expect(
        () => service.validateBackup(
          '{"app":"Other","backupVersion":2,"data":{}}',
        ),
        throwsA(isA<BackupValidationException>()),
      );
      expect(
        () => service.validateBackup('{"app":"My Health Log","data":{}}'),
        throwsA(isA<BackupValidationException>()),
      );
      expect(
        () => service.validateBackup(
          '{"app":"My Health Log","backupVersion":999,"data":{}}',
        ),
        throwsA(isA<BackupValidationException>()),
      );
      expect(
        () => service.validateBackup(
          '{"app":"My Health Log","backupVersion":2,"createdAt":"2026-01-01T00:00:00.000","appVersion":"1","data":{"healthRecords":{}}}',
        ),
        throwsA(isA<BackupValidationException>()),
      );
    });

    test('restores by replacing all existing data', () async {
      final original = _snapshot(idSuffix: 'original');
      final replacement = _snapshot(idSuffix: 'replacement');
      final repository = InMemoryBackupRepository(original);
      final service = BackupService(repository: repository);

      await service.restoreBackup(
        BackupDocument(
          createdAt: _dateTime(),
          appVersion: '1',
          snapshot: replacement,
        ),
      );

      final restored = await repository.fetchSnapshot();
      expect(_snapshotJson(restored), _snapshotJson(replacement));
      expect(_snapshotJson(restored), isNot(_snapshotJson(original)));
    });

    test(
      'round-trips backup, delete/change, and restore without data loss',
      () async {
        final original = _snapshot();
        final repository = InMemoryBackupRepository(original);
        final service = BackupService(repository: repository);
        final backup = await service.createBackup(createdAt: _dateTime());

        await repository.replaceWith(
          const BackupSnapshot(
            healthRecords: [],
            medications: [],
            medicationLogs: [],
            labResults: [],
          ),
        );
        await service.restoreBackup(
          service.validateBackup(backup.toPrettyJson()),
        );

        final restored = await repository.fetchSnapshot();
        expect(_snapshotJson(restored), _snapshotJson(original));
      },
    );

    test(
      'repeat restore keeps the same replacement state without duplicates',
      () async {
        final replacement = _snapshot();
        final repository = InMemoryBackupRepository();
        final service = BackupService(repository: repository);
        final document = BackupDocument(
          createdAt: _dateTime(),
          appVersion: '1',
          snapshot: replacement,
        );

        await service.restoreBackup(document);
        await service.restoreBackup(document);

        final restored = await repository.fetchSnapshot();
        expect(_snapshotJson(restored), _snapshotJson(replacement));
        expect(restored.totalForTest, replacement.totalForTest);
      },
    );

    test('keeps existing data when restore fails', () async {
      final original = _snapshot(idSuffix: 'original');
      final replacement = _snapshot(idSuffix: 'replacement');
      final repository = _FailingRestoreRepository(original);
      final service = BackupService(repository: repository);

      expect(
        () => service.restoreBackup(
          BackupDocument(
            createdAt: _dateTime(),
            appVersion: '1',
            snapshot: replacement,
          ),
        ),
        throwsException,
      );

      final restored = await repository.fetchSnapshot();
      expect(_snapshotJson(restored), _snapshotJson(original));
    });

    test('keeps existing lab settings when restore fails', () async {
      final originalSettings = LabTestSettingsService.inMemory();
      await originalSettings.load();
      await originalSettings.setManagementType(
        LabManagementType.liverTransplant,
      );
      await originalSettings.setEnabledLabTestIds(['ast', 'alt']);
      final replacementSettings = LabTestSettingsBackup(
        managementType: LabManagementType.dialysis,
        enabledLabTestIds: const ['ktv'],
        customDefinitions: const [],
      );
      final repository = _FailingRestoreRepository(
        _snapshot(idSuffix: 'original'),
      );
      final service = BackupService(
        repository: repository,
        labTestSettingsService: originalSettings,
      );

      expect(
        () => service.restoreBackup(
          BackupDocument(
            createdAt: _dateTime(),
            appVersion: '1',
            snapshot: _snapshot(idSuffix: 'replacement')
                .copyWith(labTestSettings: replacementSettings),
          ),
        ),
        throwsException,
      );

      expect(
        originalSettings.managementType,
        LabManagementType.liverTransplant,
      );
      expect(originalSettings.enabledLabTestIds, ['ast', 'alt']);
    });
  });
}

extension on BackupSnapshot {
  int get totalForTest {
    return healthRecords.length +
        medications.length +
        medicationLogs.length +
        prnMedicationLogs.length +
        medicationDoseHistory.length +
        symptomDefinitions.length +
        symptomRecords.length +
        prnSymptomLinks.length +
        exerciseRecords.length +
        labResults.length;
  }
}

class _FailingRestoreRepository implements BackupRepository {
  _FailingRestoreRepository(this._snapshot);

  BackupSnapshot _snapshot;
  bool _shouldFail = true;

  @override
  Future<BackupSnapshot> fetchSnapshot() async => _snapshot;

  @override
  Future<void> replaceWith(BackupSnapshot snapshot) async {
    if (_shouldFail) {
      _shouldFail = false;
      throw Exception('restore failed');
    }
    _snapshot = snapshot;
  }
}

BackupSnapshot _snapshot({String idSuffix = 'sample'}) {
  final now = _dateTime();
  final day = DateTime(2026, 8, 24);
  final medicationId = 'med-$idSuffix';
  return BackupSnapshot(
    healthRecords: [
      HealthRecord(
        id: 'health-$idSuffix',
        date: day,
        createdAt: now,
        updatedAt: now,
        weight: 0,
        systolicBloodPressure: 120,
        diastolicBloodPressure: 80,
        waterIntake: 0,
        steps: 12345,
        sleepHours: null,
        condition: HealthCondition.bad,
      ),
    ],
    medications: [
      Medication(
        id: medicationId,
        name: '혈압약 한글 !@#',
        dose: '긴 용량 메모 !@# 한글',
        morning: true,
        lunch: false,
        evening: true,
        bedtime: false,
        isActive: false,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    medicationLogs: [
      MedicationLog(
        id: 'log-$idSuffix',
        medicationId: medicationId,
        date: day,
        timeSlot: MedicationTimeSlot.morning,
        isTaken: true,
        takenAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    labResults: [
      LabResult(
        id: 'lab-$idSuffix',
        date: day,
        testName: '공복혈당 특수 !@#',
        value: 0,
        unit: 'mg/dL',
        createdAt: now,
        updatedAt: now,
      ),
    ],
    exerciseRecords: [_exerciseRecord(idSuffix)],
  );
}

ExerciseRecord _exerciseRecord(String idSuffix) {
  final now = _dateTime();
  return ExerciseRecord(
    id: 'exercise-$idSuffix',
    date: DateTime(2026, 8, 24),
    exerciseType: ExerciseType.walking,
    durationMinutes: 60,
    intensity: ExerciseIntensity.moderate,
    weightSnapshot: 60.2,
    metSnapshot: 3.8,
    estimatedCalories: 137.28,
    createdAt: now,
    updatedAt: now,
  );
}

BackupSnapshot _symptomSnapshot({
  required String idSuffix,
  bool includeSymptomRecord = true,
  bool includePrnSymptomLink = true,
}) {
  final now = _dateTime();
  final day = DateTime(2026, 8, 24);
  final medicationId = 'prn-med-$idSuffix';
  final symptomId = 'symptom-$idSuffix';
  final prnLogId = 'prn-log-$idSuffix';
  return BackupSnapshot(
    healthRecords: const [],
    medications: [
      Medication(
        id: medicationId,
        name: 'PRN medication $idSuffix',
        type: MedicationType.prn,
        morning: false,
        lunch: false,
        evening: false,
        bedtime: false,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    medicationLogs: const [],
    prnMedicationLogs: [
      PrnMedicationLog(
        id: prnLogId,
        medicationId: medicationId,
        date: day,
        takenAt: DateTime(2026, 8, 24, 9),
        createdAt: now,
        updatedAt: now,
      ),
    ],
    symptomDefinitions: [
      SymptomDefinition(
        id: symptomId,
        name: 'Symptom $idSuffix',
        isDefault: false,
        isActive: true,
        sortOrder: 10,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    symptomRecords: includeSymptomRecord
        ? [
            SymptomRecord(
              id: 'symptom-record-$idSuffix',
              symptomDefinitionId: symptomId,
              date: day,
              severity: SymptomSeverity.severe,
              createdAt: now,
              updatedAt: now,
            ),
          ]
        : const [],
    prnSymptomLinks: includePrnSymptomLink
        ? [
            PrnSymptomLink(
              id: 'prn-symptom-link-$idSuffix',
              prnMedicationLogId: prnLogId,
              symptomDefinitionId: symptomId,
              createdAt: now,
            ),
          ]
        : const [],
    exerciseRecords: [_exerciseRecord(idSuffix)],
    labResults: const [],
  );
}

BackupSnapshot _userSymptomSnapshot() {
  final now = _dateTime();
  final updatedAt = DateTime(2026, 8, 24, 11);
  const symptomId = 'symptom-user-neck-pain';
  const medicationId = 'prn-med-user';
  const prnLogId = 'prn-log-user';
  final day = DateTime(2026, 8, 24);
  return BackupSnapshot(
    healthRecords: const [],
    medications: [
      Medication(
        id: medicationId,
        name: 'PRN medication user',
        type: MedicationType.prn,
        morning: false,
        lunch: false,
        evening: false,
        bedtime: false,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    medicationLogs: const [],
    prnMedicationLogs: [
      PrnMedicationLog(
        id: prnLogId,
        medicationId: medicationId,
        date: day,
        takenAt: DateTime(2026, 8, 24, 9),
        createdAt: now,
        updatedAt: now,
      ),
    ],
    symptomDefinitions: [
      SymptomDefinition(
        id: symptomId,
        name: '목 통증',
        isDefault: false,
        isActive: true,
        sortOrder: 50,
        createdAt: now,
        updatedAt: updatedAt,
      ),
    ],
    symptomRecords: [
      SymptomRecord(
        id: 'symptom-record-user',
        symptomDefinitionId: symptomId,
        date: day,
        severity: SymptomSeverity.severe,
        createdAt: now,
        updatedAt: updatedAt,
      ),
    ],
    prnSymptomLinks: [
      PrnSymptomLink(
        id: 'prn-symptom-link-user',
        prnMedicationLogId: prnLogId,
        symptomDefinitionId: symptomId,
        createdAt: now,
      ),
    ],
    exerciseRecords: const [],
    labResults: const [],
  );
}

String _version4BackupJson({required String omitKey}) {
  final data = <String, Object?>{
    'healthRecords': <Object?>[],
    'medications': <Object?>[],
    'medicationLogs': <Object?>[],
    'prnMedicationLogs': <Object?>[],
    'medicationDoseHistory': <Object?>[],
    'symptomDefinitions': <Object?>[],
    'symptomRecords': <Object?>[],
    'prnSymptomLinks': <Object?>[],
    'labResults': <Object?>[],
  }..remove(omitKey);
  return jsonEncode({
    'app': 'My Health Log',
    'backupVersion': 4,
    'createdAt': '2026-08-24T10:30:45.000',
    'appVersion': '1.0.1+2',
    'data': data,
  });
}

String _version5BackupJson({required String omitKey}) {
  final data = <String, Object?>{
    'healthRecords': <Object?>[],
    'medications': <Object?>[],
    'medicationLogs': <Object?>[],
    'prnMedicationLogs': <Object?>[],
    'medicationDoseHistory': <Object?>[],
    'symptomDefinitions': <Object?>[],
    'symptomRecords': <Object?>[],
    'prnSymptomLinks': <Object?>[],
    'exerciseRecords': <Object?>[],
    'labResults': <Object?>[],
  }..remove(omitKey);
  return jsonEncode({
    'app': 'My Health Log',
    'backupVersion': 5,
    'createdAt': '2026-08-24T10:30:45.000',
    'appVersion': '1.0.1+2',
    'data': data,
  });
}

DateTime _dateTime() => DateTime(2026, 8, 24, 10, 30, 45);

Map<String, Object?> _snapshotJson(BackupSnapshot snapshot) =>
    Map<String, Object?>.of(snapshot.toJson())..remove('labTestSettings');

String _version6BackupJson({
  bool omitLabSettings = false,
  Map<String, Object?>? labSettings,
}) {
  return jsonEncode({
    'app': 'My Health Log',
    'backupVersion': 6,
    'createdAt': '2026-08-24T10:30:45.000',
    'appVersion': '1.0.1+2',
    'data': {
      'healthRecords': <Object?>[],
      'medications': <Object?>[],
      'medicationLogs': <Object?>[],
      'prnMedicationLogs': <Object?>[],
      'medicationDoseHistory': <Object?>[],
      'symptomDefinitions': <Object?>[],
      'symptomRecords': <Object?>[],
      'prnSymptomLinks': <Object?>[],
      'exerciseRecords': <Object?>[],
      'labResults': <Object?>[],
      if (!omitLabSettings)
        'labTestSettings':
            labSettings ??
            {
              'managementType': 'general_health',
              'enabledLabTestIds': ['creatinine'],
              'customDefinitions': <Object?>[],
            },
    },
  });
}
