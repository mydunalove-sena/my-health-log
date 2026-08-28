import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/health_record.dart';
import '../../models/lab_result.dart';
import '../../services/health_field_visibility_service.dart';
import '../../services/health_record_service.dart';
import '../../services/lab_result_service.dart';

enum _StatsTab { weight, bloodPressure, lab }

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
    required this.healthRecordService,
    required this.labResultService,
    this.healthFieldVisibilityService,
    this.onOpenHealth,
    this.onOpenLab,
  });

  final HealthRecordService healthRecordService;
  final LabResultService labResultService;
  final HealthFieldVisibilityService? healthFieldVisibilityService;
  final VoidCallback? onOpenHealth;
  final VoidCallback? onOpenLab;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  _StatsTab _selectedTab = _StatsTab.weight;
  String? _selectedLabTestName;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.healthRecordService,
        widget.labResultService,
        if (widget.healthFieldVisibilityService != null)
          widget.healthFieldVisibilityService!,
      ]),
      builder: (context, _) {
        final tabs = _visibleTabs();
        final selectedTab = tabs.contains(_selectedTab)
            ? _selectedTab
            : tabs.first;
        return Scaffold(
          appBar: AppBar(title: const Text('\uD1B5\uACC4')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _StatsTabs(
                  tabs: tabs,
                  selectedTab: selectedTab,
                  onSelected: (tab) {
                    setState(() {
                      _selectedTab = tab;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                _buildSelectedTab(selectedTab),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_StatsTab> _visibleTabs() {
    final visibility = widget.healthFieldVisibilityService;
    return [
      if (visibility?.weightVisible ?? true) _StatsTab.weight,
      if (visibility?.bloodPressureVisible ?? true) _StatsTab.bloodPressure,
      _StatsTab.lab,
    ];
  }

  Widget _buildSelectedTab(_StatsTab selectedTab) {
    return switch (selectedTab) {
      _StatsTab.weight => _WeightStatsView(
        records: widget.healthRecordService.records,
        onOpenHealth: widget.onOpenHealth,
      ),
      _StatsTab.bloodPressure => _BloodPressureStatsView(
        records: widget.healthRecordService.records,
        onOpenHealth: widget.onOpenHealth,
      ),
      _StatsTab.lab => _LabStatsView(
        results: widget.labResultService.results,
        selectedTestName: _selectedLabTestName,
        onSelectedTestName: (name) {
          setState(() {
            _selectedLabTestName = name;
          });
        },
        onOpenLab: widget.onOpenLab,
      ),
    };
  }
}

class _StatsTabs extends StatelessWidget {
  const _StatsTabs({
    required this.tabs,
    required this.selectedTab,
    required this.onSelected,
  });

  final List<_StatsTab> tabs;
  final _StatsTab selectedTab;
  final ValueChanged<_StatsTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < tabs.length; index += 1) ...[
          if (index > 0) const SizedBox(width: AppSpacing.xs),
          _StatsTabChip(
            label: _labelFor(tabs[index]),
            selected: selectedTab == tabs[index],
            onSelected: () => onSelected(tabs[index]),
          ),
        ],
      ],
    );
  }

  String _labelFor(_StatsTab tab) {
    return switch (tab) {
      _StatsTab.weight => '\uCCB4\uC911',
      _StatsTab.bloodPressure => '\uD608\uC555',
      _StatsTab.lab => '\uAC80\uC0AC',
    };
  }
}

class _StatsTabChip extends StatelessWidget {
  const _StatsTabChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ChoiceChip(
        label: Center(child: Text(label)),
        selected: selected,
        onSelected: (_) => onSelected(),
        selectedColor: AppColors.primaryLight,
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : AppColors.mainText,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
      ),
    );
  }
}

class _WeightStatsView extends StatelessWidget {
  const _WeightStatsView({required this.records, this.onOpenHealth});

  final List<HealthRecord> records;
  final VoidCallback? onOpenHealth;

