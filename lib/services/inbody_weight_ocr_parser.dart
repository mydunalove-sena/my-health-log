import '../models/lab_capture_candidate.dart';
import '../models/weight_capture_candidate.dart';

class InBodyWeightOcrParser {
  const InBodyWeightOcrParser();

  WeightCaptureCandidate? parse(List<LabOcrDocument> documents) {
    final candidates = [
      for (final document in documents) ..._parseDocument(document),
    ];
    if (candidates.isEmpty) {
      return null;
    }
    if (candidates.length == 1) {
      return candidates.single;
    }
    final best = candidates.first;
    return WeightCaptureCandidate(
      value: best.value,
      unit: best.unit,
      sourceLabel: best.sourceLabel,
      sourceImageIndex: best.sourceImageIndex,
      rawOcrText: best.rawOcrText,
      type: best.type,
      warning: WeightCaptureWarning.ambiguous,
    );
  }

  List<WeightCaptureCandidate> _parseDocument(LabOcrDocument document) {
    final lines = _sortedLines(document.lines);
    final candidates = <WeightCaptureCandidate>[];
    for (final label in lines.where(_isWeightLabel)) {
      final inline = _inlineCandidate(label);
      if (inline != null) {
        candidates.add(inline);
        continue;
      }

      final sectionBottom = _nextExcludedLabelY(lines, label);
      final values = _nearbyValues(lines, label, sectionBottom);
      if (values.isEmpty) {
        continue;
      }
      values.sort((a, b) => _distance(label, a).compareTo(_distance(label, b)));
      final valueLine = values.first;
      final unit = _unitForValue(lines, valueLine, label);
      candidates.add(
        WeightCaptureCandidate(
          value: _parseNumber(valueLine.text)!,
          unit: unit,
          sourceLabel: label.text.trim(),
          sourceImageIndex: valueLine.sourceImageIndex,
          rawOcrText:
              '${label.text.trim()} ${valueLine.text.trim()}'
              '${unit == null ? '' : ' $unit'}',
          type: WeightCaptureCandidateType.inBodyWeight,
          warning: values.length == 1
              ? (unit == null
                    ? WeightCaptureWarning.missingUnit
                    : WeightCaptureWarning.none)
              : WeightCaptureWarning.ambiguous,
        ),
      );
    }
    return candidates;
  }

  List<LabOcrLine> _sortedLines(List<LabOcrLine> lines) {
    return [
      for (final line in lines)
        if (line.text.trim().isNotEmpty) line,
    ]..sort((a, b) {
      final y = a.normalizedCenterY.compareTo(b.normalizedCenterY);
      if ((a.normalizedCenterY - b.normalizedCenterY).abs() > 0.01) return y;
      return a.normalizedCenterX.compareTo(b.normalizedCenterX);
    });
  }

  bool _isWeightLabel(LabOcrLine line) {
    final text = _compact(line.text);
    return (text.contains('체중') || text.contains('weight')) &&
        !_isExcludedLabel(line);
  }

  bool _isExcludedLabel(LabOcrLine line) {
    final text = _compact(line.text);
    return text.contains('골격근량') ||
        text.contains('골격근') ||
        text.contains('체지방량') ||
        text.contains('체지방') ||
        text.contains('인바디점수') ||
        text.contains('bmi');
  }

  WeightCaptureCandidate? _inlineCandidate(LabOcrLine label) {
    final match = RegExp(
      r'(?:체중|weight)\s*([0-9]+(?:\.[0-9]+)?)\s*(kg)?',
      caseSensitive: false,
    ).firstMatch(label.text);
    if (match == null) {
      return null;
    }
    final value = double.tryParse(match.group(1)!);
    if (value == null || value <= 0 || value.isNaN || value.isInfinite) {
      return null;
    }
    final unit = match.group(2);
    return WeightCaptureCandidate(
      value: value,
      unit: unit,
      sourceLabel: '체중',
      sourceImageIndex: label.sourceImageIndex,
      rawOcrText: label.text.trim(),
      type: WeightCaptureCandidateType.inBodyWeight,
      warning: unit == null
          ? WeightCaptureWarning.missingUnit
          : WeightCaptureWarning.none,
    );
  }

