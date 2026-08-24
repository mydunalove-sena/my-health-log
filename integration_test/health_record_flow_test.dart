import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:my_health_log/app.dart';
import 'package:my_health_log/models/health_record.dart';
import 'package:my_health_log/models/lab_result.dart';
import 'package:my_health_log/models/medication.dart';
import 'package:my_health_log/services/health_record_service.dart';
import 'package:my_health_log/services/lab_result_service.dart';
import 'package:my_health_log/services/medication_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('STEP 14 Statistics and existing feature regression', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final healthService = HealthRecordService(
      InMemoryHealthRecordStorage([
        _healthRecord(
          id: 'health-1',
          date: today.subtract(const Duration(days: 14)),
          weight: 55,
          systolic: 122,
          diastolic: 82,
        ),
        _healthRecord(
          id: 'health-2',
          date: today.subtract(const Duration(days: 7)),
          weight: 54.4,
          systolic: 118,
          diastolic: 78,
        ),
        _healthRecord(
          id: 'health-3',
          date: today,
          weight: 54.2,
          systolic: 120,
          diastolic: 80,
        ),
      ]),
    );
    await healthService.load();

    final medicationService = MedicationService(
      InMemoryMedicationStorage(
        medications: [
          Medication(
            id: 'med-1',
            name: '\uD0C0\uD06C\uB85C\uBCA8',
            dose: '1\uC815',
            morning: true,
            lunch: false,
            evening: true,
            bedtime: false,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );
    await medicationService.load();

    final labService = LabResultService(
      InMemoryLabResultStorage([
        _labResult(
          id: 'lab-1',
          date: today.subtract(const Duration(days: 60)),
          testName: '\uC911\uC131\uC9C0\uBC29',
          value: 220,
          unit: 'mg/dL',
        ),
        _labResult(
          id: 'lab-2',
          date: today.subtract(const Duration(days: 30)),
          testName: '\uC911\uC131\uC9C0\uBC29',
          value: 205,
          unit: 'mg/dL',
        ),
        _labResult(
          id: 'lab-3',
          date: today,
          testName: '\uC911\uC131\uC9C0\uBC29',
          value: 185,
          unit: 'mg/dL',
        ),
        _labResult(
          id: 'lab-4',
          date: today,
          testName: '\uC694\uC0B0',
          value: 6.2,
          unit: 'mg/dL',
        ),
      ]),
    );
    await labService.load();

    await tester.pumpWidget(
      MyHealthLogApp(
        healthRecordService: healthService,
        medicationService: medicationService,
        labResultService: labService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('54.2 kg'), findsOneWidget);
    expect(find.text('120 / 80 mmHg'), findsOneWidget);
    expect(find.text('\uD0C0\uD06C\uB85C\uBCA8'), findsWidgets);

    await tester.tap(find.text('\uD1B5\uACC4').last);
    await tester.pumpAndSettle();
    expect(find.text('\uCCB4\uC911 \uBCC0\uD654'), findsOneWidget);
    expect(find.byKey(const Key('statistics-chart')), findsOneWidget);
    expect(find.text('54.2 kg'), findsOneWidget);
    expect(find.text('54.4 kg'), findsOneWidget);
    expect(find.text('55 kg'), findsOneWidget);

    await tester.tap(find.text('\uD608\uC555'));
    await tester.pumpAndSettle();
    expect(find.text('\uC218\uCD95\uAE30'), findsOneWidget);
    expect(find.text('\uC774\uC644\uAE30'), findsOneWidget);
    expect(find.text('120 / 80 mmHg'), findsOneWidget);
    expect(find.text('118 / 78 mmHg'), findsOneWidget);

    await tester.tap(find.text('\uAC80\uC0AC').first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('statistics-lab-test-dropdown')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('statistics-lab-test-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('\uC911\uC131\uC9C0\uBC29').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('statistics-chart')), findsOneWidget);
    expect(find.text('185 mg/dL'), findsOneWidget);
    expect(find.text('205 mg/dL'), findsOneWidget);
    expect(find.text('220 mg/dL'), findsOneWidget);

    await tester.tap(find.byKey(const Key('statistics-lab-test-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('\uC694\uC0B0').last);
    await tester.pumpAndSettle();
    expect(find.text('6.2 mg/dL'), findsOneWidget);

    await healthService.save(
      _healthRecord(
        id: 'health-3',
        date: today,
        weight: 53.9,
        systolic: 119,
        diastolic: 79,
      ),
    );
    await tester.tap(find.text('\uCCB4\uC911'));
    await tester.pumpAndSettle();
    expect(find.text('53.9 kg'), findsOneWidget);

    await healthService.delete('health-2');
    await tester.pumpAndSettle();
    expect(find.text('54.4 kg'), findsNothing);

    await tester.tap(find.text('\uAC80\uC0AC').first);
    await tester.pumpAndSettle();
    await labService.save(
      _labResult(
        id: 'lab-3',
        date: today,
        testName: '\uC911\uC131\uC9C0\uBC29',
        value: 180,
        unit: 'mg/dL',
      ),
    );
    await tester.tap(find.byKey(const Key('statistics-lab-test-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('\uC911\uC131\uC9C0\uBC29').last);
    await tester.pumpAndSettle();
    expect(find.text('180 mg/dL'), findsOneWidget);

    await labService.delete('lab-2');
    await tester.pumpAndSettle();
    expect(find.text('205 mg/dL'), findsNothing);

    await tester.tap(find.text('\uAC74\uAC15').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('53.9 kg'), findsOneWidget);

    await tester.tap(find.text('\uBCF5\uC57D').last);
    await tester.pumpAndSettle();
    expect(find.text('\uD0C0\uD06C\uB85C\uBCA8'), findsWidgets);

    await tester.tap(find.text('\uAC80\uC0AC').first);
    await tester.pumpAndSettle();
    expect(find.text('180 mg/dL'), findsOneWidget);
  });
}

HealthRecord _healthRecord({
  required String id,
  required DateTime date,
  required double weight,
  required int systolic,
  required int diastolic,
}) {
  final now = DateTime.now();
  return HealthRecord(
    id: id,
    date: date,
    weight: weight,
    systolicBloodPressure: systolic,
    diastolicBloodPressure: diastolic,
    waterIntake: 1200,
    steps: 6400,
    sleepHours: 6.5,
    condition: HealthCondition.normal,
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
}) {
  final now = DateTime.now();
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
