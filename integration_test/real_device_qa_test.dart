import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:my_health_log/models/health_record.dart';
import 'package:my_health_log/models/lab_result.dart';
import 'package:my_health_log/models/medication.dart';
import 'package:my_health_log/screens/health/health_screen.dart';
import 'package:my_health_log/screens/home/home_screen.dart';
import 'package:my_health_log/screens/lab/lab_screen.dart';
import 'package:my_health_log/screens/medication/medication_screen.dart';
import 'package:my_health_log/screens/statistics/statistics_screen.dart';
import 'package:my_health_log/services/health_record_service.dart';
import 'package:my_health_log/services/lab_result_service.dart';
import 'package:my_health_log/services/medication_service.dart';
import 'package:my_health_log/services/symptom_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real device QA sample data persists without clearing user data', (
    tester,
  ) async {
    final runId = DateTime.now().microsecondsSinceEpoch.toString();
    final suffix = runId.substring(runId.length - 6);

    final healthService = HealthRecordService(SqfliteHealthRecordStorage());
    final medicationService = MedicationService(SqfliteMedicationStorage());
    final labResultService = LabResultService(SqfliteLabResultStorage());
    final symptomService = SymptomService(SqfliteSymptomStorage());
    await Future.wait([
      healthService.load(),
      medicationService.load(),
      labResultService.load(),
      symptomService.load(),
    ]);

    final firstHealthDate = _firstUnusedHealthDate(healthService);
    final secondHealthDate = firstHealthDate.add(const Duration(days: 1));
    final labDate = firstHealthDate.add(const Duration(days: 2));
    final now = DateTime.now();

    final healthAlpha = _healthRecord(
      id: 'qa-health-alpha-$runId',
      date: firstHealthDate,
      weight: 71.2,
      systolic: 123,
      diastolic: 81,
      water: 1420,
      steps: 4321,
      sleep: 6.4,
      now: now,
    );
    final healthBeta = _healthRecord(
      id: 'qa-health-beta-$runId',
      date: secondHealthDate,
      weight: 68.8,
      systolic: 117,
      diastolic: 76,
      water: 1650,
      steps: 8765,
      sleep: 7.2,
      now: now,
    );
    await healthService.save(healthAlpha);
    await healthService.save(healthBeta);

    final medicationAlpha = _medication(
      id: 'qa-med-alpha-$runId',
      name: 'MHL QA Med Alpha $suffix',
      dose: 'QA dose A $suffix',
      morning: true,
      evening: true,
      now: now,
    );
    final medicationBeta = _medication(
      id: 'qa-med-beta-$runId',
      name: 'MHL QA Med Beta $suffix',
      dose: 'QA dose B $suffix',
      lunch: true,
      bedtime: true,
      now: now,
    );
    await medicationService.saveMedication(medicationAlpha);
    await medicationService.saveMedication(medicationBeta);

    final labAlpha = _labResult(
      id: 'qa-lab-alpha-$runId',
      date: labDate,
      testName: 'MHL QA LDL $suffix',
      value: 101.2,
      unit: 'mg/dL',
      now: now,
    );
    final labBeta = _labResult(
      id: 'qa-lab-beta-$runId',
      date: labDate,
      testName: 'MHL QA A1C $suffix',
      value: 5.4,
      unit: '%',
      now: now,
    );
    await labResultService.save(labAlpha);
    await labResultService.save(labBeta);

    await _smokeHome(tester, healthService, medicationService);
    await _smokeHealth(
      tester,
      healthService,
      symptomService,
      firstHealthDate,
      secondHealthDate,
    );
    await _smokeMedicationAndCreateLog(
      tester,
      medicationService,
      medicationAlpha,
      medicationBeta,
    );
    await _smokeLab(tester, labResultService, labDate, labAlpha, labBeta);
    await _smokeStatistics(tester, healthService, labResultService, labAlpha);

    final editedHealthAlpha = healthAlpha.copyWith(
      weight: 72.4,
      updatedAt: DateTime.now(),
    );
    await healthService.save(editedHealthAlpha);
    await tester.pumpAndSettle();
    expect(healthService.recordForDate(firstHealthDate)?.weight, 72.4);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final reloadedHealthService = HealthRecordService(
      SqfliteHealthRecordStorage(),
    );
    final reloadedMedicationService = MedicationService(
      SqfliteMedicationStorage(),
    );
    final reloadedLabResultService = LabResultService(
      SqfliteLabResultStorage(),
    );
    final reloadedSymptomService = SymptomService(SqfliteSymptomStorage());
    await Future.wait([
      reloadedHealthService.load(),
      reloadedMedicationService.load(),
      reloadedLabResultService.load(),
      reloadedSymptomService.load(),
    ]);

    expect(reloadedHealthService.recordForDate(firstHealthDate)?.weight, 72.4);
    expect(reloadedHealthService.recordForDate(secondHealthDate)?.weight, 68.8);
    expect(
      reloadedMedicationService.activeMedications.map((item) => item.name),
      containsAll([medicationAlpha.name, medicationBeta.name]),
    );
    expect(
      reloadedMedicationService
          .logFor(
            medicationAlpha.id,
            DateTime.now(),
            MedicationTimeSlot.morning,
          )
          ?.isTaken,
      isTrue,
    );
    expect(reloadedLabResultService.resultById(labAlpha.id)?.value, 101.2);
    expect(reloadedLabResultService.resultById(labBeta.id)?.value, 5.4);

    await _smokeHome(tester, reloadedHealthService, reloadedMedicationService);
    await _smokeHealth(
      tester,
      reloadedHealthService,
      reloadedSymptomService,
      firstHealthDate,
      secondHealthDate,
    );
    await _smokeMedicationPersisted(
      tester,
      reloadedMedicationService,
      medicationAlpha,
      medicationBeta,
    );
    await _smokeLab(
      tester,
      reloadedLabResultService,
      labDate,
      labAlpha,
      labBeta,
    );
    await _smokeStatistics(
      tester,
      reloadedHealthService,
      reloadedLabResultService,
      labAlpha,
    );

    // Keep this concise so the device-run log can be used as a QA data ledger.
    // ignore: avoid_print
    print('QA_DATA health=${healthAlpha.dateKey},${healthBeta.dateKey}');
    // ignore: avoid_print
    print('QA_DATA medications=${medicationAlpha.name},${medicationBeta.name}');
    // ignore: avoid_print
    print('QA_DATA medication_log=${medicationAlpha.name}:morning:taken');
    // ignore: avoid_print
    print('QA_DATA labs=${labAlpha.testName},${labBeta.testName}');
  });
}

