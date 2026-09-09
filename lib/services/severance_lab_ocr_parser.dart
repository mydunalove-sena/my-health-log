import '../models/lab_capture_candidate.dart';

class SeveranceLabOcrParser {
  const SeveranceLabOcrParser();

  List<ParsedLabCaptureCandidate> parse(List<LabOcrDocument> documents) {
    return [for (final document in documents) ..._parseDocument(document)];
  }

  List<ParsedLabCaptureCandidate> _parseDocument(LabOcrDocument document) {
    final lines = _sortedMeaningfulLines(document.lines);
    if (lines.isEmpty) return [];
    final date = _readDate(lines);
    final results = <ParsedLabCaptureCandidate>[];

    for (final resultLabel in lines.where(_isResultLabel)) {
      final resultValue = _nearestResultValue(lines, resultLabel);
      if (resultValue == null) continue;
      final testName = _nearestTestName(lines, resultLabel);
      if (testName == null) continue;
      final unit = _nearestUnit(lines, resultLabel);
      results.add(
        ParsedLabCaptureCandidate(
          rawTestName: _cleanTestName(testName.text),
          value: _parseResultNumber(resultValue.text)!,
          unit: unit == null ? null : _cleanUnit(unit.text),
          date: date,
          sourceImageIndex: resultLabel.sourceImageIndex,
        ),
      );
    }

    return results;
  }

  List<LabOcrLine> _sortedMeaningfulLines(List<LabOcrLine> lines) {
    return [
      for (final line in lines)
        if (!_isStatusBarLine(line) && line.text.trim().isNotEmpty) line,
    ]..sort((a, b) {
      final y = a.normalizedCenterY.compareTo(b.normalizedCenterY);
      if ((a.normalizedCenterY - b.normalizedCenterY).abs() > 0.01) return y;
      return a.normalizedCenterX.compareTo(b.normalizedCenterX);
    });
  }

  DateTime? _readDate(List<LabOcrLine> lines) {
    final pattern = RegExp(r'(\d{4})-(\d{2})-(\d{2})');
    for (final line in lines) {
      final match = pattern.firstMatch(line.text);
      if (match == null) continue;
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    }
    return null;
  }

  LabOcrLine? _nearestResultValue(
    List<LabOcrLine> lines,
    LabOcrLine resultLabel,
  ) {
    final candidates = [
      for (final line in lines)
        if (line.sourceImageIndex == resultLabel.sourceImageIndex &&
            line.normalizedCenterX > resultLabel.normalizedCenterX + 0.08 &&
            line.isNearY(resultLabel, tolerance: 0.03) &&
            _parseResultNumber(line.text) != null)
          line,
    ];
    if (candidates.isEmpty) return null;
    candidates.sort(
      (a, b) => (a.normalizedCenterX - 0.32).abs().compareTo(
        (b.normalizedCenterX - 0.32).abs(),
      ),
    );
    return candidates.first;
  }

