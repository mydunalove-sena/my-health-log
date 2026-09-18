import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/lab_test_definitions.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/lab_result.dart';
import '../../models/lab_capture_candidate.dart';
import '../../models/lab_test_definition.dart';
import '../../services/lab_capture_mapping_service.dart';
import '../../services/lab_image_picker_service.dart';
import '../../services/lab_ocr_service.dart';
import '../../services/lab_result_service.dart';
import '../../services/lab_test_settings_service.dart';
import '../../services/severance_lab_ocr_parser.dart';
import 'lab_capture_review_screen.dart';
import 'lab_result_batch_form_screen.dart';
import 'lab_result_form_screen.dart';
import 'lab_test_settings_screen.dart';

class LabScreen extends StatelessWidget {
  const LabScreen({
    super.key,
    required this.service,
    this.labTestSettingsService,
    this.imagePickerService,
    this.ocrService,
  });

  final LabResultService service;
  final LabTestSettingsService? labTestSettingsService;
  final LabImagePickerService? imagePickerService;
  final LabOcrService? ocrService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final groups = service.groups;
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('\uAC80\uC0AC \uACB0\uACFC'),
                if (labTestSettingsService != null)
                  Text(
                    labTestSettingsService!.managementType.displayName,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
            actions: [
              if (labTestSettingsService != null)
                PopupMenuButton<LabManagementType>(
                  key: const Key('lab-profile-menu-button'),
                  tooltip: '검사 프로필 선택',
                  icon: const Icon(Icons.menu),
                  onSelected: (type) => _selectProfile(context, type),
                  itemBuilder: (context) => [
                    for (final type in visibleLabManagementTypes)
                      PopupMenuItem(
                        key: Key('lab-profile-${type.id}'),
                        value: type,
                        child: Row(
                          children: [
                            Icon(
                              type == labTestSettingsService!.managementType
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(type.displayName),
                          ],
                        ),
                      ),
                  ],
                ),
              IconButton(
                key: const Key('lab-settings-button'),
                tooltip: '\uAC80\uC0AC \uC124\uC815',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => _openSettings(context),
              ),
              IconButton(
                key: const Key('lab-add-button'),
                tooltip: '\uAC80\uC0AC \uACB0\uACFC \uB4F1\uB85D',
                icon: const Icon(Icons.add),
                onPressed: () => _openInputChoice(context),
              ),
            ],
          ),
          body: SafeArea(
            child: groups.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Center(
                      child: EmptyState(
                        icon: Icons.science_outlined,
                        message: '\uAC80\uC0AC \uACB0\uACFC\uAC00 \uC5C6\uC2B5\uB2C8\uB2E4.\n\n\uBCD1\uC6D0 \uAC80\uC0AC \uACB0\uACFC\uB97C \uAE30\uB85D\uD558\uACE0\n\uC774\uC804 \uC218\uCE58\uC640 \uBE44\uAD50\uD574\uBCF4\uC138\uC694.',
                        action: PrimaryButton(
                          label: '+ \uAC80\uC0AC \uACB0\uACFC \uB4F1\uB85D',
                          onPressed: () => _openInputChoice(context),
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.xxl,
                    ),
                    itemCount: groups.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return _LabDateGroupCard(
                        group: group,
                        onTap: () => _openDetail(context, group.date),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Future<void> _selectProfile(
    BuildContext context,
    LabManagementType type,
  ) async {
    final settings = labTestSettingsService;
    if (settings == null || type == settings.managementType) return;
    final preset = defaultLabTestIdsByManagementType[settings.managementType]!;
    final enabled = settings.enabledLabTestIds;
    final personalized =
        enabled.length != preset.length ||
        List.generate(
          enabled.length,
          (index) => index,
        ).any((index) => enabled[index] != preset[index]);
    if (personalized) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('관리 유형 변경'),
          content: const Text('관리 유형을 변경하면 선택한 검사 항목이 새 프로필의 기본 검사 세트로 변경됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              key: const Key('lab-profile-change-confirm-button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('변경'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await settings.setManagementType(type);
  }

  Future<void> _openInputChoice(
    BuildContext context, {
    DateTime? initialDate,
    bool showSavedDetail = true,
  }) async {
    final choice = await showModalBottomSheet<_LabInputChoice>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('검사 항목 추가', style: Theme.of(context).textTheme.titleMedium),
              ListTile(
                key: const Key('lab-direct-input-button'),
                leading: const Icon(Icons.edit_outlined),
                title: const Text('직접 입력'),
                subtitle: const Text('검사명과 결과값을 직접 입력합니다.'),
                onTap: () => Navigator.of(context).pop(_LabInputChoice.direct),
              ),
              ListTile(
                key: const Key('lab-photo-input-button'),
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('사진으로 입력'),
                subtitle: const Text('검사 결과 사진에서 값을 가져옵니다.'),
                onTap: () => Navigator.of(context).pop(_LabInputChoice.photo),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case _LabInputChoice.direct:
        await _openForm(
          context,
          initialDate: initialDate,
          showSavedDetail: showSavedDetail,
        );
      case _LabInputChoice.photo:
        await _openPhotoCapture(
          context,
          initialDate: initialDate,
          showSavedDetail: showSavedDetail,
        );
    }
  }

  Future<void> _openSettings(BuildContext context) async {
    final settingsService = labTestSettingsService;
    final fallbackSettingsService = settingsService == null
        ? LabTestSettingsService.inMemory()
        : null;
    if (fallbackSettingsService != null) {
      await fallbackSettingsService.load();
    }
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LabTestSettingsScreen(
          service: settingsService ?? fallbackSettingsService!,
        ),
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context, {
    DateTime? initialDate,
    bool showSavedDetail = true,
  }) async {
    final settingsService = labTestSettingsService;
    final fallbackSettingsService = settingsService == null
        ? LabTestSettingsService.inMemory()
        : null;
    if (fallbackSettingsService != null) {
      await fallbackSettingsService.load();
    }
    if (!context.mounted) {
      return;
    }
    final savedDate = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(
        builder: (_) => LabResultBatchFormScreen(
          labResultService: service,
          labTestSettingsService: settingsService ?? fallbackSettingsService!,
          initialDate: initialDate,
        ),
      ),
    );
    if (context.mounted && savedDate != null) {
      if (showSavedDetail) {
        await _openDetail(context, savedDate);
      } else if (initialDate != null &&
          LabResult.formatDateKey(savedDate) !=
              LabResult.formatDateKey(initialDate)) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _openPhotoCapture(
    BuildContext context, {
    DateTime? initialDate,
    bool showSavedDetail = true,
  }) async {
    final settingsService = labTestSettingsService;
    final fallbackSettingsService = settingsService == null
        ? LabTestSettingsService.inMemory()
        : null;
    if (fallbackSettingsService != null) {
      await fallbackSettingsService.load();
    }
    final activeSettings = settingsService ?? fallbackSettingsService!;
    final picker = imagePickerService ?? ImagePickerLabImagePickerService();
    final imagePaths = await picker.pickImages();
    if (!context.mounted || imagePaths.isEmpty) return;
    final processedPaths = imagePaths.toSet();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    var candidates = <LabCaptureCandidate>[];
    var reviewDate = initialDate;
    try {
      final documents = await _recognizeImages(imagePaths);
      final parsed = const SeveranceLabOcrParser().parse(documents);
      reviewDate ??= _reviewDate(parsed.map((item) => item.date));
      candidates = LabCaptureMappingService(activeSettings.allDefinitions).map(
        parsed,
        date: reviewDate,
        existingResults: service.resultsForDate(reviewDate ?? DateTime.now()),
      );
    } catch (_) {
      // The same Review route exposes retry/direct input for OCR failure.
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();
    final savedDate = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(
        builder: (_) => LabCaptureReviewScreen(
          labResultService: service,
          labTestSettingsService: activeSettings,
          candidates: candidates,
          initialDate: reviewDate,
          onAddPhotos: () async {
            final pickedPaths = await picker.pickImages();
            final newPaths = [
              for (final path in pickedPaths)
                if (processedPaths.add(path)) path,
            ];
            if (newPaths.isEmpty) return const [];
            final addedDocuments = await _recognizeImages(newPaths);
            return const SeveranceLabOcrParser().parse(addedDocuments);
          },
          onPickAgain: () {
            Navigator.of(context).pop();
            _openPhotoCapture(
              context,
              initialDate: initialDate,
              showSavedDetail: showSavedDetail,
            );
          },
          onDirectInput: () {
            Navigator.of(context).pop();
            _openForm(
              context,
              initialDate: initialDate,
              showSavedDetail: showSavedDetail,
            );
          },
        ),
      ),
    );
    if (context.mounted && savedDate != null && showSavedDetail) {
      await _openDetail(context, savedDate);
    }
  }

  Future<List<LabOcrDocument>> _recognizeImages(List<String> imagePaths) async {
    final ocr = ocrService ?? MlKitLabOcrService();
    try {
      return await ocr.recognize(imagePaths);
    } finally {
      if (ocrService == null && ocr is MlKitLabOcrService) {
        await ocr.close();
      }
    }
  }

  DateTime? _reviewDate(Iterable<DateTime?> dates) {
    final values = {
      for (final date in dates.whereType<DateTime>())
        LabResult.formatDateKey(date): date,
    };
    return values.length == 1 ? values.values.single : null;
  }

  Future<void> _openDetail(BuildContext context, DateTime date) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LabResultDetailScreen(
          service: service,
          date: date,
          onAddResults: (detailContext) => _openInputChoice(
            detailContext,
            initialDate: date,
            showSavedDetail: false,
          ),
        ),
      ),
    );
  }
}

enum _LabInputChoice { direct, photo }

class LabResultDetailScreen extends StatelessWidget {
  const LabResultDetailScreen({
    super.key,
    required this.service,
    required this.date,
    required this.onAddResults,
  });

  final LabResultService service;
  final DateTime date;
  final Future<void> Function(BuildContext) onAddResults;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final results = service.resultsForDate(date);
        return Scaffold(
          appBar: AppBar(title: const Text('\uAC80\uC0AC \uACB0\uACFC')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              children: [
                Text(
                  LabResult.formatDisplayDate(date),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                if (results.isEmpty)
                  EmptyState(
                    icon: Icons.science_outlined,
                    message: '\uAC80\uC0AC \uACB0\uACFC\uAC00 \uC5C6\uC2B5\uB2C8\uB2E4.',
                    action: PrimaryButton(
                      key: const Key('lab-detail-add-button'),
                      label: '+ \uAC80\uC0AC \uD56D\uBAA9 \uCD94\uAC00',
                      onPressed: () => onAddResults(context),
                    ),
                  )
                else ...[
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < results.length; i++) ...[
                          _LabResultRow(
                            key: ValueKey('lab-result-${results[i].id}'),
                            result: results[i],
                            onTap: () => _editResult(context, results[i]),
                            onEdit: () => _editResult(context, results[i]),
                            onDelete: () => _deleteResult(context, results[i]),
                          ),
                          if (i != results.length - 1)
                            const Divider(height: 1, color: AppColors.border),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    key: const Key('lab-detail-add-button'),
                    label: '+ \uAC80\uC0AC \uD56D\uBAA9 \uCD94\uAC00',
                    onPressed: () => onAddResults(context),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editResult(BuildContext context, LabResult result) async {
    final saved = await Navigator.of(context).push<LabResult>(
      MaterialPageRoute(
        builder: (_) => LabResultFormScreen(
          service: service,
          result: result,
          initialDate: date,
        ),
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (service.resultsForDate(date).isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    if (saved is LabResult && saved.dateKey != LabResult.formatDateKey(date)) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteResult(BuildContext context, LabResult result) async {
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
            key: const Key('lab-detail-confirm-delete-button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '\uC0AD\uC81C',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (shouldDelete != true) {
      return;
    }
    await service.delete(result.id);
    if (context.mounted && service.resultsForDate(date).isEmpty) {
      Navigator.of(context).pop();
    }
  }
}

class _LabDateGroupCard extends StatelessWidget {
  const _LabDateGroupCard({required this.group, required this.onTap});

  final LabResultDateGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('lab-group-${group.dateKey}'),
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      LabResult.formatDisplayDate(group.date),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.secondaryText,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final result in group.results)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          result.testName,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        result.displayValue,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabResultRow extends StatelessWidget {
  const _LabResultRow({
    super.key,
    required this.result,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final LabResult result;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.testName,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        result.displayValue,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.secondaryText),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.secondaryText),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                OutlinedButton.icon(
                  key: ValueKey('lab-edit-${result.id}'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('\uC218\uC815'),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton.icon(
                  key: ValueKey('lab-delete-${result.id}'),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text(
                    '\uC0AD\uC81C',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
