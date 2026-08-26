import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/health_record.dart';
import '../../services/health_record_service.dart';
import '../../services/symptom_service.dart';
import 'health_form_screen.dart';
import 'symptom_record_screen.dart';

class HealthScreen extends StatelessWidget {
  const HealthScreen({
    super.key,
    required this.service,
    required this.symptomService,
  });

  final HealthRecordService service;
  final SymptomService symptomService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final records = service.records;
        return Scaffold(
          appBar: AppBar(
            title: const Text('건강 기록'),
            actions: [
              IconButton(
                tooltip: '증상 기록',
                icon: const Icon(
                  Icons.sick_outlined,
                  key: Key('symptom-record-button'),
                ),
                onPressed: () => _openSymptomRecord(context),
              ),
              IconButton(
                tooltip: '건강 기록 추가',
                icon: const Icon(Icons.add, key: Key('health-add-button')),
                onPressed: () => _openForm(context),
              ),
            ],
          ),
          body: SafeArea(
            child: records.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Center(
                      child: EmptyState(
                        icon: Icons.monitor_heart_outlined,
                        message: '건강 기록이 없습니다.\n\n매일의 건강 상태를\n기록해보세요.',
                        action: PrimaryButton(
                          label: '+ 첫 기록 작성',
                          onPressed: () => _openForm(context),
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
                    itemCount: records.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return _HealthRecordListItem(
                        record: record,
                        onTap: () => _openForm(context, record: record),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Future<void> _openForm(BuildContext context, {HealthRecord? record}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HealthFormScreen(service: service, record: record),
      ),
    );
  }

  Future<void> _openSymptomRecord(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SymptomRecordScreen(service: symptomService),
      ),
    );
  }
}

class _HealthRecordListItem extends StatelessWidget {
  const _HealthRecordListItem({required this.record, required this.onTap});

  final HealthRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('health-record-${record.dateKey}'),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(record.date),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _SummaryLine(label: '체중', value: _weightText(record)),
                    _SummaryLine(
                      label: '혈압',
                      value: _bloodPressureText(record),
                    ),
                    _SummaryLine(
                      label: '컨디션',
                      value: record.condition?.label ?? '기록 없음',
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year.$month.$day';
  }

  String _weightText(HealthRecord record) {
    if (record.weight == null) {
      return '기록 없음';
    }
    return '${_formatDouble(record.weight!)} kg';
  }

  String _bloodPressureText(HealthRecord record) {
    if (record.systolicBloodPressure == null ||
        record.diastolicBloodPressure == null) {
      return '기록 없음';
    }
    return '${record.systolicBloodPressure} / ${record.diastolicBloodPressure} mmHg';
  }

  String _formatDouble(double value) {
    return value.toStringAsFixed(1);
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Text(
        '$label  $value',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
