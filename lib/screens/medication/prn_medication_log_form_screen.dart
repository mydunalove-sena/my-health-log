import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/medication.dart';
import '../../services/medication_service.dart';

class PrnMedicationLogFormScreen extends StatefulWidget {
  const PrnMedicationLogFormScreen({
    super.key,
    required this.service,
    required this.medication,
  });

  final MedicationService service;
  final Medication medication;

  @override
  State<PrnMedicationLogFormScreen> createState() =>
      _PrnMedicationLogFormScreenState();
}

class _PrnMedicationLogFormScreenState
    extends State<PrnMedicationLogFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late final TextEditingController _doseController;
  late MedicationDoseUnit _doseUnit;
  late final TextEditingController _noteController;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedTime = TimeOfDay.fromDateTime(now);
    _doseController = TextEditingController(
      text: widget.medication.doseValue == null
          ? ''
          : Medication.formatDoseValue(widget.medication.doseValue!),
    );
    _doseUnit = widget.medication.doseUnit ?? MedicationDoseUnit.tablet;
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _doseController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('필요 시 약 복용 기록')),
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
                Text(
                  widget.medication.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (widget.medication.displayDose != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    widget.medication.displayDose!,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.secondaryText),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                _ActionField(
                  key: const Key('prn-date-field'),
                  label: '복용 날짜',
                  value: _formatDate(_selectedDate),
                  onTap: _pickDate,
                ),
                const SizedBox(height: AppSpacing.md),
                _ActionField(
                  key: const Key('prn-time-field'),
                  label: '실제 복용 시간',
                  value: MaterialLocalizations.of(context)
                      .formatTimeOfDay(_selectedTime),
                  onTap: _pickTime,
                ),
                const SizedBox(height: AppSpacing.md),
                Text('실제 복용량', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('prn-dose-field'),
                        controller: _doseController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration(),
                        validator: _doseValidator,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      width: 110,
                      child: DropdownButtonFormField<MedicationDoseUnit>(
                        key: const Key('prn-dose-unit-field'),
                        initialValue: _doseUnit,
                        decoration: _inputDecoration(),
                        items: [
                          for (final unit in MedicationDoseUnit.values)
                            DropdownMenuItem(
                              value: unit,
                              child: Text(unit.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _doseUnit = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text('메모 (선택)', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  key: const Key('prn-note-field'),
                  controller: _noteController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: _inputDecoration(),
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
                  key: const Key('prn-save-button'),
                  label: '복용 기록 저장',
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _doseValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null) return '복용량은 숫자로 입력해주세요.';
    if (parsed <= 0) return '복용량은 0보다 큰 값으로 입력해주세요.';
    return null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _formError = null;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _formError = null;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _formError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final doseText = _doseController.text.trim();
    final doseValue = doseText.isEmpty ? null : double.parse(doseText);
    final takenAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      await widget.service.recordPrnTaken(
        medication: widget.medication,
        takenAt: takenAt,
        doseValue: doseValue,
        doseUnit: doseValue == null ? null : _doseUnit,
        note: _noteController.text,
      );
    } on FuturePrnMedicationDateException {
      setState(() => _formError = '미래 날짜에는 복용 기록을 저장할 수 없습니다.');
      return;
    } on FuturePrnMedicationTimeException {
      setState(() => _formError = '현재보다 미래 시간에는 복용 기록을 저장할 수 없습니다.');
      return;
    } on InvalidMedicationDoseException {
      _formKey.currentState?.validate();
      return;
    } on InvalidPrnMedicationException {
      setState(() => _formError = '필요 시 복용약만 이 방식으로 기록할 수 있습니다.');
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('복용 기록을 저장했습니다.')));
    Navigator.of(context).pop();
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year.$month.$day';
  }
}

class _ActionField extends StatelessWidget {
  const _ActionField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: InputDecorator(
            decoration: _inputDecoration(),
            child: Row(
              children: [
                Expanded(child: Text(value)),
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
