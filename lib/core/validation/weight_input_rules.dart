import 'package:flutter/services.dart';

enum WeightRangeStatus { block, normal }

class WeightValidationResult {
  const WeightValidationResult._({
    required this.status,
    required this.value,
    this.message,
  });

  const WeightValidationResult.block(String message)
    : this._(status: WeightRangeStatus.block, value: null, message: message);

  const WeightValidationResult.normal(double value)
    : this._(status: WeightRangeStatus.normal, value: value);

  final WeightRangeStatus status;
  final double? value;
  final String? message;

  bool get isBlock => status == WeightRangeStatus.block;
  bool get canSave => !isBlock;
}

class WeightInputRules {
  const WeightInputRules._();

  static const minAllowedKg = 15.0;
  static const maxAllowedKg = 500.0;

  static const blockMessage = '체중은 15kg 이상 500kg 이하로 입력해 주세요.';

  static final TextInputFormatter formatter = TextInputFormatter.withFunction((
    oldValue,
    newValue,
  ) {
    return isAllowedEditingText(newValue.text) ? newValue : oldValue;
  });

  static final RegExp _editingPattern = RegExp(r'^[0-9]*(?:\.[0-9]{0,2})?$');
  static final RegExp _finalPattern = RegExp(r'^[0-9]+(?:\.[0-9]{0,2})?$');

  static bool isAllowedEditingText(String text) {
    return _editingPattern.hasMatch(text);
  }

  static WeightValidationResult validate(
    String? value, {
    bool required = true,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return required
          ? const WeightValidationResult.block(blockMessage)
          : const WeightValidationResult.normal(0);
    }
    if (!_finalPattern.hasMatch(text)) {
      return const WeightValidationResult.block(blockMessage);
    }
    return validateValue(double.tryParse(text));
  }

  static WeightValidationResult validateValue(double? value) {
    if (value == null || value.isNaN || value.isInfinite) {
      return const WeightValidationResult.block(blockMessage);
    }
    if (value < minAllowedKg || value > maxAllowedKg) {
      return const WeightValidationResult.block(blockMessage);
    }
    return WeightValidationResult.normal(value);
  }

  static double? parse(String value) {
    final result = validate(value, required: true);
    return result.canSave ? result.value : null;
  }
}
