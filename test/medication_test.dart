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

    expect(
      find.text(
        '\uB4F1\uB85D\uB41C \uC57D\uC774 \uC5C6\uC2B5\uB2C8\uB2E4.\n\n\uBCF5\uC6A9 \uC911\uC778 \uC57D\uC744\n\uBA3C\uC800 \uB4F1\uB85D\uD574\uC8FC\uC138\uC694.',
      ),
      findsOneWidget,
    );
    expect(find.text('+ \uC57D \uB4F1\uB85D'), findsOneWidget);
  });

  testWidgets('Medication Add screen opens from list', (tester) async {
    final service = await _service();
    await tester.pumpWidget(
      MaterialApp(home: MedicationListScreen(service: service)),
    );

    await tester.tap(find.byTooltip('\uC57D \uB4F1\uB85D'));
    await tester.pumpAndSettle();

    expect(find.text('\uC57D \uB4F1\uB85D'), findsWidgets);
    expect(find.text('\uC57D \uC774\uB984'), findsOneWidget);
    expect(find.text('\uBCF5\uC6A9 \uC2DC\uAC04'), findsOneWidget);
  });

  testWidgets('Medication validation requires name and one time slot', (
    tester,
  ) async {
    final service = await _service();
    await tester.pumpWidget(
      MaterialApp(home: MedicationFormScreen(service: service)),
    );

    await tester.tap(find.text('\uC800\uC7A5'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '\uC57D \uC774\uB984\uC744 \uC785\uB825\uD574\uC8FC\uC138\uC694.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '\uBCF5\uC6A9 \uC2DC\uAC04\uC744 \uD558\uB098 \uC774\uC0C1 \uC120\uD0DD\uD574\uC8FC\uC138\uC694.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Medication can be saved and displayed in list', (tester) async {
    final service = await _service();
    await tester.pumpWidget(
      MaterialApp(home: MedicationListScreen(service: service)),
    );

    await tester.tap(find.byTooltip('\uC57D \uB4F1\uB85D'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      '\uD0C0\uD06C\uB85C\uBCA8',
    );
    await tester.enterText(find.byType(TextFormField).at(1), '1\uC815');
    await tester.tap(find.text('\uC544\uCE68'));
    await tester.tap(find.text('\uC800\uB141'));
    await tester.tap(find.text('\uC800\uC7A5'));
    await tester.pumpAndSettle();

    expect(service.activeMedications.length, 1);
    expect(find.text('\uD0C0\uD06C\uB85C\uBCA8'), findsWidgets);
    expect(find.text('1\uC815'), findsOneWidget);
    expect(find.textContaining('\uC544\uCE68'), findsOneWidget);
    expect(find.textContaining('\uC800\uB141'), findsOneWidget);
  });

  testWidgets('Medication edit shows existing values and updates same record', (
    tester,
  ) async {
    final medication = _medication();
    final service = await _service(medications: [medication]);
    await tester.pumpWidget(
      MaterialApp(home: MedicationListScreen(service: service)),
    );

    await tester.tap(find.text('\uD0C0\uD06C\uB85C\uBCA8'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextFormField, '\uD0C0\uD06C\uB85C\uBCA8'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, '1\uC815'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), '2\uC815');
    await tester.tap(find.text('\uBCC0\uACBD\uC0AC\uD56D \uC800\uC7A5'));
    await tester.pumpAndSettle();

    expect(service.activeMedications.length, 1);
    expect(service.activeMedications.first.id, medication.id);
    expect(service.activeMedications.first.dose, '2\uC815');
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

    await tester.tap(find.text('\uD0C0\uD06C\uB85C\uBCA8'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('\uC0AD\uC81C'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('\uC0AD\uC81C').last);
    await tester.pumpAndSettle();

    expect(service.activeMedications, isEmpty);
    expect(await service.allLogsForTest(), hasLength(1));
    expect(
      find.text(
        '\uB4F1\uB85D\uB41C \uC57D\uC774 \uC5C6\uC2B5\uB2C8\uB2E4.\n\n\uBCF5\uC6A9 \uC911\uC778 \uC57D\uC744\n\uB4F1\uB85D\uD574\uC8FC\uC138\uC694.',
      ),
      findsOneWidget,
    );
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

    expect(find.text('\uD0C0\uD06C\uB85C\uBCA8'), findsWidgets);
    expect(find.textContaining('\uBCF5\uC6A9 \uC644\uB8CC'), findsOneWidget);
  });

  testWidgets('Medication Today toggles false to true and back', (
    tester,
  ) async {
    final medication = _medication();
    final service = await _service(medications: [medication]);
    await tester.pumpWidget(
      MaterialApp(home: MedicationScreen(service: service)),
    );

    await tester.tap(find.text('\uBCF5\uC6A9').first);
    await tester.pumpAndSettle();
    expect(find.text('\uBCF5\uC6A9 \uC644\uB8CC'), findsOneWidget);

    await tester.tap(find.text('\uBCF5\uC6A9 \uC644\uB8CC'));
    await tester.pumpAndSettle();
    expect(find.text('\uBCF5\uC6A9'), findsWidgets);
  });
}

Future<MedicationService> _service({
  List<Medication>? medications,
  List<MedicationLog>? logs,
  DateTime? date,
}) async {
  final service = MedicationService(
    InMemoryMedicationStorage(medications: medications, logs: logs),
  );
  await service.load(date: date);
  return service;
}

Medication _medication({
  String id = 'med-1',
  String name = '\uD0C0\uD06C\uB85C\uBCA8',
  String? dose = '1\uC815',
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
    dose: dose,
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