Future<void> _smokeHome(
  WidgetTester tester,
  HealthRecordService healthService,
  MedicationService medicationService,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomeScreen(
        healthRecordService: healthService,
        medicationService: medicationService,
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('My Health Log'), findsOneWidget);
}

Future<void> _smokeHealth(
  WidgetTester tester,
  HealthRecordService service,
  SymptomService symptomService,
  DateTime firstDate,
  DateTime secondDate,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HealthScreen(service: service, symptomService: symptomService),
    ),
  );
  await tester.pumpAndSettle();
  expect(
    find.byKey(ValueKey('health-record-${_dateKey(firstDate)}')),
    findsOneWidget,
  );
  expect(
    find.byKey(ValueKey('health-record-${_dateKey(secondDate)}')),
    findsOneWidget,
  );
  expect(find.textContaining('71.2 kg'), findsOneWidget);
  expect(find.textContaining('68.8 kg'), findsOneWidget);

  await tester.tap(
    find.byKey(ValueKey('health-record-${_dateKey(firstDate)}')),
  );
  await tester.pumpAndSettle();
  expect(find.widgetWithText(TextFormField, '71.2'), findsOneWidget);
  expect(find.widgetWithText(TextFormField, '123'), findsOneWidget);
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();
}

Future<void> _smokeMedicationAndCreateLog(
  WidgetTester tester,
  MedicationService service,
  Medication medicationAlpha,
  Medication medicationBeta,
) async {
  await tester.pumpWidget(
    MaterialApp(home: MedicationScreen(service: service)),
  );
  await tester.pumpAndSettle();
  expect(find.text(medicationAlpha.name), findsWidgets);
  expect(find.text(medicationBeta.name), findsWidgets);
  expect(find.text(medicationAlpha.dose!), findsWidgets);
  expect(find.text(medicationBeta.dose!), findsWidgets);

  await tester.tap(find.byKey(ValueKey('take-${medicationAlpha.id}-morning')));
  await tester.pumpAndSettle();
  expect(
    find.byKey(ValueKey('take-${medicationAlpha.id}-morning')),
    findsNothing,
  );
}

