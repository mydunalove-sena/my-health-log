import 'package:flutter_test/flutter_test.dart';
import 'package:my_health_log/core/constants/lab_test_definitions.dart';
import 'package:my_health_log/models/lab_capture_candidate.dart';
import 'package:my_health_log/services/lab_capture_mapping_service.dart';
import 'package:my_health_log/services/severance_lab_ocr_parser.dart';

void main() {
  const parser = SeveranceLabOcrParser();

  test('runtime Na and K retain their labels and mmol/L units', () {
    final parsed = parser.parse([_runtimeDocument()]);
    final sodium = parsed.singleWhere((item) => item.value == 136);
    final potassium = parsed.singleWhere((item) => item.value == 4.5);
    expect(sodium.rawTestName, 'Na(나트륨)');
    expect(potassium.rawTestName, 'K(칼륨)');
    expect(sodium.unit, 'mmol/L');
    expect(potassium.unit, 'mmol/L');
    expect(parsed.any((item) => item.rawTestName == '(mmol/L)K(칼륨)'), isFalse);
  });

  test('runtime HDL head and tail still join after continuation guards', () {
    final parsed = parser.parse([_runtimeDocument()]);
    final hdl = parsed.singleWhere((item) => item.value == 65);
    expect(hdl.rawTestName, 'HDL-Cholesterol (고밀도지단백콜레스테롤검사)');
    expect(hdl.unit, 'mg/dL');
  });

  test(
    'complete runtime capture maps all four labels without changing values',
    () {
      final parsed = parser.parse([_runtimeDocument()]);
      final mapped = LabCaptureMappingService(predefinedLabTestDefinitions)
          .map(parsed);
      expect(mapped.map((item) => item.definition?.id), [
        'triglyceride',
        'hdl',
        'sodium',
        'potassium',
      ]);
      expect(mapped.map((item) => item.value), [164, 65, 136, 4.5]);
      expect(mapped.map((item) => item.ocrUnit), [
        'mg/dL',
        'mg/dL',
        'mmol/L',
        'mmol/L',
      ]);
    },
  );

  for (final unit in [
    'mmol/L',
    'mg/dL',
    'g/dL',
    'ng/mL',
    'IU/L',
    'U/L',
    'pg/mL',
    'mL/min',
    '10^3/uL',
    '×10³/µL',
    'mL/min/1.73m²',
    'mg/L',
    '%',
    'mg / dL',
  ]) {
    test(
      'unit syntax $unit is extracted and excluded from name candidates',
      () {
        final parsed = parser.parse([
          _doc([
            _line('($unit)', 600, 250, 715, 280),
            _line('Q', 80, 300, 100, 340),
            _line('결과', 42, 440, 100, 470),
            _line('4.5', 278, 444, 350, 474),
            _line('참고치', 28, 538, 140, 575),
            _line('($unit)', 598, 546, 730, 580),
          ]),
        ]);
        expect(parsed.single.rawTestName, 'Q');
        expect(parsed.single.unit, unit);
        expect(
          parser.parse([
            _doc([
              _line('($unit)', 80, 300, 320, 340),
              _line('결과', 42, 440, 100, 470),
              _line('4.5', 278, 444, 350, 474),
            ]),
          ]),
          isEmpty,
        );
      },
    );
  }

  for (final label in [
    'AST(GOT)',
    'Total Protein(E)',
    'Kt/V',
    'General English Label',
    'HbA1c',
  ]) {
    test('does not classify lab or English label $label as a unit', () {
      final parsed = parser.parse([
        _doc([
          _line(label, 80, 300, 650, 340),
          _line('결과', 42, 440, 100, 470),
          _line('21', 278, 444, 350, 474),
          _line('참고치', 28, 538, 140, 575),
          _line(label, 598, 546, 900, 580),
        ]),
      ]);
      expect(parsed.single.rawTestName, label);
      expect(parsed.single.unit, isNull);
    });
  }

  for (final range in ['135.0-145.0', '3.5~5.5', '-1.0-1.0']) {
    test('numeric reference range $range is never a test name', () {
      expect(
        parser.parse([
          _doc([
            _line(range, 80, 300, 420, 340),
            _line('결과', 42, 440, 100, 470),
            _line('4.5', 278, 444, 350, 474),
          ]),
        ]),
        isEmpty,
      );
    });
  }

  test(
    'balanced name does not consume a different label ending in parentheses',
    () {
      final parsed = parser.parse([
        _doc([
          _line('Marker(검사)', 80, 300, 350, 340),
          _line('Q(항목)', 82, 342, 220, 374),
          _line('결과', 42, 440, 100, 470),
          _line('21', 278, 444, 350, 474),
        ]),
      ]);
      expect(parsed.single.rawTestName, 'Marker(검사)');
    },
  );

  test(
    'continuation stops when balanced and rejects a fresh parenthetical label',
    () {
      for (final tail in ['끝)', 'Q(항목)']) {
        final parsed = parser.parse([
          _doc([
            _line('Marker(미완성', 80, 300, 350, 340),
            _line(tail, 82, 342, 220, 374),
            _line('Z(기타)', 82, 380, 220, 410),
            _line('결과', 42, 440, 100, 470),
            _line('21', 278, 444, 350, 474),
          ]),
        ]);
        expect(
          parsed.single.rawTestName,
          tail == '끝)' ? 'Marker(미완성끝)' : 'Marker(미완성',
        );
      }
    },
  );

  test('preserves decimals and integers while excluding reference ranges', () {
    final parsed = parser.parse([
      _doc([
        _line('9:41', 20, 20, 90, 50),
        _line('Creatinine(크레아티닌)', 80, 300, 420, 340),
        _line('결과', 42, 440, 100, 470),
        _line('1.31 ▲', 278, 442, 390, 474),
        _line('참고치', 26, 535, 140, 574),
        _line('0.49-0.91', 278, 545, 452, 574),
        _line('(mg/dL)', 600, 545, 715, 578),
        _line('Glucose(혈당)', 80, 700, 300, 738),
        _line('결과', 42, 842, 100, 872),
        _line('89', 278, 846, 320, 876),
        _line('참고치', 28, 938, 140, 975),
        _line('70-110', 278, 946, 405, 976),
        _line('(mg/dL)', 598, 946, 715, 980),
      ]),
    ]);

    expect(parsed.map((item) => item.value), [1.31, 89]);
    expect(parsed.map((item) => item.unit), ['mg/dL', 'mg/dL']);
  });

  test('keeps result decimals and strips low/high indicators', () {
    final parsed = parser.parse([
      _doc([
        ..._row('Calcium(칼슘)', '22.3 A', '8.5~10.5', 300),
        ..._row('Albumin(알부민)', '4.6 ▼', '3.3~5.3', 700),
      ]),
    ]);

    expect(parsed.map((item) => item.value), [22.3, 4.6]);
  });

  test(
    'supports negative result values without treating ranges as results',
    () {
      final parsed = parser.parse([
        _doc([..._row('Delta', '-0.2', '-1.0-1.0', 300)]),
      ]);

      expect(parsed.single.value, -0.2);
    },
  );

  test('handles split long test names', () {
    final parsed = parser.parse([
      _doc([
        _line('AST(GOT) (아스파르테이트아미노전이효', 80, 300, 650, 340),
        _line('소)', 82, 342, 120, 374),
        _line('결과', 42, 440, 100, 470),
        _line('21', 278, 444, 315, 474),
        _line('참고치', 28, 538, 140, 575),
        _line('13.0-34.0', 278, 546, 454, 575),
        _line('(IU/L)', 598, 546, 678, 580),
      ]),
    ]);

    expect(parsed.single.rawTestName, contains('AST(GOT)'));
    expect(parsed.single.rawTestName, endsWith('소)'));
    expect(parsed.single.value, 21);
  });

  test('returns empty candidates for empty or partial OCR', () {
    expect(parser.parse([_doc([])]), isEmpty);
    expect(
      parser.parse([
        _doc([_line('BUN(혈액요소질소)', 80, 300, 350, 340)]),
      ]),
      isEmpty,
    );
  });

  test('reads a single visible Severance date', () {
    final parsed = parser.parse([
      _doc([
        _line('2026-08-11 (화)', 40, 160, 340, 200),
        ..._row('BUN(혈액요소질소)', '19.4', '7.3~20.5', 300),
      ]),
    ]);

    expect(parsed.single.date, DateTime(2026, 8, 11));
  });
}

