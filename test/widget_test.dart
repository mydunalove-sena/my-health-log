import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_health_log/app.dart';
import 'package:my_health_log/core/widgets/health_summary_card.dart';
import 'package:my_health_log/models/health_record.dart';
import 'package:my_health_log/models/home_mock_state.dart';
import 'package:my_health_log/models/medication.dart';
import 'package:my_health_log/services/lab_result_service.dart';
import 'package:my_health_log/screens/health/health_form_screen.dart';
import 'package:my_health_log/screens/health/health_screen.dart';
import 'package:my_health_log/screens/home/home_screen.dart';
import 'package:my_health_log/services/health_record_service.dart';
import 'package:my_health_log/services/medication_service.dart';
import 'package:my_health_log/services/symptom_service.dart';

void main() {
  testWidgets('shows root navigation destinations', (tester) async {
    final service = await _service();
    await tester.pumpWidget(
      MyHealthLogApp(
        healthRecordService: service,
        medicationService: await _medService(),
        labResultService: await _labService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('\uD648'), findsWidgets);
    expect(find.text('\uAC74\uAC15'), findsWidgets);
    expect(find.text('\uBCF5\uC57D'), findsWidgets);
    expect(find.text('\uAC80\uC0AC'), findsWidgets);
    expect(find.text('\uD1B5\uACC4'), findsWidgets);
  });

  testWidgets('navigates between root screens', (tester) async {
    final service = await _service();
    await tester.pumpWidget(
      MyHealthLogApp(
        healthRecordService: service,
        medicationService: await _medService(),
        labResultService: await _labService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.science_outlined));
    await tester.pumpAndSettle();

    expect(find.text('\uAC80\uC0AC'), findsWidgets);
  });

  testWidgets('home shows title, health summary, and mock medication summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(mockState: HomeMockState.withData())),
    );

    expect(find.text('My Health Log'), findsOneWidget);
    expect(find.text('\uC624\uB298\uC758 \uAC74\uAC15'), findsOneWidget);
    expect(find.byType(HealthSummaryCard), findsNWidgets(6));
    expect(find.text('\uCCB4\uC911'), findsOneWidget);
    expect(find.textContaining('54.2 kg'), findsOneWidget);
    expect(find.text('\uD608\uC555'), findsOneWidget);
    expect(find.textContaining('120 / 80 mmHg'), findsOneWidget);
    expect(find.text('\uC624\uB298\uC758 \uBCF5\uC57D'), findsOneWidget);
    expect(find.text('\uC544\uCE68\uC57D'), findsOneWidget);
    expect(find.textContaining('\uBCF5\uC6A9 \uC644\uB8CC'), findsOneWidget);
    expect(find.textContaining('\uBBF8\uBCF5\uC6A9'), findsOneWidget);
  });

  testWidgets('home health summary values fit on a narrow Android screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(mockState: HomeMockState.withData())),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('120 / 80 mmHg'), findsOneWidget);
    expect(find.textContaining('6,420 \uAC78\uC74C'), findsOneWidget);
    expect(find.textContaining('54.2 kg'), findsOneWidget);
    expect(find.textContaining('1,200 mL'), findsOneWidget);
    expect(find.textContaining('\uC2DC\uAC04'), findsOneWidget);
  });

  testWidgets('home empty state renders without crashing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(mockState: HomeMockState.empty())),
    );

    expect(find.text('\uC624\uB298\uC758 \uAC74\uAC15'), findsOneWidget);
    expect(
      find.text('\uC544\uC9C1 \uAE30\uB85D\uC774 \uC5C6\uC2B5\uB2C8\uB2E4.'),
      findsOneWidget,
    );
    expect(
      find.text('+ \uAC74\uAC15 \uAE30\uB85D\uD558\uAE30'),
      findsOneWidget,
    );
    expect(find.text('\uC624\uB298\uC758 \uBCF5\uC57D'), findsOneWidget);
    expect(
      find.text('\uB4F1\uB85D\uB41C \uC57D\uC774 \uC5C6\uC2B5\uB2C8\uB2E4.'),
      findsOneWidget,
    );
    expect(find.text('\uC57D \uB4F1\uB85D\uD558\uAE30'), findsOneWidget);
  });

  testWidgets('home medication button opens Medication root tab', (
    tester,
  ) async {
    final healthService = await _service(records: [_record()]);
    final medService = await _medService(medications: [_medication()]);
    await tester.pumpWidget(
      MyHealthLogApp(
        healthRecordService: healthService,
        medicationService: medService,
        labResultService: await _labService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('\uBCF5\uC57D \uD655\uC778'));
    await tester.tap(find.text('\uBCF5\uC57D \uD655\uC778'));
    await tester.pumpAndSettle();

    expect(find.text('\uBCF5\uC57D'), findsWidgets);
    expect(find.text('\uC624\uB298\uC758 \uBCF5\uC57D'), findsOneWidget);
  });

  testWidgets('bottom navigation stays visible on home', (tester) async {
    final service = await _service();
    await tester.pumpWidget(
      MyHealthLogApp(
        healthRecordService: service,
        medicationService: await _medService(),
        labResultService: await _labService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('\uD648'), findsWidgets);
    expect(find.text('\uAC74\uAC15'), findsWidgets);
    expect(find.text('\uBCF5\uC57D'), findsWidgets);
    expect(find.text('\uAC80\uC0AC'), findsWidgets);
    expect(find.text('\uD1B5\uACC4'), findsWidgets);
  });

  testWidgets('health empty state is shown', (tester) async {
    final service = await _service();
    await tester.pumpWidget(
      MaterialApp(
        home: HealthScreen(service: service, symptomService: await _symptoms()),
      ),
    );

    expect(find.byIcon(Icons.monitor_heart_outlined), findsWidgets);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('health add screen opens from list', (tester) async {
    final service = await _service();
    await tester.pumpWidget(
      MaterialApp(
        home: HealthScreen(service: service, symptomService: await _symptoms()),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('health-weight-field')), findsOneWidget);
    expect(find.byKey(const Key('health-save-button')), findsOneWidget);
  });

  testWidgets('empty health record cannot be saved', (tester) async {
    final service = await _service();
    await tester.pumpWidget(
      MaterialApp(home: HealthFormScreen(service: service)),
    );

    await tester.ensureVisible(find.byKey(const Key('health-save-button')));
    await tester.tap(find.byKey(const Key('health-save-button')));
    await tester.pumpAndSettle();

    expect(service.records, isEmpty);
  });

  testWidgets('numeric validation keeps invalid health record unsaved', (
    tester,
  ) async {
    final service = await _service();
    await tester.pumpWidget(
      MaterialApp(home: HealthFormScreen(service: service)),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'abc');
    await tester.ensureVisible(find.byKey(const Key('health-save-button')));
    await tester.tap(find.byKey(const Key('health-save-button')));
    await tester.pumpAndSettle();

    expect(service.records, isEmpty);
  });

  testWidgets('health record is saved and displayed in list', (tester) async {
    final service = await _service();
    await tester.pumpWidget(
      MaterialApp(
        home: HealthScreen(service: service, symptomService: await _symptoms()),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '54.2');
    await tester.enterText(find.byType(TextFormField).at(1), '120');
    await tester.enterText(find.byType(TextFormField).at(2), '80');
    await tester.ensureVisible(find.byKey(const Key('health-save-button')));
    await tester.tap(find.byKey(const Key('health-save-button')));
    await tester.pumpAndSettle();

    expect(service.records.length, 1);
    expect(service.records.first.weight, 54.2);
    expect(find.textContaining('54.2 kg'), findsOneWidget);
    expect(find.textContaining('120 / 80 mmHg'), findsOneWidget);
  });

  testWidgets('existing health record can be edited', (tester) async {
    final service = await _service(records: [_record(weight: 54.2)]);
    await tester.pumpWidget(
      MaterialApp(
        home: HealthScreen(service: service, symptomService: await _symptoms()),
      ),
    );

    await tester.tap(find.text(_todayListDate()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '54.0');
    await tester.ensureVisible(find.byKey(const Key('health-save-button')));
    await tester.tap(find.byKey(const Key('health-save-button')));
    await tester.pumpAndSettle();

    expect(service.records.length, 1);
    expect(service.records.first.weight, 54.0);
  });

  testWidgets('health record can be deleted after confirm', (tester) async {
    final service = await _service(records: [_record()]);
    await tester.pumpWidget(
      MaterialApp(
        home: HealthScreen(service: service, symptomService: await _symptoms()),
      ),
    );

    await tester.tap(find.text(_todayListDate()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();

    expect(service.records, isEmpty);
  });

  test('same date duplicate health record is prevented by service', () async {
    final today = DateTime.now();
    final service = await _service(
      records: [_record(id: 'a', date: today)],
    );

    expect(
      () => service.save(_record(id: 'b', date: today, weight: 55)),
      throwsA(isA<DuplicateHealthRecordException>()),
    );
  });

  testWidgets('null health values are not displayed as zero', (tester) async {
    final service = await _service(
      records: [_record(weight: null, systolic: null, diastolic: null)],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HealthScreen(service: service, symptomService: await _symptoms()),
      ),
    );

    expect(find.textContaining('0 kg'), findsNothing);
    expect(find.textContaining('0 mmHg'), findsNothing);
  });

  testWidgets('home reflects today health record', (tester) async {
    final service = await _service(records: [_record(weight: 54.2)]);
    await tester.pumpWidget(
      MyHealthLogApp(
        healthRecordService: service,
        medicationService: await _medService(),
        labResultService: await _labService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('\uC624\uB298\uC758 \uAC74\uAC15'), findsOneWidget);
    expect(find.textContaining('54.2 kg'), findsOneWidget);
    expect(find.textContaining('120 / 80 mmHg'), findsOneWidget);
  });
}

Future<HealthRecordService> _service({List<HealthRecord>? records}) async {
  final service = HealthRecordService(InMemoryHealthRecordStorage(records));
  await service.load();
  return service;
}

Future<MedicationService> _medService({List<Medication>? medications}) async {
  final service = MedicationService(
    InMemoryMedicationStorage(medications: medications),
  );
  await service.load();
  return service;
}

Future<SymptomService> _symptoms() async {
  final service = SymptomService(InMemorySymptomStorage());
  await service.load();
  return service;
}

HealthRecord _record({
  String id = 'record-1',
  DateTime? date,
  double? weight = 54.2,
  int? systolic = 120,
  int? diastolic = 80,
}) {
  final now = DateTime.now();
  final targetDate = date ?? DateTime(now.year, now.month, now.day);
  return HealthRecord(
    id: id,
    date: targetDate,
    weight: weight,
    systolicBloodPressure: systolic,
    diastolicBloodPressure: diastolic,
    waterIntake: 1200,
    steps: 6420,
    sleepHours: 6.5,
    condition: HealthCondition.normal,
    createdAt: now,
    updatedAt: now,
  );
}

Medication _medication() {
  final now = DateTime.now();
  return Medication(
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
  );
}

String _todayListDate() {
  final now = DateTime.now();
  final year = now.year.toString().padLeft(4, '0');
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '$year.$month.$day';
}

Future<LabResultService> _labService() async {
  final service = LabResultService(InMemoryLabResultStorage());
  await service.load();
  return service;
}
