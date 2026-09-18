import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_health_log/core/constants/lab_test_definitions.dart';
import 'package:my_health_log/models/lab_capture_candidate.dart';
import 'package:my_health_log/models/lab_result.dart';
import 'package:my_health_log/models/lab_test_definition.dart';
import 'package:my_health_log/services/lab_capture_mapping_service.dart';
import 'package:my_health_log/services/lab_test_settings_service.dart';

// User-confirmed HOSPITAL SCREENSHOT GROUND TRUTH (2026-09-18).
// [hospital label, hospital unit, existing/new ID, app canonical unit].
// Existing WBC/Platelet scale notation stays unchanged for stored-row safety.
const hospitalGroundTruth = [
  ['WBC COUNT(백혈구수)', '10^3/µL', 'wbc', '×10³/µL'],
  ['RBC COUNT(적혈구수)', '10^6/µL', 'rbc', '10^6/µL'],
  ['Hemoglobin(혈색소)', 'g/dL', 'hemoglobin', 'g/dL'],
  ['Hct(적혈구 용적율)', '%', 'hematocrit', '%'],
  ['PLT Count(혈소판수)', '10^3/µL', 'platelet', '×10³/µL'],
  ['Neutrophil(#)(중성구)', '10^3/µL', 'neutrophil_absolute', '10^3/µL'],
  ['Calcium(칼슘)', 'mg/dL', 'calcium', 'mg/dL'],
  ['Inorganic P(인)', 'mg/dL', 'phosphorus', 'mg/dL'],
  ['Glucose(혈당)', 'mg/dL', 'glucose', 'mg/dL'],
  ['BUN(혈액요소질소)', 'mg/dL', 'bun', 'mg/dL'],
  ['Creatinine(크레아티닌)', 'mg/dL', 'creatinine', 'mg/dL'],
  ['Uric Acid(요산)', 'mg/dL', 'uric_acid', 'mg/dL'],
  ['Total cholesterol(총콜레스테롤)', 'mg/dL', 'total_cholesterol', 'mg/dL'],
  ['Total Protein(총 단백)', 'g/dL', 'total_protein', 'g/dL'],
  ['Albumin(알부민)', 'g/dL', 'albumin', 'g/dL'],
  ['Alk. Phos(알칼리인산분해효소)', 'IU/L', 'alp', 'IU/L'],
  ['AST(GOT)(아스파르테이트아미노전이효소)', 'IU/L', 'ast', 'IU/L'],
  ['ALT(GPT)(알라닌아미노전이효소)', 'IU/L', 'alt', 'IU/L'],
  ['T. Bilirubin(총 빌리루빈)', 'mg/dL', 'total_bilirubin', 'mg/dL'],
  ['Triglyceride(중성지방)', 'mg/dL', 'triglyceride', 'mg/dL'],
  ['HDL-Cholesterol(고밀도지단백콜레스테롤검사)', 'mg/dL', 'hdl', 'mg/dL'],
  ['Na(나트륨)', 'mmol/L', 'sodium', 'mmol/L'],
  ['K(칼륨)', 'mmol/L', 'potassium', 'mmol/L'],
  ['Cl(염화물)', 'mmol/L', 'chloride', 'mmol/L'],
  ['tCO2(총이산화탄소)', 'mmol/L', 'tco2', 'mmol/L'],
  ['Cystatin C(시스타틴 C 검사)', 'mg/L', 'cystatin_c', 'mg/L'],
  ['Tacrolimus (FK-506)(타크로리무스)', 'ng/mL', 'tacrolimus', 'ng/mL'],
];