// Actual ML Kit order/boxes from runtime session 1789705938450810, image 0.
// Retain the full 1080 x 2316 document, including prior-row units and UI labels.
LabOcrDocument _runtimeDocument() {
  const entries = <(String, double, double, double, double)>[
    ('12:40 O •', 50, 32, 317, 71),
    ('← 검사결과조회', 31, 144, 361, 196),
    ('Triglyceride(중성지방)', 91, 356, 468, 395),
    ('결과', 47, 512, 112, 546),
    ('참고치', 28, 619, 156, 663),
    ('롤검사)', 90, 844, 203, 886),
    ('결과', 47, 1001, 112, 1035),
    ('HDL-Cholesterol (고밀도지단백콜레스테', 79, 806, 756, 849),
    ('참고치', 30, 1109, 158, 1152),
    ('Na(나트륨)', 72, 1295, 282, 1338),
    ('결과', 47, 1457, 112, 1491),
    ('참고치', 29, 1566, 158, 1609),
    ('K(칼륨)', 92, 1755, 209, 1795),
    ('결과', 47, 1913, 112, 1947),
    ('164', 315, 518, 385, 550),
    ('참고치', 47, 2025, 143, 2059),
    ('48-200', 314, 631, 472, 663),
    ('65', 315, 1007, 364, 1039),
    ('40-75', 314, 1120, 443, 1152),
    ('136', 315, 1463, 384, 1495),
    ('135.0-145.0', 313, 1576, 557, 1607),
    ('4.5', 315, 1919, 374, 1951),
    ('3.5~5.5', 315, 2031, 466, 2063),
    ('(mg/dL)', 677, 631, 810, 668),
    ('검사정보', 799, 354, 931, 389),
    ('(mg/dL)', 677, 1119, 806, 1157),
    ('l100', 912, 37, 1036, 70),
    ('검사정보', 799, 824, 951, 862),
    ('(mmol/L)', 677, 1576, 828, 1613),
    ('그래프', 871, 514, 971, 549),
    ('검사정보', 800, 1301, 951, 1336),
    ('(mmol/L)', 676, 2028, 826, 2069),
    ('그래프', 871, 1004, 971, 1039),
    ('그래프', 872, 1461, 972, 1495),
    ('검사정보', 799, 1754, 932, 1790),
    ('그래프', 872, 1917, 972, 1951),
  ];
  return LabOcrDocument(
    sourceImageIndex: 0,
    imageWidth: 1080,
    imageHeight: 2316,
    lines: [
      for (final (text, left, top, right, bottom) in entries)
        LabOcrLine(
          text: text,
          left: left,
          top: top,
          right: right,
          bottom: bottom,
          sourceImageIndex: 0,
          imageWidth: 1080,
          imageHeight: 2316,
        ),
    ],
  );
}

LabOcrDocument _doc(List<LabOcrLine> lines) {
  return LabOcrDocument(
    sourceImageIndex: 0,
    imageWidth: 955,
    imageHeight: 2048,
    lines: lines,
  );
}

List<LabOcrLine> _row(String name, String value, String range, double top) {
  return [
    _line(name, 80, top, 520, top + 35),
    _line('검사정보', 707, top, 825, top + 31),
    _line('결과', 42, top + 140, 100, top + 170),
    _line(value, 278, top + 144, 390, top + 176),
    _line('그래프', 770, top + 142, 860, top + 176),
    _line('참고치', 28, top + 238, 142, top + 276),
    _line(range, 278, top + 246, 454, top + 276),
    _line('(mg/dL)', 598, top + 246, 716, top + 280),
  ];
}

LabOcrLine _line(
  String text,
  double left,
  double top,
  double right,
  double bottom,
) {
  return LabOcrLine(
    text: text,
    left: left,
    top: top,
    right: right,
    bottom: bottom,
    sourceImageIndex: 0,
    imageWidth: 955,
    imageHeight: 2048,
  );
}
