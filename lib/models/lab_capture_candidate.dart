import 'dart:math' as math;

import 'lab_result.dart';
import 'lab_test_definition.dart';

class LabOcrLine {
  const LabOcrLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.sourceImageIndex,
    required this.imageWidth,
    required this.imageHeight,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final int sourceImageIndex;
  final double imageWidth;
  final double imageHeight;

  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  double get normalizedLeft => imageWidth == 0 ? 0 : left / imageWidth;
  double get normalizedTop => imageHeight == 0 ? 0 : top / imageHeight;
  double get normalizedCenterX => imageWidth == 0 ? 0 : centerX / imageWidth;
  double get normalizedCenterY => imageHeight == 0 ? 0 : centerY / imageHeight;

  bool isNearY(LabOcrLine other, {double tolerance = 0.022}) {
    return (normalizedCenterY - other.normalizedCenterY).abs() <= tolerance;
  }
}

class LabOcrDocument {
  const LabOcrDocument({
    required this.sourceImageIndex,
    required this.imageWidth,
    required this.imageHeight,
    required this.lines,
  });

  final int sourceImageIndex;
  final double imageWidth;
  final double imageHeight;
  final List<LabOcrLine> lines;
}

class ParsedLabCaptureCandidate {
  const ParsedLabCaptureCandidate({
    required this.rawTestName,
    required this.value,
    required this.sourceImageIndex,
    this.unit,
    this.date,
  });

  final String rawTestName;
  final double value;
  final String? unit;
  final DateTime? date;
  final int sourceImageIndex;

  String get normalizedUnit {
    final text = unit?.trim();
    if (text == null || text.isEmpty) return '';
    return text.replaceAll('(', '').replaceAll(')', '');
  }
}

enum LabCaptureMappingStatus { mapped, unmapped }

class LabCaptureCandidate {
  LabCaptureCandidate({
    required this.id,
    required this.rawTestName,
    required this.value,
    required this.sourceImageIndices,
    required this.mappingStatus,
    this.ocrUnit,
    this.definition,
    this.date,
    this.hasImportConflict = false,
    this.existingResult,
  }) : isSelected =
           mappingStatus == LabCaptureMappingStatus.mapped &&
           !hasImportConflict;

  final String id;
  final String rawTestName;
  double value;
  String? ocrUnit;
  final List<int> sourceImageIndices;
  LabCaptureMappingStatus mappingStatus;
  LabTestDefinition? definition;
  DateTime? date;
  bool hasImportConflict;
  LabResult? existingResult;
  bool isSelected;

  String get displayName => definition?.displayName ?? rawTestName;
  String? get saveUnit => definition?.defaultUnit ?? _emptyToNull(ocrUnit);

  bool get isMapped => mappingStatus == LabCaptureMappingStatus.mapped;
  bool get hasExistingSameValue {
    final existing = existingResult;
    if (existing == null) return false;
    return existing.value == value && (existing.unit ?? '') == (saveUnit ?? '');
  }

  bool get hasExistingConflict {
    final existing = existingResult;
    if (existing == null) return false;
    return existing.value != value || (existing.unit ?? '') != (saveUnit ?? '');
  }

  bool get hasUnitWarning {
    final recognized = _emptyToNull(ocrUnit);
    final configured = definition?.defaultUnit;
    if (recognized == null || configured == null) return false;
    return _normalizeUnit(recognized) != _normalizeUnit(configured);
  }

  void mapTo(LabTestDefinition definition) {
    this.definition = definition;
    mappingStatus = LabCaptureMappingStatus.mapped;
    if (!hasImportConflict && !hasExistingSameValue) {
      isSelected = true;
    }
  }

  LabResult toLabResult(DateTime date, DateTime now) {
    final existing = existingResult;
    if (existing != null) {
      return existing.copyWith(
        date: date,
        value: value,
        unit: saveUnit,
        clearUnit: saveUnit == null,
        updatedAt: now,
      );
    }
    return LabResult(
      id: 'lab-${now.microsecondsSinceEpoch}-$id',
      date: date,
      testName: displayName,
      value: value,
      unit: saveUnit,
      createdAt: now,
      updatedAt: now,
    );
  }

  static String? _emptyToNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String _normalizeUnit(String value) {
    return value
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll(' ', '')
        .toLowerCase();
  }
}

String formatLabCaptureValue(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  final precision = math.max(1, math.min(6, _decimalPlaces(value)));
  var text = value.toStringAsFixed(precision);
  while (text.contains('.') && text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
}

int _decimalPlaces(double value) {
  final text = value.toString();
  final index = text.indexOf('.');
  return index == -1 ? 0 : text.length - index - 1;
}