// Names/units observed in the prior runtime log; synthetic IDs only.
// These are upgrade fixtures, NOT newly approved aliases or metadata edits.
const legacyCustoms = [
  LabTestDefinition(
    id: 'custom-rbc',
    displayName: 'RBC COUNT(적혈구수)',
    defaultUnit: '10^6/uL',
  ),
  LabTestDefinition(
    id: 'custom-hct',
    displayName: 'Hct(적혈구 용적율)',
    defaultUnit: '%',
  ),
  LabTestDefinition(
    id: 'custom-plt',
    displayName: 'PLT COunt(혈소판수)',
    defaultUnit: '10^3/uL',
  ),
  LabTestDefinition(
    id: 'custom-tco2',
    displayName: 'tCO2(총산화탄소)',
    defaultUnit: 'mmol/L',
  ),
  LabTestDefinition(id: 'custom-neutrophil', displayName: 'Neutrophil(#)(중성구)'),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'all 32 legacy identities, display names, units and order are preserved',
    () {
      const legacy = [
        ['creatinine', 'Creatinine', 'mg/dL'],
        ['bun', 'BUN', 'mg/dL'],
        ['egfr', 'eGFR', 'mL/min/1.73m²'],
        ['sodium', 'Na(나트륨)', 'mmol/L'],
        ['potassium', 'K(칼륨)', 'mmol/L'],
        ['chloride', 'Cl(염소)', 'mmol/L'],
        ['calcium', 'Ca(칼슘)', 'mg/dL'],
        ['phosphorus', 'P(인)', 'mg/dL'],
        ['magnesium', 'Mg(마그네슘)', 'mg/dL'],
        ['albumin', 'Albumin', 'g/dL'],
        ['total_protein', 'Total Protein', 'g/dL'],
        ['wbc', 'WBC', '×10³/µL'],
        ['hemoglobin', 'Hemoglobin', 'g/dL'],
        ['platelet', 'Platelet', '×10³/µL'],
        ['ast', 'AST(GOT)', 'IU/L'],
        ['alt', 'ALT(GPT)', 'IU/L'],
        ['alp', 'ALP', 'IU/L'],
        ['ggt', 'GGT', 'IU/L'],
        ['total_bilirubin', 'Total Bilirubin', 'mg/dL'],
        ['glucose', 'Glucose', 'mg/dL'],
        ['hba1c', 'HbA1c', '%'],
        ['total_cholesterol', 'Total Cholesterol', 'mg/dL'],
        ['ldl', 'LDL Cholesterol', 'mg/dL'],
        ['hdl', 'HDL Cholesterol', 'mg/dL'],
        ['triglyceride', 'Triglyceride', 'mg/dL'],
        ['uric_acid', 'Uric Acid', 'mg/dL'],
        ['tacrolimus', 'Tacrolimus', 'ng/mL'],
        ['amylase', 'Amylase', 'U/L'],
        ['lipase', 'Lipase', 'U/L'],
        ['pth', 'Intact PTH', 'pg/mL'],
        ['ktv', 'Kt/V', null],
        ['urr', 'URR', '%'],
      ];
      expect(
        predefinedLabTestDefinitions
            .take(32)
            .map((d) => [d.id, d.displayName, d.defaultUnit])
            .toList(),
        legacy,
      );
    },
  );

  for (final row in hospitalGroundTruth) {
    test('hospital definition, bilingual resolver and unit: ${row[2]}', () {
      final mapper = LabCaptureMappingService(predefinedLabTestDefinitions);
      final definition = predefinedLabTestDefinitions.singleWhere(
        (d) => d.id == row[2],
      );
      expect(mapper.matchDefinition(row[0]), same(definition));
      expect(definition.defaultUnit, row[3]);
      // Explicitly document the ONLY two representation-equivalent exceptions.
      expect(
        row[3],
        row[1] == '10^3/µL' && ['wbc', 'platelet'].contains(row[2])
            ? '×10³/µL'
            : row[1],
      );
      final candidate = mapper.map([
        ParsedLabCaptureCandidate(
          rawTestName: row[0],
          value: 1,
          unit: row[1],
          sourceImageIndex: 0,
        ),
      ]).single;
      expect(candidate.definition, same(definition));
      expect(candidate.rawTestName, row[0]);
      expect(candidate.ocrUnit, row[1]);
      expect(candidate.saveUnit, row[3]);
      expect(mapper.canonicalKeyForName(row[0]), 'def:${row[2]}');
    });

    test(
      'shared custom validation rejects hospital duplicate: ${row[2]}',
      () async {
        final settings = LabTestSettingsService.inMemory();
        final before = settings.enabledLabTestIds;
        await expectLater(
          settings.addCustomDefinition(
            displayName: row[0],
            defaultUnit: row[1],
          ),
          throwsA(isA<DuplicateLabTestDefinitionException>()),
        );
        expect(settings.customDefinitions, isEmpty);
        expect(settings.enabledLabTestIds, before);
      },
    );
  }

  for (final legacy in legacyCustoms) {
    test(
      'legacy collision stays ambiguous and exact saved identity survives: ${legacy.id}',
      () {
        final definitions = [...predefinedLabTestDefinitions, legacy];
        for (final ordered in [definitions, definitions.reversed.toList()]) {
          final mapper = LabCaptureMappingService(ordered);
          final candidate = mapper.map([
            ParsedLabCaptureCandidate(
              rawTestName: legacy.displayName,
              value: 5,
              unit: legacy.defaultUnit,
              sourceImageIndex: 0,
            ),
          ]).single;
          expect(candidate.definition, isNull);
          expect(candidate.isSelected, isFalse);
          expect(
            mapper.canonicalKeyForName(legacy.displayName),
            startsWith('raw:'),
          );
          final now = DateTime(2026, 9, 18);
          final stored = LabResult(
            id: 'old-row',
            date: now,
            testName: legacy.displayName,
            value: 5,
            unit: legacy.defaultUnit,
            createdAt: now,
            updatedAt: now,
          );
          candidate.mapTo(
            legacy,
          ); // Explicit user choice, NOT automatic priority.
          candidate.existingResult = mapper.existingForCandidate(candidate, [
            stored,
          ]);
          expect(candidate.existingResult, same(stored));
          expect(candidate.hasExistingSameValue, isTrue);
          candidate.value = 6;
          expect(candidate.hasExistingConflict, isTrue);
          final update = candidate.toLabResult(now, now);
          expect(update.id, 'old-row');
          expect(update.testName, legacy.displayName);
          expect(update.unit, legacy.defaultUnit);
        }
      },
    );
  }

  test('legacy settings load/export/restore preserves all custom metadata and enabled IDs', () async {
    final original = LabTestSettingsBackup(
      managementType: LabManagementType.dialysis,
      enabledLabTestIds: ['urr', ...legacyCustoms.map((d) => d.id)],
      customDefinitions: legacyCustoms,
    );
    SharedPreferences.setMockInitialValues({
      LabTestSettingsService.managementTypeKey: original.managementType.id,
      LabTestSettingsService.enabledLabTestIdsKey: original.enabledLabTestIds,
      LabTestSettingsService.customLabDefinitionsKey: jsonEncode(
        legacyCustoms.map((d) => d.toJson()).toList(),
      ),
    });
    final settings = LabTestSettingsService();
    await settings.load();
    expect(settings.exportBackup().toJson(), original.toJson());
    expect(settings.allDefinitions, hasLength(37 + legacyCustoms.length));
    for (final legacy in legacyCustoms) {
      await expectLater(
        settings.addCustomDefinition(displayName: legacy.displayName),
        throwsA(isA<DuplicateLabTestDefinitionException>()),
      );
    }
    final restored = LabTestSettingsService.inMemory();
    await restored.applyBackup(
      LabTestSettingsBackup.fromJson(settings.exportBackup().toJson()),
    );
    expect(restored.exportBackup().toJson(), original.toJson());
  });

  for (final id in [
    'rbc',
    'hematocrit',
    'neutrophil_absolute',
    'tco2',
    'cystatin_c',
  ]) {
    test(
      'backup accepts a legacy custom with newly predefined exact name: $id',
      () async {
        final definition = predefinedLabTestDefinitions.singleWhere(
          (d) => d.id == id,
        );
        final payload = LabTestSettingsBackup(
          managementType: LabManagementType.custom,
          enabledLabTestIds: ['custom-legacy-$id'],
          customDefinitions: [
            LabTestDefinition(
              id: 'custom-legacy-$id',
              displayName: definition.displayName,
            ),
          ],
        ).toJson();
        final validated = LabTestSettingsBackup.fromJson(payload);
        expect(validated.toJson(), payload);
        final settings = LabTestSettingsService.inMemory();
        await settings.applyBackup(validated);
        expect(settings.exportBackup().toJson(), payload);
        expect(
          LabCaptureMappingService(settings.allDefinitions)
              .matchDefinition(definition.displayName),
          isNull,
        );
      },
    );
  }

  test('restore still rejects invalid or duplicate custom identities', () {
    for (final definitions in [
      [const LabTestDefinition(id: 'tco2', displayName: 'Other')],
      [const LabTestDefinition(id: 'custom-x', displayName: '')],
      [
        const LabTestDefinition(id: 'custom-x', displayName: 'One'),
        const LabTestDefinition(id: 'custom-x', displayName: 'Two'),
      ],
      [
        const LabTestDefinition(id: 'custom-x', displayName: 'One'),
        const LabTestDefinition(id: 'custom-y', displayName: ' one '),
      ],
    ]) {
      expect(
        () => LabTestSettingsBackup.fromJson(
          LabTestSettingsBackup(
            managementType: LabManagementType.custom,
            enabledLabTestIds: [],
            customDefinitions: definitions,
          ).toJson(),
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'meaningful qualifiers and similar unknown labels remain distinct',
    () async {
      final mapper = LabCaptureMappingService(predefinedLabTestDefinitions);
      for (final name in [
        'Neutrophil(%)',
        'Neutrophil',
        'RBC COUNT Extra(검사)',
        'tCO20(검사)',
        'Tacrolimus(FK-507)(검사)',
      ]) {
        expect(mapper.matchDefinition(name), isNull);
      }
      final settings = LabTestSettingsService.inMemory();
      final distinct = await settings.addCustomDefinition(
        displayName: 'Neutrophil(%)',
        defaultUnit: '%',
      );
      expect(distinct.defaultUnit, '%');
      expect(settings.customDefinitions.single.id, distinct.id);
    },
  );

  test('new definitions are opt-in and do not alter management presets', () {
    expect(predefinedLabTestDefinitions, hasLength(37));
    expect(predefinedLabTestDefinitions[31].id, 'urr');
    for (final preset in defaultLabTestIdsByManagementType.values) {
      expect(
        preset.toSet().intersection({
          'rbc',
          'hematocrit',
          'neutrophil_absolute',
          'tco2',
          'cystatin_c',
        }),
        isEmpty,
      );
    }
  });
}
