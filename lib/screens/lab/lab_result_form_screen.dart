import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/lab_result.dart';
import '../../services/lab_result_service.dart';

class LabResultFormScreen extends StatefulWidget {
  const LabResultFormScreen({
    super.key,
    required this.service,
    this.result,
    this.initialDate,
  });

  final LabResultService service;
  final LabResult? result;
  final DateTime? initialDate;

  @override
  State<LabResultFormScreen> createState() => _LabResultFormScreenState();
}

class _LabResultFormScreenState extends State<LabResultFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late final TextEditingController _testNameController;
  late final TextEditingController _valueController;
  late final TextEditingController _unitController;
  late final String _initialSnapshot;
  String? _formError;

  bool get _isEdit => widget.result != null;

  @override
  void initState() {
    super.initState();
    final result = widget.result;
    final now = DateTime.now();
    _selectedDate =
        result?.date ??
        widget.initialDate ??
        DateTime(now.year, now.month, now.day);
    _testNameController = TextEditingController(text: result?.testName ?? '');
    _valueController = TextEditingController(
      text: result == null ? '' : LabResult.formatValue(result.value),
    );
    _unitController = TextEditingController(text: result?.unit ?? '');
    _initialSnapshot = _snapshot();
  }

  @override
  void dispose() {
    _testNameController.dispose();
    _valueController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _hasUnsavedChanges) {
          final shouldLeave = await _confirmLeave();
          if (shouldLeave && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '\uB4A4\uB85C',
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (!_hasUnsavedChanges || await _confirmLeave()) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
          ),
          title: Text(
            _isEdit
                ? '\uAC80\uC0AC \uACB0\uACFC \uC218\uC815'
                : '\uAC80\uC0AC \uACB0\uACFC \uB4F1\uB85D',
          ),
          actions: [
            if (_isEdit)
              TextButton(
                onPressed: _delete,
                child: const Text(
                  '\uC0AD\uC81C',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DateField(date: _selectedDate, onTap: _pickDate),
                  const SizedBox(height: AppSpacing.md),
                  _TextInput(
                    key: const Key('lab-test-name-field'),
                    label: '\uAC80\uC0AC \uD56D\uBAA9',
                    controller: _testNameController,
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return '\uAC80\uC0AC \uD56D\uBAA9\uC744 \uC785\uB825\uD574\uC8FC\uC138\uC694.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _TextInput(
                    key: const Key('lab-value-field'),
                    label: '\uACB0\uACFC',
                    controller: _valueController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) {
                        return '\uACB0\uACFC\uAC12\uC744 \uC785\uB825\uD574\uC8FC\uC138\uC694.';
                      }
                      if (double.tryParse(text) == null) {
                        return '\uACB0\uACFC\uAC12\uC740 \uC22B\uC790\uB85C \uC785\uB825\uD574\uC8FC\uC138\uC694.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _TextInput(
                    key: const Key('lab-unit-field'),
                    label: '\uB2E8\uC704',
                    controller: _unitController,
                  ),
                  if (_formError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _formError!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    key: const Key('lab-save-button'),
                    label: _isEdit
                        ? '\uBCC0\uACBD\uC0AC\uD56D \uC800\uC7A5'
                        : '\uC800\uC7A5',
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasUnsavedChanges => _snapshot() != _initialSnapshot;

  String _snapshot() {
    return [
      LabResult.formatDateKey(_selectedDate),
      _testNameController.text,
      _valueController.text,
      _unitController.text,
    ].join('|');
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
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<bool> _confirmLeave() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '\uBCC0\uACBD\uC0AC\uD56D\uC744 \uC800\uC7A5\uD558\uC9C0 \uC54A\uC558\uC2B5\uB2C8\uB2E4.',
        ),
        content: const Text(
          '\uD654\uBA74\uC744 \uB098\uAC00\uC2DC\uACA0\uC2B5\uB2C8\uAE4C?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('\uACC4\uC18D \uC791\uC131'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('\uB098\uAC00\uAE30'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _save() async {
    setState(() {
      _formError = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final now = DateTime.now();
    final base = widget.result;
    final result = LabResult(
      id: base?.id ?? 'lab-${now.microsecondsSinceEpoch}',
      date: _selectedDate,
      testName: _testNameController.text.trim(),
      value: double.parse(_valueController.text.trim()),
      unit: _unitController.text.trim().isEmpty
          ? null
          : _unitController.text.trim(),
      createdAt: base?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await widget.service.save(result);
    } on FutureLabResultDateException {
      setState(() {
        _formError = '미래 날짜에는 검사 결과를 저장할 수 없습니다.';
      });
      return;
    } on DuplicateLabResultException {
      setState(() {
        _formError = '\uAC19\uC740 \uB0A0\uC9DC\uC758 \uAC19\uC740 \uAC80\uC0AC \uD56D\uBAA9\uC774 \uC774\uBBF8 \uC788\uC2B5\uB2C8\uB2E4.';
      });
      return;
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEdit
              ? '\u2713 \uC218\uC815\uB418\uC5C8\uC2B5\uB2C8\uB2E4.'
              : '\u2713 \uC800\uC7A5\uB418\uC5C8\uC2B5\uB2C8\uB2E4.',
        ),
      ),
    );
    Navigator.of(context).pop(result);
  }

  Future<void> _delete() async {
    final result = widget.result;
    if (result == null) {
      return;
    }
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '\uAC80\uC0AC \uACB0\uACFC\uB97C \uC0AD\uC81C\uD558\uC2DC\uACA0\uC2B5\uB2C8\uAE4C?',
        ),
        content: const Text(
          '\uC0AD\uC81C\uD55C \uAE30\uB85D\uC740 \uBCF5\uAD6C\uD560 \uC218 \uC5C6\uC2B5\uB2C8\uB2E4.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('\uCDE8\uC18C'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '\uC0AD\uC81C',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      await widget.service.delete(result.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '\uAC80\uC0AC \uB0A0\uC9DC',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          key: const Key('lab-date-field'),
          borderRadius: BorderRadius.circular(AppRadius.input),
          onTap: onTap,
          child: InputDecorator(
            decoration: _inputDecoration(),
            child: Row(
              children: [
                Expanded(child: Text(LabResult.formatDisplayDate(date))),
                const Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.secondaryText,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: _inputDecoration(),
          validator: validator,
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: const BorderSide(color: AppColors.primary),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: const BorderSide(color: AppColors.error),
    ),
  );
}
