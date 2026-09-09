import 'package:flutter_test/flutter_test.dart';
import 'package:my_health_log/core/constants/lab_test_definitions.dart';
import 'package:my_health_log/models/lab_capture_candidate.dart';
import 'package:my_health_log/models/lab_result.dart';
import 'package:my_health_log/services/lab_capture_mapping_service.dart';

void main() {
  late LabCaptureMappingService service;

  setUp(() {
    service = LabCaptureMappingService(predefinedLabTestDefinitions);
  });

  test('maps Severance names through explicit aliases only', () {
    final cases = {
      'Calcium(칼슘)': 'calcium',
      'Inorganic P(인)': 'phosphorus',
      'Glucose(혈당)': 'glucose',
      'BUN(혈액요소질소)': 'bun',
      'Creatinine(크레아티닌)': 'creatinine',
      'Uric Acid(요산)': 'uric_acid',
      'Total cholesterol(총콜레스테롤)': 'total_cholesterol',
      'Alk. Phos(알칼리인산분해효소)': 'alp',
      'AST(GOT)(아스파르테이트아미노전이효소)': 'ast',
    };

    for (final entry in cases.entries) {
      expect(service.matchDefinition(entry.key)?.id, entry.value);
    }
  });

  test('maps exact names and approved English anchors', () {
    expect(service.matchDefinition('Albumin')?.id, 'albumin');
    expect(service.matchDefinition('AST(GOT) (아스파르테이트')?.id, 'ast');
    expect(service.matchDefinition('Alk. Phos (알칼리')?.id, 'alp');
  });

  test('leaves Total Protein and fuzzy-like unknown names unmapped', () {
    expect(service.matchDefinition('Total Protein(총 단백)'), isNull);
    expect(service.matchDefinition('Creatin'), isNull);
    expect(service.matchDefinition('Inorganic Phosphorus'), isNull);
    expect(service.matchDefinition('Protein Albumin'), isNull);
  });

  test('deduplicates same multi-image value and flags conflicts', () {
    final deduped = service.map([
      _parsed('BUN(혈액요소질소)', 19.4, 0),
      _parsed('BUN(혈액요소질소)', 19.4, 1),
    ]);
    expect(deduped, hasLength(1));
    expect(deduped.single.sourceImageIndices, [0, 1]);
    expect(deduped.single.hasImportConflict, isFalse);

    final conflicted = service.map([
      _parsed('BUN(혈액요소질소)', 19.4, 0),
      _parsed('BUN(혈액요소질소)', 18.2, 1),
    ]);
    expect(conflicted, hasLength(2));
    expect(conflicted.every((item) => item.hasImportConflict), isTrue);
    expect(conflicted.every((item) => item.isSelected), isFalse);
  });

  test('deduplicates same mapped value when one OCR unit is missing', () {
    final deduped = service.map([
      _parsed('BUN', 19.4, 0, unit: null),
      _parsed('BUN', 19.4, 1),
    ]);

    expect(deduped, hasLength(1));
    expect(deduped.single.definition?.id, 'bun');
    expect(deduped.single.ocrUnit, 'mg/dL');
    expect(deduped.single.sourceImageIndices, [0, 1]);
    expect(deduped.single.hasImportConflict, isFalse);
  });

  test('deduplicates approved alias names in one import batch', () {
    final deduped = service.map([
      _parsed('Inorganic P(인)', 2.1, 0),
      _parsed('P(인)', 2.1, 1),
    ]);

    expect(deduped, hasLength(1));
    expect(deduped.single.definition?.id, 'phosphorus');
    expect(deduped.single.sourceImageIndices, [0, 1]);
    expect(deduped.single.hasImportConflict, isFalse);
  });

  test('uses approved aliases for existing row same value and conflicts', () {
    final same = service.map(
      [_parsed('P(인)', 2.1, 0)],
      existingResults: [_result('Inorganic P(인)', 2.1)],
    );
    expect(same.single.existingResult?.testName, 'Inorganic P(인)');
    expect(same.single.hasExistingSameValue, isTrue);
    expect(same.single.isSelected, isFalse);

    final changed = service.map(
      [_parsed('P(인)', 2.1, 0)],
      existingResults: [_result('Inorganic P(인)', 2.0)],
    );
    expect(changed.single.existingResult?.testName, 'Inorganic P(인)');
    expect(changed.single.hasExistingConflict, isTrue);
    expect(changed.single.isSelected, isTrue);
  });

  test('uses approved HDL aliases for existing row comparison', () {
    final same = service.map(
      [_parsed('HDL Cholesterol', 62, 0)],
      existingResults: [_result('HDL-Cholesterol', 62)],
    );

    expect(same.single.definition?.id, 'hdl');
    expect(same.single.existingResult?.testName, 'HDL-Cholesterol');
    expect(same.single.hasExistingSameValue, isTrue);
    expect(same.single.isSelected, isFalse);
  });

  test('marks existing same value and existing conflict', () {
    final same = service.map(
      [_parsed('BUN(혈액요소질소)', 19.4, 0)],
      existingResults: [_result('BUN', 19.4)],
    );
    expect(same.single.hasExistingSameValue, isTrue);
    expect(same.single.isSelected, isFalse);

    final changed = service.map(
      [_parsed('BUN(혈액요소질소)', 19.4, 0)],
      existingResults: [_result('BUN', 18.2)],
    );
    expect(changed.single.hasExistingConflict, isTrue);
    expect(changed.single.isSelected, isTrue);
  });
}

ParsedLabCaptureCandidate _parsed(
  String name,
  double value,
  int imageIndex, {
  String? unit = 'mg/dL',
}) {
  return ParsedLabCaptureCandidate(
    rawTestName: name,
    value: value,
    unit: unit,
    sourceImageIndex: imageIndex,
  );
}

LabResult _result(String testName, double value) {
  final now = DateTime.now();
  return LabResult(
    id: 'existing-$testName',
    date: DateTime(now.year, now.month, now.day),
    testName: testName,
    value: value,
    unit: 'mg/dL',
    createdAt: now,
    updatedAt: now,
  );
}
