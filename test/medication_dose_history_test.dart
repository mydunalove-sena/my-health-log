import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_health_log/models/medication.dart';
import 'package:my_health_log/screens/medication/medication_form_screen.dart';
import 'package:my_health_log/services/backup_service.dart';
import 'package:my_health_log/services/medication_service.dart';

void main() {
  group('Medication dose history', () {
    test(
      'new medication does not fabricate an initial history event',
      () async {
        final service = await _service();

        await service.saveMedication(_medication(id: 'new-med'));

        expect(await service.allDoseHistoryForTest(), isEmpty);
      },
    );

    test(
      'dose change stores previous and new dose with changed time',
      () async {
        final original = _medication(
          dose: '0.5mg',
          doseValue: 0.5,
          doseUnit: MedicationDoseUnit.mg,
        );
        final service = await _service(medications: [original]);
        final changedAt = DateTime(2026, 8, 25, 9, 30);

        await service.saveMedication(
          original.copyWith(
            dose: '1mg',
            doseValue: 1,
            doseUnit: MedicationDoseUnit.mg,
            updatedAt: changedAt,
          ),
        );

        final history = await service.allDoseHistoryForTest();
        expect(history, hasLength(1));
        expect(history.single.previousDisplayDose, '0.5mg');
        expect(history.single.newDisplayDose, '1mg');
        expect(history.single.changedAt, changedAt);
      },
    );

    test('non-dose edit does not create dose history', () async {
      final original = _medication();
      final service = await _service(medications: [original]);

      await service.saveMedication(
        original.copyWith(
          name: '이름만 수정',
          evening: true,
          updatedAt: DateTime(2026, 8, 25, 10),
        ),
      );

      expect(await service.allDoseHistoryForTest(), isEmpty);
    });

    test('same structured legacy dose does not create false history', () async {
      final legacy = Medication.fromMap({
        'id': 'legacy',
        'name': '기존약',
        'dose': '10 mg',
        'morning': 1,
        'lunch': 0,
        'evening': 0,
        'bedtime': 0,
        'isActive': 1,
        'createdAt': '2026-08-24T08:00:00.000',
        'updatedAt': '2026-08-24T08:00:00.000',
      });
      final service = await _service(medications: [legacy]);

      await service.saveMedication(
        legacy.copyWith(
          dose: '10mg',
          doseValue: 10,
          doseUnit: MedicationDoseUnit.mg,
          updatedAt: DateTime(2026, 8, 25, 10),
        ),
      );

      expect(await service.allDoseHistoryForTest(), isEmpty);
    });

    test(
      'clearing dose creates history and preserves previous value',
      () async {
        final original = _medication();
        final service = await _service(medications: [original]);

        await service.saveMedication(
          original.copyWith(
            clearDose: true,
            clearDoseValue: true,
            clearDoseUnit: true,
            updatedAt: DateTime(2026, 8, 25, 10),
          ),
        );

        final history = await service.allDoseHistoryForTest();
        expect(history, hasLength(1));
        expect(history.single.previousDisplayDose, '1정');
        expect(history.single.newDisplayDose, isNull);
      },
    );

    testWidgets('edit screen shows stored dose history', (tester) async {
      final medication = _medication();
      final history = MedicationDoseHistory(
        id: 'history-1',
        medicationId: medication.id,
        previousDose: '0.5mg',
        previousDoseValue: 0.5,
        previousDoseUnit: MedicationDoseUnit.mg,
        newDose: '1mg',
        newDoseValue: 1,
        newDoseUnit: MedicationDoseUnit.mg,
        changedAt: DateTime(2026, 8, 25, 9, 30),
        createdAt: DateTime(2026, 8, 25, 9, 30),
      );
      final service = await _service(
        medications: [medication],
        histories: [history],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MedicationFormScreen(service: service, medication: medication),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('복용량 변경 이력'), findsOneWidget);
      expect(find.text('0.5mg → 1mg'), findsOneWidget);
      expect(find.text('2026.08.25 09:30'), findsOneWidget);
    });
  });

  group('Scheduled medication dose snapshot', () {
    test('taken log snapshots current scheduled dose', () async {
      final medication = _medication(
        dose: '0.5mg',
        doseValue: 0.5,
        doseUnit: MedicationDoseUnit.mg,
      );
      final date = DateTime(2026, 8, 25);
      final service = await _service(medications: [medication], date: date);

      await service.toggleTaken(
        medication: medication,
        timeSlot: MedicationTimeSlot.morning,
        date: date,
        now: DateTime(2026, 8, 25, 8),
      );

      final log = service.logFor(
        medication.id,
        date,
        MedicationTimeSlot.morning,
      );
      expect(log?.displayDoseSnapshot, '0.5mg');
      expect(log?.doseValueSnapshot, 0.5);
      expect(log?.doseUnitSnapshot, MedicationDoseUnit.mg);
    });

    test('later medication edit does not mutate past taken snapshot', () async {
      final medication = _medication(
        dose: '0.5mg',
        doseValue: 0.5,
        doseUnit: MedicationDoseUnit.mg,
      );
      final date = DateTime(2026, 8, 25);
      final service = await _service(medications: [medication], date: date);

      await service.toggleTaken(
        medication: medication,
        timeSlot: MedicationTimeSlot.morning,
        date: date,
        now: DateTime(2026, 8, 25, 8),
      );
      await service.saveMedication(
        medication.copyWith(
          dose: '1mg',
          doseValue: 1,
          doseUnit: MedicationDoseUnit.mg,
          updatedAt: DateTime(2026, 8, 25, 9),
        ),
      );

      final log = service.logFor(
        medication.id,
        date,
        MedicationTimeSlot.morning,
      );
      expect(log?.displayDoseSnapshot, '0.5mg');
      expect(service.activeMedications.single.displayDose, '1mg');
    });

    test('untake clears snapshot and retake snapshots current dose', () async {
      final original = _medication(
        dose: '0.5mg',
        doseValue: 0.5,
        doseUnit: MedicationDoseUnit.mg,
      );
      final date = DateTime(2026, 8, 25);
      final service = await _service(medications: [original], date: date);

      await service.toggleTaken(
        medication: original,
        timeSlot: MedicationTimeSlot.morning,
        date: date,
        now: DateTime(2026, 8, 25, 8),
      );
      await service.toggleTaken(
        medication: original,
        timeSlot: MedicationTimeSlot.morning,
        date: date,
        now: DateTime(2026, 8, 25, 8, 5),
      );

      var log = service.logFor(original.id, date, MedicationTimeSlot.morning);
      expect(log?.isTaken, isFalse);
      expect(log?.displayDoseSnapshot, isNull);

      await service.saveMedication(
        original.copyWith(
          dose: '1mg',
          doseValue: 1,
          doseUnit: MedicationDoseUnit.mg,
          updatedAt: DateTime(2026, 8, 25, 9),
        ),
      );
      final current = service.activeMedications.single;

      await service.toggleTaken(
        medication: current,
        timeSlot: MedicationTimeSlot.morning,
        date: date,
        now: DateTime(2026, 8, 25, 9, 5),
      );

      log = service.logFor(original.id, date, MedicationTimeSlot.morning);
      expect(log?.isTaken, isTrue);
      expect(log?.displayDoseSnapshot, '1mg');
    });

    test('legacy scheduled log without snapshot remains unknown', () {
      final log = MedicationLog.fromMap({
        'id': 'legacy-log',
        'medicationId': 'med-1',
        'date': '2026-08-24',
        'timeSlot': 'morning',
        'isTaken': 1,
        'takenAt': '2026-08-24T08:00:00.000',
        'createdAt': '2026-08-24T08:00:00.000',
        'updatedAt': '2026-08-24T08:00:00.000',
      });

      expect(log.isTaken, isTrue);
      expect(log.displayDoseSnapshot, isNull);
    });
  });

  group('Dose-history backup compatibility', () {
    test('backup version 3 preserves history and scheduled snapshot', () async {
      final medication = _medication(
        dose: '1mg',
        doseValue: 1,
        doseUnit: MedicationDoseUnit.mg,
      );
      final now = DateTime(2026, 8, 25, 10);
      final snapshot = BackupSnapshot(
        healthRecords: const [],
        medications: [medication],
        medicationLogs: [
          MedicationLog(
            id: 'log-1',
            medicationId: medication.id,
            date: DateTime(2026, 8, 25),
            timeSlot: MedicationTimeSlot.morning,
            isTaken: true,
            takenAt: DateTime(2026, 8, 25, 8),
            doseSnapshot: '0.5mg',
            doseValueSnapshot: 0.5,
            doseUnitSnapshot: MedicationDoseUnit.mg,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        medicationDoseHistory: [
          MedicationDoseHistory(
            id: 'history-1',
            medicationId: medication.id,
            previousDose: '0.5mg',
            previousDoseValue: 0.5,
            previousDoseUnit: MedicationDoseUnit.mg,
            newDose: '1mg',
            newDoseValue: 1,
            newDoseUnit: MedicationDoseUnit.mg,
            changedAt: now,
            createdAt: now,
          ),
        ],
        labResults: const [],
      );
      final service = BackupService(
        repository: InMemoryBackupRepository(snapshot),
      );

      final backup = await service.createBackup(createdAt: now);
      final restored = service.validateBackup(backup.toPrettyJson());

      expect(restored.toJson()['backupVersion'], 6);
      expect(restored.snapshot.medicationDoseHistory, hasLength(1));
      expect(
        restored.snapshot.medicationDoseHistory.single.previousDisplayDose,
        '0.5mg',
      );
      expect(
        restored.snapshot.medicationLogs.single.displayDoseSnapshot,
        '0.5mg',
      );
    });

    test('backup version 2 remains accepted with empty history/snapshot', () {
      final service = BackupService(repository: InMemoryBackupRepository());
      final legacy = jsonEncode({
        'app': 'My Health Log',
        'backupVersion': 2,
        'createdAt': '2026-08-25T10:00:00.000',
        'appVersion': '1.0.1+2',
        'data': {
          'healthRecords': <Object?>[],
          'medications': [
            {
              'id': 'med-1',
              'name': '기존약',
              'medicationType': 'scheduled',
              'dose': '1정',
              'doseValue': 1,
              'doseUnit': 'tablet',
              'morning': 1,
              'lunch': 0,
              'evening': 0,
              'bedtime': 0,
              'isActive': 1,
              'createdAt': '2026-08-24T08:00:00.000',
              'updatedAt': '2026-08-24T08:00:00.000',
            },
          ],
          'medicationLogs': [
            {
              'id': 'log-1',
              'medicationId': 'med-1',
              'date': '2026-08-24',
              'timeSlot': 'morning',
              'isTaken': 1,
              'takenAt': '2026-08-24T08:00:00.000',
              'createdAt': '2026-08-24T08:00:00.000',
              'updatedAt': '2026-08-24T08:00:00.000',
            },
          ],
          'prnMedicationLogs': <Object?>[],
          'labResults': <Object?>[],
        },
      });

      final restored = service.validateBackup(legacy);

      expect(restored.snapshot.medicationDoseHistory, isEmpty);
      expect(
        restored.snapshot.medicationLogs.single.displayDoseSnapshot,
        isNull,
      );
    });
  });
}

Future<MedicationService> _service({
  List<Medication>? medications,
  List<MedicationLog>? logs,
  List<MedicationDoseHistory>? histories,
  DateTime? date,
}) async {
  final service = MedicationService(
    InMemoryMedicationStorage(
      medications: medications,
      logs: logs,
      doseHistory: histories,
    ),
  );
  await service.load(date: date);
  return service;
}

Medication _medication({
  String id = 'med-1',
  String name = '테스트약',
  String? dose = '1정',
  double? doseValue = 1,
  MedicationDoseUnit? doseUnit = MedicationDoseUnit.tablet,
  DateTime? updatedAt,
}) {
  final createdAt = DateTime(2026, 8, 24, 8);
  return Medication(
    id: id,
    name: name,
    dose: dose,
    doseValue: doseValue,
    doseUnit: doseUnit,
    morning: true,
    lunch: false,
    evening: false,
    bedtime: false,
    isActive: true,
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
  );
}
