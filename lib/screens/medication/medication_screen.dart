import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/medication.dart';
import '../../services/medication_service.dart';
import 'medication_form_screen.dart';
import 'prn_medication_log_form_screen.dart';

class MedicationScreen extends StatelessWidget {
  const MedicationScreen({super.key, required this.service});

  final MedicationService service;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final items = service.todayDoseItems;
        final prnMedications = service.activePrnMedications;
        return Scaffold(
          appBar: AppBar(
            title: const Text('오늘의 복약'),
            actions: [
              TextButton(
                onPressed: () => _openList(context),
                child: const Text('관리'),
              ),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: service.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xxl,
                ),
                children: [
                  Text(
                    _formatDate(DateTime.now()),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (service.activeMedications.isEmpty)
                    Center(
                      child: EmptyState(
                        icon: Icons.medication_outlined,
                        message: '등록된 약이 없습니다.\n\n복용 중인 약을\n먼저 등록해주세요.',
                        action: PrimaryButton(
                          label: '+ 약 등록',
                          onPressed: () => _openForm(context),
                        ),
                      ),
                    )
                  else ...[
                    for (final slot in MedicationTimeSlot.values)
                      if (items.any((item) => item.timeSlot == slot)) ...[
                        _TimeSlotGroup(
                          title: slot.label,
                          items: items
                              .where((item) => item.timeSlot == slot)
                              .toList(),
                          onToggle: (item) => service.toggleTaken(
                            medication: item.medication,
                            timeSlot: item.timeSlot,
                            date: DateTime.now(),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    if (prnMedications.isNotEmpty)
                      _PrnMedicationGroup(
                        medications: prnMedications,
                        service: service,
                        onRecord: (medication) =>
                            _openPrnRecord(context, medication),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openList(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MedicationListScreen(service: service)),
    );
  }

  Future<void> _openForm(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MedicationFormScreen(service: service)),
    );
  }

  Future<void> _openPrnRecord(
    BuildContext context,
    Medication medication,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrnMedicationLogFormScreen(
          service: service,
          medication: medication,
        ),
      ),
    );
  }
}

class MedicationListScreen extends StatelessWidget {
  const MedicationListScreen({super.key, required this.service});

  final MedicationService service;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final medications = service.activeMedications;
        return Scaffold(
          appBar: AppBar(
            title: const Text('약 관리'),
            actions: [
              IconButton(
                key: const Key('medication-add-button'),
                tooltip: '약 등록',
                icon: const Icon(Icons.add),
                onPressed: () => _openForm(context),
              ),
            ],
          ),
          body: SafeArea(
            child: medications.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Center(
                      child: EmptyState(
                        icon: Icons.medication_outlined,
                        message: '등록된 약이 없습니다.\n\n복용 중인 약을\n등록해주세요.',
                        action: PrimaryButton(
                          label: '+ 약 등록',
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
                    itemCount: medications.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final medication = medications[index];
                      return _MedicationListItem(
                        medication: medication,
                        onTap: () => _openForm(context, medication: medication),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Future<void> _openForm(BuildContext context, {Medication? medication}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MedicationFormScreen(service: service, medication: medication),
      ),
    );
  }
}

class _TimeSlotGroup extends StatelessWidget {
  const _TimeSlotGroup({
    required this.title,
    required this.items,
    required this.onToggle,
  });

  final String title;
  final List<MedicationDoseItem> items;
  final ValueChanged<MedicationDoseItem> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _MedicationDoseRow(
                  key: ValueKey(
                    'dose-${items[i].medication.id}-${items[i].timeSlot.value}',
                  ),
                  item: items[i],
                  onToggle: () => onToggle(items[i]),
                ),
                if (i != items.length - 1)
                  const Divider(height: 1, color: AppColors.border),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MedicationDoseRow extends StatelessWidget {
  const _MedicationDoseRow({
    super.key,
    required this.item,
    required this.onToggle,
  });

  final MedicationDoseItem item;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final medication = item.medication;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication.name,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (medication.displayDose != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    medication.displayDose!,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.secondaryText),
                  ),
                ],
              ],
            ),
          ),
          if (item.isTaken)
            TextButton.icon(
              onPressed: onToggle,
              icon: const Icon(Icons.check_circle, color: AppColors.success),
              label: const Text(
                '복용 완료',
                style: TextStyle(color: AppColors.success),
              ),
            )
          else
            OutlinedButton(
              key: ValueKey(
                'take-${item.medication.id}-${item.timeSlot.value}',
              ),
              onPressed: onToggle,
              child: const Text('복용'),
            ),
        ],
      ),
    );
  }
}

class _PrnMedicationGroup extends StatelessWidget {
  const _PrnMedicationGroup({
    required this.medications,
    required this.service,
    required this.onRecord,
  });

  final List<Medication> medications;
  final MedicationService service;
  final ValueChanged<Medication> onRecord;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('필요 시 복용약', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < medications.length; i++) ...[
                _PrnMedicationRow(
                  medication: medications[i],
                  logs: service.prnLogsForMedication(medications[i].id),
                  onRecord: () => onRecord(medications[i]),
                ),
                if (i != medications.length - 1)
                  const Divider(height: 1, color: AppColors.border),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PrnMedicationRow extends StatelessWidget {
  const _PrnMedicationRow({
    required this.medication,
    required this.logs,
    required this.onRecord,
  });

  final Medication medication;
  final List<PrnMedicationLog> logs;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final latest = logs.isEmpty ? null : logs.first;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication.name,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (medication.displayDose != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    medication.displayDose!,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.secondaryText),
                  ),
                ],
                if (latest != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '오늘 ${logs.length}회 복용 · ${_formatTime(latest.takenAt)}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.secondaryText),
                  ),
                ],
              ],
            ),
          ),
          OutlinedButton(
            key: ValueKey('prn-record-${medication.id}'),
            onPressed: onRecord,
            child: const Text('복용 기록'),
          ),
        ],
      ),
    );
  }
}

class _MedicationListItem extends StatelessWidget {
  const _MedicationListItem({required this.medication, required this.onTap});

  final Medication medication;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheduleText = medication.isPrn
        ? '필요 시(PRN)'
        : '정기 · ${medication.timeSlots.map((slot) => slot.label).join(' · ')}';

    return Material(
      key: ValueKey('medication-${medication.id}'),
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
                      medication.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (medication.displayDose != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        medication.displayDose!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      scheduleText,
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
}

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year.$month.$day';
}

String _formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