Future<void> _smokeMedicationPersisted(
  WidgetTester tester,
  MedicationService service,
  Medication medicationAlpha,
  Medication medicationBeta,
) async {
  await tester.pumpWidget(
    MaterialApp(home: MedicationScreen(service: service)),
  );
  await tester.pumpAndSettle();
  expect(find.text(medicationAlpha.name), findsWidgets);
  expect(find.text(medicationBeta.name), findsWidgets);
  expect(
    find.byKey(ValueKey('take-${medicationAlpha.id}-morning')),
    findsNothing,
  );
}

Future<void> _smokeLab(
  WidgetTester tester,
  LabResultService service,
  DateTime labDate,
  LabResult labAlpha,
  LabResult labBeta,
) async {
  await tester.pumpWidget(MaterialApp(home: LabScreen(service: service)));
  await tester.pumpAndSettle();
  expect(
    find.byKey(ValueKey('lab-group-${_dateKey(labDate)}')),
    findsOneWidget,
  );
  expect(find.text(labAlpha.testName), findsOneWidget);
  expect(find.text(labBeta.testName), findsOneWidget);
  expect(find.text('101.2 mg/dL'), findsOneWidget);
  expect(find.text('5.4 %'), findsOneWidget);

  await tester.tap(find.byKey(ValueKey('lab-group-${_dateKey(labDate)}')));
  await tester.pumpAndSettle();
  expect(find.text(labAlpha.testName), findsOneWidget);
  expect(find.text(labBeta.testName), findsOneWidget);
  await tester.tap(find.text(labAlpha.testName));
  await tester.pumpAndSettle();
  expect(find.widgetWithText(TextFormField, labAlpha.testName), findsOneWidget);
  expect(find.widgetWithText(TextFormField, '101.2'), findsOneWidget);
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();
}

Future<void> _smokeStatistics(
  WidgetTester tester,
  HealthRecordService healthService,
  LabResultService labResultService,
  LabResult labAlpha,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: StatisticsScreen(
        healthRecordService: healthService,
        labResultService: labResultService,
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('statistics-chart')), findsOneWidget);
  await tester.tap(find.byType(ChoiceChip).at(1));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('statistics-chart')), findsOneWidget);
  await tester.tap(find.byType(ChoiceChip).at(2));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('statistics-lab-test-dropdown')), findsOneWidget);
  expect(find.text(labAlpha.testName), findsWidgets);
}

DateTime _firstUnusedHealthDate(HealthRecordService service) {
  final start = DateTime(
    2099,
    1,
    1,
  ).add(Duration(days: DateTime.now().millisecondsSinceEpoch % 300));
  for (var offset = 0; offset < 600; offset += 1) {
    final date = start.add(Duration(days: offset));
    final nextDate = date.add(const Duration(days: 1));
    final labDate = date.add(const Duration(days: 2));
    if (date.year > 2100 || labDate.year > 2100) {
      break;
    }
    if (service.recordForDate(date) == null &&
        service.recordForDate(nextDate) == null) {
      return date;
    }
  }
  throw StateError('No unused QA health dates available before 2101.');
}

HealthRecord _healthRecord({
  required String id,
  required DateTime date,
  required double weight,
  required int systolic,
  required int diastolic,
  required int water,
  required int steps,
  required double sleep,
  required DateTime now,
}) {
  return HealthRecord(
    id: id,
    date: date,
    weight: weight,
    systolicBloodPressure: systolic,
    diastolicBloodPressure: diastolic,
    waterIntake: water,
    steps: steps,
    sleepHours: sleep,
    condition: HealthCondition.normal,
    createdAt: now,
    updatedAt: now,
  );
}

Medication _medication({
  required String id,
  required String name,
  required String dose,
  bool morning = false,
  bool lunch = false,
  bool evening = false,
  bool bedtime = false,
  required DateTime now,
}) {
  return Medication(
    id: id,
    name: name,
    dose: dose,
    morning: morning,
    lunch: lunch,
    evening: evening,
    bedtime: bedtime,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

LabResult _labResult({
  required String id,
  required DateTime date,
  required String testName,
  required double value,
  required String unit,
  required DateTime now,
}) {
  return LabResult(
    id: id,
    date: date,
    testName: testName,
    value: value,
    unit: unit,
    createdAt: now,
    updatedAt: now,
  );
}

String _dateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
