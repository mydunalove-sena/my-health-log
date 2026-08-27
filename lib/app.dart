import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/data_management/data_management_screen.dart';
import 'screens/health/health_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/lab/lab_screen.dart';
import 'screens/medication/medication_screen.dart';
import 'screens/statistics/statistics_screen.dart';
import 'services/backup_service.dart';
import 'services/health_field_visibility_service.dart';
import 'services/health_record_service.dart';
import 'services/lab_result_service.dart';
import 'services/medication_service.dart';
import 'services/symptom_service.dart';

class MyHealthLogApp extends StatelessWidget {
  const MyHealthLogApp({
    super.key,
    this.healthRecordService,
    this.medicationService,
    this.labResultService,
    this.symptomService,
    this.healthFieldVisibilityService,
  });

  final HealthRecordService? healthRecordService;
  final MedicationService? medicationService;
  final LabResultService? labResultService;
  final SymptomService? symptomService;
  final HealthFieldVisibilityService? healthFieldVisibilityService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Health Log',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: _AppBootstrap(
        healthRecordService: healthRecordService,
        medicationService: medicationService,
        labResultService: labResultService,
        symptomService: symptomService,
        healthFieldVisibilityService: healthFieldVisibilityService,
      ),
    );
  }
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap({
    this.healthRecordService,
    this.medicationService,
    this.labResultService,
    this.symptomService,
    this.healthFieldVisibilityService,
  });

  final HealthRecordService? healthRecordService;
  final MedicationService? medicationService;
  final LabResultService? labResultService;
  final SymptomService? symptomService;
  final HealthFieldVisibilityService? healthFieldVisibilityService;

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  late final HealthRecordService _healthService;
  late final MedicationService _medicationService;
  late final LabResultService _labResultService;
  late final SymptomService _symptomService;
  late final HealthFieldVisibilityService _fieldVisibilityService;
  late final Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _healthService =
        widget.healthRecordService ??
        HealthRecordService(SqfliteHealthRecordStorage());
    _medicationService =
        widget.medicationService ??
        MedicationService(SqfliteMedicationStorage());
    _labResultService =
        widget.labResultService ?? LabResultService(SqfliteLabResultStorage());
    _symptomService =
        widget.symptomService ??
        SymptomService(
          _hasInjectedServices
              ? InMemorySymptomStorage()
              : SqfliteSymptomStorage(),
        );
    _fieldVisibilityService =
        widget.healthFieldVisibilityService ??
        (_hasInjectedServices
            ? HealthFieldVisibilityService.inMemory()
            : HealthFieldVisibilityService());
    _loadFuture = Future.wait<void>([
      _healthService.load(),
      _medicationService.load(),
      _labResultService.load(),
      _symptomService.load(),
      _fieldVisibilityService.load(),
    ]);
  }

  bool get _hasInjectedServices {
    return widget.healthRecordService != null ||
        widget.medicationService != null ||
        widget.labResultService != null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text(
                '\uB370\uC774\uD130\uB97C \uBD88\uB7EC\uC624\uC9C0 \uBABB\uD588\uC2B5\uB2C8\uB2E4.',
              ),
            ),
          );
        }
        return AppShell(
          healthRecordService: _healthService,
          medicationService: _medicationService,
          labResultService: _labResultService,
          symptomService: _symptomService,
          healthFieldVisibilityService: _fieldVisibilityService,
        );
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.healthRecordService,
    required this.medicationService,
    required this.labResultService,
    required this.symptomService,
    required this.healthFieldVisibilityService,
  });

  final HealthRecordService healthRecordService;
  final MedicationService medicationService;
  final LabResultService labResultService;
  final SymptomService symptomService;
  final HealthFieldVisibilityService healthFieldVisibilityService;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(
        healthRecordService: widget.healthRecordService,
        medicationService: widget.medicationService,
        healthFieldVisibilityService: widget.healthFieldVisibilityService,
        onOpenHealthRoot: () => _selectTab(1),
        onOpenMedication: () => _selectTab(2),
        onOpenDataManagement: _openDataManagement,
      ),
      HealthScreen(
        service: widget.healthRecordService,
        symptomService: widget.symptomService,
        healthFieldVisibilityService: widget.healthFieldVisibilityService,
      ),
      MedicationScreen(
        service: widget.medicationService,
        symptomService: widget.symptomService,
      ),
      LabScreen(service: widget.labResultService),
      StatisticsScreen(
        healthRecordService: widget.healthRecordService,
        labResultService: widget.labResultService,
        healthFieldVisibilityService: widget.healthFieldVisibilityService,
        onOpenHealth: () => _selectTab(1),
        onOpenLab: () => _selectTab(3),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.house_outlined),
            selectedIcon: Icon(Icons.house),
            label: '\uD648',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: '\uAC74\uAC15',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication),
            label: '\uBCF5\uC57D',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science),
            label: '\uAC80\uC0AC',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '\uD1B5\uACC4',
          ),
        ],
      ),
    );
  }

  Future<void> _openDataManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DataManagementScreen(
          backupService: BackupService(repository: SqfliteBackupRepository()),
          healthRecordService: widget.healthRecordService,
          medicationService: widget.medicationService,
          labResultService: widget.labResultService,
          symptomService: widget.symptomService,
        ),
      ),
    );
  }
}
