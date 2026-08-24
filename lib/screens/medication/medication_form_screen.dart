import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/medication.dart';
import '../../services/medication_service.dart';

class MedicationFormScreen extends StatefulWidget {
  const MedicationFormScreen({
    super.key,
    required this.service,
    this.medication,
  });

  final MedicationService service;
  final Medication? medication;

  @override
  State<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends State<MedicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _doseController;
  late MedicationType _type;
  late MedicationDoseUnit _doseUnit;
  late bool _morning;
  late bool _lunch;
  late bool _evening;
  late bool _bedtime;
  String? _legacyDose;
  late final String _initialSnapshot;
  String? _timeSlotError;

  bool get _isEdit => widget.medication != null;

  @override
  void initState() {
    super.initState();
    final medication = widget.medication;
    _nameController = TextEditingController(text: medication?.name ?? '');
    _doseController = TextEditingController(
      text: medication?.doseValue == null
          ? ''
          : Medication.formatDoseValue(medication!.doseValue!),
    );
    _type = medication?.type ?? MedicationType.scheduled;
    _doseUnit = medication?.doseUnit ?? MedicationDoseUnit.tablet;
    _legacyDose = medication?.doseValue == null ? medication?.dose : null;
    _morning = medication?.morning ?? false;
    _lunch = medication?.lunch ?? false;
    _evening = medication?.evening ?? false;
    _bedtime = medication?.bedtime ?? false;
    _initialSnapshot = _snapshot();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
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
            tooltip: '뒤로',
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (!_hasUnsavedChanges || await _confirmLeave()) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
          ),
          title: Text(_isEdit ? '약 수정' : '약 등록'),
          actions: [
            if (_isEdit)
              TextButton(
                onPressed: _delete,
                child: const Text(
                  '삭제',
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
                  _TextInput(
                    key: const Key('medication-name-field'),
                    label: '약 이름',
                    controller: _nameController,
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? '약 이름을 입력해주세요.' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('복용 유형', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.xs),
                  DropdownButtonFormField<MedicationType>(
                    key: const Key('medication-type-field'),
                    initialValue: _type,
                    decoration: _inputDecoration(),
                    items: [
                      for (final type in MedicationType.values)
                        DropdownMenuItem(value: type, child: Text(type.label)),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _type = value;
                        _timeSlotError = null;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('복용량', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key('medication-dose-field'),
                          controller: _doseController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _inputDecoration(),
                          validator: _doseValidator,
                          onChanged: (_) {
                            if (_legacyDose != null) {
                              setState(() => _legacyDose = null);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(
                        width: 110,
                        child: DropdownButtonFormField<MedicationDoseUnit>(
                          key: const Key('medication-dose-unit-field'),
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
                  if (_legacyDose != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '기존 복용량: $_legacyDose',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.secondaryText),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (_type == MedicationType.scheduled) ...[
                    Text('복용 시점', style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: AppSpacing.xs),
                    _TimeSlotCheck(
                      key: const Key('medication-morning-check'),
                      label: '아침',
                      value: _morning,
                      onChanged: (value) => _setSlot(() => _morning = value),
                    ),
                    _TimeSlotCheck(
                      key: const Key('medication-lunch-check'),
                      label: '점심',
                      value: _lunch,
                      onChanged: (value) => _setSlot(() => _lunch = value),
                    ),
                    _TimeSlotCheck(
                      key: const Key('medication-evening-check'),
                      label: '저녁',
                      value: _evening,
                      onChanged: (value) => _setSlot(() => _evening = value),
                    ),
                    _TimeSlotCheck(
                      key: const Key('medication-bedtime-check'),
                      label: '취침 전',
                      value: _bedtime,
                      onChanged: (value) => _setSlot(() => _bedtime = value),
                    ),
                    if (_timeSlotError != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _timeSlotError!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ] else
                    Text(
                      '필요 시 약은 실제로 복용한 경우에만 복용 기록을 남깁니다.',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.secondaryText),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    key: const Key('medication-save-button'),
                    label: _isEdit ? '변경사항 저장' : '저장',
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

  String _snapshot() => [
    _nameController.text,
    _type.value,
    _doseController.text,
    _doseUnit.value,
    _legacyDose ?? '',
    _morning,
    _lunch,
    _evening,
    _bedtime,
  ].join('|');

  String? _doseValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null) return '복용량은 숫자로 입력해주세요.';
    if (parsed <= 0) return '복용량은 0보다 큰 값으로 입력해주세요.';
    return null;
  }

  void _setSlot(VoidCallback update) {
    setState(() {
      update();
      _timeSlotError = null;
    });
  }

  Future<bool> _confirmLeave() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('변경사항을 저장하지 않았습니다.'),
        content: const Text('화면을 나가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속 작성'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _save() async {
    setState(() => _timeSlotError = null);
    final isValid = _formKey.currentState?.validate() ?? false;
    final hasSlot = _morning || _lunch || _evening || _bedtime;
    if (_type == MedicationType.scheduled && !hasSlot) {
      setState(() => _timeSlotError = '복용 시점을 하나 이상 선택해주세요.');
    }
    if (!isValid || (_type == MedicationType.scheduled && !hasSlot)) return;

    final doseText = _doseController.text.trim();
    final doseValue = doseText.isEmpty ? null : double.parse(doseText);
    final doseTextForStorage = doseValue == null
        ? _legacyDose
        : '${Medication.formatDoseValue(doseValue)}${_doseUnit.label}';

    final now = DateTime.now();
    final base = widget.medication;
    final medication = Medication(
      id: base?.id ?? 'med-${now.microsecondsSinceEpoch}',
      name: _nameController.text.trim(),
      type: _type,
      dose: doseTextForStorage,
      doseValue: doseValue,
      doseUnit: doseValue == null ? null : _doseUnit,
      morning: _morning,
      lunch: _lunch,
      evening: _evening,
      bedtime: _bedtime,
      isActive: true,
      createdAt: base?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await widget.service.saveMedication(medication);
    } on EmptyMedicationNameException {
      _formKey.currentState?.validate();
      return;
    } on EmptyMedicationTimeSlotException {
      setState(() => _timeSlotError = '복용 시점을 하나 이상 선택해주세요.');
      return;
    } on InvalidMedicationDoseException {
      _formKey.currentState?.validate();
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEdit ? '약을 수정했습니다.' : '약을 저장했습니다.')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final medication = widget.medication;
    if (medication == null) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('약을 삭제하시겠습니까?'),
        content: const Text('현재 복약 목록에서는 더 이상 표시되지 않습니다.\n기존 복약 기록은 유지됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      await widget.service.softDeleteMedication(medication);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
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
          decoration: _inputDecoration(),
          validator: validator,
        ),
      ],
    );
  }
}

class _TimeSlotCheck extends StatelessWidget {
  const _TimeSlotCheck({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      title: Text(label),
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (value) => onChanged(value ?? false),
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
