import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/symptom.dart';
import '../../services/symptom_service.dart';
import 'symptom_management_screen.dart';

class SymptomRecordScreen extends StatefulWidget {
  const SymptomRecordScreen({super.key, required this.service});

  final SymptomService service;

  @override
  State<SymptomRecordScreen> createState() => _SymptomRecordScreenState();
}

class _SymptomRecordScreenState extends State<SymptomRecordScreen> {
  late DateTime _selectedDate;
  final Map<String, SymptomSeverity> _selectedSeverities = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _syncSelections();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        _ensureSelections();
        return Scaffold(
          appBar: AppBar(
            title: const Text('증상 기록'),
            actions: [
              IconButton(
                key: const Key('symptom-management-button'),
                tooltip: '증상 관리',
                icon: const Icon(Icons.manage_search_outlined),
                onPressed: _openSymptomManagement,
              ),
            ],
          ),
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
                for (final definition in widget.service.definitions) ...[
                  _SymptomSeverityCard(
                    definition: definition,
                    severity:
                        _selectedSeverities[definition.id] ??
                        SymptomSeverity.none,
                    onChanged: (severity) {
                      setState(() {
                        _selectedSeverities[definition.id] = severity;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  key: const Key('symptom-save-button'),
                  label: _isSaving ? '저장 중' : '저장',
                  onPressed: _isSaving ? () {} : _save,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(today) ? today : _selectedDate,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _syncSelections();
      });
    }
  }

  Future<void> _openSymptomManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SymptomManagementScreen(service: widget.service),
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });
    final now = DateTime.now();
    var offset = 0;
    for (final definition in widget.service.definitions) {
      await widget.service.saveSeverity(
        date: _selectedDate,
        symptomDefinitionId: definition.id,
        severity: _selectedSeverities[definition.id] ?? SymptomSeverity.none,
        now: now.add(Duration(microseconds: offset++)),
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
      _syncSelections();
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('증상 기록을 저장했습니다.')));
  }

  void _syncSelections() {
    _selectedSeverities
      ..clear()
      ..addEntries(
        widget.service
            .recordsForDate(_selectedDate)
            .map(
              (record) => MapEntry(record.symptomDefinitionId, record.severity),
            ),
      );
    _ensureSelections();
  }

  void _ensureSelections() {
    for (final definition in widget.service.definitions) {
      _selectedSeverities.putIfAbsent(
        definition.id,
        () => SymptomSeverity.none,
      );
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
        Text('날짜', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          key: const Key('symptom-date-field'),
          borderRadius: BorderRadius.circular(AppRadius.input),
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
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
            ),
            child: Row(
              children: [
                Expanded(child: Text(SymptomRecord.formatDisplayDate(date))),
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

class _SymptomSeverityCard extends StatelessWidget {
  const _SymptomSeverityCard({
    required this.definition,
    required this.severity,
    required this.onChanged,
  });

  final SymptomDefinition definition;
  final SymptomSeverity severity;
  final ValueChanged<SymptomSeverity> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('symptom-card-${definition.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(definition.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<SymptomSeverity>(
            key: ValueKey('symptom-severity-${definition.id}'),
            initialValue: severity,
            decoration: const InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(),
            ),
            items: SymptomSeverity.values
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.label)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onChanged(value);
              }
            },
          ),
        ],
      ),
    );
  }
}
