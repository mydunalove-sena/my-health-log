import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_health_log/core/constants/lab_test_definitions.dart';
import 'package:my_health_log/models/lab_capture_candidate.dart';
import 'package:my_health_log/models/lab_result.dart';
import 'package:my_health_log/models/lab_test_definition.dart';
import 'package:my_health_log/screens/lab/lab_capture_review_screen.dart';
import 'package:my_health_log/screens/lab/lab_screen.dart';
import 'package:my_health_log/services/lab_capture_mapping_service.dart';
import 'package:my_health_log/services/lab_image_picker_service.dart';
import 'package:my_health_log/services/lab_ocr_service.dart';
import 'package:my_health_log/services/lab_result_service.dart';
import 'package:my_health_log/services/lab_test_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

  testWidgets('mapped enabled candidate remains ready for import', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = await _profileSettings(LabManagementType.kidneyTransplant);
    final candidate = _mappedCandidates([_parsed('Creatinine', 1.21)]).single;

    await _pumpReview(tester, labService, settings, [candidate]);

    expect(candidate.isSelected, isTrue);
    expect(find.text('현재 검사 목록에 없는 항목입니다.'), findsNothing);
  });

  testWidgets(
    'mapped disabled candidate can be enabled without leaving review or saving result',
    (tester) async {
      final labService = await _labService();
      final settings = await _persistentProfileSettings(
        LabManagementType.kidneyTransplant,
      );
      final originalProfile = settings.managementType;
      final candidate = _mappedCandidates([_parsed('Total Cholesterol', 184)])
          .single;

      await _pumpReview(tester, labService, settings, [candidate]);
      expect(candidate.isSelected, isFalse);
      expect(find.text('현재 검사 목록에 없는 항목입니다.'), findsOneWidget);
      expect(find.text('Total Cholesterol'), findsWidgets);
      final checkbox = tester.widget<CheckboxListTile>(
        find.byKey(const Key('lab-capture-check-0')),
      );
      expect(checkbox.onChanged, isNotNull);

      await tester.enterText(
        find.byKey(const Key('lab-capture-value-0')),
        '185',
      );
      await tester.tap(find.byKey(const Key('lab-capture-check-0')));
      await tester.pumpAndSettle();

      expect(settings.managementType, originalProfile);
      expect(settings.enabledLabTestIds, contains('total_cholesterol'));
      expect(candidate.value, 185);
      expect(candidate.isSelected, isTrue);
      expect(find.byType(LabCaptureReviewScreen), findsOneWidget);
      expect(find.text('현재 검사 목록에 없는 항목입니다.'), findsNothing);
      expect(labService.results, isEmpty);

      final reloaded = LabTestSettingsService();
      await reloaded.load();
      expect(reloaded.managementType, originalProfile);
      expect(reloaded.enabledLabTestIds, contains('total_cholesterol'));

      await _tapSave(tester);
      await tester.pumpAndSettle();
      expect(labService.results.single.value, 185);
    },
  );

  for (final profile in [
    LabManagementType.kidneyTransplant,
    LabManagementType.dialysis,
  ]) {
    testWidgets('enable action is profile-independent for ${profile.id}', (
      tester,
    ) async {
      final labService = await _labService();
      final settings = await _profileSettings(profile);
      final candidate = _mappedCandidates([_parsed('Total Cholesterol', 180)])
          .single;

      await _pumpReview(tester, labService, settings, [candidate]);
      await tester.tap(find.byKey(const Key('lab-capture-check-0')));
      await tester.pumpAndSettle();

      expect(settings.managementType, profile);
      expect(settings.enabledLabTestIds, contains('total_cholesterol'));
      expect(candidate.isSelected, isTrue);
      expect(labService.results, isEmpty);
    });
  }

  testWidgets('unmapped exact alias auto-links and enables on checkbox tap', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = await _profileSettings(LabManagementType.custom);
    final candidate = _unmappedCandidate('Total Protein(E)', 8, unit: 'g/dL');

    await _pumpReview(tester, labService, settings, [candidate]);
    expect(candidate.definition, isNull);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('lab-capture-check-manual')),
          )
          .onChanged,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('lab-capture-check-manual')));
    await tester.pumpAndSettle();

    expect(candidate.definition?.id, 'total_protein');
    expect(settings.enabledLabTestIds, contains('total_protein'));
    expect(candidate.isSelected, isTrue);
    expect(candidate.value, 8);
    expect(candidate.saveUnit, 'g/dL');
    expect(labService.results, isEmpty);
  });

  testWidgets('ambiguous OCR label requires explicit candidate selection', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = await _profileSettings(LabManagementType.custom);
    final candidate = _unmappedCandidate('Cholesterol', 180);

    await _pumpReview(tester, labService, settings, [candidate]);
    await tester.tap(find.byKey(const Key('lab-capture-check-manual')));
    await tester.pumpAndSettle();

    expect(find.text('검사 항목을 선택해 주세요'), findsOneWidget);
    expect(candidate.definition, isNull);
    expect(settings.enabledLabTestIds, isEmpty);

    await tester.tap(
      find.byKey(const Key('lab-capture-match-total_cholesterol')),
    );
    await tester.pumpAndSettle();

    expect(candidate.definition?.id, 'total_cholesterol');
    expect(settings.enabledLabTestIds, contains('total_cholesterol'));
    expect(candidate.isSelected, isTrue);
  });

  testWidgets('search requires explicit selection and confirmation', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = await _profileSettings(LabManagementType.custom);
    final candidate = _unmappedCandidate('Unknown Marker', 9);

    await _pumpReview(tester, labService, settings, [candidate]);
    await tester.tap(find.byKey(const Key('lab-capture-check-manual')));
    await tester.pumpAndSettle();

    final search = tester.widget<TextField>(
      find.byKey(const Key('lab-capture-definition-search')),
    );
    expect(search.controller!.text, 'Unknown Marker');
    expect(candidate.definition, isNull);
    expect(find.byKey(const Key('lab-capture-search-cancel')), findsOneWidget);
    expect(find.byKey(const Key('lab-capture-search-confirm')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('lab-capture-search-confirm')),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('lab-capture-definition-search')),
      'Creatinine',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lab-capture-search-creatinine')));
    await tester.pump();

    expect(candidate.definition, isNull);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('lab-capture-search-confirm')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('lab-capture-search-confirm')));
    await tester.pumpAndSettle();

    expect(candidate.definition?.id, 'creatinine');
    expect(settings.enabledLabTestIds, contains('creatinine'));
    expect(candidate.isSelected, isTrue);
    expect(candidate.value, 9);
    expect(labService.results, isEmpty);
  });

  testWidgets('search cancellation leaves candidate and settings unchanged', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = await _profileSettings(LabManagementType.dialysis);
    final originalProfile = settings.managementType;
    final originalEnabledIds = settings.enabledLabTestIds;
    final candidate = _unmappedCandidate('Unknown Marker', 9, unit: 'IU/L');

    await _pumpReview(tester, labService, settings, [candidate]);
    await tester.tap(find.byKey(const Key('lab-capture-check-manual')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('lab-capture-definition-search')),
      'Creatinine',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lab-capture-search-creatinine')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('lab-capture-search-cancel')));
    await tester.pumpAndSettle();

    expect(candidate.definition, isNull);
    expect(candidate.isSelected, isFalse);
    expect(candidate.value, 9);
    expect(candidate.ocrUnit, 'IU/L');
    expect(settings.enabledLabTestIds, originalEnabledIds);
    expect(settings.managementType, originalProfile);
    expect(labService.results, isEmpty);
  });

  testWidgets('orphan OCR value is excluded even when marked selected', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = await _settings();
    final valid = _mappedCandidates([_parsed('BUN', 19.4)]).single;
    final orphan = _unmappedCandidate('', 174, unit: 'mg/dL');

    await _pumpReview(tester, labService, settings, [valid, orphan]);
    expect(orphan.isSelected, isFalse);
    expect(find.text('검사 항목을 인식하지 못했습니다. 저장에서 제외됩니다.'), findsOneWidget);

    orphan.isSelected = true;
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(labService.results, hasLength(1));
    expect(labService.results.single.testName, 'BUN');
    expect(labService.results.single.value, 19.4);
    expect(labService.results.single.value, isNot(174));
  });

  testWidgets('orphan OCR value is savable after explicit mapping confirm', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = await _profileSettings(LabManagementType.kidneyTransplant);
    final originalProfile = settings.managementType;
    final candidate = _unmappedCandidate('', 174, unit: 'mg/dL');

    await _pumpReview(tester, labService, settings, [candidate]);
    await tester.tap(find.byKey(const Key('lab-capture-check-manual')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('lab-capture-definition-search')),
      'Creatinine',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lab-capture-search-creatinine')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('lab-capture-search-confirm')));
    await tester.pumpAndSettle();

    expect(candidate.definition?.id, 'creatinine');
    expect(candidate.displayName, 'Creatinine');
    expect(candidate.value, 174);
    expect(candidate.ocrUnit, 'mg/dL');
    expect(candidate.isSelected, isTrue);
    expect(settings.enabledLabTestIds, contains('creatinine'));
    expect(settings.managementType, originalProfile);
    expect(labService.results, isEmpty);

    await _tapSave(tester);
    await tester.pumpAndSettle();
    expect(labService.results, hasLength(1));
    expect(labService.results.single.testName, 'Creatinine');
    expect(labService.results.single.value, 174);
  });

  testWidgets('multiple disabled candidates are enabled independently', (
    tester,
  ) async {
    final labService = await _labService();
    final settings = await _profileSettings(LabManagementType.custom);
    final candidates = _mappedCandidates([
      _parsed('Creatinine', 1.1),
      _parsed('Albumin', 4.2),
    ]);

    await _pumpReview(tester, labService, settings, candidates);
    await tester.tap(find.byKey(const Key('lab-capture-check-0')));
    await tester.pumpAndSettle();

    expect(settings.enabledLabTestIds, contains('creatinine'));
    expect(settings.enabledLabTestIds, isNot(contains('albumin')));
    expect(candidates[1].value, 4.2);
    expect(candidates, hasLength(2));
    expect(candidates[1].isSelected, isFalse);
    expect(labService.results, isEmpty);
  });

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
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
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

LabCaptureCandidate _unmappedCandidate(
  String name,
  double value, {
  String? unit = 'mg/dL',
}) {
  return LabCaptureCandidate(
    id: 'manual',
    rawTestName: name,
    value: value,
    ocrUnit: unit,
    sourceImageIndices: const [0],
    mappingStatus: LabCaptureMappingStatus.unmapped,
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
  await service.setEnabledLabTestIds([
    for (final definition in predefinedLabTestDefinitions) definition.id,
  ]);
  return service;
}

Future<LabTestSettingsService> _profileSettings(
  LabManagementType profile,
) async {
  final service = LabTestSettingsService.inMemory();
  await service.load();
  await service.setManagementType(profile);
  return service;
}

Future<LabTestSettingsService> _persistentProfileSettings(
  LabManagementType profile,
) async {
  final service = LabTestSettingsService();
  await service.load();
  await service.setManagementType(profile);
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
