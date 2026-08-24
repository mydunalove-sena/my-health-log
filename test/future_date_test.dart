import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_health_log/models/health_record.dart';
import 'package:my_health_log/models/lab_result.dart';
import 'package:my_health_log/screens/health/health_form_screen.dart';
import 'package:my_health_log/screens/lab/lab_result_form_screen.dart';
import 'package:my_health_log/screens/statistics/statistics_screen.dart';
import 'package:my_health_log/services/health_record_service.dart';
import 'package:my_health_log/services/lab_result_service.dart';

void main() {
  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  group('HealthRecord future-date policy', () {
    test('today and past dates can be saved', () async {
      final current = today();
      final service = await _healthService();

      await service.save(_healthRecord(id: 'today', date: current));
      await service.save(
        _healthRecord(
          id: 'past',
          date: current.subtract(const Duration(days: 1)),
        ),
      );

      expect(
        service.records.map((record) => record.id),
        containsAll(['today', 'past']),
      );
    });

    test('tomorrow and far-future dates are rejected', () async {
      final current = today();
      final service = await _healthService();

      await expectLater(
        service.save(
          _healthRecord(
            id: 'tomorrow',
            date: current.add(const Duration(days: 1)),
          ),
        ),
        throwsA(isA<FutureHealthRecordDateException>()),
      );
      await expectLater(
        service.save(
          _healthRecord(id: 'far-future', date: DateTime(2100, 1, 1)),
        ),
        throwsA(isA<FutureHealthRecordDateException>()),
      );
    });

    test('editing an existing record to a future date is rejected', () async {
      final current = today();
      final service = await _healthService(
        records: [_healthRecord(id: 'existing', date: current)],
      );

      await expectLater(
        service.save(
          _healthRecord(
            id: 'existing',
            date: current.add(const Duration(days: 1)),
          ),
        ),
        throwsA(isA<FutureHealthRecordDateException>()),
      );
      expect(
        service.records.single.dateKey,
        HealthRecord.formatDateKey(current),
      );
    });

    test('pre-existing future records are preserved but hidden', () async {
      final current = today();
      final future = current.add(const Duration(days: 1));
      final service = await _healthService(
        records: [
          _healthRecord(id: 'valid', date: current),
          _healthRecord(id: 'legacy-future', date: future),
        ],
      );

      expect(service.records.map((record) => record.id), ['valid']);
      expect(service.recordForDate(future)?.id, 'legacy-future');
      expect(service.todayRecord?.id, 'valid');
    });
  });

  group('LabResult future-date policy', () {
    test('today and past dates can be saved', () async {
      final current = today();
      final service = await _labService();

      await service.save(_labResult(id: 'today', date: current));
      await service.save(
        _labResult(
          id: 'past',
          date: current.subtract(const Duration(days: 1)),
          testName: '요산',
        ),
      );

      expect(
        service.results.map((result) => result.id),
        containsAll(['today', 'past']),
      );
    });

    test('tomorrow and far-future dates are rejected', () async {
      final current = today();
      final service = await _labService();

      await expectLater(
        service.save(
          _labResult(
            id: 'tomorrow',
            date: current.add(const Duration(days: 1)),
          ),
        ),
        throwsA(isA<FutureLabResultDateException>()),
      );
      await expectLater(
        service.save(_labResult(id: 'far-future', date: DateTime(2100, 1, 1))),
        throwsA(isA<FutureLabResultDateException>()),
      );
    });

    test('editing an existing result to a future date is rejected', () async {
      final current = today();
      final service = await _labService(
        results: [_labResult(id: 'existing', date: current)],
      );

      await expectLater(
        service.save(
          _labResult(
            id: 'existing',
            date: current.add(const Duration(days: 1)),
          ),
        ),
        throwsA(isA<FutureLabResultDateException>()),
      );
      expect(service.results.single.dateKey, LabResult.formatDateKey(current));
    });

    test('pre-existing future results are preserved but hidden', () async {
      final current = today();
      final future = current.add(const Duration(days: 1));
      final service = await _labService(
        results: [
          _labResult(id: 'valid', date: current),
          _labResult(id: 'legacy-future', date: future, testName: '요산'),
        ],
      );

      expect(service.results.map((result) => result.id), ['valid']);
      expect(service.groups.length, 1);
      expect(service.groups.single.results.single.id, 'valid');
      expect(service.resultsForDate(future), isEmpty);
      expect(service.resultById('legacy-future')?.id, 'legacy-future');
    });
  });

  testWidgets('Health DatePicker maximum date is today', (tester) async {
    final service = await _healthService();
    await tester.pumpWidget(
      MaterialApp(home: HealthFormScreen(service: service)),
    );

    final current = today();
    await tester.tap(find.text(_healthDisplayDate(current)));
    await tester.pumpAndSettle();

    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(DateUtils.isSameDay(picker.lastDate, current), isTrue);
  });

  testWidgets('Lab DatePicker maximum date is today', (tester) async {
    final service = await _labService();
    await tester.pumpWidget(
      MaterialApp(home: LabResultFormScreen(service: service)),
    );

    final current = today();
    await tester.tap(find.byKey(const Key('lab-date-field')));
    await tester.pumpAndSettle();

    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(DateUtils.isSameDay(picker.lastDate, current), isTrue);
  });

  testWidgets('Statistics excludes a pre-existing future health record', (
    tester,
  ) async {
    final current = today();
    final healthService = await _healthService(
      records: [
        _healthRecord(
          id: 'future-health',
          date: current.add(const Duration(days: 1)),
          weight: 99.9,
        ),
      ],
    );
    final labService = await _labService();

    await tester.pumpWidget(
      MaterialApp(
        home: StatisticsScreen(
          healthRecordService: healthService,
          labResultService: labService,
        ),
      ),
    );

    expect(find.textContaining('99.9 kg'), findsNothing);
  });

  testWidgets('Statistics excludes a pre-existing future lab result', (
    tester,
  ) async {
    final current = today();
    final healthService = await _healthService();
    final labService = await _labService(
      results: [
        _labResult(
          id: 'future-lab',
          date: current.add(const Duration(days: 1)),
          testName: '미래검사',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatisticsScreen(
          healthRecordService: healthService,
          labResultService: labService,
        ),
      ),
    );
    await tester.tap(find.text('검사'));
    await tester.pumpAndSettle();

    expect(find.text('미래검사'), findsNothing);
  });
}

Future<HealthRecordService> _healthService({
  List<HealthRecord>? records,
}) async {
  final service = HealthRecordService(InMemoryHealthRecordStorage(records));
  await service.load();
  return service;
}

Future<LabResultService> _labService({List<LabResult>? results}) async {
  final service = LabResultService(InMemoryLabResultStorage(results));
  await service.load();
  return service;
}

HealthRecord _healthRecord({
  required String id,
  required DateTime date,
  double? weight = 54.2,
}) {
  final now = DateTime.now();
  return HealthRecord(
    id: id,
    date: date,
    weight: weight,
    systolicBloodPressure: 120,
    diastolicBloodPressure: 80,
    waterIntake: 1200,
    steps: 6000,
    sleepHours: 7,
    condition: HealthCondition.normal,
    createdAt: now,
    updatedAt: now,
  );
}

LabResult _labResult({
  required String id,
  required DateTime date,
  String testName = '중성지방',
}) {
  final now = DateTime.now();
  return LabResult(
    id: id,
    date: date,
    testName: testName,
    value: 185,
    unit: 'mg/dL',
    createdAt: now,
    updatedAt: now,
  );
}

String _healthDisplayDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year.$month.$day';
}
