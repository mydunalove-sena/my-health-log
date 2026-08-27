import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/health_summary_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/section_header.dart';
import '../../models/health_record.dart';
import '../../models/home_mock_state.dart';
import '../../models/medication.dart';
import '../../services/health_field_visibility_service.dart';
import '../../services/health_record_service.dart';
import '../../services/medication_service.dart';
import '../health/health_form_screen.dart';
import '../medication/medication_form_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.healthRecordService,
    this.medicationService,
    this.healthFieldVisibilityService,
    this.mockState,
    this.onOpenHealthRoot,
    this.onOpenMedication,
    this.onOpenDataManagement,
  });

  final HealthRecordService? healthRecordService;
  final MedicationService? medicationService;
  final HealthFieldVisibilityService? healthFieldVisibilityService;
  final HomeMockState? mockState;
  final VoidCallback? onOpenHealthRoot;
  final VoidCallback? onOpenMedication;
  final VoidCallback? onOpenDataManagement;

  @override
  Widget build(BuildContext context) {
    final healthService = healthRecordService;
    final medService = medicationService;
    if (healthService == null) {
      Widget buildContent() {
        final mockHasMeds = mockState?.hasMedications ?? medService == null;
        final medicationItems = medService == null
            ? mockHasMeds
                  ? const [
                      _HomeMedicationItem(
                        name: '\uC544\uCE68\uC57D',
                        detail: '\uC544\uCE68 \u00B7 \uBCF5\uC6A9 \uC644\uB8CC',
                        isTaken: true,
                      ),
                      _HomeMedicationItem(
                        name: '\uC800\uB141\uC57D',
                        detail: '\uC800\uB141 \u00B7 \uBBF8\uBCF5\uC6A9',
                        isTaken: false,
                      ),
                    ]
                  : const <_HomeMedicationItem>[]
            : medService.todayDoseItems
                  .take(3)
                  .map(_HomeMedicationItem.fromDoseItem)
                  .toList();
        return _HomeContent(
          date: DateTime.now(),
          healthRecord: mockState?.hasHealthRecord ?? true
              ? _mockHealthRecord()
              : null,
          healthFieldVisibilityService: healthFieldVisibilityService,
          medicationItems: medicationItems,
          onOpenHealth: () {},
          onOpenMedication: onOpenMedication,
          onAddMedication: onOpenMedication,
          onOpenDataManagement: onOpenDataManagement,
        );
      }

      if (medService != null) {
        return AnimatedBuilder(
          animation: medService,
          builder: (context, _) => buildContent(),
        );
      }
      return buildContent();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        healthService,
        ?medService,
        ?healthFieldVisibilityService,
      ]),
      builder: (context, _) {
        final todayRecord = healthService.todayRecord;
        final items = medService == null
            ? const <_HomeMedicationItem>[]
            : medService.todayDoseItems
                  .take(3)
                  .map(_HomeMedicationItem.fromDoseItem)
                  .toList();
        return _HomeContent(
          date: DateTime.now(),
          healthRecord: todayRecord,
          healthFieldVisibilityService: healthFieldVisibilityService,
          medicationItems: items,
          onOpenHealth: () async {
            if (todayRecord == null) {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HealthFormScreen(
                    service: healthService,
                    healthFieldVisibilityService: healthFieldVisibilityService,
                  ),
                ),
              );
            } else {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HealthFormScreen(
                    service: healthService,
                    record: todayRecord,
                    healthFieldVisibilityService: healthFieldVisibilityService,
                  ),
                ),
              );
            }
            onOpenHealthRoot?.call();
          },
          onOpenMedication: onOpenMedication,
          onAddMedication: medService == null
              ? onOpenMedication
              : () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MedicationFormScreen(service: medService),
                    ),
                  );
                  onOpenMedication?.call();
                },
          onOpenDataManagement: onOpenDataManagement,
        );
      },
    );
  }

  HealthRecord _mockHealthRecord() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return HealthRecord(
      id: 'home-mock',
      date: today,
      weight: 54.2,
      systolicBloodPressure: 120,
      diastolicBloodPressure: 80,
      waterIntake: 1200,
      steps: 6420,
      sleepHours: 6.5,
      condition: HealthCondition.normal,
      createdAt: now,
      updatedAt: now,
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.date,
    required this.healthRecord,
    this.healthFieldVisibilityService,
    required this.medicationItems,
    required this.onOpenHealth,
    this.onOpenMedication,
    this.onAddMedication,
    this.onOpenDataManagement,
  });

  final DateTime date;
  final HealthRecord? healthRecord;
  final HealthFieldVisibilityService? healthFieldVisibilityService;
  final List<_HomeMedicationItem> medicationItems;
  final VoidCallback onOpenHealth;
  final VoidCallback? onOpenMedication;
  final VoidCallback? onAddMedication;
  final VoidCallback? onOpenDataManagement;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Health Log'),
        actions: [
          IconButton(
            tooltip: '데이터 관리',
            onPressed: onOpenDataManagement,
            icon: const Icon(Icons.manage_history_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatToday(date),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              _HealthSection(
                record: healthRecord,
                visibilityService: healthFieldVisibilityService,
                onOpenHealth: onOpenHealth,
              ),
              const SizedBox(height: AppSpacing.xl),
              _MedicationSection(
                items: medicationItems,
                onOpenMedication: onOpenMedication,
                onAddMedication: onAddMedication,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatToday(DateTime date) {
    const weekdays = [
      '\uC6D4\uC694\uC77C',
      '\uD654\uC694\uC77C',
      '\uC218\uC694\uC77C',
      '\uBAA9\uC694\uC77C',
      '\uAE08\uC694\uC77C',
      '\uD1A0\uC694\uC77C',
      '\uC77C\uC694\uC77C',
    ];
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year.$month.$day ${weekdays[date.weekday - 1]}';
  }
}

class _HealthSection extends StatelessWidget {
  const _HealthSection({
    required this.record,
    required this.onOpenHealth,
    this.visibilityService,
  });

  final HealthRecord? record;
  final VoidCallback onOpenHealth;
  final HealthFieldVisibilityService? visibilityService;

  @override
  Widget build(BuildContext context) {
    final currentRecord = record;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '\uC624\uB298\uC758 \uAC74\uAC15'),
        const SizedBox(height: AppSpacing.sm),
        if (currentRecord != null) ...[
          if (_visibleCards(currentRecord).isNotEmpty)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.45,
              children: _visibleCards(currentRecord),
            ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: '+ \uC624\uB298 \uAC74\uAC15 \uAE30\uB85D',
            onPressed: onOpenHealth,
          ),
        ] else
          EmptyState(
            icon: Icons.monitor_heart_outlined,
            message:
                '\uC544\uC9C1 \uAE30\uB85D\uC774 \uC5C6\uC2B5\uB2C8\uB2E4.',
            action: PrimaryButton(
              label: '+ \uAC74\uAC15 \uAE30\uB85D\uD558\uAE30',
              onPressed: onOpenHealth,
            ),
          ),
      ],
    );
  }

  List<Widget> _visibleCards(HealthRecord record) {
    final visibility = visibilityService;
    return [
      if (visibility?.weightVisible ?? true)
        HealthSummaryCard(
          key: const Key('home-weight-card'),
          title: '\uCCB4\uC911',
          value: _doubleText(record.weight),
          unit: record.weight == null ? null : 'kg',
          icon: Icons.monitor_weight_outlined,
        ),
      if (visibility?.bloodPressureVisible ?? true)
        HealthSummaryCard(
          key: const Key('home-blood-pressure-card'),
          title: '\uD608\uC555',
          value: _bloodPressureText(record),
          unit: record.systolicBloodPressure == null ? null : 'mmHg',
          icon: Icons.favorite_outline,
        ),
      if (visibility?.waterIntakeVisible ?? true)
        HealthSummaryCard(
          key: const Key('home-water-card'),
          title: '\uC218\uBD84',
          value: _intText(record.waterIntake),
          unit: record.waterIntake == null ? null : 'mL',
          icon: Icons.water_drop_outlined,
        ),
      if (visibility?.stepsVisible ?? true)
        HealthSummaryCard(
          key: const Key('home-steps-card'),
          title: '\uC6B4\uB3D9',
          value: _intText(record.steps),
          unit: record.steps == null ? null : '\uAC78\uC74C',
          icon: Icons.directions_walk_outlined,
        ),
      if (visibility?.sleepHoursVisible ?? true)
        HealthSummaryCard(
          key: const Key('home-sleep-card'),
          title: '\uC218\uBA74',
          value: record.sleepHours == null
              ? '\uAE30\uB85D \uC5C6\uC74C'
              : '${_formatDouble(record.sleepHours!)}\uC2DC\uAC04',
          icon: Icons.bedtime_outlined,
        ),
      if (visibility?.conditionVisible ?? true)
        HealthSummaryCard(
          key: const Key('home-condition-card'),
          title: '\uCEE8\uB514\uC158',
          value: record.condition?.label ?? '\uAE30\uB85D \uC5C6\uC74C',
          icon: Icons.sentiment_satisfied_outlined,
        ),
    ];
  }

  String _doubleText(double? value) =>
      value == null ? '\uAE30\uB85D \uC5C6\uC74C' : _formatDouble(value);

  String _intText(int? value) =>
      value == null ? '\uAE30\uB85D \uC5C6\uC74C' : _formatInt(value);

  String _bloodPressureText(HealthRecord record) {
    if (record.systolicBloodPressure == null ||
        record.diastolicBloodPressure == null) {
      return '\uAE30\uB85D \uC5C6\uC74C';
    }
    return '${record.systolicBloodPressure} / ${record.diastolicBloodPressure}';
  }

  String _formatDouble(double value) => value.toStringAsFixed(1);

  String _formatInt(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final remaining = text.length - i;
      buffer.write(text[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }
}

class _MedicationSection extends StatelessWidget {
  const _MedicationSection({
    required this.items,
    this.onOpenMedication,
    this.onAddMedication,
  });

  final List<_HomeMedicationItem> items;
  final VoidCallback? onOpenMedication;
  final VoidCallback? onAddMedication;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '\uC624\uB298\uC758 \uBCF5\uC57D'),
        const SizedBox(height: AppSpacing.sm),
        if (items.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (final item in items) _MedicationSummaryRow(item: item),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: '\uBCF5\uC57D \uD655\uC778',
            onPressed: onOpenMedication ?? () {},
          ),
        ] else
          EmptyState(
            icon: Icons.medication_outlined,
            message:
                '\uB4F1\uB85D\uB41C \uC57D\uC774 \uC5C6\uC2B5\uB2C8\uB2E4.',
            action: SecondaryButton(
              label: '\uC57D \uB4F1\uB85D\uD558\uAE30',
              onPressed: onAddMedication ?? onOpenMedication ?? () {},
            ),
          ),
      ],
    );
  }
}