  double _nextExcludedLabelY(List<LabOcrLine> lines, LabOcrLine label) {
    final below = [
      for (final line in lines)
        if (line.sourceImageIndex == label.sourceImageIndex &&
            _isExcludedLabel(line) &&
            _isConnectedBelow(label, line))
          line.normalizedCenterY,
    ];
    if (below.isEmpty) {
      return label.normalizedCenterY + 0.16;
    }
    below.sort();
    return below.first;
  }

  List<LabOcrLine> _nearbyValues(
    List<LabOcrLine> lines,
    LabOcrLine label,
    double sectionBottom,
  ) {
    return [
      for (final line in lines)
        if (line.sourceImageIndex == label.sourceImageIndex &&
            line != label &&
            line.normalizedCenterY >= label.normalizedCenterY - 0.025 &&
            line.normalizedCenterY < sectionBottom &&
            line.normalizedCenterY <= label.normalizedCenterY + 0.12 &&
            !_isExcludedLabel(line) &&
            !_isGraphRange(line.text) &&
            _parseNumber(line.text) != null &&
            _isConnectedValue(label, line))
          line,
    ];
  }

  bool _isConnectedBelow(LabOcrLine label, LabOcrLine line) {
    return line.normalizedCenterY > label.normalizedCenterY + 0.025 &&
        _hasColumnConnection(label, line);
  }

  bool _isConnectedValue(LabOcrLine label, LabOcrLine line) {
    final isBelow = line.normalizedCenterY > label.normalizedCenterY + 0.025;
    if (!isBelow) {
      return line.normalizedCenterX >= label.normalizedCenterX - 0.18;
    }
    return _hasColumnConnection(label, line);
  }

  bool _hasColumnConnection(LabOcrLine label, LabOcrLine line) {
    final overlap =
        _min(_normalizedRight(label), _normalizedRight(line)) -
        _max(label.normalizedLeft, line.normalizedLeft);
    if (overlap > 0) {
      return true;
    }
    return (line.normalizedCenterX - label.normalizedCenterX).abs() <= 0.24;
  }

  String? _unitForValue(
    List<LabOcrLine> lines,
    LabOcrLine valueLine,
    LabOcrLine label,
  ) {
    if (_containsKg(label.text)) {
      return 'kg';
    }
    if (_containsKg(valueLine.text)) {
      return 'kg';
    }
    final units = [
      for (final line in lines)
        if (line.sourceImageIndex == valueLine.sourceImageIndex &&
            line != valueLine &&
            _containsKg(line.text) &&
            (line.isNearY(valueLine, tolerance: 0.03) ||
                (line.normalizedCenterY - valueLine.normalizedCenterY).abs() <=
                    0.05) &&
            (line.normalizedCenterX - valueLine.normalizedCenterX).abs() <=
                0.22)
          line,
    ];
    return units.isEmpty ? null : 'kg';
  }

  double? _parseNumber(String text) {
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(text);
    if (match == null) {
      return null;
    }
    final value = double.tryParse(match.group(1)!);
    if (value == null || value <= 0 || value.isNaN || value.isInfinite) {
      return null;
    }
    return value;
  }

  bool _isGraphRange(String text) {
    final compact = text.replaceAll(' ', '');
    return RegExp(r'\d+(?:\.\d+)?[-~]\d+(?:\.\d+)?').hasMatch(compact);
  }

  bool _containsKg(String text) => text.toLowerCase().contains('kg');

  double _distance(LabOcrLine label, LabOcrLine value) {
    final dx = value.normalizedCenterX - label.normalizedCenterX;
    final dy = value.normalizedCenterY - label.normalizedCenterY;
    return (dx * dx) + (dy * dy);
  }

  double _min(double a, double b) => a < b ? a : b;

  double _max(double a, double b) => a > b ? a : b;

  double _normalizedRight(LabOcrLine line) =>
      line.imageWidth == 0 ? 0 : line.right / line.imageWidth;

  String _compact(String text) =>
      text.replaceAll(RegExp(r'\s+'), '').trim().toLowerCase();
}
