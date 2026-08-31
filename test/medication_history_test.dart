import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_health_log/models/medication.dart';
import 'package:my_health_log/models/symptom.dart';
import 'package:my_health_log/screens/medication/medication_screen.dart';
import 'package:my_health_log/services/app_database.dart';
import 'package:my_health_log/services/backup_service.dart';
import 'package:my_health_log/services/medication_service.dart';

void main() {
  group('Medication history read model', () {
    test('uses actual logs without creating missed records', () async {
      final date = DateTime(2026, 8, 27);
      final takenMedication = _medication(
        id: 'taken-med',
        name: 'Taken med',
        dose: '2mg',
        doseValue: 2,
        doseUnit: MedicationDoseUnit.mg,
      );
      final notTakenMedication = _medication(
        id: 'not-taken-med',
        name: 'Not taken med',
      );
      final noLogMedication = _medication(id: 'no-log-med', name: 'No log med');
      final inactiveMedication = _medication(
        id: 'inactive-med',
        name: 'Inactive med',
        isActive: false,
      );
      final service = await _service(
        medications: [
          takenMedication,
          notTakenMedication,
          noLogMedication,
          inactiveMedication,
        ],
        logs: [
          _scheduledLog(
            id: 'taken-log',
            medicationId: takenMedication.id,
            date: date,
            isTaken: true,
            doseSnapshot: '1mg',
            doseValueSnapshot: 1,
            doseUnitSnapshot: MedicationDoseUnit.mg,
          ),
          _scheduledLog(
            id: 'not-taken-log',
            medicationId: notTakenMedication.id,
            date: date,
            isTaken: false,
          ),
          _scheduledLog(
            id: 'inactive-log',
            medicationId: inactiveMedication.id,
            date: date,
            isTaken: true,
            doseSnapshot: '0.5\uC815',
            doseValueSnapshot: 0.5,
            doseUnitSnapshot: MedicationDoseUnit.tablet,
          ),
        ],
      );

      final history = await service.historyForDate(date);

      expect(history.scheduledEntries, hasLength(3));
      expect(
        history.scheduledEntries.map((entry) => entry.medicationName),
        containsAll(['Taken med', 'Not taken med', 'Inactive med']),
      );
      expect(
        history.scheduledEntries.map((entry) => entry.medicationName),
        isNot(contains('No log med')),
      );
      final taken = history.scheduledEntries.singleWhere(
        (entry) => entry.log.id == 'taken-log',
      );
      final notTaken = history.scheduledEntries.singleWhere(
        (entry) => entry.log.id == 'not-taken-log',
      );
      final inactive = history.scheduledEntries.singleWhere(
        (entry) => entry.log.id == 'inactive-log',
      );
      expect(taken.isTaken, isTrue);
      expect(taken.doseLabel, '1mg');
      expect(notTaken.isTaken, isFalse);
      expect(notTaken.statusLabel, '\uBBF8\uBCF5\uC6A9 \uAE30\uB85D');
      expect(inactive.medicationName, 'Inactive med');
      expect(inactive.doseLabel, '0.5\uC815');
    });

    test(
      'legacy scheduled snapshot does not fall back to current dose',
      () async {
        final date = DateTime(2026, 8, 27);
        final medication = _medication(
          id: 'legacy-med',
          name: 'Legacy med',
          dose: '2mg',
          doseValue: 2,
          doseUnit: MedicationDoseUnit.mg,
        );
        final service = await _service(
          medications: [medication],
          logs: [
            _scheduledLog(
              id: 'legacy-log',
              medicationId: medication.id,
              date: date,
              isTaken: true,
            ),
          ],
        );

        final history = await service.historyForDate(date);

        expect(
          history.scheduledEntries.single.doseLabel,
          '\uBCF5\uC6A9\uB7C9 \uAE30\uB85D \uC5C6\uC74C',
        );
        expect(history.scheduledEntries.single.doseLabel, isNot('2mg'));
      },
    );

    test('PRN history uses actual PRN log data and links by log id', () async {
      final date = DateTime(2026, 8, 27);
      final medication = _medication(
        id: 'prn-med',
        name: 'PRN med',
        type: MedicationType.prn,
        dose: '2mg',
        doseValue: 2,
        doseUnit: MedicationDoseUnit.mg,
        morning: false,
      );
      final firstLog = _prnLog(
        id: 'prn-1',
        medicationId: medication.id,
        takenAt: DateTime(2026, 8, 27, 9, 10),
        doseValue: 0.5,
        doseUnit: MedicationDoseUnit.tablet,
      );
      final secondLog = _prnLog(
        id: 'prn-2',
        medicationId: medication.id,
        takenAt: DateTime(2026, 8, 27, 14, 20),
      );
      final service = await _service(
        medications: [medication],
        prnLogs: [firstLog, secondLog],
        prnSymptomLinks: [
          _prnSymptomLink(
            id: 'link-1',
            prnMedicationLogId: firstLog.id,
            symptomDefinitionId: 'symptom-headache',
          ),
        ],
      );

      final history = await service.historyForDate(date);

      expect(history.prnEntries, hasLength(2));
      final linked = history.prnEntries.singleWhere(
        (entry) => entry.log.id == 'prn-1',
      );
      final unlinked = history.prnEntries.singleWhere(
        (entry) => entry.log.id == 'prn-2',
      );
      expect(linked.log.takenAt, DateTime(2026, 8, 27, 9, 10));
      expect(linked.doseLabel, '0.5\uC815');
      expect(linked.doseLabel, isNot('2mg'));
      expect(linked.symptomDefinitionIds, ['symptom-headache']);
      expect(unlinked.symptomDefinitionIds, isEmpty);
    });

    test('history lookup does not mutate today medication state', () async {
      final today = DateTime(2026, 8, 28);
      final past = DateTime(2026, 8, 27);
      final medication = _medication(id: 'med-1', name: 'Today med');
      final service = await _service(
        medications: [medication],
        logs: [
          _scheduledLog(
            id: 'today-log',
            medicationId: medication.id,
            date: today,
            isTaken: true,
            doseSnapshot: '1\uC815',
            doseValueSnapshot: 1,
            doseUnitSnapshot: MedicationDoseUnit.tablet,
          ),
          _scheduledLog(
            id: 'past-log',
            medicationId: medication.id,
            date: past,
            isTaken: false,
          ),
        ],
        date: today,
      );

      final before = service.todayDoseItems.single.log?.id;
      await service.historyForDate(past);
      final after = service.todayDoseItems.single.log?.id;

      expect(before, 'today-log');
      expect(after, 'today-log');
      expect(service.todayDoseItems.single.isTaken, isTrue);
    });
  });

  group('Medication history UI', () {
    testWidgets('opens from Medication Today screen', (tester) async {
      final service = await _service();
      await tester.pumpWidget(
        MaterialApp(home: MedicationScreen(service: service)),
      );

      await tester.tap(find.byKey(const Key('medication-history-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('medication-history-screen')),
        findsOneWidget,
      );
    });

    testWidgets('shows scheduled and PRN history with edit actions', (
      tester,
    ) async {
      final date = DateTime.now();
      final medication = _medication(id: 'med-1', name: 'History med');
      final prnMedication = _medication(
        id: 'prn-med',
        name: 'PRN med',
        type: MedicationType.prn,
        morning: false,
      );
      final prnLog = _prnLog(
        id: 'prn-log',
        medicationId: prnMedication.id,
        takenAt: DateTime(date.year, date.month, date.day, 9, 10),
        doseValue: 0.5,
        doseUnit: MedicationDoseUnit.tablet,
      );
      final service = await _service(
        medications: [medication, prnMedication],
        logs: [
          _scheduledLog(
            id: 'taken-log',
            medicationId: medication.id,
            date: date,
            isTaken: true,
            doseSnapshot: '1mg',
            doseValueSnapshot: 1,
            doseUnitSnapshot: MedicationDoseUnit.mg,
          ),
        ],
        prnLogs: [prnLog],
        prnSymptomLinks: [
          _prnSymptomLink(
            id: 'link-1',
            prnMedicationLogId: prnLog.id,
            symptomDefinitionId: 'symptom-headache',
          ),
        ],
        date: date,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MedicationHistoryScreen(
            service: service,
            symptomDefinitions: [
              _symptomDefinition(id: 'symptom-headache', name: 'Headache'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('med-history-scheduled-taken-log')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('med-history-prn-prn-log')),
        findsOneWidget,
      );
      expect(find.text('History med'), findsOneWidget);
      expect(find.text('PRN med'), findsOneWidget);
      expect(find.textContaining('1mg'), findsOneWidget);
      expect(find.textContaining('09:10'), findsOneWidget);
      expect(find.textContaining('0.5\uC815'), findsOneWidget);
      expect(
        find.textContaining('\uAD00\uB828 \uC99D\uC0C1: Headache'),
        findsOneWidget,
      );
      expect(find.text('\uC218\uC815'), findsNWidgets(2));
      expect(find.text('\uC0AD\uC81C'), findsNothing);
    });
  });

  test('V3.1.0 compatibility versions include exercise records', () {
    expect(AppDatabase.databaseVersion, 8);
    expect(BackupDocument.backupVersion, 6);
  });
}

Future<MedicationService> _service({
  List<Medication>? medications,
  List<MedicationLog>? logs,
  List<PrnMedicationLog>? prnLogs,
  List<PrnSymptomLink>? prnSymptomLinks,
  DateTime? date,
}) async {
  final service = MedicationService(
    InMemoryMedicationStorage(
      medications: medications,
      logs: logs,
      prnLogs: prnLogs,
      prnSymptomLinks: prnSymptomLinks,
    ),
  );
  await service.load(date: date);
  return service;
}

Medication _medication({
  required String id,
  required String name,
  MedicationType type = MedicationType.scheduled,
  String? dose = '1\uC815',
  double? doseValue = 1,
  MedicationDoseUnit? doseUnit = MedicationDoseUnit.tablet,
  bool morning = true,
  bool isActive = true,
}) {
  final now = DateTime(2026, 8, 27, 8);
  return Medication(
    id: id,
    name: name,
    type: type,
    dose: dose,
    doseValue: doseValue,
    doseUnit: doseUnit,
    morning: morning,
    lunch: false,
    evening: false,
    bedtime: false,
    isActive: isActive,
    createdAt: now,
    updatedAt: now,
  );
}

MedicationLog _scheduledLog({
  required String id,
  required String medicationId,
  required DateTime date,
  required bool isTaken,
  String? doseSnapshot,
  double? doseValueSnapshot,
  MedicationDoseUnit? doseUnitSnapshot,
}) {
  final now = DateTime(date.year, date.month, date.day, 8);
  return MedicationLog(
    id: id,
    medicationId: medicationId,
    date: DateTime(date.year, date.month, date.day),
    timeSlot: MedicationTimeSlot.morning,
    isTaken: isTaken,
    takenAt: isTaken ? now : null,
    doseSnapshot: doseSnapshot,
    doseValueSnapshot: doseValueSnapshot,
    doseUnitSnapshot: doseUnitSnapshot,
    createdAt: now,
    updatedAt: now,
  );
}

PrnMedicationLog _prnLog({
  required String id,
  required String medicationId,
  required DateTime takenAt,
  double? doseValue,
  MedicationDoseUnit? doseUnit,
}) {
  final date = DateTime(takenAt.year, takenAt.month, takenAt.day);
  return PrnMedicationLog(
    id: id,
    medicationId: medicationId,
    date: date,
    takenAt: takenAt,
    doseValue: doseValue,
    doseUnit: doseUnit,
    createdAt: takenAt,
    updatedAt: takenAt,
  );
}

PrnSymptomLink _prnSymptomLink({
  required String id,
  required String prnMedicationLogId,
  required String symptomDefinitionId,
}) {
  return PrnSymptomLink(
    id: id,
    prnMedicationLogId: prnMedicationLogId,
    symptomDefinitionId: symptomDefinitionId,
    createdAt: DateTime(2026, 8, 27, 9),
  );
}

SymptomDefinition _symptomDefinition({
  required String id,
  required String name,
}) {
  final now = DateTime(2026, 8, 27);
  return SymptomDefinition(
    id: id,
    name: name,
    isDefault: false,
    isActive: true,
    sortOrder: 10,
    createdAt: now,
    updatedAt: now,
  );
}
