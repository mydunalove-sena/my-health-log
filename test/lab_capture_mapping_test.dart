import 'package:flutter_test/flutter_test.dart';
import 'package:my_health_log/core/constants/lab_test_definitions.dart';
import 'package:my_health_log/models/lab_capture_candidate.dart';
import 'package:my_health_log/models/lab_result.dart';
import 'package:my_health_log/models/lab_test_definition.dart';
import 'package:my_health_log/services/lab_capture_mapping_service.dart';

void main() {
  late LabCaptureMappingService service;

  setUp(() {
    service = LabCaptureMappingService(predefinedLabTestDefinitions);
  });

  test('maps approved Severance names', () {
    final cases = {
      'Calcium(칼슘)': 'calcium',
      'Inorganic P(인)': 'phosphorus',
      'Glucose(혈당)': 'glucose',
      'BUN(혈액요소질소)': 'bun',
      'Creatinine(크레아티닌)': 'creatinine',
      'Uric Acid(요산)': 'uric_acid',
      'Total cholesterol(총콜레스테롤)': 'total_cholesterol',
      'Total Protein(E)': 'total_protein',
      'Total Protein(총 단백)': 'total_protein',
      'Alk. Phos(알칼리인산분해효소)': 'alp',
      'AST(GOT)(아스파르테이트아미노전이효소)': 'ast',
    };

    for (final entry in cases.entries) {
      expect(service.matchDefinition(entry.key)?.id, entry.value);
    }
  });

  test(
    'reported balanced Alk. Phos label already resolves with approved data',
    () {
      for (final name in ['Alk. Phos', 'Alk. Phos(알칼리인산분해효소)']) {
        final definition = service.matchDefinition(name);
        expect(definition?.id, 'alp');
        expect(definition?.displayName, 'ALP');
        expect(definition?.defaultUnit, 'IU/L');
      }
    },
  );

  test('maps exact and balanced bilingual names without prefix matching', () {
    expect(service.matchDefinition('Albumin')?.id, 'albumin');
    expect(service.matchDefinition('AST(GOT) (아스파르테이트)')?.id, 'ast');
    expect(service.matchDefinition('Alk. Phos (알칼리)')?.id, 'alp');
    expect(service.matchDefinition('AST(GOT) (아스파르테이트'), isNull);
    expect(service.matchDefinition('Alk. Phos (알칼리'), isNull);
  });

  for (final definition in predefinedLabTestDefinitions) {
    test('resolves predefined displayName ${definition.id}', () {
      expect(
        service.matchDefinition(definition.displayName)?.id,
        definition.id,
      );
      expect(
        service.canonicalKeyForName(definition.displayName),
        'def:${definition.id}',
      );
    });
  }

  for (final alias in LabCaptureMappingService.explicitAliases.entries) {
    test('resolves approved alias ${alias.key}', () {
      expect(service.matchDefinition(alias.key)?.id, alias.value);
      expect(service.canonicalKeyForName(alias.key), 'def:${alias.value}');
    });
  }

  final bilingualCases = {
    'Triglyceride(중성지방)': 'triglyceride',
    'HDL-Cholesterol (고밀도지단백콜레스테롤검사)': 'hdl',
    'AST(GOT) (아스파르테이트아미노전이효소)': 'ast',
    'Alk. Phos (알칼리인산분해효소검사)': 'alp',
    'ALT(GPT)(검사)': 'alt',
    'Hemoglobin(혈색소)': 'hemoglobin',
    'HbA1c(당화혈색소)': 'hba1c',
    'Kt/V(투석적절도)': 'ktv',
    'Na': 'sodium',
    'Calcium': 'calcium',
    'Inorganic P': 'phosphorus',
    'Total Protein( E)': 'total_protein',
    '  TOTAL\n Protein \t( E )  ': 'total_protein',
    '  HDL-Cholesterol \n( 고밀도지단백콜레스테롤검사 ) ': 'hdl',
  };
  for (final entry in bilingualCases.entries) {
    test('resolves common comparison variants: ${entry.key}', () {
      final parsed = _parsed(entry.key, 65, 0);
      final mapped = service.map([parsed]).single;
      expect(mapped.definition?.id, entry.value);
      expect(service.canonicalKeyForName(entry.key), 'def:${entry.value}');
      expect(parsed.rawTestName, entry.key);
      expect(mapped.rawTestName, entry.key);
      expect(mapped.value, 65);
    });
  }

  for (final unknown in [
    '',
    '164',
    'Unknown Test(알수없는검사)',
    'TriglyceridesSomething(중성지방)',
    'HDLCholesterol(검사)',
    'KtV',
    'AST(GOT)unexpected',
    'Alk. Phos unexpected',
    'Triglyceride(중성지방',
    'Triglyceride)중성지방(',
    'Triglyceride((중성지방))',
    '(중성지방)',
    'Triglyceride(중성지방) extra',
    'Triglyceride(E)',
  ]) {
    test('does not guess unknown or malformed name: $unknown', () {
      expect(service.matchDefinition(unknown), isNull);
      expect(service.canonicalKeyForName(unknown), startsWith('raw:'));
    });
  }

  test('preserves meaningful non-Hangul parentheses and punctuation', () {
    final synthetic = LabCaptureMappingService(const [
      LabTestDefinition(id: 'base', displayName: 'Marker'),
      LabTestDefinition(id: 'qualified', displayName: 'Marker(E)'),
      LabTestDefinition(id: 'hyphen', displayName: 'Marker-A'),
      LabTestDefinition(id: 'slash', displayName: 'Marker/A'),
    ]);
    expect(synthetic.matchDefinition('Marker( E )')?.id, 'qualified');
    expect(synthetic.matchDefinition('Marker(E)(검사)')?.id, 'qualified');
    expect(synthetic.matchDefinition('Marker(X)'), isNull);
    expect(synthetic.matchDefinition('MarkerA'), isNull);
    expect(service.matchDefinition('AST(GOT)')?.id, 'ast');
    expect(service.matchDefinition('AST'), isNull);
    expect(service.matchDefinition('Total Protein(E)')?.id, 'total_protein');
    final withoutAliasTarget = LabCaptureMappingService(const [
      LabTestDefinition(id: 'custom-protein', displayName: 'Total Protein'),
    ]);
    expect(withoutAliasTarget.matchDefinition('Total Protein(E)'), isNull);
    expect(
      withoutAliasTarget.canonicalKeyForName('Total Protein(E)'),
      'raw:total protein(e)',
    );
  });

  test('normalizes definition and OCR sides with the same contract', () {
    final synthetic = LabCaptureMappingService(const [
      LabTestDefinition(
        id: 'marker',
        displayName: '  Synthetic \n Marker ( 한글 ) ',
      ),
    ]);
    for (final input in ['synthetic marker', 'SYNTHETIC\tMARKER(한글)']) {
      expect(synthetic.matchDefinition(input)?.id, 'marker');
    }
  });

  test(
    'rejects distinct IDs sharing exact or variant keys in either order',
    () {
      for (final secondName in ['Synthetic', 'Synthetic(한글)']) {
        final definitions = [
          const LabTestDefinition(id: 'one', displayName: 'Synthetic'),
          LabTestDefinition(id: 'two', displayName: secondName),
        ];
        for (final order in [definitions, definitions.reversed.toList()]) {
          final resolver = LabCaptureMappingService(order);
          for (final input in ['Synthetic', 'Synthetic(한글)']) {
            expect(resolver.matchDefinition(input), isNull);
            expect(resolver.canonicalKeyForName(input), startsWith('raw:'));
            final candidate = resolver.map([_parsed(input, 1, 0)]).single;
            expect(candidate.definition, isNull);
            expect(candidate.isSelected, isFalse);
          }
        }
      }
    },
  );

  test('approved alias and custom displayName collision is ambiguous', () {
    final definitions = [
      ...predefinedLabTestDefinitions,
      const LabTestDefinition(id: 'custom-hdl', displayName: 'HDL-Cholesterol'),
    ];
    for (final order in [definitions, definitions.reversed.toList()]) {
      final resolver = LabCaptureMappingService(order);
      for (final name in ['HDL-Cholesterol', 'HDL-Cholesterol(한글)']) {
        expect(resolver.matchDefinition(name), isNull);
        expect(resolver.canonicalKeyForName(name), startsWith('raw:'));
      }
    }
  });

  test(
    'missing alias target never falls back to a different displayName ID',
    () {
      final resolver = LabCaptureMappingService(const [
        LabTestDefinition(id: 'custom-alp', displayName: 'alp'),
      ]);
      expect(resolver.matchDefinition('Alk. Phos'), isNull);
      expect(resolver.canonicalKeyForName('Alk. Phos'), 'raw:alk. phos');
    },
  );

  test('multiple alias and variant hits for one ID remain unique', () {
    for (final name in ['Total Protein(총 단백)', 'AST(GOT)(검사)', 'Calcium(칼슘)']) {
      expect(service.matchDefinition(name), isNotNull);
    }
    final resolver = LabCaptureMappingService(const [
      LabTestDefinition(id: 'same', displayName: 'Synthetic'),
      LabTestDefinition(id: 'same', displayName: 'Synthetic(한글)'),
    ]);
    expect(resolver.matchDefinition('Synthetic(한글)')?.id, 'same');
  });

  test(
    'bilingual identity is shared by import and existing-result comparison',
    () {
      final mapped = service.map(
        [
          _parsed('Triglyceride(중성지방)', 164, 0),
          _parsed('Triglyceride', 164, 1),
        ],
        existingResults: [_result('Triglyceride', 164)],
      );
      expect(mapped, hasLength(1));
      expect(mapped.single.sourceImageIndices, [0, 1]);
      expect(mapped.single.hasExistingSameValue, isTrue);
      expect(mapped.single.isSelected, isFalse);
      final conflicts = service.map([
        _parsed('HDL-Cholesterol(검사)', 65, 0),
        _parsed('HDL Cholesterol', 66, 1),
      ]);
      expect(conflicts.every((item) => item.hasImportConflict), isTrue);
      expect(conflicts.every((item) => !item.isSelected), isTrue);
    },
  );

  test('leaves fuzzy-like unknown names unmapped', () {
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
