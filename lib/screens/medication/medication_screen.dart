import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/medication.dart';
import '../../models/symptom.dart';
import '../../services/medication_service.dart';
import '../../services/symptom_service.dart';
import 'medication_form_screen.dart';
import 'prn_medication_log_form_screen.dart';

class MedicationScreen extends StatelessWidget {
  const MedicationScreen({
    super.key,
    required this.service,
    this.symptomService,
  });

  final MedicationService service;
  final SymptomService? symptomService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([service, ?symptomService]),
      builder: (context, _) {
        final items = service.todayDoseItems;
        final prnMedications = service.activePrnMedications;
        return Scaffold(
          appBar: AppBar(
            title: const Text('오늘의 복약'),
            actions: [
              TextButton(
                key: const Key('medication-history-button'),
                onPressed: () => _openHistory(context),
                child: const Text('\uAE30\uB85D'),
              ),
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
                        symptomDefinitions:
                            symptomService?.definitions ?? const [],
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

  Future<void> _openHistory(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationHistoryScreen(
          service: service,
          symptomService: symptomService,
          symptomDefinitions: symptomService?.definitions ?? const [],
        ),
      ),
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
          symptomService: symptomService,
          medication: medication,
        ),
      ),
    );
  }
}

class MedicationHistoryScreen extends StatefulWidget {
  const MedicationHistoryScreen({
    super.key,
    required this.service,
    this.symptomService,
    this.symptomDefinitions = const [],
  });

  final MedicationService service;
  final SymptomService? symptomService;
  final List<SymptomDefinition> symptomDefinitions;

  @override
  State<MedicationHistoryScreen> createState() =>
      _MedicationHistoryScreenState();
}

