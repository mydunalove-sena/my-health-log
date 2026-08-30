import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_health_log/models/medication.dart';
import 'package:my_health_log/screens/medication/medication_form_screen.dart';
import 'package:my_health_log/screens/medication/medication_screen.dart';
import 'package:my_health_log/services/medication_service.dart';

void main() {
  group('Medication V3 structured dose', () {
    test('legacy tablet dose is parsed without losing original text', () {
      final medication = Medication.fromMap(_legacyMedicationMap(dose: '0.5정'));
      expect(medication.type, MedicationType.scheduled);
      expect(medication.dose, '0.5정');
      expect(medication.doseValue, 0.5);
      expect(medication.doseUnit, MedicationDoseUnit.tablet);
      expect(medication.displayDose, '0.5정');
    });

    test('legacy mg and ml dose values are parsed', () {
      final mg = Medication.fromMap(_legacyMedicationMap(dose: '10 mg'));
      final ml = Medication.fromMap(_legacyMedicationMap(dose: '2.5ml'));
      expect(mg.doseValue, 10);
      expect(mg.doseUnit, MedicationDoseUnit.mg);
      expect(mg.displayDose, '10mg');
      expect(mg.toMap()['dose'], '10 mg');
      expect(ml.doseValue, 2.5);
      expect(ml.doseUnit, MedicationDoseUnit.ml);
      expect(ml.displayDose, '2.5ml');
    });

    test('unstructured legacy dose remains unchanged', () {
      final medication = Medication.fromMap(
        _legacyMedicationMap(dose: '아침 반알'),
      );
      expect(medication.dose, '아침 반알');
      expect(medication.doseValue, isNull);
      expect(medication.doseUnit, isNull);
      expect(medication.displayDose, '아침 반알');
    });

    test('service accepts decimal tablet, mg, and ml doses', () async {
      final service = await _service();
      await service.saveMedication(
        _medication(
          id: 'tablet',
          doseValue: 0.25,
          doseUnit: MedicationDoseUnit.tablet,
        ),
      );
      await service.saveMedication(
        _medication(id: 'mg', doseValue: 5, doseUnit: MedicationDoseUnit.mg),
      );
      await service.saveMedication(
        _medication(id: 'ml', doseValue: 2.5, doseUnit: MedicationDoseUnit.ml),
      );

      expect(
        service.activeMedications.map((item) => item.displayDose),
        containsAll(['0.25정', '5mg', '2.5ml']),
      );
    });

    testWidgets('dose unit dropdown exposes tablet, mg, and ml', (
      tester,
    ) async {
      final service = await _service();
      await tester.pumpWidget(
        MaterialApp(home: MedicationFormScreen(service: service)),
      );

      await tester.tap(find.byKey(const Key('medication-dose-unit-field')));
      await tester.pumpAndSettle();

      expect(find.text('정'), findsWidgets);
      expect(find.text('mg'), findsWidgets);
      expect(find.text('ml'), findsWidgets);
    });
  });

  group('Medication V3 scheduled and PRN', () {
    test('scheduled medication still requires a time slot', () async {
      final service = await _service();
      await expectLater(
        service.saveMedication(
          _medication(id: 'scheduled-no-slot', morning: false, evening: false),
        ),
        throwsA(isA<EmptyMedicationTimeSlotException>()),
      );
    });

    test('PRN medication saves without a time slot', () async {
      final service = await _service();
      await service.saveMedication(
        _medication(
          id: 'prn',
          type: MedicationType.prn,
          morning: false,
          evening: false,
        ),
      );

      expect(service.activePrnMedications, hasLength(1));
      expect(service.activePrnMedications.single.hasAnyTimeSlot, isFalse);
      expect(service.todayDoseItems, isEmpty);
    });

    testWidgets('PRN form hides scheduled time slots', (tester) async {
      final service = await _service();
      await tester.pumpWidget(
        MaterialApp(home: MedicationFormScreen(service: service)),
      );

      await tester.tap(find.byKey(const Key('medication-type-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('필요 시(PRN)').last);
      await tester.pumpAndSettle();

      expect(find.text('복용 시점'), findsNothing);
      expect(find.text('필요 시 약은 실제로 복용한 경우에만 복용 기록을 남깁니다.'), findsOneWidget);
    });

    test('PRN logs are created only when actual dose is recorded', () async {
      final now = DateTime(2026, 8, 25, 8, 30);
      final medication = _medication(
        id: 'prn',
        type: MedicationType.prn,
        morning: false,
        evening: false,
      );
      final service = await _service(
        medications: [medication],
        date: DateTime(2026, 8, 25),
      );

      expect(await service.allPrnLogsForTest(), isEmpty);

      await service.recordPrnTaken(
        medication: medication,
        takenAt: DateTime(2026, 8, 25, 8, 10),
        doseValue: 0.5,
        doseUnit: MedicationDoseUnit.tablet,
        note: '두통',
        now: now,
      );

      final logs = await service.allPrnLogsForTest();
      expect(logs, hasLength(1));
      expect(logs.single.displayDose, '0.5정');
      expect(logs.single.note, '두통');
    });

    test('PRN allows multiple actual doses on the same day', () async {
      final now = DateTime(2026, 8, 25, 18);
      final medication = _medication(
        id: 'prn',
        type: MedicationType.prn,
        morning: false,
        evening: false,
      );
      final service = await _service(
        medications: [medication],
        date: DateTime(2026, 8, 25),
      );

      await service.recordPrnTaken(
        medication: medication,
        takenAt: DateTime(2026, 8, 25, 9),
        doseValue: 1,
        doseUnit: MedicationDoseUnit.tablet,
        now: now,
      );
      await service.recordPrnTaken(
        medication: medication,
        takenAt: DateTime(2026, 8, 25, 15),
        doseValue: 1,
        doseUnit: MedicationDoseUnit.tablet,
        now: now.add(const Duration(microseconds: 1)),
      );

      expect(await service.allPrnLogsForTest(), hasLength(2));
      expect(service.prnLogsForMedication(medication.id), hasLength(2));
    });

    test('future PRN date and future time are rejected', () async {
      final now = DateTime(2026, 8, 25, 10);
      final medication = _medication(
        id: 'prn',
        type: MedicationType.prn,
        morning: false,
        evening: false,
      );
      final service = await _service(
        medications: [medication],
        date: DateTime(2026, 8, 25),
      );

      await expectLater(
        service.recordPrnTaken(
          medication: medication,
          takenAt: DateTime(2026, 8, 26, 9),
          now: now,
        ),
        throwsA(isA<FuturePrnMedicationDateException>()),
      );
      await expectLater(
        service.recordPrnTaken(
          medication: medication,
          takenAt: DateTime(2026, 8, 25, 11),
          now: now,
        ),
        throwsA(isA<FuturePrnMedicationTimeException>()),
      );
    });

    testWidgets('PRN medication is shown without a missed status', (
      tester,
    ) async {
      final medication = _medication(
        id: 'prn',
        name: '편두통약',
        type: MedicationType.prn,
        morning: false,
        evening: false,
      );
      final service = await _service(medications: [medication]);

      await tester.pumpWidget(
        MaterialApp(home: MedicationScreen(service: service)),
      );

      expect(find.text('필요 시 복용약'), findsOneWidget);
      expect(find.text('편두통약'), findsOneWidget);
      expect(find.text('복용'), findsOneWidget);
      expect(find.textContaining('미복용'), findsNothing);
    });
  });
}

Map<String, Object?> _legacyMedicationMap({required String dose}) => {
  'id': 'legacy-med',
  'name': '기존약',
  'dose': dose,
  'morning': 1,
  'lunch': 0,
  'evening': 0,
  'bedtime': 0,
  'isActive': 1,
  'createdAt': '2026-08-24T09:00:00.000',
  'updatedAt': '2026-08-24T09:00:00.000',
};

Future<MedicationService> _service({
  List<Medication>? medications,
  DateTime? date,
}) async {
  final service = MedicationService(
    InMemoryMedicationStorage(medications: medications),
  );
  await service.load(date: date);
  return service;
}

Medication _medication({
  String id = 'med',
  String name = '테스트약',
  MedicationType type = MedicationType.scheduled,
  double? doseValue = 1,
  MedicationDoseUnit? doseUnit = MedicationDoseUnit.tablet,
  bool morning = true,
  bool evening = true,
}) {
  final now = DateTime(2026, 8, 25, 8);
  return Medication(
    id: id,
    name: name,
    type: type,
    dose: doseValue == null || doseUnit == null
        ? null
        : '${Medication.formatDoseValue(doseValue)}${doseUnit.label}',
    doseValue: doseValue,
    doseUnit: doseUnit,
    morning: morning,
    lunch: false,
    evening: evening,
    bedtime: false,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}
