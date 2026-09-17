import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../models/lab_capture_candidate.dart';
import '../../models/lab_result.dart';
import '../../models/lab_test_definition.dart';
import '../../services/lab_capture_mapping_service.dart';
import '../../services/lab_result_service.dart';
import '../../services/lab_test_settings_service.dart';

typedef AddLabCapturePhotos =
    Future<List<ParsedLabCaptureCandidate>> Function();

class LabCaptureReviewScreen extends StatefulWidget {
  const LabCaptureReviewScreen({
    super.key,
    required this.labResultService,
    required this.labTestSettingsService,
    required this.candidates,
    this.initialDate,
    this.onPickAgain,
    this.onDirectInput,
    this.onAddPhotos,
  });

  final LabResultService labResultService;
  final LabTestSettingsService labTestSettingsService;
  final List<LabCaptureCandidate> candidates;
  final DateTime? initialDate;
  final VoidCallback? onPickAgain;
  final VoidCallback? onDirectInput;
  final AddLabCapturePhotos? onAddPhotos;

  @override
  State<LabCaptureReviewScreen> createState() => _LabCaptureReviewScreenState();
}

class _LabCaptureReviewScreenState extends State<LabCaptureReviewScreen> {
  late DateTime _selectedDate;
  late final List<LabCaptureCandidate> _candidates;
  final Map<String, TextEditingController> _valueControllers = {};
  String? _formError;
  bool _isSaving = false;
  bool _isAddingPhotos = false;
  int _addedBatchCount = 0;
  final Set<String> _enablingCandidateIds = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate =
        widget.initialDate ??
        _singleRecognizedDate(widget.candidates) ??
        DateTime(now.year, now.month, now.day);
    _candidates = [for (final candidate in widget.candidates) candidate];
    for (final candidate in _candidates) {
      _valueControllers[candidate.id] = TextEditingController(
        text: formatLabCaptureValue(candidate.value),
      );
      if (!_isCandidateEnabled(candidate)) {
        candidate.isSelected = false;
      }
    }
    _refreshExistingRows();
  }

  @override
  void dispose() {
    for (final controller in _valueControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCandidates = _candidates.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('사진 분석 결과')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: [
            if (!hasCandidates)
              _FailurePanel(
                onPickAgain: widget.onPickAgain,
                onDirectInput: widget.onDirectInput,
              )
            else ...[
              _DateField(date: _selectedDate, onTap: _pickDate),
              const SizedBox(height: AppSpacing.md),
              for (final candidate in _candidates) ...[
                _CandidateTile(
                  candidate: candidate,
                  definitions: widget.labTestSettingsService.allDefinitions,
                  valueController: _valueControllers[candidate.id]!,
                  isEnabled: _isCandidateEnabled(candidate),
                  isEnabling: _enablingCandidateIds.contains(candidate.id),
                  onEnable: () => _enableCandidate(candidate),
                  onChanged: () => setState(_refreshExistingRows),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (_formError != null) ...[
                Text(
                  _formError!,
                  style: const TextStyle(color: AppColors.error),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('lab-capture-cancel-button'),
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('lab-capture-pick-again-button'),
                      onPressed: _isSaving ? null : widget.onPickAgain,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('다시 선택'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('lab-capture-add-photos-button'),
                  onPressed: _isSaving || _isAddingPhotos ? null : _addPhotos,
                  icon: _isAddingPhotos
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('+ 사진 추가'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton(
                  key: const Key('lab-capture-save-button'),
                  onPressed: _isSaving ? null : _save,
                  child: const Text('확인 후 저장'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isCandidateEnabled(LabCaptureCandidate candidate) {
    final definition = candidate.definition;
    return definition != null &&
        widget.labTestSettingsService.enabledLabTestIds.contains(definition.id);
  }

  Future<void> _enableCandidate(LabCaptureCandidate candidate) async {
    final definition = candidate.definition;
    if (definition == null || _enablingCandidateIds.contains(candidate.id)) {
      return;
    }
    _syncEditedValues();
    setState(() => _enablingCandidateIds.add(candidate.id));
    try {
      await widget.labTestSettingsService.enableLabTest(definition.id);
      if (!mounted) return;
      setState(() {
        if (!candidate.hasImportConflict && !candidate.hasExistingSameValue) {
          candidate.isSelected = true;
        }
        _refreshExistingRows();
      });
    } finally {
      if (mounted) {
        setState(() => _enablingCandidateIds.remove(candidate.id));
      }
    }
  }

  Future<void> _addPhotos() async {
    final addPhotos = widget.onAddPhotos;
    if (addPhotos == null) return;
    _syncEditedValues();
    setState(() {
      _formError = null;
      _isAddingPhotos = true;
    });
    try {
      final parsed = await addPhotos();
      if (!mounted || parsed.isEmpty) return;
      final additions =
          LabCaptureMappingService(widget.labTestSettingsService.allDefinitions)
              .map(
                parsed,
                date: _selectedDate,
                existingResults: widget.labResultService.resultsForDate(
                  _selectedDate,
                ),
                idPrefix: 'added-${_addedBatchCount++}-',
              );
      setState(() {
        for (final addition in additions) {
          _mergeCandidate(addition);
        }
        _refreshExistingRows();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _formError = '추가 사진을 분석하지 못했습니다. 다시 시도해 주세요.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingPhotos = false);
      }
    }
  }

  void _syncEditedValues() {
    for (final candidate in _candidates) {
      final value = double.tryParse(
        _valueControllers[candidate.id]?.text.trim() ?? '',
      );
      if (value != null && !value.isNaN && !value.isInfinite) {
        candidate.value = value;
      }
    }
  }

  void _mergeCandidate(LabCaptureCandidate addition) {
    final mapping = LabCaptureMappingService(
      widget.labTestSettingsService.allDefinitions,
    );
    final additionKey = mapping.canonicalKeyForName(addition.displayName);
    final matches = _candidates.where(
      (candidate) =>
          mapping.canonicalKeyForName(candidate.displayName) == additionKey,
    );
    for (final existing in matches) {
      if (existing.value == addition.value &&
          _normalizedUnit(existing.saveUnit) ==
              _normalizedUnit(addition.saveUnit)) {
        for (final index in addition.sourceImageIndices) {
          if (!existing.sourceImageIndices.contains(index)) {
            existing.sourceImageIndices.add(index);
          }
        }
        return;
      }
      existing.hasImportConflict = true;
      existing.isSelected = false;
      addition.hasImportConflict = true;
      addition.isSelected = false;
    }
    _candidates.add(addition);
    _valueControllers[addition.id] = TextEditingController(
      text: formatLabCaptureValue(addition.value),
    );
  }

  String _normalizedUnit(String? value) =>
      (value ?? '').replaceAll(RegExp(r'[()\\s]'), '').toLowerCase();

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
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _refreshExistingRows();
    });
  }

  Future<void> _save() async {
    setState(() {
      _formError = null;
      _isSaving = true;
    });
    final selected = _candidates.where((candidate) => candidate.isSelected);
    final pending = <LabResult>[];
    final seenNames = <String>{};
    for (final candidate in selected) {
      if (!candidate.isMapped) {
        setState(() {
          _formError = '검사 항목을 선택하지 않은 결과가 있습니다.';
          _isSaving = false;
        });
        return;
      }
      if (!_isCandidateEnabled(candidate)) {
        setState(() {
          _formError = '${candidate.displayName} 검사를 먼저 검사 목록에 추가해 주세요.';
          _isSaving = false;
        });
        return;
      }
      if (candidate.hasImportConflict) {
        setState(() {
          _formError = '같은 검사 항목의 서로 다른 인식값을 먼저 확인해 주세요.';
          _isSaving = false;
        });
        return;
      }
      final value = double.tryParse(
        _valueControllers[candidate.id]!.text.trim(),
      );
      if (value == null || value.isNaN || value.isInfinite) {
        setState(() {
          _formError = '${candidate.displayName} 결과값을 숫자로 입력해 주세요.';
          _isSaving = false;
        });
        return;
      }
      candidate.value = value;
      final name = candidate.displayName.trim().toLowerCase();
      if (!seenNames.add(name)) {
        setState(() {
          _formError = '저장할 검사 항목이 중복되어 있습니다.';
          _isSaving = false;
        });
        return;
      }
      if (candidate.hasExistingSameValue) {
        continue;
      }
      pending.add(candidate.toLabResult(_selectedDate, DateTime.now()));
    }
    if (pending.isEmpty) {
      setState(() {
        _formError = '저장할 검사 결과를 선택해 주세요.';
        _isSaving = false;
      });
      return;
    }

    try {
      for (final result in pending) {
        await widget.labResultService.save(result);
      }
    } on FutureLabResultDateException {
      setState(() {
        _formError = '미래 날짜에는 검사 결과를 저장할 수 없습니다.';
        _isSaving = false;
      });
      return;
    } on DuplicateLabResultException {
      setState(() {
        _formError = '같은 날짜에 같은 검사 항목이 이미 있습니다.';
        _isSaving = false;
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(_selectedDate);
  }

  void _refreshExistingRows() {
    final mappingService = LabCaptureMappingService(
      widget.labTestSettingsService.allDefinitions,
    );
    final existingResults = widget.labResultService.resultsForDate(
      _selectedDate,
    );
    for (final candidate in _candidates) {
      final controller = _valueControllers[candidate.id];
      final editedValue = controller == null
          ? null
          : double.tryParse(controller.text.trim());
      if (editedValue != null &&
          !editedValue.isNaN &&
          !editedValue.isInfinite) {
        candidate.value = editedValue;
      }
      candidate.existingResult = mappingService.existingForCandidate(
        candidate,
        existingResults,
      );
      if (!_isCandidateEnabled(candidate)) {
        candidate.isSelected = false;
      }
      if (candidate.hasExistingSameValue) {
        candidate.isSelected = false;
      }
    }
  }

  DateTime? _singleRecognizedDate(List<LabCaptureCandidate> candidates) {
    final keys = <String, DateTime>{};
    for (final candidate in candidates) {
      final date = candidate.date;
      if (date != null) {
        keys[LabResult.formatDateKey(date)] = date;
      }
    }
    return keys.length == 1 ? keys.values.single : null;
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.candidate,
    required this.definitions,
    required this.valueController,
    required this.isEnabled,
    required this.isEnabling,
    required this.onEnable,
    required this.onChanged,
  });

  final LabCaptureCandidate candidate;
  final List<LabTestDefinition> definitions;
  final TextEditingController valueController;
  final bool isEnabled;
  final bool isEnabling;
  final VoidCallback onEnable;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final unit = candidate.saveUnit;
    return Container(
      key: ValueKey('lab-capture-candidate-${candidate.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: AppColors.surface,
            child: CheckboxListTile(
              key: ValueKey('lab-capture-check-${candidate.id}'),
              value: candidate.isSelected,
              contentPadding: EdgeInsets.zero,
              onChanged: !candidate.isMapped || !isEnabled
                  ? null
                  : (value) {
                      candidate.isSelected = value ?? false;
                      onChanged();
                    },
              title: Text(candidate.displayName),
              subtitle: Text(candidate.rawTestName),
            ),
          ),
          DropdownButtonFormField<LabTestDefinition>(
            key: ValueKey('lab-capture-map-${candidate.id}'),
            initialValue: candidate.definition,
            decoration: const InputDecoration(labelText: '검사 항목'),
            items: [
              for (final definition in definitions)
                DropdownMenuItem(
                  value: definition,
                  child: Text(definition.displayName),
                ),
            ],
            onChanged: (definition) {
              if (definition != null) {
                candidate.mapTo(definition);
                onChanged();
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            key: ValueKey('lab-capture-value-${candidate.id}'),
            controller: valueController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(labelText: '결과값', suffixText: unit),
            onChanged: (_) => onChanged(),
          ),
          if (!candidate.isMapped)
            const _Notice(text: '검사 항목 선택 필요', color: AppColors.error),
          if (candidate.isMapped && !isEnabled) ...[
            const _Notice(text: '현재 검사 목록에 없는 항목입니다.', color: AppColors.error),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              key: ValueKey('lab-capture-enable-${candidate.id}'),
              onPressed: isEnabling ? null : onEnable,
              icon: isEnabling
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.playlist_add),
              label: const Text('검사 목록에 추가'),
            ),
          ],
          if (candidate.hasImportConflict)
            const _Notice(
              text: '같은 검사 항목에서 서로 다른 값이 인식되었습니다.',
              color: AppColors.error,
            ),
          if (candidate.hasExistingSameValue)
            const _Notice(
              text: '이미 같은 값이 저장되어 있습니다.',
              color: AppColors.secondaryText,
            ),
          if (candidate.hasExistingConflict)
            _Notice(
              text:
                  '기존값: ${candidate.existingResult!.displayValue} / 인식값: ${formatLabCaptureValue(candidate.value)} ${unit ?? ''}',
              color: AppColors.error,
            ),
          if (candidate.hasUnitWarning)
            const _Notice(text: '인식 단위와 설정 단위가 다릅니다.', color: AppColors.error),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(text, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('lab-capture-date-field'),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(labelText: '검사 날짜'),
        child: Row(
          children: [
            Expanded(child: Text(LabResult.formatDisplayDate(date))),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

class _FailurePanel extends StatelessWidget {
  const _FailurePanel({this.onPickAgain, this.onDirectInput});

  final VoidCallback? onPickAgain;
  final VoidCallback? onDirectInput;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xl),
        const Icon(Icons.image_not_supported_outlined, size: 52),
        const SizedBox(height: AppSpacing.md),
        const Text('사진에서 검사 결과를 정확히 찾지 못했습니다.'),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          key: const Key('lab-capture-failure-pick-again-button'),
          onPressed: onPickAgain,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('다시 선택'),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          key: const Key('lab-capture-failure-direct-button'),
          onPressed: onDirectInput,
          child: const Text('직접 입력'),
        ),
      ],
    );
  }
}
