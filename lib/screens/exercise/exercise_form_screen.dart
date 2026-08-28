import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/exercise_met_values.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/exercise_record.dart';
import '../../services/exercise_service.dart';
import '../../services/health_record_service.dart';

class ExerciseFormScreen extends StatefulWidget {
  const ExerciseFormScreen({
    super.key,
    required this.exerciseService,
    required this.healthRecordService,
    this.record,
  });

  final ExerciseService exerciseService;
  final HealthRecordService healthRecordService;
  final ExerciseRecord? record;

  @override
  State<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends State<ExerciseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late ExerciseType _exerciseType;
  late ExerciseIntensity _intensity;
  late final TextEditingController _durationController;
  String? _formError;

  bool get _isEdit => widget.record != null;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    final now = DateTime.now();
    _selectedDate = record?.date ?? DateTime(now.year, now.month, now.day);
    _exerciseType = record?.exerciseType ?? ExerciseType.walking;
    _intensity = record?.intensity ?? ExerciseIntensity.moderate;
    _durationController = TextEditingController(
      text: record?.durationMinutes.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weight = widget.healthRecordService
        .recordForDate(_selectedDate)
        ?.weight;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '운동 기록 수정' : '운동 기록'),
        actions: [
          if (_isEdit)
            TextButton(
              onPressed: _delete,
              child: const Text('삭제', style: TextStyle(color: AppColors.error)),
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
                Text('운동 종류', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<ExerciseType>(
                  key: const Key('exercise-type-field'),
                  initialValue: _exerciseType,
                  decoration: _inputDecoration(null),
                  items: ExerciseType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _exerciseType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Text('운동 시간', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  key: const Key('exercise-duration-field'),
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('분'),
                  validator: _durationValidator,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('강도', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<ExerciseIntensity>(
                  key: const Key('exercise-intensity-field'),
                  initialValue: _intensity,
                  decoration: _inputDecoration(null),
                  items: ExerciseIntensity.values
                      .map(
                        (intensity) => DropdownMenuItem(
                          value: intensity,
                          child: Text(intensity.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _intensity = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Text(_weightText(weight)),
                const SizedBox(height: AppSpacing.xs),
                Text(_previewText(weight)),
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
                  key: const Key('exercise-save-button'),
                  label: _isEdit ? '변경사항 저장' : '저장',
                  onPressed: _save,
                ),
              ],
            ),
          ),
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
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _formError = null;
    });
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }
    final now = DateTime.now();
    final record = ExerciseRecord(
      id: widget.record?.id ?? 'exercise-${now.microsecondsSinceEpoch}',
      date: _selectedDate,
      exerciseType: _exerciseType,
      durationMinutes: int.parse(_durationController.text.trim()),
      intensity: _intensity,
      weightSnapshot: widget.record?.weightSnapshot,
      metSnapshot: widget.record?.metSnapshot ?? 0,
      estimatedCalories: widget.record?.estimatedCalories,
      createdAt: widget.record?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await widget.exerciseService.save(record);
    } on FutureExerciseRecordDateException {
      setState(() {
        _formError = '미래 날짜에는 운동 기록을 저장할 수 없습니다.';
      });
      return;
    } on InvalidExerciseDurationException {
      setState(() {
        _formError = '운동 시간은 0보다 큰 값으로 입력해주세요.';
      });
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final record = widget.record;
    if (record == null) {
      return;
    }
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('운동 기록을 삭제하시겠습니까?'),
        content: const Text('삭제한 기록은 복구할 수 없습니다.'),
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
      await widget.exerciseService.delete(record.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  String? _durationValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '운동 시간을 입력해주세요.';
    }
    final parsed = int.tryParse(text);
    if (parsed == null || parsed <= 0) {
      return '운동 시간은 0보다 큰 값으로 입력해주세요.';
    }
    return null;
  }

  String _weightText(double? weight) {
    if (weight == null) {
      return '적용 체중: 당일 체중 기록 없음';
    }
    return '적용 체중: ${_formatDouble(weight)} kg';
  }

  String _previewText(double? weight) {
    final duration = int.tryParse(_durationController.text.trim());
    if (duration == null || duration <= 0) {
      return '예상 소모 칼로리 계산 불가';
    }
    final met = ExerciseMetValues.metFor(_exerciseType, _intensity);
    final calories = ExerciseMetValues.estimatedCalories(
      met: met,
      weight: weight,
      durationMinutes: duration,
    );
    if (calories == null) {
      return '예상 소모 칼로리 계산 불가';
    }
    return '예상 소모 칼로리 ${calories.round()} kcal';
  }

  String _formatDouble(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
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
        Text('날짜', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.input),
          onTap: onTap,
          child: InputDecorator(
            decoration: _inputDecoration(null),
            child: Row(
              children: [
                Expanded(child: Text(_formatDate(date))),
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

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year.$month.$day';
  }
}

InputDecoration _inputDecoration(String? unit) {
  return InputDecoration(
    suffixText: unit,
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