  @override
  Widget build(BuildContext context) {
    final filtered = records.where((record) => record.weight != null).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (filtered.isEmpty) {
      return _StatsEmptyState(
        icon: Icons.monitor_weight_outlined,
        message: '\uC544\uC9C1 \uD45C\uC2DC\uD560 \uCCB4\uC911 \uAE30\uB85D\uC774 \uC5C6\uC2B5\uB2C8\uB2E4.\n\n\uAC74\uAC15 \uAE30\uB85D\uC744 \uC785\uB825\uD558\uBA74\n\uBCC0\uD654 \uCD94\uC774\uB97C \uD655\uC778\uD560 \uC218 \uC788\uC2B5\uB2C8\uB2E4.',
        buttonLabel: '\uAC74\uAC15 \uAE30\uB85D\uD558\uAE30',
        onPressed: onOpenHealth,
      );
    }

    final points = [
      for (final record in filtered)
        _ChartPoint(date: record.date, value: record.weight!),
    ];
    final recent = filtered.reversed.toList();

    return _StatsSection(
      title: '\uCCB4\uC911 \uBCC0\uD654',
      chart: _LineChart(
        series: [_ChartSeries(color: AppColors.primary, points: points)],
        axisFormat: _ChartAxisFormat.weight,
      ),
      children: [
        for (final record in recent)
          _ValueRow(
            date: record.date,
            value: '${LabResult.formatValue(record.weight!)} kg',
          ),
      ],
    );
  }
}

class _BloodPressureStatsView extends StatelessWidget {
  const _BloodPressureStatsView({required this.records, this.onOpenHealth});

  final List<HealthRecord> records;
  final VoidCallback? onOpenHealth;

  @override
  Widget build(BuildContext context) {
    final filtered =
        records
            .where(
              (record) =>
                  record.systolicBloodPressure != null &&
                  record.diastolicBloodPressure != null,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    if (filtered.isEmpty) {
      return _StatsEmptyState(
        icon: Icons.favorite_border,
        message: '\uC544\uC9C1 \uD45C\uC2DC\uD560 \uD608\uC555 \uAE30\uB85D\uC774 \uC5C6\uC2B5\uB2C8\uB2E4.\n\n\uAC74\uAC15 \uAE30\uB85D\uC744 \uC785\uB825\uD558\uBA74\n\uBCC0\uD654 \uCD94\uC774\uB97C \uD655\uC778\uD560 \uC218 \uC788\uC2B5\uB2C8\uB2E4.',
        buttonLabel: '\uAC74\uAC15 \uAE30\uB85D\uD558\uAE30',
        onPressed: onOpenHealth,
      );
    }

    final recent = filtered.reversed.toList();
    return _StatsSection(
      title: '\uD608\uC555 \uBCC0\uD654',
      legends: const [
        _Legend(label: '\uC218\uCD95\uAE30', color: AppColors.primary),
        _Legend(label: '\uC774\uC644\uAE30', color: AppColors.success),
      ],
      chart: _LineChart(
        series: [
          _ChartSeries(
            color: AppColors.primary,
            points: [
              for (final record in filtered)
                _ChartPoint(
                  date: record.date,
                  value: record.systolicBloodPressure!.toDouble(),
                ),
            ],
          ),
          _ChartSeries(
            color: AppColors.success,
            points: [
              for (final record in filtered)
                _ChartPoint(
                  date: record.date,
                  value: record.diastolicBloodPressure!.toDouble(),
                ),
            ],
          ),
        ],
        axisFormat: _ChartAxisFormat.bloodPressure,
      ),
      children: [
        for (final record in recent)
          _ValueRow(
            date: record.date,
            value:
                '${record.systolicBloodPressure} / ${record.diastolicBloodPressure} mmHg',
          ),
      ],
    );
  }
}

class _LabStatsView extends StatelessWidget {
  const _LabStatsView({
    required this.results,
    required this.selectedTestName,
    required this.onSelectedTestName,
    this.onOpenLab,
  });

