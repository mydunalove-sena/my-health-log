import 'package:flutter_test/flutter_test.dart';
import 'package:my_health_log/models/lab_capture_candidate.dart';
import 'package:my_health_log/services/severance_lab_ocr_parser.dart';

void main() {
  const parser = SeveranceLabOcrParser();

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
