import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/exercise_record.dart';
import '../../services/exercise_service.dart';
import '../../services/health_record_service.dart';
import 'exercise_form_screen.dart';

class ExerciseScreen extends StatelessWidget {
  const ExerciseScreen({
    super.key,
    required this.exerciseService,
    required this.healthRecordService,
  });

  final ExerciseService exerciseService;
  final HealthRecordService healthRecordService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: exerciseService,
      builder: (context, _) {
        final records = exerciseService.records;
        return Scaffold(
          appBar: AppBar(
            title: const Text('운동 기록'),
            actions: [
              IconButton(
                tooltip: '운동 추가',
                icon: const Icon(Icons.add, key: Key('exercise-add-button')),
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
                        icon: Icons.fitness_center_outlined,
                        message: '운동 기록이 없습니다.',
                        action: PrimaryButton(
                          label: '+ 운동 기록하기',
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
                      return _ExerciseRecordListItem(
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

  Future<void> _openForm(BuildContext context, {ExerciseRecord? record}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseFormScreen(
          exerciseService: exerciseService,
          healthRecordService: healthRecordService,
          record: record,
        ),
      ),
    );
  }
}

class _ExerciseRecordListItem extends StatelessWidget {
  const _ExerciseRecordListItem({required this.record, required this.onTap});

  final ExerciseRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('exercise-record-${record.id}'),
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
                    Text(
                      '${record.exerciseType.label} · '
                      '${record.durationMinutes}분 · '
                      '${record.intensity.label}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _calorieText(record),
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.secondaryText),
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

  String _calorieText(ExerciseRecord record) {
    final calories = record.estimatedCalories;
    if (calories == null) {
      return '예상 소모 칼로리 계산 불가';
    }
    return '예상 소모 칼로리 ${calories.round()} kcal';
  }
}
