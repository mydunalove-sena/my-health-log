import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/lab_result.dart';
import '../../services/lab_result_service.dart';
import 'lab_result_form_screen.dart';

class LabScreen extends StatelessWidget {
  const LabScreen({super.key, required this.service});

  final LabResultService service;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final groups = service.groups;
        return Scaffold(
          appBar: AppBar(
            title: const Text('\uAC80\uC0AC \uACB0\uACFC'),
            actions: [
              IconButton(
                key: const Key('lab-add-button'),
                tooltip: '\uAC80\uC0AC \uACB0\uACFC \uB4F1\uB85D',
                icon: const Icon(Icons.add),
                onPressed: () => _openForm(context),
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

  Future<void> _openForm(BuildContext context, {DateTime? initialDate}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            LabResultFormScreen(service: service, initialDate: initialDate),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, DateTime date) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LabResultDetailScreen(service: service, date: date),
      ),
    );
  }
}

class LabResultDetailScreen extends StatelessWidget {
  const LabResultDetailScreen({
    super.key,
    required this.service,
    required this.date,
  });

  final LabResultService service;
  final DateTime date;

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
                      label: '+ \uAC80\uC0AC \uD56D\uBAA9 \uCD94\uAC00',
                      onPressed: () => _openForm(context),
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
                            onTap: () => _openForm(context, result: results[i]),
                          ),
                          if (i != results.length - 1)
                            const Divider(height: 1, color: AppColors.border),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: '+ \uAC80\uC0AC \uD56D\uBAA9 \uCD94\uAC00',
                    onPressed: () => _openForm(context),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openForm(BuildContext context, {LabResult? result}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LabResultFormScreen(
          service: service,
          result: result,
          initialDate: date,
        ),
      ),
    );
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
  const _LabResultRow({super.key, required this.result, required this.onTap});

  final LabResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
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
      ),
    );
  }
}
