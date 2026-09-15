enum WeightCaptureCandidateType { inBodyWeight, scaleLcdWeight }

enum WeightCaptureWarning {
  none,
  missingUnit,
  unitUncertain,
  ambiguous,
  suspiciousDecimal,
  noMeasurement,
}

class WeightCaptureCandidate {
  const WeightCaptureCandidate({
    required this.value,
    required this.unit,
    required this.sourceLabel,
    required this.sourceImageIndex,
    required this.rawOcrText,
    required this.type,
    this.warning = WeightCaptureWarning.none,
    this.sourceLeft,
    this.sourceTop,
    this.sourceRight,
    this.sourceBottom,
    this.sourceImageWidth,
    this.sourceImageHeight,
  });

  final double value;
  final String? unit;
  final String sourceLabel;
  final int sourceImageIndex;
  final String rawOcrText;
  final WeightCaptureCandidateType type;
  final WeightCaptureWarning warning;
  final double? sourceLeft;
  final double? sourceTop;
  final double? sourceRight;
  final double? sourceBottom;
  final double? sourceImageWidth;
  final double? sourceImageHeight;

  bool get canAutoSelect => warning == WeightCaptureWarning.none;

  bool get hasSourceBoundingBox {
    return sourceLeft != null &&
        sourceTop != null &&
        sourceRight != null &&
        sourceBottom != null &&
        sourceImageWidth != null &&
        sourceImageHeight != null;
  }
}