  final List<LabResult> results;
  final String? selectedTestName;
  final ValueChanged<String?> onSelectedTestName;
  final VoidCallback? onOpenLab;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return _StatsEmptyState(
        icon: Icons.science_outlined,
        message: '\uC544\uC9C1 \uD45C\uC2DC\uD560 \uAC80\uC0AC \uAE30\uB85D\uC774 \uC5C6\uC2B5\uB2C8\uB2E4.\n\n\uAC80\uC0AC \uACB0\uACFC\uB97C \uC785\uB825\uD558\uBA74\n\uBCC0\uD654 \uCD94\uC774\uB97C \uD655\uC778\uD560 \uC218 \uC788\uC2B5\uB2C8\uB2E4.',
        buttonLabel: '\uAC80\uC0AC \uACB0\uACFC \uAE30\uB85D\uD558\uAE30',
        onPressed: onOpenLab,
      );
    }

    final testNames = <String>{};
    for (final result in results) {
      testNames.add(result.testName.trim());
    }
    final sortedNames = testNames.toList()..sort();
    final selected = sortedNames.contains(selectedTestName)
        ? selectedTestName!
        : sortedNames.first;
    final filtered =
        results.where((result) => result.testName.trim() == selected).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final unitSet = {for (final result in filtered) (result.unit ?? '').trim()};
    final hasMixedUnits = unitSet.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '\uAC80\uC0AC \uD56D\uBAA9',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<String>(
          key: const Key('statistics-lab-test-dropdown'),
          initialValue: selected,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
          ),
          items: [
            for (final name in sortedNames)
              DropdownMenuItem(value: name, child: Text(name)),
          ],
          onChanged: onSelectedTestName,
        ),
        const SizedBox(height: AppSpacing.xl),
        if (filtered.isEmpty)
          _StatsEmptyState(
            icon: Icons.science_outlined,
            message: '\uD574\uB2F9 \uAC80\uC0AC \uD56D\uBAA9\uC758 \uAE30\uB85D\uC774 \uC5C6\uC2B5\uB2C8\uB2E4.',
            buttonLabel: '\uAC80\uC0AC \uACB0\uACFC \uAE30\uB85D\uD558\uAE30',
            onPressed: onOpenLab,
          )
        else
          _StatsSection(
            title: selected,
            notice: hasMixedUnits
                ? '\uAE30\uB85D\uB41C \uB2E8\uC704\uAC00 \uC11C\uB85C \uB2E4\uB985\uB2C8\uB2E4.'
                : null,
            chart: hasMixedUnits
                ? null
                : _LineChart(
                    series: [
                      _ChartSeries(
                        color: AppColors.primary,
                        points: [
                          for (final result in filtered)
                            _ChartPoint(date: result.date, value: result.value),
                        ],
                      ),
                    ],
                    axisFormat: _ChartAxisFormat.lab,
                  ),
            children: [
              for (final result in filtered.reversed)
                _ValueRow(date: result.date, value: result.displayValue),
            ],
          ),
      ],
    );
  }
}

class _StatsEmptyState extends StatelessWidget {
  const _StatsEmptyState({
    required this.icon,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String message;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: icon,
      message: message,
      action: PrimaryButton(
        label: buttonLabel,
        icon: Icons.add,
        onPressed: onPressed ?? () {},
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.title,
    required this.children,
    this.chart,
    this.legends = const [],
    this.notice,
  });

  final String title;
  final Widget? chart;
  final List<_Legend> legends;
  final String? notice;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (legends.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: legends,
            ),
          ],
          if (notice != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              notice!,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.secondaryText),
            ),
          ],
          if (chart != null) ...[const SizedBox(height: AppSpacing.md), chart!],
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label),
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.date, required this.value});

  final DateTime date;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                _formatShortDate(date),
                maxLines: 1,
                softWrap: false,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.secondaryText),
              ),
            ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChartAxisFormat { weight, bloodPressure, lab }

class _LineChart extends StatelessWidget {
  const _LineChart({required this.series, required this.axisFormat});

