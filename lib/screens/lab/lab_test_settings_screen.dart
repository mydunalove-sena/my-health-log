import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/lab_test_definitions.dart';
import '../../models/lab_test_definition.dart';
import '../../services/lab_test_settings_service.dart';

class LabTestSettingsScreen extends StatelessWidget {
  const LabTestSettingsScreen({super.key, required this.service});

  final LabTestSettingsService service;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('검사 설정')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              children: [
                Text('관리 유형', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                _ManagementTypeList(service: service),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '사용할 검사 항목',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('lab-settings-add-custom-button'),
                      onPressed: () => _showAddCustomDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('검사 항목 추가'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        for (
                          var i = 0;
                          i < service.allDefinitions.length;
                          i++
                        ) ...[
                          _DefinitionCheckbox(
                            definition: service.allDefinitions[i],
                            enabled: service.enabledLabTestIds.contains(
                              service.allDefinitions[i].id,
                            ),
                            onChanged: (value) => _setDefinitionEnabled(
                              service.allDefinitions[i].id,
                              value,
                            ),
                          ),
                          if (i != service.allDefinitions.length - 1)
                            const Divider(height: 1, color: AppColors.border),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _setDefinitionEnabled(String id, bool enabled) async {
    final ids = List<String>.of(service.enabledLabTestIds);
    if (enabled) {
      if (!ids.contains(id)) {
        ids.add(id);
      }
    } else {
      ids.remove(id);
    }
    await service.setEnabledLabTestIds(ids);
  }

  Future<void> _showAddCustomDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AddCustomLabTestDialog(service: service),
    );
  }
}

class _ManagementTypeList extends StatelessWidget {
  const _ManagementTypeList({required this.service});

  final LabTestSettingsService service;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            for (var i = 0; i < LabManagementType.values.length; i++) ...[
              ListTile(
                key: Key(
                  'lab-management-type-${LabManagementType.values[i].id}',
                ),
                leading: Icon(
                  LabManagementType.values[i] == service.managementType
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(LabManagementType.values[i].displayName),
                onTap: () => _selectType(context, LabManagementType.values[i]),
              ),
              if (i != LabManagementType.values.length - 1)
                const Divider(height: 1, color: AppColors.border),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectType(BuildContext context, LabManagementType type) async {
    if (type == service.managementType) {
      return;
    }

    final shouldApply =
        !_hasPersonalizedEnabledList(service) ||
        await _confirmPresetChange(context);
    if (!shouldApply) {
      return;
    }
    await service.setManagementType(type);
  }

  bool _hasPersonalizedEnabledList(LabTestSettingsService service) {
    final preset = defaultLabTestIdsByManagementType[service.managementType]!;
    final enabled = service.enabledLabTestIds;
    if (enabled.length != preset.length) {
      return true;
    }
    for (var i = 0; i < preset.length; i++) {
      if (enabled[i] != preset[i]) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _confirmPresetChange(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('관리 유형 변경'),
        content: const Text('관리 유형을 변경하면 선택된 검사 항목이 새 기본 검사 세트로 변경됩니다.'),
        actions: [
          TextButton(
            key: const Key('lab-management-change-cancel-button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            key: const Key('lab-management-change-confirm-button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('변경'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}

class _DefinitionCheckbox extends StatelessWidget {
  const _DefinitionCheckbox({
    required this.definition,
    required this.enabled,
    required this.onChanged,
  });

  final LabTestDefinition definition;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final unit = definition.defaultUnit?.trim();
    return CheckboxListTile(
      key: Key('lab-definition-checkbox-${definition.id}'),
      title: Text(definition.displayName),
      subtitle: unit == null || unit.isEmpty ? null : Text(unit),
      value: enabled,
      onChanged: (value) => onChanged(value ?? false),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}

class _AddCustomLabTestDialog extends StatefulWidget {
  const _AddCustomLabTestDialog({required this.service});

  final LabTestSettingsService service;

  @override
  State<_AddCustomLabTestDialog> createState() =>
      _AddCustomLabTestDialogState();
}

class _AddCustomLabTestDialogState extends State<_AddCustomLabTestDialog> {
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  String? _error;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('검사 항목 추가'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('lab-custom-name-field'),
            controller: _nameController,
            decoration: const InputDecoration(labelText: '검사 항목명'),
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('lab-custom-unit-field'),
            controller: _unitController,
            decoration: const InputDecoration(labelText: '기본 단위'),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        TextButton(
          key: const Key('lab-custom-save-button'),
          onPressed: _isSaving ? null : _save,
          child: const Text('추가'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _isSaving = true;
    });
    try {
      await widget.service.addCustomDefinition(
        displayName: _nameController.text,
        defaultUnit: _unitController.text,
      );
    } on EmptyCustomLabTestNameException {
      setState(() {
        _error = '검사 항목명을 입력해주세요.';
        _isSaving = false;
      });
      return;
    } on DuplicateLabTestDefinitionException {
      setState(() {
        _error = '이미 등록된 검사 항목입니다.';
        _isSaving = false;
      });
      return;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