class _MedicationSummaryRow extends StatelessWidget {
  const _MedicationSummaryRow({required this.item});

  final _HomeMedicationItem item;

  @override
  Widget build(BuildContext context) {
    final statusColor = item.isTaken
        ? AppColors.success
        : AppColors.secondaryText;
    final statusIcon = item.isTaken
        ? Icons.check_circle
        : Icons.radio_button_unchecked;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  item.detail,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
          Icon(statusIcon, size: 20, color: statusColor),
        ],
      ),
    );
  }
}

class _HomeMedicationItem {
  const _HomeMedicationItem({
    required this.name,
    required this.detail,
    required this.isTaken,
  });

  final String name;
  final String detail;
  final bool isTaken;

  factory _HomeMedicationItem.fromDoseItem(MedicationDoseItem item) {
    final state = item.isTaken
        ? '\uBCF5\uC6A9 \uC644\uB8CC'
        : '\uBBF8\uBCF5\uC6A9';
    final displayedDose = item.isTaken
        ? item.log?.displayDoseSnapshot
        : item.medication.displayDose;
    final dose = displayedDose == null ? '' : ' \u00B7 $displayedDose';
    return _HomeMedicationItem(
      name: item.medication.name,
      detail: '${item.timeSlot.label}$dose \u00B7 $state',
      isTaken: item.isTaken,
    );
  }
}
