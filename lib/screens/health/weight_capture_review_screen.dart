import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/validation/weight_input_rules.dart';
import '../../models/health_record.dart';
import '../../models/lab_capture_candidate.dart';
import '../../models/weight_capture_candidate.dart';
import '../../services/health_record_service.dart';

class WeightCaptureReviewScreen extends StatefulWidget {
  const WeightCaptureReviewScreen({
    super.key,
    required this.service,
    required this.candidate,
    required this.initialDate,
    this.diagnosticDocuments = const [],
    this.showOcrDiagnostics = kDebugMode,
  });

  final HealthRecordService service;
  final WeightCaptureCandidate? candidate;
  final DateTime initialDate;
  final List<LabOcrDocument> diagnosticDocuments;
  final bool showOcrDiagnostics;

  @override
  State<WeightCaptureReviewScreen> createState() =>
      _WeightCaptureReviewScreenState();
}

class _WeightCaptureReviewScreenState extends State<WeightCaptureReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late final TextEditingController _weightController;
  late final String _initialWeightText;
  String? _formError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _initialWeightText = _initialFieldText(widget.candidate);
    _weightController = TextEditingController(text: _initialWeightText)
      ..addListener(_handleWeightChanged);
  }

  @override
  void dispose() {
    _weightController.removeListener(_handleWeightChanged);
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '\uC0AC\uC9C4/\uCEA1\uCC98 \uC778\uC2DD \uACB0\uACFC',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: [
            _DateField(date: _selectedDate, onTap: _pickDate),
            const SizedBox(height: AppSpacing.md),
            Text('\uCCB4\uC911', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.xs),
            Form(
              key: _formKey,
              child: TextFormField(
                key: const Key('weight-capture-value-field'),
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [WeightInputRules.formatter],
                decoration: const InputDecoration(suffixText: 'kg'),
                validator: (value) =>
                    WeightInputRules.validate(value, required: true).message,
              ),
            ),
            if (_recognizedReferenceText != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _recognizedReferenceText!,
                key: const Key('weight-capture-recognized-reference'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_warningTextForCurrentState != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _Notice(
                key: const Key('weight-capture-warning'),
                text: _warningTextForCurrentState!,
                color: AppColors.error,
              ),
            ],
            if (_unitHelperTextForCurrentState != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _Notice(
                key: const Key('weight-capture-unit-helper'),
                text: _unitHelperTextForCurrentState!,
                color: AppColors.secondaryText,
              ),
            ],
            if (_showsDiagnostics) ...[
              const SizedBox(height: AppSpacing.md),
              _OcrDiagnostics(documents: widget.diagnosticDocuments),
            ],
            if (_formError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _formError!,
                key: const Key('weight-capture-form-error'),
                style: const TextStyle(color: AppColors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('weight-capture-cancel-button'),
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('\uCDE8\uC18C'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    key: const Key('weight-capture-save-button'),
                    onPressed: _canSubmit ? _save : null,
                    child: const Text('\uD655\uC778 \uD6C4 \uC800\uC7A5'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleWeightChanged() {
    setState(() {});
  }

  bool get _canSubmit {
    if (_isSaving) {
      return false;
    }
    final result = WeightInputRules.validate(
      _weightController.text,
      required: true,
    );
    if (!result.canSave) {
      return false;
    }
    return switch (widget.candidate?.warning) {
      WeightCaptureWarning.suspiciousDecimal ||
      WeightCaptureWarning.ambiguous =>
        _weightController.text.trim() != _initialWeightText,
      _ => true,
    };
  }

  bool get _requiresUserEdit {
    return switch (widget.candidate?.warning) {
      WeightCaptureWarning.suspiciousDecimal ||
      WeightCaptureWarning.ambiguous => true,
      _ => false,
    };
  }

  bool get _showsDiagnostics {
    if (!widget.showOcrDiagnostics) {
      return false;
    }
    return widget.candidate == null ||
        widget.candidate?.warning == WeightCaptureWarning.suspiciousDecimal;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialDate = _selectedDate.isAfter(today) ? today : _selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _save() async {
    setState(() {
      _formError = null;
      _isSaving = true;
    });
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      setState(() {
        _isSaving = false;
      });
      return;
    }
    if (_requiresUserEdit &&
        _weightController.text.trim() == _initialWeightText) {
      setState(() {
        _formError = '\uC778\uC2DD\uB41C \uCCB4\uC911 \uAC12\uC744 \uD655\uC778\uD558\uACE0 \uC218\uC815\uD574 \uC8FC\uC138\uC694.';
        _isSaving = false;
      });
      return;
    }
    final weight = WeightInputRules.parse(_weightController.text)!;
    final now = DateTime.now();
    final existing = widget.service.recordForDate(_selectedDate);
    final record =
        existing?.copyWith(weight: weight, updatedAt: now) ??
        HealthRecord(
          id: 'health-${now.microsecondsSinceEpoch}',
          date: _selectedDate,
          weight: weight,
          createdAt: now,
          updatedAt: now,
        );

    try {
      await widget.service.save(record);
    } on FutureHealthRecordDateException {
      setState(() {
        _formError = '\uBBF8\uB798 \uB0A0\uC9DC\uC5D0\uB294 \uAC74\uAC15 \uAE30\uB85D\uC744 \uC800\uC7A5\uD560 \uC218 \uC5C6\uC2B5\uB2C8\uB2E4.';
        _isSaving = false;
      });
      return;
    } on DuplicateHealthRecordException {
      setState(() {
        _formError = '\uAC19\uC740 \uB0A0\uC9DC\uC758 \uAC74\uAC15 \uAE30\uB85D\uC774 \uC774\uBBF8 \uC788\uC2B5\uB2C8\uB2E4.';
        _isSaving = false;
      });
      return;
    } on EmptyHealthRecordException {
      setState(() {
        _formError =
            '\uCCB4\uC911 \uAC12\uC744 \uC785\uB825\uD574 \uC8FC\uC138\uC694.';
        _isSaving = false;
      });
      return;
    } on InvalidHealthRecordWeightException {
      setState(() {
        _formError = WeightInputRules.blockMessage;
        _isSaving = false;
      });
      return;
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(_selectedDate);
  }

  String _initialFieldText(WeightCaptureCandidate? candidate) {
    if (candidate == null) {
      return '';
    }
    if (candidate.warning == WeightCaptureWarning.noMeasurement) {
      return '';
    }
    final decimalText = RegExp(r'([0-9]+[\.,\u00B7\u318D][0-9]+)')
        .firstMatch(candidate.rawOcrText)
        ?.group(1);
    if (decimalText != null) {
      return decimalText
          .replaceAll(',', '.')
          .replaceAll('\u00B7', '.')
          .replaceAll('\u318D', '.');
    }
    return _formatInitial(candidate.value);
  }

  String _formatInitial(double? value) {
    if (value == null) {
      return '';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  }

  String? get _recognizedReferenceText {
    return null;
  }

  String? get _warningTextForCurrentState {
    final candidate = widget.candidate;
    if (candidate == null) {
      return '\uCCB4\uC911\uC744 \uC815\uD655\uD788 \uC778\uC2DD\uD558\uC9C0 \uBABB\uD588\uC2B5\uB2C8\uB2E4. \uC0AC\uC9C4\uC744 \uD655\uC778\uD558\uACE0 \uCCB4\uC911\uC744 \uC9C1\uC811 \uC785\uB825\uD574 \uC8FC\uC138\uC694.';
    }
    if (candidate.warning == WeightCaptureWarning.none) {
      return null;
    }
    if (candidate.warning == WeightCaptureWarning.unitUncertain) {
      return null;
    }
    return _warningText(candidate.warning);
  }

  String? get _unitHelperTextForCurrentState {
    final candidate = widget.candidate;
    return candidate != null &&
            candidate.warning == WeightCaptureWarning.unitUncertain
        ? '\uCCB4\uC911 \uC22B\uC790\uB97C \uD655\uC778\uD574 \uC8FC\uC138\uC694.'
        : null;
  }

  String _warningText(WeightCaptureWarning warning) {
    return switch (warning) {
      WeightCaptureWarning.none => '',
      WeightCaptureWarning.missingUnit =>
        '\uB2E8\uC704\uAC00 \uBA85\uD655\uD558\uC9C0 \uC54A\uC2B5\uB2C8\uB2E4.',
      WeightCaptureWarning.unitUncertain => '\uB2E8\uC704\uB97C \uC815\uD655\uD788 \uC778\uC2DD\uD558\uC9C0 \uBABB\uD588\uC2B5\uB2C8\uB2E4. \uCCB4\uC911 \uC22B\uC790\uB97C \uD655\uC778\uD574 \uC8FC\uC138\uC694.',
      WeightCaptureWarning.ambiguous => '\uC778\uC2DD\uB41C \uCCB4\uC911 \uC22B\uC790\uB97C \uD655\uC778\uD574 \uC8FC\uC138\uC694.',
      WeightCaptureWarning.suspiciousDecimal => '\uC778\uC2DD\uB41C \uCCB4\uC911 \uC22B\uC790\uB97C \uD655\uC778\uD574 \uC8FC\uC138\uC694.',
      WeightCaptureWarning.noMeasurement => '\uCE21\uC815\uB41C \uCCB4\uC911\uC744 \uD655\uC778\uD560 \uC218 \uC5C6\uC2B5\uB2C8\uB2E4. \uB2E4\uC2DC \uCD2C\uC601\uD558\uAC70\uB098 \uC9C1\uC811 \uC785\uB825\uD574 \uC8FC\uC138\uC694.',
    };
  }
}

class _OcrDiagnostics extends StatelessWidget {
  const _OcrDiagnostics({required this.documents});

  final List<LabOcrDocument> documents;

  @override
  Widget build(BuildContext context) {
    final lines = [
      for (final document in documents)
        for (final line in document.lines) line,
    ];
    return ExpansionTile(
      key: const Key('weight-capture-diagnostics-toggle'),
      tilePadding: EdgeInsets.zero,
      title: const Text('OCR \uC9C4\uB2E8 \uBCF4\uAE30'),
      subtitle: Text(
        'OCR line count: ${lines.length}',
        key: const Key('weight-capture-ocr-line-count'),
      ),
      children: [
        if (lines.isEmpty)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'OCR\uC5D0\uC11C \uC77D\uD78C \uD14D\uC2A4\uD2B8\uAC00 \uC5C6\uC2B5\uB2C8\uB2E4.',
              key: Key('weight-capture-ocr-empty'),
            ),
          )
        else
          for (var index = 0; index < lines.length; index += 1)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: SelectableText(
                  _formatLine(index, lines[index]),
                  key: ValueKey('weight-capture-ocr-line-$index'),
                ),
              ),
            ),
      ],
    );
  }

  String _formatLine(int index, LabOcrLine line) {
    final number = (index + 1).toString().padLeft(2, '0');
    return '[$number] ${line.text} | sourceImageIndex=${line.sourceImageIndex}, '
        'left=${line.left.round()}, '
        'top=${line.top.round()}, right=${line.right.round()}, '
        'bottom=${line.bottom.round()}';
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('weight-capture-date-field'),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '\uAE30\uB85D \uB0A0\uC9DC',
        ),
        child: Row(
          children: [
            Expanded(child: Text(_formatDate(date))),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year.$month.$day';
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(color: color, fontSize: 13));
  }
}
