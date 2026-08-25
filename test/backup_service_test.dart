import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_health_log/models/health_record.dart';
import 'package:my_health_log/models/lab_result.dart';
import 'package:my_health_log/models/medication.dart';
import 'package:my_health_log/services/backup_service.dart';

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
      expect(decoded.toJson()['backupVersion'], 3);
      expect(decoded.snapshot.healthRecords, isEmpty);
      expect(decoded.snapshot.medications, isEmpty);
      expect(decoded.snapshot.medicationLogs, isEmpty);
      expect(decoded.snapshot.prnMedicationLogs, isEmpty);
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
  });
}

extension on BackupSnapshot {
  int get totalForTest {
    return healthRecords.length +
        medications.length +
        medicationLogs.length +
        prnMedicationLogs.length +
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
  );
}

DateTime _dateTime() => DateTime(2026, 8, 24, 10, 30, 45);

Map<String, Object?> _snapshotJson(BackupSnapshot snapshot) =>
    snapshot.toJson();
