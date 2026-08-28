import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_health_log/models/lab_result.dart';
import 'package:my_health_log/screens/lab/lab_result_form_screen.dart';
import 'package:my_health_log/screens/lab/lab_screen.dart';
import 'package:my_health_log/services/lab_result_service.dart';

void main() {
  testWidgets('Lab empty state is shown', (tester) async {
    final service = await _service();
    await tester.pumpWidget(MaterialApp(home: LabScreen(service: service)));

    expect(
      find.textContaining(
        '\uAC80\uC0AC \uACB0\uACFC\uAC00 \uC5C6\uC2B5\uB2C8\uB2E4.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('+ \uAC80\uC0AC \uACB0\uACFC \uB4F1\uB85D'),
      findsOneWidget,
    );
  });

  testWidgets('Lab Add screen opens', (tester) async {
    final service = await _service();
    await tester.pumpWidget(MaterialApp(home: LabScreen(service: service)));

    await tester.tap(find.byKey(const Key('lab-add-button')));
    await tester.pumpAndSettle();

    expect(find.text('\uAC80\uC0AC \uACB0\uACFC \uB4F1\uB85D'), findsWidgets);
    expect(find.byKey(const Key('lab-date-field')), findsOneWidget);
    expect(find.byKey(const Key('lab-test-name-field')), findsOneWidget);
    expect(find.byKey(const Key('lab-value-field')), findsOneWidget);
  });

  testWidgets('Lab validation requires test name and value', (tester) async {
    final service = await _service();
    await tester.pumpWidget(
      MaterialApp(home: LabResultFormScreen(service: service)),
    );

    await tester.tap(find.byKey(const Key('lab-save-button')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '\uAC80\uC0AC \uD56D\uBAA9\uC744 \uC785\uB825\uD574\uC8FC\uC138\uC694.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '\uACB0\uACFC\uAC12\uC744 \uC785\uB825\uD574\uC8FC\uC138\uC694.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Lab value must be numeric', (tester) async {
    final service = await _service();
    await tester.pumpWidget(
      MaterialApp(home: LabResultFormScreen(service: service)),
    );

    await tester.enterText(
      find.byKey(const Key('lab-test-name-field')),
      '\uC911\uC131\uC9C0\uBC29',
    );
    await tester.enterText(find.byKey(const Key('lab-value-field')), 'abc');
    await tester.tap(find.byKey(const Key('lab-save-button')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '\uACB0\uACFC\uAC12\uC740 \uC22B\uC790\uB85C \uC785\uB825\uD574\uC8FC\uC138\uC694.',
      ),
      findsOneWidget,
    );
    expect(service.results, isEmpty);
  });

  testWidgets('LabResult saves and appears in date group', (tester) async {
    final service = await _service();
    await tester.pumpWidget(MaterialApp(home: LabScreen(service: service)));

    await _addLabResult(
      tester,
      testName: '\uC911\uC131\uC9C0\uBC29',
      value: '185',
      unit: 'mg/dL',
    );

    expect(service.results.length, 1);
    expect(find.text('\uC911\uC131\uC9C0\uBC29'), findsOneWidget);
    expect(find.text('185 mg/dL'), findsOneWidget);
    expect(find.text(LabResult.formatDisplayDate(DateTime.now())), findsWidgets);
  });

  testWidgets('Same date multiple LabResults are grouped together', (
    tester,
  ) async {
    final today = DateTime.now();
    final service = await _service(
      results: [
        _result(
          id: 'lab-1',
          date: today,
          testName: '\uC911\uC131\uC9C0\uBC29',
          value: 185,
          unit: 'mg/dL',
        ),
        _result(
          id: 'lab-2',
          date: today,
          testName: '\uC694\uC0B0',
          value: 6.2,
          unit: 'mg/dL',
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: LabScreen(service: service)));

    expect(service.groups.length, 1);
    expect(find.byKey(ValueKey('lab-group-${_todayKey()}')), findsOneWidget);
    expect(find.text('\uC911\uC131\uC9C0\uBC29'), findsOneWidget);
    expect(find.text('\uC694\uC0B0'), findsOneWidget);
  });

  testWidgets('Lab Detail shows date results and opens edit', (tester) async {
    final today = DateTime.now();
    final service = await _service(
      results: [
        _result(
          id: 'lab-1',
          date: today,
          testName: '\uC911\uC131\uC9C0\uBC29',
          value: 185,
          unit: 'mg/dL',
        ),
        _result(
          id: 'lab-2',
          date: today,
          testName: '\uC694\uC0B0',
          value: 6.2,
          unit: 'mg/dL',
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: LabScreen(service: service)));

    await tester.tap(find.byKey(ValueKey('lab-group-${_todayKey()}')));
    await tester.pumpAndSettle();

    expect(find.text(LabResult.formatDisplayDate(today)), findsOneWidget);
    expect(find.text('\uC911\uC131\uC9C0\uBC29'), findsOneWidget);
    expect(find.text('\uC694\uC0B0'), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-edit-lab-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-delete-lab-1')), findsOneWidget);

    await tester.tap(find.text('\uC911\uC131\uC9C0\uBC29'));
    await tester.pumpAndSettle();
    expect(find.text('\uAC80\uC0AC \uACB0\uACFC \uC218\uC815'), findsWidgets);
    expect(
      find.widgetWithText(TextFormField, '\uC911\uC131\uC9C0\uBC29'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, '185'), findsOneWidget);
  });

  testWidgets('Lab explicit edit action opens existing values', (tester) async {
    final today = DateTime.now();
    final service = await _service(
      results: [
        _result(
          id: 'lab-1',
          date: today,
          testName: '\uC911\uC131\uC9C0\uBC29',
          value: 185,
          unit: 'mg/dL',
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: LabScreen(service: service)));

    await tester.tap(find.byKey(ValueKey('lab-group-${_todayKey()}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lab-edit-lab-1')));
    await tester.pumpAndSettle();

    expect(find.text('\uAC80\uC0AC \uACB0\uACFC \uC218\uC815'), findsWidgets);
    expect(
      find.widgetWithText(TextFormField, '\uC911\uC131\uC9C0\uBC29'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, '185'), findsOneWidget);
  });

  testWidgets('Lab Edit updates same result', (tester) async {
    final today = DateTime.now();
    final result = _result(
      id: 'lab-1',
      date: today,
      testName: '\uC911\uC131\uC9C0\uBC29',
      value: 185,
      unit: 'mg/dL',
    );
    final service = await _service(results: [result]);
    await tester.pumpWidget(
      MaterialApp(
        home: LabResultFormScreen(service: service, result: result),
      ),
    );

    await tester.enterText(find.byKey(const Key('lab-value-field')), '180');
    await tester.tap(find.byKey(const Key('lab-save-button')));
    await tester.pumpAndSettle();

    expect(service.results.length, 1);
    expect(service.results.first.id, 'lab-1');
    expect(service.results.first.value, 180);
  });

  testWidgets('Lab edit can move a today result to a past date group', (
    tester,
  ) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final pastDate = todayDate.subtract(const Duration(days: 1));
    final result = _result(
      id: 'lab-1',
      date: todayDate,
      testName: '\uC911\uC131\uC9C0\uBC29',
      value: 185,
      unit: 'mg/dL',
    );
    final service = await _service(results: [result]);
    await tester.pumpWidget(
      MaterialApp(
        home: LabResultFormScreen(service: service, result: result),
      ),
    );

    await _pickVisibleDay(tester, pastDate);
    await tester.tap(find.byKey(const Key('lab-save-button')));
    await tester.pumpAndSettle();

    expect(service.results.single.dateKey, LabResult.formatDateKey(pastDate));
    expect(service.groups.single.dateKey, LabResult.formatDateKey(pastDate));
  });

  testWidgets('Lab explicit delete cancel keeps result', (tester) async {
    final today = DateTime.now();
    final service = await _service(
      results: [
        _result(
          id: 'lab-1',
          date: today,
          testName: '\uC911\uC131\uC9C0\uBC29',
          value: 185,
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: LabScreen(service: service)));

    await tester.tap(find.byKey(ValueKey('lab-group-${_todayKey()}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lab-delete-lab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('\uCDE8\uC18C'));
    await tester.pumpAndSettle();

    expect(service.results, hasLength(1));
    expect(find.byKey(const ValueKey('lab-result-lab-1')), findsOneWidget);
  });

  testWidgets('Lab explicit delete confirm removes result', (tester) async {
    final today = DateTime.now();
    final service = await _service(
      results: [
        _result(
          id: 'lab-1',
          date: today,
          testName: '\uC911\uC131\uC9C0\uBC29',
          value: 185,
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: LabScreen(service: service)));

    await tester.tap(find.byKey(ValueKey('lab-group-${_todayKey()}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lab-delete-lab-1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('lab-detail-confirm-delete-button')),
    );
    await tester.pumpAndSettle();

    expect(service.results, isEmpty);
    expect(service.groups, isEmpty);
  });

  testWidgets('LabResult delete removes last date group', (tester) async {
    final today = DateTime.now();
    final result = _result(
      id: 'lab-1',
      date: today,
      testName: '\uC911\uC131\uC9C0\uBC29',
      value: 185,
      unit: 'mg/dL',
    );
    final service = await _service(results: [result]);
    await tester.pumpWidget(MaterialApp(home: LabScreen(service: service)));

    await tester.tap(find.byKey(ValueKey('lab-group-${_todayKey()}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('\uC911\uC131\uC9C0\uBC29'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('\uC0AD\uC81C'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('\uC0AD\uC81C').last);
    await tester.pumpAndSettle();

    expect(service.results, isEmpty);
    expect(service.groups, isEmpty);
    expect(
      find.textContaining(
        '\uAC80\uC0AC \uACB0\uACFC\uAC00 \uC5C6\uC2B5\uB2C8\uB2E4.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Main lab add opens saved date detail', (tester) async {
    final service = await _service();
    final pastDate = DateTime.now().subtract(const Duration(days: 1));
    await tester.pumpWidget(MaterialApp(home: LabScreen(service: service)));

    await _addLabResult(
      tester,
      testName: '\uBE44\uD0C0\uBBBCD',
      value: '42',
      unit: 'ng/mL',
      date: pastDate,
    );

    expect(find.text(LabResult.formatDisplayDate(pastDate)), findsWidgets);
    expect(find.byKey(const Key('lab-detail-add-button')), findsOneWidget);
  });

  testWidgets('Detail lab add keeps the detail date as initial date', (
    tester,
  ) async {
    final date = DateTime.now().subtract(const Duration(days: 1));
    final service = await _service(
      results: [
        _result(
          id: 'lab-1',
          date: date,
          testName: '\uC911\uC131\uC9C0\uBC29',
          value: 185,
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: LabScreen(service: service)));

    await tester.tap(
      find.byKey(ValueKey('lab-group-${LabResult.formatDateKey(date)}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lab-detail-add-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lab-date-field')), findsOneWidget);
    expect(find.text(LabResult.formatDisplayDate(date)), findsOneWidget);
  });

  test('Duplicate date and testName is prevented', () async {
    final today = DateTime.now();
    final service = await _service(
      results: [
        _result(
          id: 'lab-1',
          date: today,
          testName: '\uC911\uC131\uC9C0\uBC29',
          value: 185,
        ),
      ],
    );

    expect(
      () => service.save(
        _result(
          id: 'lab-2',
          date: today,
          testName: '\uC911\uC131\uC9C0\uBC29',
          value: 180,
        ),
      ),
      throwsA(isA<DuplicateLabResultException>()),
    );
  });

  testWidgets('Empty unit displays value without null or extra unit', (
    tester,
  ) async {
    final service = await _service(
      results: [
        _result(
          id: 'lab-1',
          testName: '\uBE44\uD0C0\uBBBCD',
          value: 42,
          unit: null,
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: LabScreen(service: service)));

    expect(find.text('42'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
  });

  test(
    'LabResult data persists after service reload with same storage',
    () async {
      final storage = InMemoryLabResultStorage();
      final first = LabResultService(storage);
      await first.load();
      await first.save(
        _result(
          id: 'lab-1',
          testName: '\uC694\uC0B0',
          value: 6.2,
          unit: 'mg/dL',
        ),
      );

      final second = LabResultService(storage);
      await second.load();

      expect(second.results.length, 1);
      expect(second.results.first.testName, '\uC694\uC0B0');
    },
  );
}

Future<void> _addLabResult(
  WidgetTester tester, {
  required String testName,
  required String value,
  String? unit,
  DateTime? date,
}) async {
  await tester.tap(find.byKey(const Key('lab-add-button')));
  await tester.pumpAndSettle();
  if (date != null) {
    await _pickVisibleDay(tester, date);
  }
  await tester.enterText(
    find.byKey(const Key('lab-test-name-field')),
    testName,
  );
  await tester.enterText(find.byKey(const Key('lab-value-field')), value);
  if (unit != null) {
    await tester.enterText(find.byKey(const Key('lab-unit-field')), unit);
  }
  await tester.tap(find.byKey(const Key('lab-save-button')));
  await tester.pumpAndSettle();
}

Future<void> _pickVisibleDay(WidgetTester tester, DateTime date) async {
  await tester.tap(find.byKey(const Key('lab-date-field')));
  await tester.pumpAndSettle();
  final calendar = find.byType(CalendarDatePicker);
  expect(calendar, findsOneWidget);
  final day = find
      .descendant(of: calendar, matching: find.text('${date.day}'))
      .hitTestable();
  expect(day, findsOneWidget);
  await tester.tap(day);
  await tester.pumpAndSettle();
  final dialog = find.byType(DatePickerDialog);
  expect(dialog, findsOneWidget);
  final context = tester.element(dialog);
  final okLabel = MaterialLocalizations.of(context).okButtonLabel;
  final okButton = find
      .descendant(
        of: dialog,
        matching: find.widgetWithText(TextButton, okLabel),
      )
      .hitTestable();
  expect(okButton, findsOneWidget);
  await tester.tap(okButton);
  await tester.pumpAndSettle();
}

Future<LabResultService> _service({List<LabResult>? results}) async {
  final service = LabResultService(InMemoryLabResultStorage(results));
  await service.load();
  return service;
}

LabResult _result({
  required String id,
  DateTime? date,
  required String testName,
  required double value,
  String? unit,
}) {
  final now = DateTime.now();
  return LabResult(
    id: id,
    date: date ?? DateTime(now.year, now.month, now.day),
    testName: testName,
    value: value,
    unit: unit,
    createdAt: now,
    updatedAt: now,
  );
}

String _todayKey() {
  final now = DateTime.now();
  return LabResult.formatDateKey(DateTime(now.year, now.month, now.day));
}