class _MedicationHistoryScreenState extends State<MedicationHistoryScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('medication-history-screen'),
      appBar: AppBar(title: const Text('\uBCF5\uC57D \uAE30\uB85D')),
      body: SafeArea(
        child: FutureBuilder<MedicationHistoryDay>(
          future: widget.service.historyForDate(_selectedDate),
          builder: (context, snapshot) {
            final day = snapshot.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              children: [
                _HistoryDateField(date: _selectedDate, onTap: _pickDate),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  key: const Key('med-history-add-missing-button'),
                  label: '누락 복약 추가',
                  onPressed: _openMissingLogTypeDialog,
                ),
                const SizedBox(height: AppSpacing.md),
                if (snapshot.connectionState != ConnectionState.done)
                  const Center(child: CircularProgressIndicator())
                else if (day == null || day.isEmpty)
                  EmptyState(
                    icon: Icons.history,
                    message: '\uC800\uC7A5\uB41C \uBCF5\uC57D \uAE30\uB85D\uC774 \uC5C6\uC2B5\uB2C8\uB2E4.',
                    action: const SizedBox.shrink(),
                  )
                else ...[
                  if (day.scheduledEntries.isNotEmpty) ...[
                    Text(
                      '\uC815\uAE30 \uBCF5\uC57D',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _HistorySection(
                      children: [
                        for (final entry in day.scheduledEntries)
                          _ScheduledHistoryRow(
                            entry: entry,
                            onEdit: entry.medication == null
                                ? null
                                : () => _openScheduledCorrection(
                                    entry.medication!,
                                    existingLog: entry.log,
                                  ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (day.prnEntries.isNotEmpty) ...[
                    Text(
                      '\uD544\uC694 \uC2DC \uBCF5\uC57D',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _HistorySection(
                      children: [
                        for (final entry in day.prnEntries)
                          _PrnHistoryRow(
                            entry: entry,
                            symptomNames: _symptomNamesFor(entry),
                            onEdit: entry.medication == null
                                ? null
                                : () => _openPrnCorrection(
                                    entry.medication!,
                                    existingLog: entry.log,
                                    symptomDefinitionIds:
                                        entry.symptomDefinitionIds,
                                  ),
                          ),
                      ],
                    ),
                  ],
                ],
              ],
            );
          },
        ),
      ),
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
      });
    }
  }

  Future<void> _openMissingLogTypeDialog() async {
    final scheduled = widget.service.activeScheduledMedications;
    final prn = widget.service.activePrnMedications;
    final type = await showDialog<_MissingMedicationLogType>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('누락 복약 추가'),
        children: [
          if (scheduled.isNotEmpty)
            SimpleDialogOption(
              key: const Key('med-history-add-scheduled-option'),
              onPressed: () =>
                  Navigator.of(context)
                      .pop(_MissingMedicationLogType.scheduled),
              child: const Text('정기 복약'),
            ),
          if (prn.isNotEmpty)
            SimpleDialogOption(
              key: const Key('med-history-add-prn-option'),
              onPressed: () =>
                  Navigator.of(context).pop(_MissingMedicationLogType.prn),
              child: const Text('필요 시 복약'),
            ),
        ],
      ),
    );
    if (type == null || !mounted) return;
    if (type == _MissingMedicationLogType.scheduled) {
      final medication = await _chooseMedication(scheduled);
      if (medication != null) {
        await _openScheduledCorrection(medication);
      }
      return;
    }
    final medication = await _chooseMedication(prn);
    if (medication != null) {
      await _openPrnCorrection(medication);
    }
  }

  Future<Medication?> _chooseMedication(List<Medication> medications) {
    return showDialog<Medication>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('약 선택'),
        children: [
          for (final medication in medications)
            SimpleDialogOption(
              key: ValueKey('med-history-pick-${medication.id}'),
              onPressed: () => Navigator.of(context).pop(medication),
              child: Text(medication.name),
            ),
        ],
      ),
    );
  }

  Future<void> _openScheduledCorrection(
    Medication medication, {
    MedicationLog? existingLog,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ScheduledMedicationLogFormScreen(
          service: widget.service,
          medication: medication,
          selectedDate: _selectedDate,
          existingLog: existingLog,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openPrnCorrection(
    Medication medication, {
    PrnMedicationLog? existingLog,
    List<String> symptomDefinitionIds = const [],
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrnMedicationLogFormScreen(
          service: widget.service,
          symptomService: widget.symptomService,
          medication: medication,
          initialDate: _selectedDate,
          existingLog: existingLog,
          initialSymptomDefinitionIds: symptomDefinitionIds,
          title: existingLog == null ? '누락 PRN 복용 추가' : 'PRN 복용 수정',
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  List<String> _symptomNamesFor(MedicationHistoryPrnEntry entry) {
    final names = <String>[];
    for (final id in entry.symptomDefinitionIds) {
      final name = _symptomNameFor(id);
      if (name != null) {
        names.add(name);
      }
    }
    return names;
  }

  String? _symptomNameFor(String id) {
    final fromService = widget.symptomService?.definitionById(id);
    if (fromService != null) {
      return fromService.name;
    }
    for (final definition in widget.symptomDefinitions) {
      if (definition.id == id) {
        return definition.name;
      }
    }
    return null;
  }
}

class _HistoryDateField extends StatelessWidget {
  const _HistoryDateField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('medication-history-date-field'),
      borderRadius: BorderRadius.circular(AppRadius.input),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '\uB0A0\uC9DC',
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
        ),
        child: Row(
          children: [
            Expanded(child: Text(_formatDate(date))),
            const Icon(Icons.arrow_drop_down, color: AppColors.secondaryText),
          ],
        ),
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

enum _MissingMedicationLogType { scheduled, prn }

class _ScheduledHistoryRow extends StatelessWidget {
  const _ScheduledHistoryRow({required this.entry, this.onEdit});

  final MedicationHistoryScheduledEntry entry;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('med-history-scheduled-${entry.log.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.medicationName,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Text(
                entry.statusLabel,
                key: ValueKey('med-history-status-${entry.log.id}'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: entry.isTaken ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${entry.log.timeSlot.label} \u00B7 ${entry.doseLabel}',
            key: ValueKey('med-history-dose-${entry.log.id}'),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.secondaryText),
          ),
          if (onEdit != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: ValueKey('med-history-edit-scheduled-${entry.log.id}'),
                onPressed: onEdit,
                child: const Text('수정'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrnHistoryRow extends StatelessWidget {
  const _PrnHistoryRow({
    required this.entry,
    required this.symptomNames,
    this.onEdit,
  });

  final MedicationHistoryPrnEntry entry;
  final List<String> symptomNames;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('med-history-prn-${entry.log.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.medicationName,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${_formatTime(entry.log.takenAt)} \u00B7 ${entry.doseLabel}',
            key: ValueKey('med-history-prn-dose-${entry.log.id}'),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.secondaryText),
          ),
          if (symptomNames.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '\uAD00\uB828 \uC99D\uC0C1: ${symptomNames.join(' \u00B7 ')}',
              key: ValueKey('med-history-prn-symptoms-${entry.log.id}'),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.secondaryText),
            ),
          ],
          if (onEdit != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: ValueKey('med-history-edit-prn-${entry.log.id}'),
                onPressed: onEdit,
                child: const Text('수정'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduledMedicationLogFormScreen extends StatefulWidget {
  const _ScheduledMedicationLogFormScreen({
    required this.service,
    required this.medication,
    required this.selectedDate,
    this.existingLog,
  });

  final MedicationService service;
  final Medication medication;
  final DateTime selectedDate;
  final MedicationLog? existingLog;

  @override
  State<_ScheduledMedicationLogFormScreen> createState() =>
      _ScheduledMedicationLogFormScreenState();
}

class _ScheduledMedicationLogFormScreenState
    extends State<_ScheduledMedicationLogFormScreen> {
  late MedicationTimeSlot _timeSlot;
  late bool _isTaken;
  late TimeOfDay _takenTime;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingLog;
    _timeSlot = existing?.timeSlot ?? widget.medication.timeSlots.first;
    _isTaken = existing?.isTaken ?? true;
    _takenTime = TimeOfDay.fromDateTime(
      existing?.takenAt ?? _defaultTakenAt(widget.selectedDate),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingLog == null ? '정기 복약 추가' : '정기 복약 수정'),
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
            Text(
              widget.medication.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _formatDate(widget.selectedDate),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.secondaryText),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<MedicationTimeSlot>(
              key: const Key('scheduled-correction-slot-field'),
              initialValue: _timeSlot,
              decoration: _inputDecoration(labelText: '복용 시간대'),
              items: [
                for (final slot in widget.medication.timeSlots)
                  DropdownMenuItem(value: slot, child: Text(slot.label)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _timeSlot = value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              key: const Key('scheduled-correction-taken-switch'),
              value: _isTaken,
              title: const Text('복용 완료'),
              onChanged: (value) => setState(() => _isTaken = value),
            ),
            if (_isTaken) ...[
              const SizedBox(height: AppSpacing.md),
              _HistoryActionField(
                key: const Key('scheduled-correction-time-field'),
                label: '실제 복용 시간',
                value: MaterialLocalizations.of(context)
                    .formatTimeOfDay(_takenTime),
                onTap: _pickTakenTime,
              ),
            ],
            if (_formError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _formError!,
                style: const TextStyle(color: AppColors.error, fontSize: 14),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              key: const Key('scheduled-correction-save-button'),
              label: '저장',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTakenTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _takenTime,
    );
    if (picked != null) {
      setState(() {
        _takenTime = picked;
        _formError = null;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _formError = null);
    final takenAt = _isTaken
        ? DateTime(
            widget.selectedDate.year,
            widget.selectedDate.month,
            widget.selectedDate.day,
            _takenTime.hour,
            _takenTime.minute,
          )
        : null;
    try {
      await widget.service.saveScheduledCorrection(
        medication: widget.medication,
        date: widget.selectedDate,
        timeSlot: _timeSlot,
        isTaken: _isTaken,
        takenAt: takenAt,
      );
    } on FuturePrnMedicationDateException {
      setState(() => _formError = '미래 날짜에는 저장할 수 없습니다.');
      return;
    } on FuturePrnMedicationTimeException {
      setState(() => _formError = '미래 시간에는 저장할 수 없습니다.');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  DateTime _defaultTakenAt(DateTime date) {
    final now = DateTime.now();
    final normalizedToday = DateTime(now.year, now.month, now.day);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    if (normalizedDate == normalizedToday) {
      return now;
    }
    return DateTime(date.year, date.month, date.day, 9);
  }

  InputDecoration _inputDecoration({String? labelText}) {
    return InputDecoration(
      labelText: labelText,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
    );
  }
}

class _HistoryActionField extends StatelessWidget {
  const _HistoryActionField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: InputDecorator(
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
            ),
            child: Row(
              children: [
                Expanded(child: Text(value)),
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
    final displayDose = item.isTaken
        ? item.log?.displayDoseSnapshot
        : medication.displayDose;
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
                if (displayDose != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    displayDose,
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
    required this.symptomDefinitions,
    required this.onRecord,
  });

  final List<Medication> medications;
  final MedicationService service;
  final List<SymptomDefinition> symptomDefinitions;
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
                  symptomDefinitions: symptomDefinitions,
                  symptomDefinitionIdsForLog:
                      service.symptomDefinitionIdsForPrnLog,
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
    required this.symptomDefinitions,
    required this.symptomDefinitionIdsForLog,
    required this.onRecord,
  });

  final Medication medication;
  final List<PrnMedicationLog> logs;
  final List<SymptomDefinition> symptomDefinitions;
  final List<String> Function(String prnMedicationLogId)
  symptomDefinitionIdsForLog;
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
                if (logs.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  for (final log in logs)
                    _PrnLogDetailItem(
                      log: log,
                      symptomNames: _symptomNamesForLog(log.id),
                    ),
                ],
              ],
            ),
          ),
          OutlinedButton(
            key: ValueKey('prn-record-${medication.id}'),
            onPressed: onRecord,
            child: Text(logs.isEmpty ? '복용' : '추가 복용'),
          ),
        ],
      ),
    );
  }

  List<String> _symptomNamesForLog(String prnMedicationLogId) {
    final ids = symptomDefinitionIdsForLog(prnMedicationLogId).toSet();
    return [
      for (final definition in symptomDefinitions)
        if (ids.contains(definition.id)) definition.name,
    ];
  }
}

class _PrnLogDetailItem extends StatelessWidget {
  const _PrnLogDetailItem({required this.log, required this.symptomNames});

  final PrnMedicationLog log;
  final List<String> symptomNames;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('prn-log-entry-${log.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxs),
          child: Text(
            _formatTime(log.takenAt),
            key: ValueKey('prn-log-time-${log.id}'),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.secondaryText),
          ),
        ),
        if (symptomNames.isNotEmpty)
          _PrnLogDetailLine(log: log, symptomNames: symptomNames),
      ],
    );
  }
}

class _PrnLogDetailLine extends StatelessWidget {
  const _PrnLogDetailLine({required this.log, required this.symptomNames});

  final PrnMedicationLog log;
  final List<String> symptomNames;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Text(
        '관련 증상: ${symptomNames.join(' · ')}',
        key: ValueKey('prn-log-detail-${log.id}'),
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.secondaryText),
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