  LabOcrLine? _nearestTestName(List<LabOcrLine> lines, LabOcrLine resultLabel) {
    final blocked = <String>{'결과', '참고치', '검사정보', '그래프'};
    final candidates = [
      for (final line in lines)
        if (line.sourceImageIndex == resultLabel.sourceImageIndex &&
            line.normalizedCenterY < resultLabel.normalizedCenterY - 0.025 &&
            line.normalizedCenterY > resultLabel.normalizedCenterY - 0.16 &&
            line.normalizedLeft < 0.68 &&
            !blocked.contains(line.text.trim()) &&
            !_looksLikeUnit(line.text) &&
            _parseAnyNumber(line.text) == null)
          line,
    ];
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final scoreCompare = _testNameScore(b).compareTo(_testNameScore(a));
      if (scoreCompare != 0) return scoreCompare;
      return b.normalizedCenterY.compareTo(a.normalizedCenterY);
    });
    final first = candidates.first;
    final splitTail = candidates
        .where(
          (line) =>
              line != first &&
              line.normalizedCenterY > first.normalizedCenterY &&
              line.normalizedCenterY < resultLabel.normalizedCenterY &&
              line.normalizedLeft < 0.25 &&
              line.text.trim().endsWith(')'),
        )
        .toList();
    if (splitTail.isEmpty) return first;
    final mergedText =
        ([first, ...splitTail]..sort(
              (a, b) => a.normalizedCenterY.compareTo(b.normalizedCenterY),
            ))
            .map((line) => line.text.trim())
            .join('');
    return LabOcrLine(
      text: mergedText,
      left: first.left,
      top: first.top,
      right: first.right,
      bottom: first.bottom,
      sourceImageIndex: first.sourceImageIndex,
      imageWidth: first.imageWidth,
      imageHeight: first.imageHeight,
    );
  }

  LabOcrLine? _nearestUnit(List<LabOcrLine> lines, LabOcrLine resultLabel) {
    final referenceLabel =
        lines
            .where(
              (line) =>
                  line.sourceImageIndex == resultLabel.sourceImageIndex &&
                  _isReferenceLabel(line) &&
                  line.normalizedCenterY > resultLabel.normalizedCenterY &&
                  line.normalizedCenterY < resultLabel.normalizedCenterY + 0.09,
            )
            .toList()
          ..sort((a, b) => a.normalizedCenterY.compareTo(b.normalizedCenterY));
    if (referenceLabel.isEmpty) return null;
    final label = referenceLabel.first;
    final units = [
      for (final line in lines)
        if (line.sourceImageIndex == label.sourceImageIndex &&
            line.normalizedCenterX > 0.55 &&
            line.isNearY(label, tolerance: 0.035) &&
            _looksLikeUnit(line.text))
          line,
    ];
    if (units.isEmpty) return null;
    units.sort((a, b) => a.normalizedCenterX.compareTo(b.normalizedCenterX));
    return units.first;
  }

  bool _isResultLabel(LabOcrLine line) => line.text.trim() == '결과';
  bool _isReferenceLabel(LabOcrLine line) => line.text.trim() == '참고치';

  bool _isStatusBarLine(LabOcrLine line) {
    if (line.normalizedTop > 0.08) return false;
    final text = line.text.trim();
    return RegExp(r'\d{1,2}:\d{2}|LTE|5ll|ll99|tll').hasMatch(text);
  }

  bool _looksLikeUnit(String text) {
    final value = text.trim().toLowerCase();
    return value.contains('mg/dl') ||
        value.contains('g/dl') ||
        value.contains('iu/l') ||
        value.contains('ng/ml') ||
        value == '%';
  }

  int _testNameScore(LabOcrLine line) {
    final text = line.text.trim();
    var score = 0;
    if (RegExp('[A-Za-z]').hasMatch(text)) score += 3;
    if (text.contains('(')) score += 1;
    if (text.length > 6) score += 1;
    if (!RegExp('[A-Za-z]').hasMatch(text) && text.length <= 4) score -= 4;
    return score;
  }

  double? _parseResultNumber(String text) {
    final cleaned = text
        .replaceAll('▲', '')
        .replaceAll('▼', '')
        .replaceAll(RegExp(r'\b[AaVv]\b'), '')
        .trim();
    if (_isRange(cleaned)) return null;
    final match = RegExp(r'^-?\d+(?:\.\d+)?$').firstMatch(cleaned);
    if (match == null) return null;
    final value = double.tryParse(match.group(0)!);
    if (value == null || value.isNaN || value.isInfinite) return null;
    return value;
  }

  double? _parseAnyNumber(String text) {
    final trimmed = text.trim();
    if (_isRange(trimmed)) return null;
    return double.tryParse(trimmed);
  }

  bool _isRange(String text) {
    final compact = text.replaceAll(' ', '');
    return RegExp(r'^-?\d+(?:\.\d+)?[~-]-?\d+(?:\.\d+)?$').hasMatch(compact);
  }

  String _cleanTestName(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _cleanUnit(String text) {
    return text.replaceAll('(', '').replaceAll(')', '').trim();
  }
}
