import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_health_log/models/medication.dart';
import 'package:my_health_log/screens/home/home_screen.dart';
import 'package:my_health_log/screens/medication/medication_screen.dart';
import 'package:my_health_log/services/medication_service.dart';

void main() {
  testWidgets(
    'Medication screen shows taken snapshot instead of current dose',
    (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final medication = _currentMedication(now);
      final log = _takenSnapshotLog(medication.id, today, now);
      final service = MedicationService(
        InMemoryMedicationStorage(medications: [medication], logs: [log]),
      );
      await service.load(date: today);

      await tester.pumpWidget(
        MaterialApp(home: MedicationScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('0.75정'), findsOneWidget);
      expect(find.text('1mg'), findsNothing);
      expect(find.text('복용 완료'), findsOneWidget);
    },
  );

  testWidgets('Home preview shows taken snapshot instead of current dose', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final medication = _currentMedication(now);
    final log = _takenSnapshotLog(medication.id, today, now);
    final service = MedicationService(
      InMemoryMedicationStorage(medications: [medication], logs: [log]),
    );
    await service.load(date: today);

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(medicationService: service)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        '\uC544\uCE68 \u00B7 0.75\uC815 \u00B7 \uBCF5\uC6A9 \uC644\uB8CC',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('1mg'), findsNothing);
    expect(find.textContaining('복용 완료'), findsOneWidget);
  });

  testWidgets('Not-taken medication still shows the current dose', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final medication = _currentMedication(now);
    final service = MedicationService(
      InMemoryMedicationStorage(medications: [medication]),
    );
    await service.load(date: today);

    await tester.pumpWidget(
      MaterialApp(home: MedicationScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('1mg'), findsOneWidget);
    expect(find.text('0.75정'), findsNothing);
  });
}

Medication _currentMedication(DateTime now) {
  return Medication(
    id: 'med-snapshot',
    name: '스냅샷약',
    dose: '1mg',
    doseValue: 1,
    doseUnit: MedicationDoseUnit.mg,
    morning: true,
    lunch: false,
    evening: false,
    bedtime: false,
    isActive: true,
    createdAt: now.subtract(const Duration(days: 1)),
    updatedAt: now,
  );
}

MedicationLog _takenSnapshotLog(
  String medicationId,
  DateTime date,
  DateTime now,
) {
  return MedicationLog(
    id: 'log-snapshot',
    medicationId: medicationId,
    date: date,
    timeSlot: MedicationTimeSlot.morning,
    isTaken: true,
    takenAt: now.subtract(const Duration(hours: 1)),
    doseSnapshot: '0.75정',
    doseValueSnapshot: 0.75,
    doseUnitSnapshot: MedicationDoseUnit.tablet,
    createdAt: now.subtract(const Duration(hours: 1)),
    updatedAt: now.subtract(const Duration(hours: 1)),
  );
}
