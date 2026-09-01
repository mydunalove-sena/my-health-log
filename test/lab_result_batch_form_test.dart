import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_health_log/models/lab_result.dart';
import 'package:my_health_log/screens/lab/lab_result_batch_form_screen.dart';
import 'package:my_health_log/services/lab_result_service.dart';
import 'package:my_health_log/services/lab_test_settings_service.dart';

void main() {
  testWidgets('enabled definitions show display names and default units', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = await _settings(ids: ['creatinine', 'ktv']);

    await _pumpBatchForm(tester, labService, settings);

    expect(find.text('Creatinine'), findsOneWidget);
    expect(find.text('mg/dL'), findsOneWidget);
    expect(find.text('Kt/V'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
    expect(find.byKey(const Key('lab-batch-value-creatinine')), findsOneWidget);
    expect(find.byKey(const Key('lab-batch-value-ktv')), findsOneWidget);
  });

  testWidgets('saving stores only rows with values for the same date', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = await _settings(ids: ['creatinine', 'bun', 'ktv']);

    await _pumpBatchForm(tester, labService, settings);
    await tester.enterText(
      find.byKey(const Key('lab-batch-value-creatinine')),
      '1.23',
    );
    await tester.enterText(find.byKey(const Key('lab-batch-value-ktv')), '1.8');
    await tester.tap(find.byKey(const Key('lab-batch-save-button')));
    await tester.pumpAndSettle();

    expect(labService.results, hasLength(2));
    expect(
      labService.results.map((result) => result.testName),
      containsAll(['Creatinine', 'Kt/V']),
    );
    expect(
      labService.results.map((result) => result.testName),
      isNot(contains('BUN')),
    );
    expect(labService.groups, hasLength(1));
    expect(
      labService.results.map((result) => result.dateKey).toSet(),
      hasLength(1),
    );
  });

  testWidgets('new rows receive ids and default units', (tester) async {
    final labService = await _labService();
    final settings = await _settings(ids: ['creatinine', 'ktv']);

    await _pumpBatchForm(tester, labService, settings);
    await tester.enterText(
      find.byKey(const Key('lab-batch-value-creatinine')),
      '0.9',
    );
    await tester.enterText(find.byKey(const Key('lab-batch-value-ktv')), '1.7');
    await tester.tap(find.byKey(const Key('lab-batch-save-button')));
    await tester.pumpAndSettle();

    final creatinine = labService.results.singleWhere(
      (result) => result.testName == 'Creatinine',
    );
    final ktv = labService.results.singleWhere(
      (result) => result.testName == 'Kt/V',
    );
    expect(creatinine.id, startsWith('lab-'));
    expect(creatinine.unit, 'mg/dL');
    expect(ktv.id, startsWith('lab-'));
    expect(ktv.unit, isNull);
  });

  testWidgets('existing results are prefilled and updated in place', (
    tester,
  ) async {
    final date = _today();
    final createdAt = DateTime(2026, 1, 1, 8);
    final existing = _result(
      id: 'lab-existing',
      date: date,
      testName: 'Creatinine',
      value: 1.1,
      unit: 'mg/dL',
      createdAt: createdAt,
      updatedAt: DateTime(2026, 1, 1, 9),
    );
    final labService = await _labService(results: [existing]);
    final settings = await _settings(ids: ['creatinine']);

    await _pumpBatchForm(tester, labService, settings, initialDate: date);

    expect(find.widgetWithText(TextField, '1.1'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('lab-batch-value-creatinine')),
      '1.4',
    );
    await tester.tap(find.byKey(const Key('lab-batch-save-button')));
    await tester.pumpAndSettle();

    expect(labService.results, hasLength(1));
    final updated = labService.results.single;
    expect(updated.id, 'lab-existing');
    expect(updated.createdAt, createdAt);
    expect(updated.updatedAt.isAfter(existing.updatedAt), isTrue);
    expect(updated.value, 1.4);
  });

  testWidgets('changing date switches prefilled values', (tester) async {
    final today = _today();
    final yesterday = today.subtract(const Duration(days: 1));
    final labService = await _labService(
      results: [
        _result(
          id: 'lab-today',
          date: today,
          testName: 'Creatinine',
          value: 1.0,
        ),
        _result(
          id: 'lab-yesterday',
          date: yesterday,
          testName: 'Creatinine',
          value: 2.0,
        ),
      ],
    );
    final settings = await _settings(ids: ['creatinine']);

    await _pumpBatchForm(tester, labService, settings, initialDate: today);
    expect(find.widgetWithText(TextField, '1'), findsOneWidget);

    await _pickVisibleDay(tester, yesterday);

    expect(find.widgetWithText(TextField, '2'), findsOneWidget);
  });

  testWidgets('future dates and non-finite values are rejected', (
    tester,
  ) async {
    final tomorrow = _today().add(const Duration(days: 1));
    final labService = await _labService();
    final settings = await _settings(ids: ['creatinine']);

    await _pumpBatchForm(tester, labService, settings, initialDate: tomorrow);
    await tester.enterText(
      find.byKey(const Key('lab-batch-value-creatinine')),
      '1.0',
    );
    await tester.tap(find.byKey(const Key('lab-batch-save-button')));
    await tester.pumpAndSettle();
    expect(labService.results, isEmpty);

    await _pumpBatchForm(tester, labService, settings);
    await tester.enterText(
      find.byKey(const Key('lab-batch-value-creatinine')),
      'abc',
    );
    await tester.tap(find.byKey(const Key('lab-batch-save-button')));
    await tester.pumpAndSettle();
    expect(labService.results, isEmpty);

    await tester.enterText(
      find.byKey(const Key('lab-batch-value-creatinine')),
      'NaN',
    );
    await tester.tap(find.byKey(const Key('lab-batch-save-button')));
    await tester.pumpAndSettle();
    expect(labService.results, isEmpty);

    await tester.enterText(
      find.byKey(const Key('lab-batch-value-creatinine')),
      'Infinity',
    );
    await tester.tap(find.byKey(const Key('lab-batch-save-button')));
    await tester.pumpAndSettle();
    expect(labService.results, isEmpty);
  });

  testWidgets('clearing an existing value does not delete its row', (
    tester,
  ) async {
    final existing = _result(
      id: 'lab-existing',
      testName: 'Creatinine',
      value: 1.1,
      unit: 'mg/dL',
    );
    final labService = await _labService(results: [existing]);
    final settings = await _settings(ids: ['creatinine']);

    await _pumpBatchForm(tester, labService, settings);
    await tester.enterText(
      find.byKey(const Key('lab-batch-value-creatinine')),
      '',
    );
    await tester.tap(find.byKey(const Key('lab-batch-save-button')));
    await tester.pumpAndSettle();

    expect(labService.results, hasLength(1));
    expect(labService.results.single.id, 'lab-existing');
    expect(labService.results.single.value, 1.1);
  });

  testWidgets('custom definitions appear after service load', (tester) async {
    final labService = await _labService();
    final settings = LabTestSettingsService.inMemory();
    await settings.load();
    final custom = await settings.addCustomDefinition(
      displayName: 'Cyclosporine',
      defaultUnit: 'ng/mL',
    );
    await settings.setEnabledLabTestIds([custom.id]);

    await _pumpBatchForm(tester, labService, settings);

    expect(settings.enabledDefinitions.single.displayName, 'Cyclosporine');
    expect(find.text('Cyclosporine'), findsOneWidget);
    expect(find.text('ng/mL'), findsOneWidget);
    expect(find.byKey(Key('lab-batch-value-${custom.id}')), findsOneWidget);
  });

  testWidgets('saved results remain after reopening the batch screen', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = await _settings(ids: ['creatinine']);

    await _pumpBatchForm(tester, labService, settings);
    await tester.enterText(
      find.byKey(const Key('lab-batch-value-creatinine')),
      '1.25',
    );
    await tester.tap(find.byKey(const Key('lab-batch-save-button')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _pumpBatchForm(tester, labService, settings);

    expect(find.widgetWithText(TextField, '1.25'), findsOneWidget);
  });
}

Future<void> _pumpBatchForm(
  WidgetTester tester,
  LabResultService labService,
  LabTestSettingsService settings, {
  DateTime? initialDate,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LabResultBatchFormScreen(
        labResultService: labService,
        labTestSettingsService: settings,
        initialDate: initialDate,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<LabResultService> _labService({List<LabResult>? results}) async {
  final service = LabResultService(InMemoryLabResultStorage(results));
  await service.load();
  return service;
}

Future<LabTestSettingsService> _settings({required List<String> ids}) async {
  final service = LabTestSettingsService.inMemory();
  await service.load();
  await service.setEnabledLabTestIds(ids);
  return service;
}

LabResult _result({
  required String id,
  DateTime? date,
  required String testName,
  required double value,
  String? unit,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime.now();
  return LabResult(
    id: id,
    date: date ?? _today(),
    testName: testName,
    value: value,
    unit: unit,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

Future<void> _pickVisibleDay(WidgetTester tester, DateTime date) async {
  await tester.tap(find.byKey(const Key('lab-batch-date-field')));
  await tester.pumpAndSettle();
  final calendar = find.byType(CalendarDatePicker);
  expect(calendar, findsOneWidget);
  await _showMonth(tester, date);
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

Future<void> _showMonth(WidgetTester tester, DateTime date) async {
  final now = DateTime.now();
  final currentMonth = DateTime(now.year, now.month);
  final targetMonth = DateTime(date.year, date.month);
  final monthDelta =
      (targetMonth.year - currentMonth.year) * 12 +
      targetMonth.month -
      currentMonth.month;
  if (monthDelta == 0) {
    return;
  }

  final dialog = find.byType(DatePickerDialog);
  final context = tester.element(dialog);
  final localizations = MaterialLocalizations.of(context);
  final tooltip = monthDelta < 0
      ? localizations.previousMonthTooltip
      : localizations.nextMonthTooltip;
  for (var i = 0; i < monthDelta.abs(); i++) {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }
}
