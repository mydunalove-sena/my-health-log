import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_health_log/core/constants/lab_test_definitions.dart';
import 'package:my_health_log/models/lab_capture_candidate.dart';
import 'package:my_health_log/models/lab_result.dart';
import 'package:my_health_log/screens/lab/lab_capture_review_screen.dart';
import 'package:my_health_log/screens/lab/lab_screen.dart';
import 'package:my_health_log/services/lab_capture_mapping_service.dart';
import 'package:my_health_log/services/lab_image_picker_service.dart';
import 'package:my_health_log/services/lab_ocr_service.dart';
import 'package:my_health_log/services/lab_result_service.dart';
import 'package:my_health_log/services/lab_test_settings_service.dart';

void main() {
  testWidgets('opening review does not save until explicit confirmation', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = await _settings();
    final candidates = _mappedCandidates([_parsed('BUN', 19.4)]);

    await _pumpReview(tester, labService, settings, candidates);

    expect(labService.results, isEmpty);
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(labService.results, hasLength(1));
    expect(labService.results.single.testName, 'BUN');
    expect(labService.results.single.value, 19.4);
  });

  testWidgets('cancel leaves LabResultService unchanged', (tester) async {
    final labService = await _labService();
    final settings = await _settings();

    await _pumpReview(
      tester,
      labService,
      settings,
      _mappedCandidates([_parsed('BUN', 19.4)]),
    );
    await tester.tap(find.byKey(const Key('lab-capture-cancel-button')));
    await tester.pumpAndSettle();

    expect(labService.results, isEmpty);
  });

  testWidgets('unchecked and unmapped candidates are not saved', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = await _settings();
    final candidates = _mappedCandidates([
      _parsed('BUN', 19.4),
      _parsed('Albumin', 4.5),
      _parsed('Total Protein(??????됰Ŧ??', 7.8),
    ]);

    candidates.first.isSelected = false;
    await _pumpReview(tester, labService, settings, candidates);
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(labService.results, hasLength(1));
    expect(labService.results.single.testName, 'Albumin');
  });

  testWidgets('user can map an unmapped candidate and save edited value', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = await _settings();
    final candidates = _mappedCandidates([
      _parsed('Total Protein(??????됰Ŧ??', 7.8),
    ]);

    await _pumpReview(tester, labService, settings, candidates);
    await tester.tap(find.byKey(const Key('lab-capture-map-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Albumin').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('lab-capture-value-0')), '4.5');
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(labService.results, hasLength(1));
    expect(labService.results.single.testName, 'Albumin');
    expect(labService.results.single.value, 4.5);
  });

  testWidgets(
    'existing same value is excluded and existing conflict updates only on save',
    (tester) async {
      final today = _today();
      final existing = _result('lab-existing', today, 'BUN', 18.2);
      final labService = await _labService(results: [existing]);
      final settings = await _settings();
      final candidates = LabCaptureMappingService(predefinedLabTestDefinitions)
          .map([
            _parsed('BUN', 19.4),
          ], existingResults: labService.resultsForDate(today));

      await _pumpReview(tester, labService, settings, candidates);
      expect(labService.results.single.value, 18.2);

      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(labService.results, hasLength(1));
      expect(labService.results.single.id, 'lab-existing');
      expect(labService.results.single.value, 19.4);
    },
  );

  testWidgets('existing P alias same value is not inserted again', (
    tester,
  ) async {
    final today = _today();
    final existing = _result('lab-existing-p', today, 'Inorganic P(인)', 2.1);
    final labService = await _labService(results: [existing]);
    final settings = await _settings();
    final candidates = _mappedCandidates([_parsed('P(인)', 2.1)]);

    await _pumpReview(tester, labService, settings, candidates);

    expect(candidates.single.existingResult?.id, 'lab-existing-p');
    expect(candidates.single.hasExistingSameValue, isTrue);
    expect(candidates.single.isSelected, isFalse);
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(labService.results, hasLength(1));
    expect(labService.results.single.id, 'lab-existing-p');
    expect(labService.results.single.testName, 'Inorganic P(인)');
    expect(labService.results.single.value, 2.1);
  });

  testWidgets('existing P alias conflict updates existing row id', (
    tester,
  ) async {
    final today = _today();
    final existing = _result('lab-existing-p', today, 'Inorganic P(인)', 2.0);
    final labService = await _labService(results: [existing]);
    final settings = await _settings();
    final candidates = _mappedCandidates([_parsed('P(인)', 2.1)]);

    await _pumpReview(tester, labService, settings, candidates);

    expect(candidates.single.existingResult?.id, 'lab-existing-p');
    expect(candidates.single.hasExistingConflict, isTrue);
    expect(candidates.single.isSelected, isTrue);
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(labService.results, hasLength(1));
    expect(labService.results.single.id, 'lab-existing-p');
    expect(labService.results.single.testName, 'Inorganic P(인)');
    expect(labService.results.single.value, 2.1);
  });

  testWidgets('existing HDL alias same value is not inserted again', (
    tester,
  ) async {
    final today = _today();
    final existing = _result('lab-existing-hdl', today, 'HDL-Cholesterol', 62);
    final labService = await _labService(results: [existing]);
    final settings = await _settings();
    final candidates = _mappedCandidates([_parsed('HDL Cholesterol', 62)]);

    await _pumpReview(tester, labService, settings, candidates);

    expect(candidates.single.existingResult?.id, 'lab-existing-hdl');
    expect(candidates.single.hasExistingSameValue, isTrue);
    expect(candidates.single.isSelected, isFalse);
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(labService.results, hasLength(1));
    expect(labService.results.single.id, 'lab-existing-hdl');
    expect(labService.results.single.testName, 'HDL-Cholesterol');
    expect(labService.results.single.value, 62);
  });

  testWidgets(
    'editing an existing same value enables explicit update on save',
    (tester) async {
      final today = _today();
      final existing = _result('lab-existing-glucose', today, 'Glucose', 89);
      final labService = await _labService(results: [existing]);
      final settings = await _settings();
      final candidates = LabCaptureMappingService(predefinedLabTestDefinitions)
          .map([
            _parsed('Glucose', 89),
          ], existingResults: labService.resultsForDate(today));
      final candidate = candidates.single;

      await _pumpReview(tester, labService, settings, candidates);

      expect(candidate.isSelected, isFalse);
      await tester.enterText(
        find.byKey(ValueKey('lab-capture-value-${candidate.id}')),
        '90',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('lab-capture-check-${candidate.id}')),
      );
      await tester.pumpAndSettle();
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(labService.results, hasLength(1));
      expect(labService.results.single.id, 'lab-existing-glucose');
      expect(labService.results.single.testName, 'Glucose');
      expect(labService.results.single.value, 90);
    },
  );

  testWidgets('future date is blocked by LabResultService on final save', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = await _settings();
    final tomorrow = _today().add(const Duration(days: 1));

    await _pumpReview(
      tester,
      labService,
      settings,
      _mappedCandidates([_parsed('BUN', 19.4)]),
      initialDate: tomorrow,
    );
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(labService.results, isEmpty);
  });

  testWidgets('OCR failure screen exposes retry and direct input fallback', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = await _settings();

    await _pumpReview(tester, labService, settings, const []);

    expect(
      find.byKey(const Key('lab-capture-failure-pick-again-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('lab-capture-failure-direct-button')),
      findsOneWidget,
    );
  });

  testWidgets('Lab photo action runs OCR and reaches review before saving', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = await _settings();
    await tester.pumpWidget(
      MaterialApp(
        home: LabScreen(
          service: labService,
          labTestSettingsService: settings,
          imagePickerService: const FixedLabImagePickerService(['sample.jpg']),
          ocrService: const AssetLabOcrService([
            LabOcrDocument(
              sourceImageIndex: 0,
              imageWidth: 955,
              imageHeight: 2048,
              lines: [
                LabOcrLine(
                  text: 'BUN',
                  left: 80,
                  top: 300,
                  right: 350,
                  bottom: 340,
                  sourceImageIndex: 0,
                  imageWidth: 955,
                  imageHeight: 2048,
                ),
                LabOcrLine(
                  text: '\uACB0\uACFC',
                  left: 42,
                  top: 440,
                  right: 100,
                  bottom: 470,
                  sourceImageIndex: 0,
                  imageWidth: 955,
                  imageHeight: 2048,
                ),
                LabOcrLine(
                  text: '19.4',
                  left: 278,
                  top: 444,
                  right: 350,
                  bottom: 474,
                  sourceImageIndex: 0,
                  imageWidth: 955,
                  imageHeight: 2048,
                ),
              ],
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('lab-add-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lab-photo-input-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lab-capture-save-button')), findsOneWidget);
    expect(labService.results, isEmpty);
  });

  testWidgets(
    'review adds second and third photo results while preserving user edits',
    (tester) async {
      final labService = await _labService();
      final settings = await _settings();
      final additions = <List<ParsedLabCaptureCandidate>>[
        [_parsed('Albumin', 4.5)],
        [_parsed('Creatinine', 1.21)],
      ];

      await _pumpReview(
        tester,
        labService,
        settings,
        _mappedCandidates([_parsed('BUN', 19.4)]),
        onAddPhotos: () async => additions.removeAt(0),
      );
      await tester.enterText(
        find.byKey(const Key('lab-capture-value-0')),
        '20.1',
      );

      await _tapAddPhotos(tester);
      expect(
        find.byKey(const Key('lab-capture-candidate-added-0-0')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('lab-capture-value-0')))
            .controller!
            .text,
        '20.1',
      );
      expect(labService.results, isEmpty);

      await _tapAddPhotos(tester);
      expect(
        find.byKey(const Key('lab-capture-candidate-added-1-0')),
        findsOneWidget,
      );
      expect(labService.results, isEmpty);

      await _tapSave(tester);
      await tester.pumpAndSettle();
      expect(labService.results, hasLength(3));
      expect(
        labService.results.singleWhere((item) => item.testName == 'BUN').value,
        20.1,
      );
    },
  );

  testWidgets(
    'added conflicting result is visible and never silently overwrites',
    (tester) async {
      final labService = await _labService();
      final settings = await _settings();
      final initial = _mappedCandidates([_parsed('Creatinine', 1.21)]);

      await _pumpReview(
        tester,
        labService,
        settings,
        initial,
        onAddPhotos: () async => [_parsed('Creatinine', 1.19)],
      );
      await _tapAddPhotos(tester);

      expect(find.byKey(const Key('lab-capture-candidate-0')), findsOneWidget);
      expect(
        find.byKey(const Key('lab-capture-candidate-added-0-0')),
        findsOneWidget,
      );
      expect(initial.single.hasImportConflict, isTrue);
      expect(initial.single.isSelected, isFalse);
      expect(labService.results, isEmpty);
    },
  );
}

Future<void> _pumpReview(
  WidgetTester tester,
  LabResultService labService,
  LabTestSettingsService settings,
  List<LabCaptureCandidate> candidates, {
  DateTime? initialDate,
  AddLabCapturePhotos? onAddPhotos,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LabCaptureReviewScreen(
        labResultService: labService,
        labTestSettingsService: settings,
        candidates: candidates,
        initialDate: initialDate,
        onAddPhotos: onAddPhotos,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapAddPhotos(WidgetTester tester) async {
  final add = find.byKey(const Key('lab-capture-add-photos-button'));
  await tester.scrollUntilVisible(
    add,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(add);
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  final save = find.byKey(const Key('lab-capture-save-button'));
  await tester.scrollUntilVisible(
    save,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(save);
}

List<LabCaptureCandidate> _mappedCandidates(
  List<ParsedLabCaptureCandidate> parsed,
) {
  return LabCaptureMappingService(predefinedLabTestDefinitions).map(parsed);
}

ParsedLabCaptureCandidate _parsed(String name, double value) {
  return ParsedLabCaptureCandidate(
    rawTestName: name,
    value: value,
    unit: 'mg/dL',
    sourceImageIndex: 0,
  );
}

Future<LabResultService> _labService({List<LabResult>? results}) async {
  final service = LabResultService(InMemoryLabResultStorage(results));
  await service.load();
  return service;
}

Future<LabTestSettingsService> _settings() async {
  final service = LabTestSettingsService.inMemory();
  await service.load();
  return service;
}

LabResult _result(String id, DateTime date, String testName, double value) {
  final now = DateTime.now();
  return LabResult(
    id: id,
    date: date,
    testName: testName,
    value: value,
    unit: 'mg/dL',
    createdAt: now,
    updatedAt: now,
  );
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
