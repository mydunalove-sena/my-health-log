import 'package:flutter/material.dart';

import '../../services/backup_service.dart';
import '../../services/health_record_service.dart';
import '../../services/lab_result_service.dart';
import '../../services/medication_service.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({
    super.key,
    required this.backupService,
    required this.healthRecordService,
    required this.medicationService,
    required this.labResultService,
  });

  final BackupService backupService;
  final HealthRecordService healthRecordService;
  final MedicationService medicationService;
  final LabResultService labResultService;

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('데이터 관리')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _isBusy ? null : _saveBackupFile,
            icon: const Icon(Icons.save_alt),
            label: const Text('백업 파일 저장'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isBusy ? null : _shareBackupFile,
            icon: const Icon(Icons.share),
            label: const Text('백업 파일 공유'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isBusy ? null : _restore,
            icon: const Icon(Icons.restore),
            label: const Text('데이터 복원'),
          ),
          if (_isBusy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Future<void> _saveBackupFile() async {
    await _runBusy(() async {
      final document = await widget.backupService.createBackup();
      final fileName = widget.backupService.backupFileName(document.createdAt);
      final path = await widget.backupService.saveBackupFile(document);
      if (!mounted) {
        return;
      }
      if (path == null) {
        _showMessage('백업 파일 저장이 취소되었습니다.');
        return;
      }
      _showMessage('백업 파일 저장 완료: $fileName');
    });
  }

  Future<void> _shareBackupFile() async {
    await _runBusy(() async {
      final document = await widget.backupService.createBackup();
      final file = await widget.backupService.writeBackupFile(document);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('백업 파일을 생성했습니다. (${document.totalCount}건)')),
      );
      await widget.backupService.shareBackupFile(file);
    });
  }

  Future<void> _restore() async {
    await _runBusy(() async {
      BackupDocument? document;
      try {
        document = await widget.backupService.pickAndValidateBackup();
      } on BackupValidationException catch (error) {
        if (mounted) {
          _showMessage(error.message);
        }
        return;
      }
      if (document == null || !mounted) {
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('데이터 복원'),
            content: Text(
              '백업 데이터를 복원하면 현재 저장된 데이터가 백업 데이터로 교체됩니다. 현재 데이터를 보관하려면 먼저 백업해 주세요.\n\n'
              '백업 날짜: ${_formatDateTime(document!.createdAt)}\n'
              '총 데이터: ${document.totalCount}건',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('복원하기'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) {
        return;
      }

      await widget.backupService.restoreBackup(document);
      await Future.wait<void>([
        widget.healthRecordService.load(),
        widget.medicationService.load(),
        widget.labResultService.load(),
      ]);
      if (mounted) {
        _showMessage('데이터 복원이 완료되었습니다.');
      }
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _isBusy = true;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        _showMessage('작업을 완료하지 못했습니다.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDateTime(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year}.${twoDigits(date.month)}.${twoDigits(date.day)} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }
}