  final List<_ChartSeries> series;
  final _ChartAxisFormat axisFormat;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('statistics-chart'),
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.border),
      ),
      child: CustomPaint(painter: _LineChartPainter(series, axisFormat)),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(this.series, this.axisFormat);

  final List<_ChartSeries> series;
  final _ChartAxisFormat axisFormat;

  @override
  void paint(Canvas canvas, Size size) {
    final allPoints = [for (final item in series) ...item.points];
    if (allPoints.isEmpty) {
      return;
    }

    var minValue = allPoints.map((point) => point.value).reduce(math.min);
    var maxValue = allPoints.map((point) => point.value).reduce(math.max);
    if (minValue == maxValue) {
      minValue -= 1;
      maxValue += 1;
    } else {
      final padding = (maxValue - minValue) * 0.12;
      minValue -= padding;
      maxValue += padding;
    }

    final plotRect = Rect.fromLTWH(44, 14, size.width - 58, size.height - 46);
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = AppColors.secondaryText
      ..strokeWidth = 1;

    for (var i = 0; i < 3; i += 1) {
      final y = plotRect.top + plotRect.height * i / 2;
      canvas.drawLine(
        Offset(plotRect.left, y),
        Offset(plotRect.right, y),
        gridPaint,
      );
      final value = maxValue - (maxValue - minValue) * i / 2;
      _drawText(
        canvas,
        _formatAxisValue(value),
        Offset(6, y - 8),
        11,
        AppColors.secondaryText,
      );
    }
    canvas.drawLine(plotRect.bottomLeft, plotRect.bottomRight, axisPaint);
    canvas.drawLine(plotRect.bottomLeft, plotRect.topLeft, axisPaint);

    final dates = allPoints.map((point) => point.date).toList()
      ..sort((a, b) => a.compareTo(b));
    final firstDate = dates.first;
    final lastDate = dates.last;
    final labelDates = <DateTime>[firstDate];
    if (dates.length > 2) {
      labelDates.add(dates[dates.length ~/ 2]);
    }
    if (lastDate != firstDate) {
      labelDates.add(lastDate);
    }
    for (final date in labelDates.toSet()) {
      final x = _xForDate(date, firstDate, lastDate, plotRect);
      _drawText(
        canvas,
        _formatShortDate(date),
        Offset(
          (x - 18).clamp(0, size.width - 36).toDouble(),
          plotRect.bottom + 8,
        ),
        11,
        AppColors.secondaryText,
      );
    }

    for (final item in series) {
      final linePaint = Paint()
        ..color = item.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final pointPaint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;
      final sorted = item.points.toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      final path = Path();
      for (var i = 0; i < sorted.length; i += 1) {
        final point = sorted[i];
        final x = _xForDate(point.date, firstDate, lastDate, plotRect);
        final y = _yForValue(point.value, minValue, maxValue, plotRect);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        canvas.drawCircle(Offset(x, y), 4, pointPaint);
      }
      if (sorted.length > 1) {
        canvas.drawPath(path, linePaint);
      }
    }
  }

  double _xForDate(DateTime date, DateTime first, DateTime last, Rect rect) {
    final totalDays = last.difference(first).inDays;
    if (totalDays == 0) {
      return rect.left + rect.width / 2;
    }
    final dayOffset = date.difference(first).inDays;
    return rect.left + rect.width * dayOffset / totalDays;
  }

  double _yForValue(double value, double minValue, double maxValue, Rect rect) {
    return rect.bottom -
        rect.height * ((value - minValue) / (maxValue - minValue));
  }

  String _formatAxisValue(double value) {
    return switch (axisFormat) {
      _ChartAxisFormat.weight => _formatMaxOneDecimal(value),
      _ChartAxisFormat.bloodPressure => value.round().toString(),
      _ChartAxisFormat.lab => _formatMaxOneDecimal(value),
    };
  }

  String _formatMaxOneDecimal(double value) {
    final text = value.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, color: color),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 42);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.axisFormat != axisFormat;
  }
}

class _ChartSeries {
  const _ChartSeries({required this.color, required this.points});
  final Color color;
  final List<_ChartPoint> points;
}

class _ChartPoint {
  const _ChartPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

String _formatShortDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$month.$day';
}
