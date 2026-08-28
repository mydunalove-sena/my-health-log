import 'package:flutter/material.dart';

import '../../services/health_field_visibility_service.dart';

class HealthFieldVisibilityScreen extends StatelessWidget {
  const HealthFieldVisibilityScreen({super.key, required this.service});

  final HealthFieldVisibilityService service;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('\uD56D\uBAA9 \uD45C\uC2DC \uC124\uC815'),
          ),
          body: SafeArea(
            child: ListView(
              children: [
                _VisibilitySwitch(
                  key: const Key('visibility-weight-switch'),
                  title: '\uCCB4\uC911',
                  value: service.weightVisible,
                  onChanged: (value) => service.setVisible(
                    HealthFieldVisibilityKey.weight,
                    value,
                  ),
                ),
                _VisibilitySwitch(
                  key: const Key('visibility-blood-pressure-switch'),
                  title: '\uD608\uC555',
                  value: service.bloodPressureVisible,
                  onChanged: (value) => service.setVisible(
                    HealthFieldVisibilityKey.bloodPressure,
                    value,
                  ),
                ),
                _VisibilitySwitch(
                  key: const Key('visibility-water-switch'),
                  title: '\uC218\uBD84',
                  value: service.waterIntakeVisible,
                  onChanged: (value) => service.setVisible(
                    HealthFieldVisibilityKey.waterIntake,
                    value,
                  ),
                ),
                _VisibilitySwitch(
                  key: const Key('visibility-sleep-switch'),
                  title: '\uC218\uBA74',
                  value: service.sleepHoursVisible,
                  onChanged: (value) => service.setVisible(
                    HealthFieldVisibilityKey.sleepHours,
                    value,
                  ),
                ),
                _VisibilitySwitch(
                  key: const Key('visibility-condition-switch'),
                  title: '\uCEE8\uB514\uC158',
                  value: service.conditionVisible,
                  onChanged: (value) => service.setVisible(
                    HealthFieldVisibilityKey.condition,
                    value,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VisibilitySwitch extends StatelessWidget {
  const _VisibilitySwitch({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}
