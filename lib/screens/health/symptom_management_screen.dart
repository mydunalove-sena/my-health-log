import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/symptom.dart';
import '../../services/symptom_service.dart';

class SymptomManagementScreen extends StatefulWidget {
  const SymptomManagementScreen({super.key, required this.service});

  final SymptomService service;

  @override
  State<SymptomManagementScreen> createState() =>
      _SymptomManagementScreenState();
}

class _SymptomManagementScreenState extends State<SymptomManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String? _errorText;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('증상 관리')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        key: const Key('symptom-definition-name-field'),
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: '새 증상',
                          errorText: _errorText,
                          filled: true,
                          fillColor: AppColors.surface,
                          border: const OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _addDefinition(),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      PrimaryButton(
                        key: const Key('symptom-definition-add-button'),
                        label: _isSaving ? '저장 중' : '추가',
                        icon: Icons.add,
                        onPressed: _isSaving ? () {} : _addDefinition,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final definition in widget.service.definitions) ...[
                  _SymptomDefinitionTile(
                    definition: definition,
                    onRename: definition.isDefault
                        ? null
                        : () => _showRenameDialog(definition),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addDefinition() async {
    setState(() {
      _errorText = null;
      _isSaving = true;
    });
    try {
      await widget.service.addUserDefinition(_nameController.text);
      _nameController.clear();
    } on EmptySymptomDefinitionNameException {
      setState(() => _errorText = '증상 이름을 입력해주세요.');
    } on DuplicateSymptomDefinitionNameException {
      setState(() => _errorText = '이미 등록된 증상입니다.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showRenameDialog(SymptomDefinition definition) async {
    final controller = TextEditingController(text: definition.name);
    String? errorText;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('증상 이름 수정'),
              content: TextField(
                key: const Key('symptom-definition-rename-field'),
                controller: controller,
                decoration: InputDecoration(
                  labelText: '증상 이름',
                  errorText: errorText,
                ),
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _renameDefinition(
                  dialogContext,
                  setDialogState,
                  definition,
                  controller.text,
                  (value) => errorText = value,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('취소'),
                ),
                FilledButton(
                  key: const Key('symptom-definition-rename-save-button'),
                  onPressed: () => _renameDefinition(
                    dialogContext,
                    setDialogState,
                    definition,
                    controller.text,
                    (value) => errorText = value,
                  ),
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _renameDefinition(
    BuildContext dialogContext,
    StateSetter setDialogState,
    SymptomDefinition definition,
    String name,
    ValueChanged<String?> setErrorText,
  ) async {
    try {
      await widget.service.renameUserDefinition(definition.id, name);
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }
    } on EmptySymptomDefinitionNameException {
      setDialogState(() => setErrorText('증상 이름을 입력해주세요.'));
    } on DuplicateSymptomDefinitionNameException {
      setDialogState(() => setErrorText('이미 등록된 증상입니다.'));
    } on DefaultSymptomDefinitionRenameException {
      setDialogState(() => setErrorText('기본 증상은 수정할 수 없습니다.'));
    }
  }
}

class _SymptomDefinitionTile extends StatelessWidget {
  const _SymptomDefinitionTile({required this.definition, this.onRename});

  final SymptomDefinition definition;
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('symptom-definition-${definition.id}'),
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    definition.name,
                    key: ValueKey('symptom-definition-name-${definition.id}'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    definition.isDefault ? '기본 증상' : '사용자 증상',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            if (onRename != null)
              IconButton(
                key: ValueKey('symptom-definition-edit-${definition.id}'),
                tooltip: '수정',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onRename,
              ),
          ],
        ),
      ),
    );
  }
}
