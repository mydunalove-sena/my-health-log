import 'package:flutter_test/flutter_test.dart';
import 'package:my_health_log/models/lab_capture_candidate.dart';
import 'package:my_health_log/models/weight_capture_candidate.dart';
import 'package:my_health_log/services/inbody_weight_ocr_parser.dart';

void main() {
  const parser = InBodyWeightOcrParser();

  test('TC1 extracts real Galaxy layout "체중 (kg)" and 50.3', () {
    final candidate = parser.parse([
      _doc([
        _line('체중 (kg)', 132, 1082, 261, 1118),
        _line('50.3', 128, 1169, 268, 1237),
      ]),
    ]);

    expect(candidate, isNotNull);
    expect(candidate!.value, 50.3);
    expect(candidate.unit, 'kg');
    expect(candidate.warning, WeightCaptureWarning.none);
  });

  test('TC2 extracts compact "체중(kg)" label and 50.3', () {
    final candidate = parser.parse([
      _doc([
        _line('체중(kg)', 132, 1082, 261, 1118),
        _line('50.3', 128, 1169, 268, 1237),
      ]),
    ]);

    expect(candidate, isNotNull);
    expect(candidate!.value, 50.3);
    expect(candidate.unit, 'kg');
    expect(candidate.warning, WeightCaptureWarning.none);
  });

  test('TC3 extracts English "Weight (kg)" label and 50.3', () {
    final candidate = parser.parse([
      _doc([
        _line('Weight (kg)', 132, 1082, 261, 1118),
        _line('50.3', 128, 1169, 268, 1237),
      ]),
    ]);

    expect(candidate, isNotNull);
    expect(candidate!.value, 50.3);
    expect(candidate.unit, 'kg');
    expect(candidate.warning, WeightCaptureWarning.none);
  });

  test('TC4 extracts real Galaxy shuffled line order by coordinates', () {
    final candidate = parser.parse([_realGalaxyShuffledDocument()]);

    expect(candidate, isNotNull);
    expect(candidate!.value, 50.3);
    expect(candidate.unit, 'kg');
    expect(candidate.warning, WeightCaptureWarning.none);
  });

  test('TC5 keeps result stable when real Galaxy lines are reordered', () {
    final candidate = parser.parse([
      _doc([
        _line('18.8', 524, 1169, 664, 1237),
        _line('체지방량 (kg)', 916, 1083, 1088, 1119),
        _line('인바디검사 요약', 59, 935, 431, 988),
        _line('50.3', 128, 1169, 268, 1237),
        _line('체중 (kg)', 132, 1082, 261, 1118),
        _line('골격근량 (kg)', 520, 1084, 710, 1120),
        _line('13.6', 920, 1169, 1060, 1237),
      ]),
    ]);

    expect(candidate, isNotNull);
    expect(candidate!.value, 50.3);
    expect(candidate.unit, 'kg');
    expect(candidate.warning, WeightCaptureWarning.none);
  });

  test('TC1 extracts 51.2 kg from a normal InBody detail layout', () {
    final candidate = parser.parse([_inBodyDocument()]);

    expect(candidate, isNotNull);
    expect(candidate!.value, 51.2);
    expect(candidate.unit, 'kg');
    expect(candidate.warning, WeightCaptureWarning.none);
  });

  test('TC2 does not select skeletal muscle mass 19.7 kg as weight', () {
    final candidate = parser.parse([_inBodyDocument()]);

    expect(candidate, isNotNull);
    expect(candidate!.value, isNot(19.7));
  });

  test('TC3 does not select body fat mass 15.4 kg as weight', () {
    final candidate = parser.parse([_inBodyDocument()]);

    expect(candidate, isNotNull);
    expect(candidate!.value, isNot(15.4));
  });

  test('TC4 does not select InBody score 75 as weight', () {
    final candidate = parser.parse([_inBodyDocument()]);

    expect(candidate, isNotNull);
    expect(candidate!.value, isNot(75));
  });

  test('TC5 uses the weight label instead of the first or any kg value', () {
    final candidate = parser.parse([
      _doc([
        _line('인바디점수', 620, 110, 780, 145),
        _line('75', 790, 105, 850, 150),
        _line('골격근·지방분석', 60, 260, 330, 300),
        ..._metric('골격근량', '19.7', 'kg', 360),
        ..._metric('체중', '51.2', 'kg', 500),
        ..._metric('체지방량', '15.4', 'kg', 640),
      ]),
    ]);

    expect(candidate, isNotNull);
    expect(candidate!.value, 51.2);
    expect(candidate.unit, 'kg');
  });

  test('TC6 marks nearby ambiguous values instead of auto-confirming', () {
    final candidate = parser.parse([
      _doc([
        _line('골격근·지방분석', 60, 260, 330, 300),
        _line('체중', 70, 360, 170, 395),
        _line('51.2', 270, 360, 345, 395),
        _line('kg', 355, 360, 395, 395),
        _line('52.1', 275, 415, 350, 450),
        _line('kg', 360, 415, 400, 450),
        ..._metric('골격근량', '19.7', 'kg', 530),
      ]),
    ]);

    expect(candidate, isNotNull);
    expect(candidate!.warning, WeightCaptureWarning.ambiguous);
    expect(candidate.canAutoSelect, isFalse);
  });

  test('TC7 keeps value candidate with missing unit warning', () {
    final candidate = parser.parse([
      _doc([
        _line('골격근·지방분석', 60, 260, 330, 300),
        _line('체중', 70, 360, 170, 395),
        _line('51.2', 270, 360, 345, 395),
        ..._metric('골격근량', '19.7', 'kg', 500),
      ]),
    ]);

    expect(candidate, isNotNull);
    expect(candidate!.value, 51.2);
    expect(candidate.unit, isNull);
    expect(candidate.warning, WeightCaptureWarning.missingUnit);
  });

  test('TC8 extracts merged OCR line "체중 51.2kg"', () {
    final candidate = parser.parse([
      _doc([
        _line('골격근·지방분석', 60, 260, 330, 300),
        _line('체중 51.2kg', 70, 360, 330, 395),
        ..._metric('골격근량', '19.7', 'kg', 500),
      ]),
    ]);

    expect(candidate, isNotNull);
    expect(candidate!.value, 51.2);
    expect(candidate.unit, 'kg');
    expect(candidate.warning, WeightCaptureWarning.none);
  });

  test('TC9 matches separate "체중" and "51.2 kg" lines by proximity', () {
    final candidate = parser.parse([
      _doc([
        _line('골격근·지방분석', 60, 260, 330, 300),
        _line('체중', 70, 360, 170, 395),
        _line('51.2 kg', 270, 360, 375, 395),
        ..._metric('골격근량', '19.7', 'kg', 500),
      ]),
    ]);

    expect(candidate, isNotNull);
    expect(candidate!.value, 51.2);
    expect(candidate.unit, 'kg');
  });
}

