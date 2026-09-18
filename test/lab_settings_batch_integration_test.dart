import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_health_log/models/lab_result.dart';
import 'package:my_health_log/models/lab_capture_candidate.dart';
import 'package:my_health_log/screens/lab/lab_capture_review_screen.dart';
import 'package:my_health_log/screens/lab/lab_result_batch_form_screen.dart';
import 'package:my_health_log/screens/lab/lab_screen.dart';
import 'package:my_health_log/screens/statistics/statistics_screen.dart';
import 'package:my_health_log/services/health_field_visibility_service.dart';
import 'package:my_health_log/services/health_record_service.dart';
import 'package:my_health_log/services/lab_result_service.dart';
import 'package:my_health_log/services/lab_test_settings_service.dart';
import 'package:my_health_log/services/lab_image_picker_service.dart';
import 'package:my_health_log/services/lab_ocr_service.dart';

void main() {
  testWidgets(
    'detail add sheet reuses direct entry and returns to the same date',
    (tester) async {
      final date = DateTime(2026, 1, 13);
      final service = await _labService(
        results: [
          _result(
            id: 'existing',
            date: date,
            testName: 'BUN',
            value: 19.4,
            unit: 'mg/dL',
          ),
        ],
      );
      final settings = await _settings(ids: ['bun', 'alp']);
      await _openDetailAddition(tester, service, settings);
      expect(find.byType(ListTile), findsNWidgets(2));
      expect(find.text('직접 입력'), findsOneWidget);
      expect(find.text('사진으로 입력'), findsOneWidget);
      await tester.tap(find.byKey(const Key('lab-direct-input-button')));
      await tester.pumpAndSettle();
      expect(find.byType(LabResultBatchFormScreen), findsOneWidget);
      expect(
        tester
            .widget<LabResultBatchFormScreen>(
              find.byType(LabResultBatchFormScreen),
            )
            .initialDate,
        date,
      );
      await tester.enterText(
        find.byKey(const Key('lab-batch-value-alp')),
        '50',
      );
      expect(service.results, hasLength(1));
      await tester.ensureVisible(
        find.byKey(const Key('lab-batch-save-button')),
      );
      await tester.tap(find.byKey(const Key('lab-batch-save-button')));
      await tester.pumpAndSettle();
      expect(
        find.byType(LabResultDetailScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text(LabResult.formatDisplayDate(date)), findsOneWidget);
      expect(find.text('ALP'), findsOneWidget);
      expect(service.resultsForDate(date), hasLength(2));
      expect(
        service.results.singleWhere((item) => item.id == 'existing').value,
        19.4,
      );
    },
  );

  for (final existingValue in [19.4, 18.2]) {
    testWidgets(
      'detail photo keeps date and explicit-save dedup/conflict for $existingValue',
      (tester) async {
        final date = DateTime(2026, 1, 13);
        final service = await _labService(
          results: [
            _result(
              id: 'existing',
              date: date,
              testName: 'BUN',
              value: existingValue,
              unit: 'mg/dL',
            ),
          ],
        );
        final settings = await _settings(ids: ['bun', 'alp']);
        await _openDetailAddition(tester, service, settings);
        await tester.tap(find.byKey(const Key('lab-photo-input-button')));
        await tester.pumpAndSettle();
        final review = tester.widget<LabCaptureReviewScreen>(
          find.byType(LabCaptureReviewScreen),
        );
        expect(review.initialDate, date);
        expect(find.text(LabResult.formatDisplayDate(date)), findsOneWidget);
        expect(review.candidates.map((item) => item.definition?.id), [
          'bun',
          'alp',
        ]);
        expect(service.results, hasLength(1));
        expect(service.results.single.value, existingValue);
        final bun = review.candidates.first;
        expect(bun.existingResult?.id, 'existing');
        if (existingValue == 19.4) {
          expect(bun.hasExistingSameValue, isTrue);
          expect(bun.isSelected, isFalse);
        } else {
          expect(bun.hasExistingConflict, isTrue);
          expect(find.textContaining('기존값:'), findsOneWidget);
        }
        await tester.scrollUntilVisible(
          find.byKey(const Key('lab-capture-save-button')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const Key('lab-capture-save-button')));
        await tester.pumpAndSettle();
        expect(find.byType(LabCaptureReviewScreen), findsNothing);
        expect(
          find.byType(LabResultDetailScreen, skipOffstage: false),
          findsOneWidget,
        );
        expect(find.text(LabResult.formatDisplayDate(date)), findsOneWidget);
        expect(find.text('ALP'), findsOneWidget);
        expect(service.resultsForDate(date), hasLength(2));
        expect(service.resultsForDate(DateTime(2026, 1, 12)), isEmpty);
        expect(
          service.results.singleWhere((item) => item.id == 'existing').value,
          19.4,
        );
        expect(
          service.results.singleWhere((item) => item.testName == 'ALP').value,
          50,
        );
      },
    );
  }

  for (final stage in ['sheet', 'picker', 'review']) {
    testWidgets('detail $stage cancel preserves records and original route', (
      tester,
    ) async {
      final service = await _labService(
        results: [
          _result(
            id: 'existing',
            date: DateTime(2026, 1, 13),
            testName: 'BUN',
            value: 19.4,
            unit: 'mg/dL',
          ),
        ],
      );
      final settings = await _settings(ids: ['bun', 'alp']);
      final before = settings.enabledLabTestIds;
      await _openDetailAddition(
        tester,
        service,
        settings,
        picker: FixedLabImagePickerService(
          stage == 'picker' ? [] : ['capture.jpg'],
        ),
      );
      if (stage == 'sheet') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byKey(const Key('lab-photo-input-button')));
        await tester.pumpAndSettle();
        if (stage == 'review') {
          final cancel = find.byKey(const Key('lab-capture-cancel-button'));
          await tester.scrollUntilVisible(
            cancel,
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(cancel);
        }
      }
      await tester.pumpAndSettle();
      expect(find.byType(LabCaptureReviewScreen), findsNothing);
      expect(
        find.byType(LabResultDetailScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(service.results, hasLength(1));
      expect(service.results.single.id, 'existing');
      expect(service.results.single.value, 19.4);
      expect(settings.enabledLabTestIds, before);
    });
  }

  for (final ocr in [
    const FailingLabOcrService('failure'),
    const AssetLabOcrService([]),
  ]) {
    testWidgets(
      'detail ${ocr.runtimeType} retry and direct fallback keep date and route',
      (tester) async {
        final date = DateTime(2026, 1, 13);
        final service = await _labService(
          results: [
            _result(
              id: 'existing',
              date: date,
              testName: 'BUN',
              value: 19.4,
              unit: 'mg/dL',
            ),
          ],
        );
        final settings = await _settings(ids: ['bun', 'alp']);
        await _openDetailAddition(tester, service, settings, ocr: ocr);
        await tester.tap(find.byKey(const Key('lab-photo-input-button')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('lab-capture-failure-pick-again-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(LabCaptureReviewScreen, skipOffstage: false),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('lab-capture-failure-direct-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(LabCaptureReviewScreen, skipOffstage: false),
          findsNothing,
        );
        final batch = tester.widget<LabResultBatchFormScreen>(
          find.byType(LabResultBatchFormScreen),
        );
        expect(batch.initialDate, date);
        expect(service.results, hasLength(1));
        await tester.enterText(
          find.byKey(const Key('lab-batch-value-alp')),
          '50',
        );
        await tester.ensureVisible(
          find.byKey(const Key('lab-batch-save-button')),
        );
        await tester.tap(find.byKey(const Key('lab-batch-save-button')));
        await tester.pumpAndSettle();
        expect(
          find.byType(LabResultDetailScreen, skipOffstage: false),
          findsOneWidget,
        );
        expect(service.resultsForDate(date), hasLength(2));
      },
    );
  }

  testWidgets('batch screen shows enabled definitions only', (tester) async {
    final labService = await _labService();
    final settings = await _settings(ids: ['creatinine']);

    await _pumpBatch(tester, labService, settings);

    expect(find.text('Creatinine'), findsOneWidget);
    expect(find.text('BUN'), findsNothing);
    expect(find.byKey(const Key('lab-batch-value-creatinine')), findsOneWidget);
    expect(find.byKey(const Key('lab-batch-value-bun')), findsNothing);
  });

  testWidgets('custom enabled definition appears in batch with default unit', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = LabTestSettingsService.inMemory();
    await settings.load();
    final custom = await settings.addCustomDefinition(
      displayName: 'CRP',
      defaultUnit: 'mg/L',
    );
    await settings.setEnabledLabTestIds([custom.id]);

    await _pumpBatch(tester, labService, settings);

    expect(find.text('CRP'), findsOneWidget);
    expect(find.text('mg/L'), findsOneWidget);
    expect(find.byKey(Key('lab-batch-value-${custom.id}')), findsOneWidget);
  });

  testWidgets('batch screen reflects setting changes on next entry', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = await _settings(ids: ['creatinine', 'bun']);

    await _pumpBatch(tester, labService, settings);
    expect(find.text('BUN'), findsOneWidget);

    await settings.setEnabledLabTestIds(['creatinine']);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpBatch(tester, labService, settings);

    expect(find.text('Creatinine'), findsOneWidget);
    expect(find.text('BUN'), findsNothing);
  });

  testWidgets('disabled existing lab result remains in list and detail', (
    tester,
  ) async {
    final date = _today();
    final labService = await _labService(
      results: [
        _result(
          id: 'lab-wbc',
          date: date,
          testName: 'WBC',
          value: 5.5,
          unit: '×10³/µL',
        ),
      ],
    );
    final settings = await _settings(ids: ['creatinine']);

    await tester.pumpWidget(
      MaterialApp(
        home: LabScreen(service: labService, labTestSettingsService: settings),
      ),
    );

    expect(find.text('WBC'), findsOneWidget);
    expect(find.text('5.5 ×10³/µL'), findsOneWidget);

    await tester.tap(
      find.byKey(ValueKey('lab-group-${LabResult.formatDateKey(date)}')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lab-result-lab-wbc')), findsOneWidget);
    expect(find.text('WBC'), findsOneWidget);
    expect(labService.results.single.testName, 'WBC');
  });

  testWidgets('disabled existing lab result remains in statistics', (
    tester,
  ) async {
    final labService = await _labService(
      results: [
        _result(id: 'lab-wbc', testName: 'WBC', value: 5.5, unit: '×10³/µL'),
      ],
    );
    final healthService = HealthRecordService(InMemoryHealthRecordStorage());
    await healthService.load();
    final visibility = HealthFieldVisibilityService.inMemory();
    await visibility.load();

    await tester.pumpWidget(
      MaterialApp(
        home: StatisticsScreen(
          healthRecordService: healthService,
          labResultService: labService,
          healthFieldVisibilityService: visibility,
          onOpenHealth: () {},
          onOpenLab: () {},
        ),
      ),
    );
    await tester.tap(find.text('검사'));
    await tester.pumpAndSettle();

    expect(find.text('WBC'), findsWidgets);
    expect(find.textContaining('5.5'), findsWidgets);
  });
}

Future<void> _openDetailAddition(
  WidgetTester tester,
  LabResultService service,
  LabTestSettingsService settings, {
  LabImagePickerService picker = const FixedLabImagePickerService([
    'capture.jpg',
  ]),
  LabOcrService? ocr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LabScreen(
        service: service,
        labTestSettingsService: settings,
        imagePickerService: picker,
        ocrService: ocr ?? AssetLabOcrService([_photoDocument()]),
      ),
    ),
  );
  await tester.tap(
    find.byKey(ValueKey('lab-group-${service.results.first.dateKey}')),
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('lab-detail-add-button')), findsOneWidget);
  expect(find.byKey(const Key('lab-photo-input-button')), findsNothing);
  await tester.tap(find.byKey(const Key('lab-detail-add-button')));
  await tester.pumpAndSettle();
}

LabOcrDocument _photoDocument() {
  LabOcrLine line(
    String text,
    double left,
    double top,
    double right,
    double bottom,
  ) => LabOcrLine(
    text: text,
    left: left,
    top: top,
    right: right,
    bottom: bottom,
    sourceImageIndex: 0,
    imageWidth: 955,
    imageHeight: 2048,
  );
  return LabOcrDocument(
    sourceImageIndex: 0,
    imageWidth: 955,
    imageHeight: 2048,
    lines: [
      line('2026-01-12', 40, 160, 340, 200),
      for (final (name, value, unit, top) in [
        ('BUN', '19.4', 'mg/dL', 300.0),
        ('Alk. Phos(알칼리인산분해효소)', '50', 'IU/L', 700.0),
      ]) ...[
        line(name, 80, top, 650, top + 40),
        line('결과', 42, top + 140, 100, top + 170),
        line(value, 278, top + 144, 350, top + 174),
        line('참고치', 28, top + 238, 140, top + 275),
        line('($unit)', 598, top + 246, 715, top + 280),
      ],
    ],
  );
}

Future<void> _pumpBatch(
  WidgetTester tester,
  LabResultService labService,
  LabTestSettingsService settings,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LabResultBatchFormScreen(
        labResultService: labService,
        labTestSettingsService: settings,
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
}) {
  final now = DateTime.now();
  return LabResult(
    id: id,
    date: date ?? _today(),
    testName: testName,
    value: value,
    unit: unit,
    createdAt: now,
    updatedAt: now,
  );
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
