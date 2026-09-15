import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/validation/weight_input_rules.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/health_record.dart';
import '../../services/health_field_visibility_service.dart';
import '../../services/health_record_service.dart';
import '../../services/lab_ocr_service.dart';
import '../../services/weight_capture_orchestrator.dart';
import '../../services/weight_capture_parser_service.dart';
import '../../services/weight_image_picker_service.dart';
import 'weight_capture_review_screen.dart';

class HealthFormScreen extends StatefulWidget {
  const HealthFormScreen({
    super.key,
    required this.service,
    this.record,
    this.healthFieldVisibilityService,
    this.weightImagePickerService,
    this.weightOcrService,
    this.weightParserService = const WeightCaptureParserService(),
    this.weightCaptureOrchestrator,
  });

  final HealthRecordService service;
  final HealthRecord? record;
  final HealthFieldVisibilityService? healthFieldVisibilityService;
  final WeightImagePickerService? weightImagePickerService;
  final LabOcrService? weightOcrService;
  final WeightCaptureParserService weightParserService;
  final WeightCaptureOrchestrator? weightCaptureOrchestrator;

  @override
  State<HealthFormScreen> createState() => _HealthFormScreenState();
}

class _HealthFormScreenState extends State<HealthFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late final TextEditingController _weightController;
  late final TextEditingController _systolicController;
  late final TextEditingController _diastolicController;
  late final TextEditingController _waterController;
  late final TextEditingController _sleepController;
  HealthCondition? _condition;
  String? _formError;
  late final String _initialSnapshot;

  bool get _isEdit => widget.record != null;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    final now = DateTime.now();
    _selectedDate = record?.date ?? DateTime(now.year, now.month, now.day);
    _weightController = TextEditingController(
      text: _doubleInitial(record?.weight),
    );
    _systolicController = TextEditingController(
      text: record?.systolicBloodPressure?.toString() ?? '',
    );
    _diastolicController = TextEditingController(
      text: record?.diastolicBloodPressure?.toString() ?? '',
    );
    _waterController = TextEditingController(
      text: record?.waterIntake?.toString() ?? '',
    );
    _sleepController = TextEditingController(
      text: _doubleInitial(record?.sleepHours),
    );
    _condition = record?.condition;
    _initialSnapshot = _snapshot();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _waterController.dispose();
    _sleepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibility = widget.healthFieldVisibilityService;
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
          title: Text(_isEdit ? '건강 기록 수정' : '건강 기록'),
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
                  _DateField(date: _selectedDate, onTap: _pickDate),
                  const SizedBox(height: AppSpacing.md),
                  if (visibility?.weightVisible ?? true) ...[
                    _NumberField(
                      key: const Key('health-weight-field'),
                      label: '체중',
                      controller: _weightController,
                      unit: 'kg',
                      inputFormatters: [WeightInputRules.formatter],
                      validator: (value) => WeightInputRules.validate(
                        value,
                        required: false,
                      ).message,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const Key('health-weight-photo-button'),
                        onPressed: _openWeightCaptureChoice,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('사진/캡처로 입력'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (visibility?.bloodPressureVisible ?? true) ...[
                    Text('혈압', style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _NumberField(
                            key: const Key('health-systolic-field'),
                            label: '수축기',
                            controller: _systolicController,
                            unit: null,
                            validator: (value) =>
                                _bloodPressureValidator(value, '수축기'),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(
                            top: 18,
                            left: AppSpacing.xs,
                            right: AppSpacing.xs,
                          ),
                          child: Text('/'),
                        ),
                        Expanded(
                          child: _NumberField(
                            key: const Key('health-diastolic-field'),
                            label: '이완기',
                            controller: _diastolicController,
                            unit: 'mmHg',
                            validator: (value) =>
                                _bloodPressureValidator(value, '이완기'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (visibility?.waterIntakeVisible ?? true) ...[
                    _NumberField(
                      key: const Key('health-water-field'),
                      label: '수분',
                      controller: _waterController,
                      unit: 'mL',
                      validator: (value) => _positiveIntValidator(value, '수분'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (visibility?.sleepHoursVisible ?? true) ...[
                    _NumberField(
                      key: const Key('health-sleep-field'),
                      label: '수면',
                      controller: _sleepController,
                      unit: '시간',
                      validator: (value) =>
                          _positiveDoubleValidator(value, '수면'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (visibility?.conditionVisible ?? true) ...[
                    Text('컨디션', style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: AppSpacing.xs),
                    DropdownButtonFormField<HealthCondition>(
                      key: const Key('health-condition-field'),
                      initialValue: _condition,
                      decoration: _inputDecoration(null),
                      items: HealthCondition.values
                          .map(
                            (condition) => DropdownMenuItem(
                              value: condition,
                              child: Text(condition.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _condition = value;
                        });
                      },
                    ),
                  ],
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
                    key: const Key('health-save-button'),
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

  String _snapshot() {
    return [
      HealthRecord.formatDateKey(_selectedDate),
      _weightController.text,
      _systolicController.text,
      _diastolicController.text,
      _waterController.text,
      _sleepController.text,
      _condition?.value ?? '',
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

  Future<void> _openWeightCaptureChoice() async {
    final source = await showModalBottomSheet<WeightImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const Key('weight-capture-camera-button'),
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('카메라 촬영'),
                onTap: () => Navigator.pop(context, WeightImageSource.camera),
              ),
              ListTile(
                key: const Key('weight-capture-gallery-button'),
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('갤러리에서 선택'),
                onTap: () => Navigator.pop(context, WeightImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || source == null) {
      return;
    }
    await _openWeightCapture(source);
  }

  Future<void> _openWeightCapture(WeightImageSource source) async {
    final picker =
        widget.weightImagePickerService ??
        ImagePickerWeightImagePickerService();
    final imagePath = await picker.pickImage(source);
    if (!mounted || imagePath == null) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final ocr = widget.weightOcrService ?? MlKitLabOcrService();
    try {
      final orchestrator =
          widget.weightCaptureOrchestrator ??
          WeightCaptureOrchestrator(parserService: widget.weightParserService);
      final result = await orchestrator.capture(
        imagePath: imagePath,
        ocrService: ocr,
      );
      if (ocr is MlKitLabOcrService) {
        await ocr.close();
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      final savedDate = await Navigator.of(context).push<DateTime>(
        MaterialPageRoute(
          builder: (_) => WeightCaptureReviewScreen(
            service: widget.service,
            candidate: result.candidate,
            initialDate: _selectedDate,
            diagnosticDocuments: result.documents,
            showOcrDiagnostics: false,
          ),
        ),
      );
      if (mounted && savedDate != null) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (ocr is MlKitLabOcrService) {
        await ocr.close();
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => WeightCaptureReviewScreen(
            service: widget.service,
            candidate: null,
            initialDate: _selectedDate,
            showOcrDiagnostics: false,
          ),
        ),
      );
    }
  }

  Future<bool> _confirmLeave() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('변경사항을 저장하지 않았습니다'),
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
    setState(() {
      _formError = null;
    });

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    if (!_bloodPressurePairValid) {
      setState(() {
        _formError = '혈압은 수축기와 이완기를 함께 입력해 주세요.';
      });
      return;
    }

    final now = DateTime.now();
    final existingSameDate = widget.service.recordForDate(_selectedDate);
    final isDuplicateEdit =
        _isEdit &&
        existingSameDate != null &&
        existingSameDate.id != widget.record!.id;
    if (isDuplicateEdit) {
      setState(() {
        _formError = '같은 날짜의 건강 기록이 이미 있습니다.';
      });
      return;
    }

    final baseRecord = _isEdit ? widget.record! : existingSameDate;
    final record = HealthRecord(
      id: baseRecord?.id ?? 'health-${now.microsecondsSinceEpoch}',
      date: _selectedDate,
      weight: _parseDouble(_weightController.text),
      systolicBloodPressure: _parseInt(_systolicController.text),
      diastolicBloodPressure: _parseInt(_diastolicController.text),
      waterIntake: _parseInt(_waterController.text),
      steps: baseRecord?.steps,
      sleepHours: _parseDouble(_sleepController.text),
      condition: _condition,
      createdAt: baseRecord?.createdAt ?? now,
      updatedAt: now,
    );

    if (!record.hasAnyHealthValue) {
      setState(() {
        _formError = '하나 이상의 건강 항목을 입력해 주세요.';
      });
      return;
    }

    try {
      await widget.service.save(record);
    } on FutureHealthRecordDateException {
      setState(() {
        _formError = '미래 날짜에는 건강 기록을 저장할 수 없습니다.';
      });
      return;
    } on DuplicateHealthRecordException {
      setState(() {
        _formError = '같은 날짜의 건강 기록이 이미 있습니다.';
      });
      return;
    } on EmptyHealthRecordException {
      setState(() {
        _formError = '하나 이상의 건강 항목을 입력해 주세요.';
      });
      return;
    } on InvalidHealthRecordWeightException {
      setState(() {
        _formError = WeightInputRules.blockMessage;
      });
      return;
    }

    if (!mounted) {
      return;
    }
    final message = _isEdit || existingSameDate != null
        ? '기록을 수정했습니다.'
        : '기록을 저장했습니다.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final record = widget.record;
    if (record == null) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록을 삭제하시겠습니까?'),
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
      await widget.service.delete(record.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    }
  }

  bool get _bloodPressurePairValid {
    if (!(widget.healthFieldVisibilityService?.bloodPressureVisible ?? true)) {
      return true;
    }
    final hasSystolic = _systolicController.text.trim().isNotEmpty;
    final hasDiastolic = _diastolicController.text.trim().isNotEmpty;
    return hasSystolic == hasDiastolic;
  }

  String? _positiveDoubleValidator(String? value, String label) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(text);
    if (parsed == null) {
      return '$label은 숫자로 입력해 주세요.';
    }
    if (parsed <= 0) {
      return '$label은 0보다 큰 값으로 입력해 주세요.';
    }
    return null;
  }

  String? _positiveIntValidator(String? value, String label) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(text);
    if (parsed == null) {
      return '$label은 숫자로 입력해 주세요.';
    }
    if (parsed <= 0) {
      return '$label은 0보다 큰 값으로 입력해 주세요.';
    }
    return null;
  }

  String? _bloodPressureValidator(String? value, String label) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(text);
    if (parsed == null) {
      return '$label 혈압은 숫자로 입력해 주세요.';
    }
    if (parsed <= 0) {
      return '$label 혈압은 0보다 큰 값으로 입력해 주세요.';
    }
    return null;
  }

  double? _parseDouble(String value) {
    final text = value.trim();
    return text.isEmpty ? null : double.parse(text);
  }

  int? _parseInt(String value) {
    final text = value.trim();
    return text.isEmpty ? null : int.parse(text);
  }

  String _doubleInitial(double? value) {
    if (value == null) {
      return '';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
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

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.label,
    required this.controller,
    required this.validator,
    this.unit,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final String? unit;
  final FormFieldValidator<String> validator;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: inputFormatters,
          decoration: _inputDecoration(unit),
          validator: validator,
        ),
      ],
    );
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