LabOcrDocument _realGalaxyShuffledDocument() {
  return _doc([
    _line('체중 (kg)', 132, 1082, 261, 1118),
    _line('인바디검사 요약', 59, 935, 431, 988),
    _line('골격근량 (kg)', 520, 1084, 710, 1120),
    _line('체지방량 (kg)', 916, 1083, 1088, 1119),
    _line('50.3', 128, 1169, 268, 1237),
    _line('18.8', 524, 1169, 664, 1237),
    _line('13.6', 920, 1169, 1060, 1237),
  ]);
}

LabOcrDocument _inBodyDocument() {
  return _doc([
    _line('2026.09.09 15:30', 60, 90, 300, 125),
    _line('인바디점수', 620, 110, 780, 145),
    _line('75', 790, 105, 850, 150),
    _line('골격근·지방분석', 60, 260, 330, 300),
    ..._metric('체중', '51.2', 'kg', 360),
    ..._metric('골격근량', '19.7', 'kg', 500),
    ..._metric('체지방량', '15.4', 'kg', 640),
  ]);
}

List<LabOcrLine> _metric(String label, String value, String unit, double top) {
  return [
    _line(label, 70, top, 175, top + 35),
    _line(value, 270, top, 345, top + 35),
    _line(unit, 355, top, 395, top + 35),
    _line('낮음', 470, top, 525, top + 28),
    _line('표준', 610, top, 665, top + 28),
    _line('높음', 760, top, 815, top + 28),
    _line('40.0-70.0', 530, top + 42, 665, top + 68),
  ];
}

LabOcrDocument _doc(List<LabOcrLine> lines) {
  return LabOcrDocument(
    sourceImageIndex: 0,
    imageWidth: 900,
    imageHeight: 1600,
    lines: lines,
  );
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
    imageWidth: 900,
    imageHeight: 1600,
  );
}
