import 'package:flutter/material.dart';

class HomeMockState {
  const HomeMockState({
    required this.hasHealthRecord,
    required this.hasMedications,
  });

  const HomeMockState.withData()
    : hasHealthRecord = true,
      hasMedications = true;

  const HomeMockState.empty() : hasHealthRecord = false, hasMedications = false;

  final bool hasHealthRecord;
  final bool hasMedications;
}

class HealthSummaryItem {
  const HealthSummaryItem({
    required this.title,
    required this.value,
    required this.icon,
    this.unit,
  });

  final String title;
  final String value;
  final String? unit;
  final IconData icon;
}

class MedicationSummaryItem {
  const MedicationSummaryItem({required this.name, required this.isTaken});

  final String name;
  final bool isTaken;
}
