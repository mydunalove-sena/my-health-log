import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_health_log/models/medication.dart';
import 'package:my_health_log/screens/home/home_screen.dart';
import 'package:my_health_log/screens/medication/medication_form_screen.dart';
import 'package:my_health_log/screens/medication/medication_screen.dart';
import 'package:my_health_log/services/medication_service.dart';

void main() {
  testWidgets('Medication Today empty state is shown', (tester) async {
    final service = await _service();
    await tester.pumpWidget(
      MaterialApp(home: MedicationScreen(service: service)),
    );

    expect(find.text('등록된 약이 없습니다.\n\n복용 중인 약을\n먼저 등록해주세요.'), findsOneWidget);
    expect(find.text('+ 약 등록'), findsOneWidget);
  });

  testWidgets('Medication Add screen opens from list', (tester) async {
    final service = await _service();
    await tester.pumpWidget(
      MaterialApp(home: MedicationListScreen(service: service)),
    );

    await tester.tap(find.byTooltip('약 등록'));
    await tester.pumpAndSettle();

    expect(find.text('약 등록'), findsWidgets);
    expect(find.text('약 이름'), findsOneWidget);
    expect(find.text('복용 유형'), findsOneWidget);
    expect(find.text('복용 시점'), findsOneWidget);
  });

  testWidgets('Medication validation requires name and one time slot', (
    tester,
  ) async {
    final service = await _service();
    await tester.pumpWidget(
      MaterialApp(home: MedicationFormScreen(service: service)),
    );

    await _tapSave(tester);

    expect(find.text('약 이름을 입력해주세요.'), findsOneWidget);
    expect(find.text('복용 시점을 하나 이상 선택해주세요.'), findsOneWidget);
  });

  testWidgets('Medication can be saved and displayed in list', (tester) async {
    final service = await _service();
    await tester.pumpWidget(
      MaterialApp(home: MedicationListScreen(service: service)),
    );

    await tester.tap(find.byTooltip('약 등록'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('medication-name-field')),
      '타크로벨',
    );
    await tester.enterText(find.byKey(const Key('medication-dose-field')), '1');
    await tester.tap(find.text('아침'));
    await tester.tap(find.text('저녁'));
    await _tapSave(tester);

    expect(service.activeMedications.length, 1);
    expect(find.text('타크로벨'), findsWidgets);
    expect(find.text('1정'), findsOneWidget);
    expect(find.textContaining('아침'), findsOneWidget);
    expect(find.textContaining('저녁'), findsOneWidget);
  });

  testWidgets('Medication edit shows existing values and updates same record', (
    tester,
  ) async {
    final medication = _medication();
    final service = await _service(medications: [medication]);
    await tester.pumpWidget(
      MaterialApp(home: MedicationListScreen(service: service)),
    );

    await tester.tap(find.text('타크로벨'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, '타크로벨'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '1'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('medication-dose-field')), '2');
    await _tapSave(tester);

    expect(service.activeMedications.length, 1);
    expect(service.activeMedications.first.id, medication.id);
    expect(service.activeMedications.first.dose, '2정');
    expect(service.activeMedications.first.doseValue, 2);
    expect(service.activeMedications.first.doseUnit, MedicationDoseUnit.tablet);
  });

  testWidgets('Medication soft delete hides active medication and keeps logs', (
    tester,
  ) async {
    final medication = _medication();
    final today = DateTime(2026, 8, 21);
    final log = _log(medicationId: medication.id, date: today);
    final service = await _service(
      medications: [medication],
      logs: [log],
      date: today,
    );
    await tester.pumpWidget(
      MaterialApp(home: MedicationListScreen(service: service)),
    );

    await tester.tap(find.text('타크로벨'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제').last);
    await tester.pumpAndSettle();

    expect(service.activeMedications, isEmpty);
    expect(await service.allLogsForTest(), hasLength(1));
  });

  test('MedicationLog toggle stores and clears takenAt', () async {
    final medication = _medication();
    final date = DateTime(2026, 8, 21);
    final takenAt = DateTime(2026, 8, 21, 8, 30);
    final service = await _service(medications: [medication], date: date);

    await service.toggleTaken(
      medication: medication,
      timeSlot: MedicationTimeSlot.morning,
      date: date,
      now: takenAt,
    );
    var log = service.logFor(medication.id, date, MedicationTimeSlot.morning);
    expect(log?.isTaken, isTrue);
    expect(log?.takenAt, takenAt);

    await service.toggleTaken(
      medication: medication,
      timeSlot: MedicationTimeSlot.morning,
      date: date,
      now: takenAt.add(const Duration(minutes: 5)),
    );
    log = service.logFor(medication.id, date, MedicationTimeSlot.morning);
    expect(log?.isTaken, isFalse);
    expect(log?.takenAt, isNull);
    expect(await service.allLogsForTest(), hasLength(1));
  });

  test('MedicationLog state is separated by date', () async {
    final medication = _medication();
    final firstDate = DateTime(2026, 8, 21);
    final secondDate = DateTime(2026, 8, 22);
    final service = await _service(medications: [medication], date: firstDate);

    await service.toggleTaken(
      medication: medication,
      timeSlot: MedicationTimeSlot.morning,
      date: firstDate,
      now: DateTime(2026, 8, 21, 8),
    );
    await service.load(date: secondDate);

    expect(
      service.logFor(medication.id, firstDate, MedicationTimeSlot.morning),
      isNull,
    );
    expect(service.todayDoseItems.first.isTaken, isFalse);
    expect(await service.allLogsForTest(), hasLength(1));
  });

  testWidgets('Home reflects actual Medication state', (tester) async {
    final medication = _medication();
    final service = await _service(medications: [medication]);
    await service.toggleTaken(
      medication: medication,
      timeSlot: MedicationTimeSlot.morning,
      date: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(medicationService: service)),
    );

    expect(find.text('타크로벨'), findsWidgets);
    expect(find.textContaining('복용 완료'), findsOneWidget);
  });

  testWidgets('Medication Today toggles false to true and back', (
    tester,
  ) async {
    final medication = _medication();
    final service = await _service(medications: [medication]);
    await tester.pumpWidget(
      MaterialApp(home: MedicationScreen(service: service)),
    );

    await tester.tap(find.text('복용').first);
    await tester.pumpAndSettle();
    expect(find.text('복용 완료'), findsOneWidget);

    await tester.tap(find.text('복용 완료'));
    await tester.pumpAndSettle();
    expect(find.text('복용'), findsWidgets);
  });
}

Future<void> _tapSave(WidgetTester tester) async {
  final button = find.byKey(const Key('medication-save-button'));
  expect(button, findsOneWidget);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<MedicationService> _service({
  List<Medication>? medications,
  List<MedicationLog>? logs,
  List<PrnMedicationLog>? prnLogs,
  DateTime? date,
}) async {
  final service = MedicationService(
    InMemoryMedicationStorage(
      medications: medications,
      logs: logs,
      prnLogs: prnLogs,
    ),
  );
  await service.load(date: date);
  return service;
}

Medication _medication({
  String id = 'med-1',
  String name = '타크로벨',
  String? dose = '1정',
  double? doseValue = 1,
  MedicationDoseUnit? doseUnit = MedicationDoseUnit.tablet,
  MedicationType type = MedicationType.scheduled,
  bool morning = true,
  bool lunch = false,
  bool evening = true,
  bool bedtime = false,
  bool isActive = true,
}) {
  final now = DateTime(2026, 8, 21, 9);
  return Medication(
    id: id,
    name: name,
    type: type,
    dose: dose,
    doseValue: doseValue,
    doseUnit: doseUnit,
    morning: morning,
    lunch: lunch,
    evening: evening,
    bedtime: bedtime,
    isActive: isActive,
    createdAt: now,
    updatedAt: now,
  );
}

MedicationLog _log({required String medicationId, required DateTime date}) {
  final now = DateTime(2026, 8, 21, 8);
  return MedicationLog(
    id: 'log-1',
    medicationId: medicationId,
    date: date,
    timeSlot: MedicationTimeSlot.morning,
    isTaken: true,
    takenAt: now,
    createdAt: now,
    updatedAt: now,
  );
}
