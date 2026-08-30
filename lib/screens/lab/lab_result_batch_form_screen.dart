import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../models/lab_result.dart';
import '../../models/lab_test_definition.dart';
import '../../services/lab_result_service.dart';
import '../../services/lab_test_settings_service.dart';

class LabResultBatchFormScreen extends StatefulWidget {
  const LabResultBatchFormScreen({
    super.key,
    required this.labResultService,
    required this.labTestSettingsService,
    this.initialDate,
  });

  final LabResultService labResultService;
  final LabTestSettingsService labTestSettingsService;
  final DateTime? initialDate;

  @override
  State<LabResultBatchFormScreen> createState() =>
      _LabResultBatchFormScreenState();
}

class _LabResultBatchFormScreenState extends State<LabResultBatchFormScreen> {
  late DateTime _selectedDate;
  late final List<LabTestDefinition> _definitions;
  late final Map<String, TextEditingController> _controllers;
  String? _formError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate =
        widget.initialDate ?? DateTime(now.year, now.month, now.day);
    _definitions = widget.labTestSettingsService.enabledDefinitions;
    _controllers = {
      for (final definition in _definitions)
        definition.id: TextEditingController(),
    };
    _prefillForSelectedDate();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('검사 결과 등록')),
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
            if (_definitions.isEmpty)
              const _EmptyDefinitionNotice()
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < _definitions.length; i++) ...[
                      _LabResultInputRow(
                        definition: _definitions[i],
                        controller: _controllers[_definitions[i].id]!,
                      ),
                      if (i != _definitions.length - 1)
                        const Divider(height: 1, color: AppColors.border),
                    ],
                  ],
                ),
              ),
            if (_formError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _formError!,
                style: const TextStyle(color: AppColors.error, fontSize: 14),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                key: const Key('lab-batch-save-button'),
                onPressed: _definitions.isEmpty || _isSaving ? null : _saveAll,
                child: const Text('전체 저장'),
              ),
            ),
          ],
        ),
      ),
    );
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
        _formError = null;
        _prefillForSelectedDate();
      });
    }
  }

  Future<void> _saveAll() async {
    setState(() {
      _formError = null;
      _isSaving = true;
    });

    final now = DateTime.now();
    final existingByTestName = _existingResultsByTestName();
    final pending = <LabResult>[];
    final seenTestNames = <String>{};

    for (final definition in _definitions) {
      final testName = definition.displayName.trim();
      final normalizedName = testName.toLowerCase();
      if (!seenTestNames.add(normalizedName)) {
        setState(() {
          _formError = '같은 검사 항목이 중복되어 있습니다.';
          _isSaving = false;
        });
        return;
      }

      final text = _controllers[definition.id]!.text.trim();
      final existing = existingByTestName[normalizedName];
      if (text.isEmpty) {
        continue;
      }

      final value = double.tryParse(text);
      if (value == null || value.isNaN || value.isInfinite) {
        setState(() {
          _formError = '$testName 결과값은 숫자로 입력해주세요.';
          _isSaving = false;
        });
        return;
      }

      pending.add(
        existing == null
            ? LabResult(
                id: 'lab-${now.microsecondsSinceEpoch}-${pending.length}',
                date: _selectedDate,
                testName: testName,
                value: value,
                unit: definition.defaultUnit,
                createdAt: now,
                updatedAt: now,
              )
            : existing.copyWith(
                value: value,
                unit: definition.defaultUnit,
                clearUnit: definition.defaultUnit == null,
                updatedAt: now,
              ),
      );
    }

    try {
      for (final result in pending) {
        await widget.labResultService.save(result);
      }
    } on FutureLabResultDateException {
      if (mounted) {
        setState(() {
          _formError = '미래 날짜에는 검사 결과를 저장할 수 없습니다.';
          _isSaving = false;
        });
      }
      return;
    } on DuplicateLabResultException {
      if (mounted) {
        setState(() {
          _formError = '같은 날짜의 같은 검사 항목이 이미 있습니다.';
          _isSaving = false;
        });
      }
      return;
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('✓ 저장되었습니다.')));
    Navigator.of(context).pop(_selectedDate);
  }

  void _prefillForSelectedDate() {
    final existingByTestName = _existingResultsByTestName();
    for (final definition in _definitions) {
      final existing =
          existingByTestName[definition.displayName.trim().toLowerCase()];
      _controllers[definition.id]!.text = existing == null
          ? ''
          : LabResult.formatValue(existing.value);
    }
  }

  Map<String, LabResult> _existingResultsByTestName() {
    return {
      for (final result in widget.labResultService.resultsForDate(
        _selectedDate,
      ))
        result.testName.trim().toLowerCase(): result,
    };
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
        Text('검사 날짜', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          key: const Key('lab-batch-date-field'),
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

class _LabResultInputRow extends StatelessWidget {
  const _LabResultInputRow({
    required this.definition,
    required this.controller,
  });

  final LabTestDefinition definition;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final unit = definition.defaultUnit?.trim();
    final valueField = TextField(
      key: ValueKey('lab-batch-value-${definition.id}'),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.right,
      scrollPadding: const EdgeInsets.only(bottom: 120),
      decoration: _valueInputDecoration(),
    );
    final unitLabel = unit == null || unit.isEmpty
        ? null
        : Text(
            unit,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.secondaryText),
          );

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // On phone-width rows, protect the result field first. A second line
          // avoids letting a fixed unit column squeeze values such as 22.3.
          final useCompactLayout = constraints.maxWidth < 360;
          if (useCompactLayout) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  definition.displayName,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: valueField),
                    if (unitLabel != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(width: 96, child: unitLabel),
                    ],
                  ],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  definition.displayName,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(flex: 3, child: valueField),
              if (unitLabel != null) ...[
                const SizedBox(width: AppSpacing.sm),
                SizedBox(width: 80, child: unitLabel),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EmptyDefinitionNotice extends StatelessWidget {
  const _EmptyDefinitionNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '활성화된 검사 항목이 없습니다.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.secondaryText),
      ),
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

InputDecoration _valueInputDecoration() {
  return _inputDecoration().copyWith(
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.sm,
    ),
  );
}
