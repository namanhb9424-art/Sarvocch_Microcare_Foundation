import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/database_helper.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_recovery_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _loading = false;
  late Future<Map<String, int>> _integrityWarnings;
  late Future<List<File>> _recoverySnapshots;
  late Future<List<Map<String, Object?>>> _auditEvents;
  final DatabaseRecoveryService _recoveryService = DatabaseRecoveryService();

  @override
  void initState() {
    super.initState();
    _integrityWarnings = _loadIntegrityWarnings();
    _recoverySnapshots = _recoveryService.listSnapshots();
    _auditEvents = _loadAuditEvents();
  }

  Future<List<Map<String, Object?>>> _loadAuditEvents() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return [];
    final db = await DatabaseHelper.instance.database;
    return db.transaction((txn) async {
      final actors = await txn.query(
        'users',
        columns: ['role', 'auth_status'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (actors.isEmpty ||
          actors.first['role'] != 'admin' ||
          actors.first['auth_status'] != 'active') {
        return [];
      }
      final rows = await txn.query(
        'audit_log',
        columns: [
          'id',
          'action',
          'entity_type',
          'entity_id',
          'actor_name',
          'actor_role',
          'occurred_at',
          'details',
        ],
        orderBy: 'id DESC',
        limit: 50,
      );
      final recoveryRows = await txn.query(
        'recovery_events',
        columns: [
          'id',
          'action',
          'source_actor_name',
          'source_label',
          'portable',
          'occurred_at',
        ],
        orderBy: 'id DESC',
        limit: 50,
      );
      final events = rows.map(Map<String, Object?>.from).toList()
        ..addAll(
          recoveryRows.map(
            (row) => <String, Object?>{
              'id': row['id'],
              'action': row['action'],
              'entity_type': 'recovery',
              'entity_id': 0,
              'actor_name': row['source_actor_name'],
              'actor_role': 'admin (source database)',
              'occurred_at': row['occurred_at'],
              'details': jsonEncode({
                'source_label': row['source_label'],
                'portable': row['portable'] == 1,
              }),
            },
          ),
        )
        ..sort(
          (a, b) => (b['occurred_at'] as String).compareTo(
            a['occurred_at'] as String,
          ),
        );
      return events.take(50).toList();
    });
  }

  String _auditActionLabel(String action) {
    switch (action) {
      case 'kyc_consent_snapshot_captured':
        return 'KYC consent choices recorded';
      case 'login_succeeded':
        return 'User signed in';
      case 'login_failed':
        return 'Sign-in failed';
      case 'login_locked':
        return 'Account temporarily locked';
      case 'session_revoked':
        return 'Session revoked';
      case 'portable_backup_exported':
        return 'Encrypted backup exported';
      case 'portable_backup_imported':
        return 'Portable backup restored';
      case 'database_recovery_restored':
        return 'Recovery snapshot restored';
      default:
        return action.replaceAll('_', ' ');
    }
  }

  String _auditSummary(Map<String, Object?> event) {
    if (event['entity_type'] == 'recovery') {
      try {
        final details = jsonDecode(event['details'] as String) as Map;
        final source = details['source_label'] as String? ?? 'backup file';
        return 'Source: $source • '
            '${details['portable'] == true ? 'portable backup' : 'device snapshot'}';
      } catch (_) {
        return 'Recovery completed; source details could not be read.';
      }
    }
    if (event['action'] != 'kyc_consent_snapshot_captured') {
      return '${event['entity_type']} #${event['entity_id']}';
    }
    try {
      final details = jsonDecode(event['details'] as String) as Map;
      final declaration = details['applicant_declaration_given'] == true
          ? 'accepted'
          : 'not accepted';
      final husband = details['husband_loan_consent_applicable'] == true
          ? (details['husband_loan_consent_given'] == true
                ? 'accepted'
                : 'not accepted')
          : 'not applicable';
      final bureau =
          details['credit_bureau_insurance_sharing_consent_given'] == true
          ? 'accepted'
          : 'not accepted';
      final visit = details['address_visit_attested'] == true
          ? 'officer attested'
          : 'not attested';
      return 'Existing notice copy (approval pending). Declaration: '
          '$declaration • Husband consent: $husband • '
          'Credit/insurance sharing: $bureau • Address visit: $visit';
    } catch (_) {
      return 'Recorded consent snapshot; details could not be read.';
    }
  }

  Future<void> _createRecoverySnapshot() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final snapshot = await _recoveryService.createSnapshot(
        actorUserId: user.id,
      );
      if (!mounted) return;
      setState(() => _recoverySnapshots = _recoveryService.listSnapshots());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Encrypted recovery snapshot created: ${snapshot.path.split(Platform.pathSeparator).last}',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create recovery snapshot.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _requestBackupPassphrase({
    required bool confirmPassphrase,
  }) async {
    final passphraseController = TextEditingController();
    final confirmationController = TextEditingController();
    var obscurePassphrase = true;
    var errorText = '';
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              confirmPassphrase
                  ? 'Protect portable backup'
                  : 'Unlock portable backup',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Use a passphrase of at least 16 characters. It is not stored with the backup; keep it separately.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passphraseController,
                  obscureText: obscurePassphrase,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Backup passphrase',
                    suffixIcon: IconButton(
                      onPressed: () => setDialogState(
                        () => obscurePassphrase = !obscurePassphrase,
                      ),
                      icon: Icon(
                        obscurePassphrase
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                if (confirmPassphrase) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmationController,
                    obscureText: obscurePassphrase,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Confirm passphrase',
                    ),
                  ),
                ],
                if (errorText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText,
                    style: const TextStyle(color: AppTheme.danger),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final passphrase = passphraseController.text;
                  if (passphrase.length < 16) {
                    setDialogState(
                      () => errorText = 'Use at least 16 characters.',
                    );
                    return;
                  }
                  if (confirmPassphrase &&
                      passphrase != confirmationController.text) {
                    setDialogState(
                      () => errorText = 'The passphrases do not match.',
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, passphrase);
                },
                child: Text(confirmPassphrase ? 'Continue' : 'Unlock'),
              ),
            ],
          ),
        ),
      );
    } finally {
      passphraseController.dispose();
      confirmationController.dispose();
    }
  }

  Future<void> _exportPortableBackup() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || kIsWeb) return;
    final passphrase = await _requestBackupPassphrase(confirmPassphrase: true);
    if (passphrase == null || !mounted) return;

    final isMobile = Platform.isAndroid || Platform.isIOS;
    final fileName =
        'microcare_backup_${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.svcbak';
    File? temporaryExport;
    setState(() => _loading = true);
    try {
      File? desktopTarget;
      if (!isMobile) {
        final destination = await getSaveLocation(
          acceptedTypeGroups: const [
            XTypeGroup(
              label: 'Encrypted Microcare backup',
              extensions: ['svcbak'],
            ),
          ],
          suggestedName: fileName,
        );
        if (destination == null) return;
        var destinationPath = destination.path;
        if (!destinationPath.toLowerCase().endsWith('.svcbak')) {
          destinationPath = '$destinationPath.svcbak';
        }
        desktopTarget = File(destinationPath);
      }

      final bytes = await _recoveryService.createPortableBackup(
        actorUserId: user.id,
        passphrase: passphrase,
      );
      if (isMobile) {
        final temporaryDirectory = await getTemporaryDirectory();
        temporaryExport = File(
          '${temporaryDirectory.path}${Platform.pathSeparator}$fileName',
        );
        await temporaryExport.writeAsBytes(bytes, flush: true);
        final renderObject = context.findRenderObject();
        final shareOrigin = renderObject is RenderBox
            ? renderObject.localToGlobal(Offset.zero) & renderObject.size
            : null;
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [XFile(temporaryExport.path)],
            title: 'Encrypted Microcare backup',
            sharePositionOrigin: shareOrigin,
          ),
        );
        if (result.status == ShareResultStatus.dismissed) return;
      } else {
        await desktopTarget!.writeAsBytes(bytes, flush: true);
      }
      var exportMessage =
          'Encrypted backup exported. Store the file and passphrase separately.';
      try {
        await _recoveryService.recordPortableBackupExport(
          actorUserId: user.id,
          fileName: isMobile ? fileName : desktopTarget!.path,
        );
      } catch (_) {
        exportMessage = 'Backup exported, but the export could not be added to the audit log.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exportMessage)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not export backup.')),
        );
      }
    } finally {
      if (temporaryExport != null && await temporaryExport.exists()) {
        await temporaryExport.delete();
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importPortableBackup() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || kIsWeb) return;
    final backupFileType = Platform.isIOS
        ? const XTypeGroup(
            label: 'Encrypted Microcare backup',
            uniformTypeIdentifiers: ['public.data'],
          )
        : const XTypeGroup(
            label: 'Encrypted Microcare backup',
            extensions: ['svcbak'],
          );
    final selected = await openFile(acceptedTypeGroups: [backupFileType]);
    if (selected == null || !mounted) return;
    final passphrase = await _requestBackupPassphrase(confirmPassphrase: false);
    if (passphrase == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import this portable backup?'),
        content: const Text(
          'Import replaces this device’s local database after the encrypted file and database are validated. The current database is saved as an on-device recovery snapshot first. You will be signed out and must use an account from the imported data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Import backup'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final name = await _recoveryService.restorePortableBackup(
        actorUserId: user.id,
        backupBytes: await selected.readAsBytes(),
        passphrase: passphrase,
        sourceName: selected.name,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.read<AuthProvider>().logout();
      messenger.showSnackBar(
        SnackBar(content: Text('Imported $name. Sign in again.')),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (_) {
      if (mounted) {
        setState(() => _recoverySnapshots = _recoveryService.listSnapshots());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not import backup.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restoreRecoverySnapshot(List<File> snapshots) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || snapshots.isEmpty) return;
    final selected = await showDialog<File>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose a recovery snapshot'),
        content: SizedBox(
          width: 440,
          height: 320,
          child: ListView.builder(
            itemCount: snapshots.length,
            itemBuilder: (context, index) {
              final file = snapshots[index];
              final name = file.path.split(Platform.pathSeparator).last;
              return ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: FutureBuilder<DateTime>(
                  future: file.lastModified(),
                  builder: (context, snapshot) => Text(
                    snapshot.hasData
                        ? snapshot.data!.toLocal().toString()
                        : 'Encrypted on-device snapshot',
                  ),
                ),
                onTap: () => Navigator.pop(dialogContext, file),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore this snapshot?'),
        content: const Text(
          'Restoring replaces the current local database. The current database will first be saved as an encrypted recovery snapshot. You will be signed out and must use an account from the restored data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore snapshot'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final restoredName = await _recoveryService.restoreSnapshot(
        actorUserId: user.id,
        snapshotPath: selected.path,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.read<AuthProvider>().logout();
      messenger.showSnackBar(
        SnackBar(content: Text('Restored $restoredName. Sign in again.')),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (_) {
      if (mounted) {
        setState(() => _recoverySnapshots = _recoveryService.listSnapshots());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not restore snapshot.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, int>> _loadIntegrityWarnings() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_meta',
      columns: ['key', 'value'],
      where: 'key LIKE ?',
      whereArgs: ['integrity_warning_%'],
    );
    return {
      for (final row in rows)
        if ((int.tryParse(row['value'] as String? ?? '') ?? 0) > 0)
          row['key'] as String: int.parse(row['value'] as String),
    };
  }

  Future<void> _retrySensitiveCleanup() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      await DatabaseHelper.instance.retrySensitiveDataScrub(
        actorUserId: user.id,
      );
      if (!mounted) return;
      setState(() => _integrityWarnings = _loadIntegrityWarnings());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sensitive data cleanup was retried.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cleanup retry failed.')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Admin Settings & Policies'),
      drawer: const CustomDrawer(currentRoute: '/settings'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<Map<String, int>>(
            future: _integrityWarnings,
            builder: (context, snapshot) {
              final warnings = snapshot.data ?? const <String, int>{};
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LOCAL DATA INTEGRITY',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (snapshot.hasError)
                        const Text('Could not read the local integrity status.')
                      else if (snapshot.connectionState != ConnectionState.done)
                        const LinearProgressIndicator()
                      else if (warnings.isEmpty)
                        const Text(
                          'No unresolved duplicate keys, MFI reference/value issues, or legacy KYC image warnings are recorded.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        )
                      else ...[
                        if (warnings.keys.any(
                          (key) => key.contains('sensitive'),
                        ))
                          const Text(
                            'Sensitive legacy values were cleared, but SQLite could not finish rewriting old database pages. Resolve storage or database-lock issues, then retry cleanup.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        if (warnings.keys.any(
                          (key) => key.contains('kyc_attachments'),
                        ))
                          const Text(
                            'Some older KYC photos could not be moved into encrypted app storage. Open each affected KYC form to replace or remove its photo, then restart the app to retry migration.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        if (warnings.keys.any((key) => key.contains('orphan_')))
                          const Text(
                            'Older records contain missing or inconsistent business references. They were preserved; review the affected customer, loan, installment or payment records before editing or exporting them.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        if (warnings.keys.any(
                          (key) => key.contains('invalid_'),
                        ))
                          const Text(
                            'Older financial records contain invalid or incomplete values. They were preserved for reconciliation; do not use affected balances for posting until reviewed.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        if (warnings.keys.any(
                          (key) =>
                              !key.contains('sensitive') &&
                              !key.contains('kyc_attachments') &&
                              !key.contains('orphan_') &&
                              !key.contains('invalid_'),
                        ))
                          const Text(
                            'Some records already shared a key during the database upgrade. The app preserved them and skipped the affected uniqueness constraint. Review these records before correcting duplicates.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        const SizedBox(height: 8),
                        for (final entry in warnings.entries)
                          _rule(
                            entry.key.contains('sensitive')
                                ? '${_integrityLabel(entry.key)}: cleanup pending'
                                : entry.key.contains('kyc_attachments')
                                ? '${_integrityLabel(entry.key)}: ${entry.value} image references need review'
                                : entry.key.contains('orphan_')
                                ? '${_integrityLabel(entry.key)}: ${entry.value} records need review'
                                : entry.key.contains('invalid_')
                                ? '${_integrityLabel(entry.key)}: ${entry.value} records need reconciliation'
                                : '${_integrityLabel(entry.key)}: ${entry.value} duplicate groups',
                          ),
                        if (warnings.keys.any(
                          (key) => key.contains('sensitive'),
                        ))
                          OutlinedButton.icon(
                            onPressed: _loading ? null : _retrySensitiveCleanup,
                            icon: const Icon(Icons.cleaning_services_outlined),
                            label: const Text('Retry sensitive-data cleanup'),
                          ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, Object?>>>(
            future: _auditEvents,
            builder: (context, snapshot) {
              final events = snapshot.data ?? const [];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'RECENT AUDIT ACTIVITY',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Refresh audit activity',
                            onPressed: () => setState(
                              () => _auditEvents = _loadAuditEvents(),
                            ),
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      if (snapshot.hasError)
                        const Text('Could not read the audit activity.')
                      else if (snapshot.connectionState != ConnectionState.done)
                        const LinearProgressIndicator()
                      else if (events.isEmpty)
                        const Text(
                          'No audit events are available on this device.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        )
                      else
                        for (final event in events)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              _auditActionLabel(
                                event['action']?.toString() ?? 'activity',
                              ),
                            ),
                            subtitle: Text(
                              '${_auditSummary(event)}\n'
                              '${event['actor_name']} • ${event['actor_role']} • '
                              '${event['occurred_at']}',
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<File>>(
            future: _recoverySnapshots,
            builder: (context, snapshot) {
              final backups = snapshot.data ?? const <File>[];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ON-DEVICE RECOVERY',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (kIsWeb)
                        const Text(
                          'On-device recovery snapshots are available in installed mobile and desktop builds.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        )
                      else if (snapshot.hasError)
                        const Text(
                          'Recovery storage is unavailable on this device.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        )
                      else if (snapshot.connectionState != ConnectionState.done)
                        const LinearProgressIndicator()
                      else ...[
                        const Text(
                          'Create an encrypted snapshot for local recovery. Snapshots and their encryption key stay on this device; this does not protect against device loss or reinstall.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${backups.length} recovery snapshot(s) available.',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _loading
                                  ? null
                                  : _createRecoverySnapshot,
                              icon: const Icon(Icons.lock_outline),
                              label: const Text('Create snapshot'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _loading || backups.isEmpty
                                  ? null
                                  : () => _restoreRecoverySnapshot(backups),
                              icon: const Icon(Icons.restore),
                              label: const Text('Restore snapshot'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PORTABLE ENCRYPTED BACKUP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kIsWeb
                        ? 'Portable database backups are available in installed mobile and desktop builds.'
                        : 'Export or import an AES-GCM encrypted database file. A 16-character passphrase protects it; the passphrase is never stored. Keep the file and passphrase separately.',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _loading ? null : _exportPortableBackup,
                          icon: const Icon(Icons.file_upload_outlined),
                          label: const Text('Export encrypted backup'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _importPortableBackup,
                          icon: const Icon(Icons.file_download_outlined),
                          label: const Text('Import encrypted backup'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MFI RULES IN THE LOCAL PORTAL PROTOTYPE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _rule('Applicant age: 18–65 years'),
                  _rule('Group size: 5–10 members'),
                  _rule(
                    'Estimated EMI: no more than 60% of monthly household income',
                  ),
                  _rule(
                    'At least two documents selected for each loan application',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'These are prototype business rules from the local website code. The organization has not configured an approved product policy in this app. Group capture is paused, and product fees, tax settings, payroll rules and statutory deductions are not calculated here.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.manage_accounts_outlined,
                color: AppTheme.tealPrimary,
              ),
              title: const Text('User Accounts & Access'),
              subtitle: const Text(
                'Create staff and customer logins, reset passwords, and disable accounts.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/users'),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Branch GPS geofences are configured on each branch record. Payment processing, issuer identity checks, WhatsApp delivery, online customer accounts and production cloud sync are not connected.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rule(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.rule, size: 16, color: AppTheme.tealPrimary),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );

  String _integrityLabel(String key) {
    if (key.contains('sensitive')) return 'Sensitive-data page cleanup';
    if (key.contains('kyc_attachments')) return 'Legacy KYC images';
    if (key.contains('orphan_applications_customer')) {
      return 'Applications with missing customers';
    }
    if (key.contains('orphan_applications_product')) {
      return 'Applications with missing products';
    }
    if (key.contains('orphan_loans')) {
      return 'Loans with inconsistent references';
    }
    if (key.contains('orphan_schedule')) {
      return 'Installments with missing loans';
    }
    if (key.contains('orphan_payments')) {
      return 'Payments with inconsistent references';
    }
    if (key.contains('invalid_applications')) {
      return 'Applications with invalid terms';
    }
    if (key.contains('invalid_approvals')) {
      return 'Approvals with invalid amounts';
    }
    if (key.contains('invalid_kyc_income')) {
      return 'KYC income/debt amounts';
    }
    if (key.contains('invalid_products_amounts')) {
      return 'Loan product amount limits';
    }
    if (key.contains('invalid_tasks_collected')) {
      return 'Field task collection amounts';
    }
    if (key.contains('invalid_pregrt_member_money')) {
      return 'Pre-GRT member income/loan amounts';
    }
    if (key.contains('invalid_employee_salary')) {
      return 'Employee salary amounts';
    }
    if (key.contains('invalid_application_cashflow')) {
      return 'Application household income/expense amounts';
    }
    if (key.contains('foreign_key_violations')) {
      return 'Database relationship violations';
    }
    if (key.contains('foreign_key_orphans')) {
      return 'Lending records blocking relationship upgrade';
    }
    if (key.contains('foreign_key_operational_orphans')) {
      return 'Operational records blocking relationship upgrade';
    }
    if (key.contains('foreign_key_migration_pending')) {
      return 'Legacy database relationship upgrade pending';
    }
    if (key.contains('invalid_loans')) return 'Loans with invalid terms';
    if (key.contains('invalid_schedule')) {
      return 'Installments with invalid values';
    }
    if (key.contains('invalid_payments')) {
      return 'Payments with invalid amounts';
    }
    if (key.contains('attendance')) return 'Attendance by officer and day';
    if (key.contains('payment_schedule')) return 'Payment by installment';
    if (key.contains('loans_application')) return 'Loan by application';
    if (key.contains('schedule')) return 'Loan installment number';
    if (key.contains('username')) return 'Case-insensitive username';
    if (key.contains('employee_user')) return 'Employee account link';
    return 'Database key';
  }
}
