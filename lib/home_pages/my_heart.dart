import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:medical/functions/app_colors.dart';
import 'package:medical/models/ecg_pipeline_models.dart';
import 'package:medical/services/api_service.dart';

class MyHeartPage extends StatefulWidget {
  const MyHeartPage({super.key});

  @override
  State<MyHeartPage> createState() => _MyHeartPageState();
}

class _MyHeartPageState extends State<MyHeartPage> {
  bool _loading = true;
  bool _assigningDevice = false;
  bool _deletingAllSessions = false;
  String? _error;
  List<MonitoringSession> _sessions = const [];
  List<Device> _devices = const [];
  List<dynamic> _patients = const [];
  Map<String, dynamic>? _profile;
  final Set<String> _deletingSessionIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        ApiService.getSessions(),
        ApiService.getDevices(),
        ApiService.getUserProfile().catchError((_) => <String, dynamic>{}),
      ]);
      final profile = Map<String, dynamic>.from(results[2] as Map);
      final role = (profile['role'] ?? '').toString();
      var patients = const <dynamic>[];
      if (role == 'doctor') {
        patients = await ApiService.getPatients();
      } else if (role == 'admin') {
        final users = await ApiService.getAllUsers();
        patients = users
            .where((user) => user is Map && user['role'] == 'patient')
            .toList(growable: false);
      }
      if (!mounted) return;
      setState(() {
        _sessions = results[0] as List<MonitoringSession>;
        _devices = results[1] as List<Device>;
        _profile = profile.isEmpty ? null : profile;
        _patients = patients;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _assignDevice(String deviceId, int? patientId) async {
    setState(() {
      _assigningDevice = true;
    });
    try {
      await ApiService.assignDevice(deviceId, patientId);
      final devices = await ApiService.getDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _assigningDevice = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device assignment updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _assigningDevice = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _deleteSession(MonitoringSession session) async {
    final confirmed = await _confirmDelete(
      context,
      title: 'Delete session?',
      message:
          'This removes ${session.sessionId}, its readings, AI analysis, and alerts.',
      actionLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _deletingSessionIds.add(session.sessionId);
    });
    try {
      await ApiService.deleteSession(session.sessionId);
      if (!mounted) return;
      setState(() {
        _sessions = _sessions
            .where((item) => item.sessionId != session.sessionId)
            .toList(growable: false);
        _deletingSessionIds.remove(session.sessionId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${session.sessionId} deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deletingSessionIds.remove(session.sessionId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete session: $e')),
      );
    }
  }

  Future<void> _deleteAllSessions() async {
    final confirmed = await _confirmDelete(
      context,
      title: 'Delete all sessions?',
      message:
          'This removes every ECG/PPG session, all readings, AI analysis, and alerts. Devices and users stay saved.',
      actionLabel: 'Delete all',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _deletingAllSessions = true;
    });
    try {
      await ApiService.deleteAllSessions();
      if (!mounted) return;
      setState(() {
        _sessions = const [];
        _deletingSessionIds.clear();
        _deletingAllSessions = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All sessions deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deletingAllSessions = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete sessions: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 68, 20, 28),
          children: [
            Row(
              children: [
                Icon(Icons.monitor_heart, color: AppColors.primary, size: 28),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'ECG/PPG Sessions',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
                if (!_loading && _sessions.isNotEmpty)
                  IconButton(
                    tooltip: 'Delete all sessions',
                    onPressed: _deletingAllSessions ? null : _deleteAllSessions,
                    icon: _deletingAllSessions
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_sweep_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'AI results are decision-support only.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _StatePanel(
                icon: Icons.cloud_off,
                title: 'Could not load sessions',
                message: _error!,
                actionLabel: 'Retry',
                onAction: _load,
              )
            else ...[
              _DeviceAssignmentPanel(
                devices: _devices,
                patients: _patients,
                profile: _profile,
                assigning: _assigningDevice,
                onAssign: _assignDevice,
              ),
              const SizedBox(height: 16),
              if (_sessions.isEmpty)
                const _StatePanel(
                  icon: Icons.timeline,
                  title: 'No sessions yet',
                  message: 'Upload ECG/PPG readings from the device to see them here.',
                )
              else
                ..._sessions.map(
                  (session) => _SessionTile(
                    session: session,
                    deleting: _deletingSessionIds.contains(session.sessionId),
                    onTap: () async {
                      final deleted = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => SessionDetailsPage(
                            sessionId: session.sessionId,
                          ),
                        ),
                      );
                      if (deleted == true) {
                        _load();
                      }
                    },
                    onDelete: () => _deleteSession(session),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeviceAssignmentPanel extends StatefulWidget {
  final List<Device> devices;
  final List<dynamic> patients;
  final Map<String, dynamic>? profile;
  final bool assigning;
  final Future<void> Function(String deviceId, int? patientId) onAssign;

  const _DeviceAssignmentPanel({
    required this.devices,
    required this.patients,
    required this.profile,
    required this.assigning,
    required this.onAssign,
  });

  @override
  State<_DeviceAssignmentPanel> createState() => _DeviceAssignmentPanelState();
}

class _DeviceAssignmentPanelState extends State<_DeviceAssignmentPanel> {
  final Map<String, int?> _selectedPatients = {};

  @override
  Widget build(BuildContext context) {
    final role = (widget.profile?['role'] ?? '').toString();
    final currentPatientId = _intValue(widget.profile?['id']);
    final canAssignPatients = role == 'doctor' || role == 'admin';
    final canSelfAssign = role == 'patient' && currentPatientId != null;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sensors, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Devices',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.devices.isEmpty)
            const Text('No hardware devices have checked in yet.')
          else
            ...widget.devices.map(
              (device) => _deviceRow(
                device,
                canAssignPatients: canAssignPatients,
                canSelfAssign: canSelfAssign,
                currentPatientId: currentPatientId,
              ),
            ),
          if (!canAssignPatients && !canSelfAssign) ...[
            const SizedBox(height: 10),
            const _InfoLine(
              icon: Icons.lock_outline,
              text: 'Sign in as a patient, doctor, or admin to manage device assignment.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _deviceRow(
    Device device, {
    required bool canAssignPatients,
    required bool canSelfAssign,
    required int? currentPatientId,
  }) {
    final assignedLabel = _assignedLabel(device.patientId);
    final patientOptions = _patientOptions();
    final optionIds = patientOptions.map((patient) => patient.id).toSet();
    final selected = _selectedPatients.containsKey(device.deviceId)
        ? _selectedPatients[device.deviceId]
        : optionIds.contains(device.patientId)
            ? device.patientId
            : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  device.label?.isNotEmpty == true ? device.label! : device.deviceId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _StatusChip(label: device.patientId == null ? 'unassigned' : 'assigned'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${device.deviceId}  |  $assignedLabel',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          if (canAssignPatients) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<int>(
                    value: selected,
                    isExpanded: true,
                    hint: const Text('Select patient'),
                    items: patientOptions
                        .map(
                          (patient) => DropdownMenuItem<int>(
                            value: patient.id,
                            child: Text(
                              patient.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: widget.assigning
                        ? null
                        : (value) {
                            setState(() {
                              _selectedPatients[device.deviceId] = value;
                            });
                          },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Assign device',
                  onPressed: widget.assigning || selected == null || selected == device.patientId
                      ? null
                      : () => widget.onAssign(device.deviceId, selected),
                  icon: const Icon(Icons.link),
                ),
                IconButton(
                  tooltip: 'Unassign device',
                  onPressed: widget.assigning || device.patientId == null
                      ? null
                      : () => widget.onAssign(device.deviceId, null),
                  icon: const Icon(Icons.link_off),
                ),
              ],
            ),
          ] else if (canSelfAssign) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: widget.assigning || device.patientId == currentPatientId
                    ? null
                    : () => widget.onAssign(device.deviceId, currentPatientId),
                icon: const Icon(Icons.link),
                label: Text(
                  device.patientId == currentPatientId ? 'Assigned to me' : 'Assign to me',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _assignedLabel(int? patientId) {
    if (patientId == null) return 'No patient assigned';
    _PatientOption? match;
    for (final patient in _patientOptions()) {
      if (patient.id == patientId) {
        match = patient;
        break;
      }
    }
    if (match != null) return 'Assigned to ${match.label}';
    final currentPatientId = _intValue(widget.profile?['id']);
    if (currentPatientId == patientId) return 'Assigned to you';
    return 'Assigned to patient #$patientId';
  }

  List<_PatientOption> _patientOptions() {
    return widget.patients
        .whereType<Map>()
        .map((patient) => Map<String, dynamic>.from(patient))
        .map((patient) {
          final id = _intValue(patient['id']);
          if (id == null) return null;
          final name = (patient['name'] ??
                  patient['username'] ??
                  patient['email'] ??
                  'Patient #$id')
              .toString();
          return _PatientOption(id: id, label: name);
        })
        .whereType<_PatientOption>()
        .toList(growable: false);
  }
}

class _PatientOption {
  final int id;
  final String label;

  const _PatientOption({required this.id, required this.label});
}

class SessionDetailsPage extends StatefulWidget {
  final String sessionId;

  const SessionDetailsPage({super.key, required this.sessionId});

  @override
  State<SessionDetailsPage> createState() => _SessionDetailsPageState();
}

class _SessionDetailsPageState extends State<SessionDetailsPage> {
  MonitoringSession? _session;
  List<RawReading> _readings = const [];
  List<AnalysisResult> _analysis = const [];
  bool _loading = true;
  bool _refreshing = false;
  bool _analyzing = false;
  bool _deleting = false;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _load(showLoading: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (_refreshing || _deleting) return;
    _refreshing = true;
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<dynamic>([
        ApiService.getSession(widget.sessionId),
        ApiService.getSessionReadings(widget.sessionId, limit: 2000),
        ApiService.getSessionAnalysis(widget.sessionId),
      ]);
      if (!mounted) return;
      setState(() {
        _session = results[0] as MonitoringSession;
        _readings = results[1] as List<RawReading>;
        _analysis = results[2] as List<AnalysisResult>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _runAnalysis() async {
    setState(() {
      _analyzing = true;
      _error = null;
    });
    try {
      final result = await ApiService.analyzeSession(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _analysis = [result, ..._analysis];
        _analyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _analyzing = false;
      });
    }
  }

  Future<void> _deleteSession() async {
    final confirmed = await _confirmDelete(
      context,
      title: 'Delete session?',
      message:
          'This removes ${widget.sessionId}, its readings, AI analysis, and alerts.',
      actionLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ApiService.deleteSession(widget.sessionId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = e.toString();
      });
    }
  }

  List<double> get _ecg =>
      _readings.expand((reading) => reading.ecg).toList(growable: false);

  List<double> get _ppg =>
      _readings.expand((reading) => reading.ppg).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final latestAnalysis = _analysis.isNotEmpty ? _analysis.first : null;
    final captureIssue = _captureIssueForReadings(_readings);
    final hasEcgIssue = _hasEcgIssueForReadings(_readings);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sessionId),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _deleting ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Delete session',
            onPressed: _deleting ? null : _deleteSession,
            icon: _deleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _session == null)
              _StatePanel(
                icon: Icons.error_outline,
                title: 'Could not load session',
                message: _error!,
                actionLabel: 'Retry',
                onAction: _load,
              )
            else ...[
              _SessionHeader(session: _session!, readings: _readings),
              const SizedBox(height: 12),
              _SignalChartCard(
                title: 'ECG Signal',
                subtitle: '${_ecg.length} samples',
                values: _ecg,
                color: const Color(0xFFE53935),
              ),
              const SizedBox(height: 12),
              _SignalChartCard(
                title: 'PPG Signal',
                subtitle: '${_ppg.length} samples',
                values: _ppg,
                color: const Color(0xFF148EBB),
              ),
              const SizedBox(height: 12),
              _AnalysisSection(
                analysis: latestAnalysis,
                isAnalyzing: _analyzing,
                captureIssue: captureIssue,
                hasEcgIssue: hasEcgIssue,
                onAnalyze: _runAnalysis,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _InlineError(message: _error!),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final MonitoringSession session;
  final bool deleting;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.deleting,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          foregroundColor: AppColors.primary,
          child: const Icon(Icons.monitor_heart),
        ),
        title: Text(
          session.sessionId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${session.deviceId}  |  ${session.samplingRate} Hz  |  ${_formatDate(session.startedAt)}',
        ),
        trailing: SizedBox(
          width: 92,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Delete session',
                onPressed: deleting ? null : onDelete,
                icon: deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  final MonitoringSession session;
  final List<RawReading> readings;

  const _SessionHeader({required this.session, required this.readings});

  @override
  Widget build(BuildContext context) {
    final sampleCount = readings.fold<int>(
      0,
      (sum, reading) => sum + reading.sampleCount,
    );
    final latestBattery = readings.isEmpty ? null : readings.last.battery;
    final latestMetadata = readings.isEmpty ? const <String, dynamic>{} : readings.last.metadataJson;
    final latestSpo2 = latestMetadata['spo2_percent'];
    final fingerDetected = _boolValue(latestMetadata['finger_detected']);
    final captureIssue = _captureIssueForReadings(readings);
    final hasEcgIssue = _hasEcgIssueForReadings(readings);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.sessionId,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusChip(label: session.status),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallMetric(label: 'Device', value: session.deviceId),
              _SmallMetric(label: 'Sampling', value: '${session.samplingRate} Hz'),
              _SmallMetric(label: 'Samples', value: '$sampleCount'),
              _SmallMetric(
                label: 'Battery',
                value: latestBattery == null ? '--' : '$latestBattery%',
              ),
              _SmallMetric(
                label: 'SpO2',
                value: latestSpo2 is num ? '${latestSpo2.toStringAsFixed(1)}%' : '--',
              ),
              _SmallMetric(
                label: 'Finger',
                value: fingerDetected == null
                    ? '--'
                    : fingerDetected
                        ? 'Detected'
                        : 'Not detected',
              ),
            ],
          ),
          if (captureIssue != null) ...[
            const SizedBox(height: 12),
            _InlineError(message: captureIssue),
          ],
          if (captureIssue == null && hasEcgIssue) ...[
            const SizedBox(height: 12),
            const _InlineError(
              message:
                  'ECG leads are off. PPG results can still be shown, but ECG and arrhythmia results are not reliable.',
            ),
          ],
        ],
      ),
    );
  }
}

class _AnalysisSection extends StatelessWidget {
  final AnalysisResult? analysis;
  final bool isAnalyzing;
  final String? captureIssue;
  final bool hasEcgIssue;
  final VoidCallback onAnalyze;

  const _AnalysisSection({
    required this.analysis,
    required this.isAnalyzing,
    required this.captureIssue,
    required this.hasEcgIssue,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    final canAnalyze = !isAnalyzing && captureIssue == null;
    if (analysis == null) {
      return _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (captureIssue == null)
              const Text('No analysis result has been stored for this session yet.')
            else
              _InlineError(message: captureIssue!),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: canAnalyze ? onAnalyze : null,
              icon: isAnalyzing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.psychology_alt_outlined),
              label: Text(isAnalyzing ? 'Analyzing...' : 'Run analysis'),
            ),
          ],
        ),
      );
    }

    final metrics = analysis!.metrics;
    final summary = Map<String, dynamic>.from(
      (analysis!.predictions['summary'] as Map?) ?? const {},
    );
    final models = Map<String, dynamic>.from(
      (analysis!.predictions['models'] as Map?) ?? const {},
    );
    final bloodPressure = Map<String, dynamic>.from(
      (models['blood_pressure_vital_meta'] as Map?) ?? const {},
    );
    final ppgRateReason = metrics['ppg_rate_reason']?.toString();
    final bpReason = bloodPressure['reason']?.toString();

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'AI Analysis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AiModelResultsPage(analysis: analysis!),
                    ),
                  );
                },
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Results'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: canAnalyze ? onAnalyze : null,
                icon: const Icon(Icons.refresh),
                label: Text(isAnalyzing ? 'Running' : 'Re-run'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (captureIssue != null) ...[
            _InlineError(message: captureIssue!),
            const SizedBox(height: 12),
            const Text(
              'PPG values are hidden until the finger sensor has valid contact.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ] else ...[
            if (hasEcgIssue) ...[
              const _InlineError(
                message:
                    'ECG leads are off. Showing PPG-related results only.',
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!hasEcgIssue) ...[
                  _SmallMetric(
                    label: 'Heart rate',
                    value: _metric(metrics['heart_rate_bpm'], suffix: ' bpm'),
                  ),
                  _SmallMetric(
                    label: 'HRV RMSSD',
                    value: _metric(metrics['hrv_rmssd_ms'], suffix: ' ms'),
                  ),
                ],
                _SmallMetric(
                  label: 'PPG rate',
                  value: _metric(metrics['ppg_rate_bpm'], suffix: ' bpm'),
                ),
                _SmallMetric(
                  label: 'SpO2',
                  value: _metric(metrics['spo2_percent'], suffix: '%'),
                ),
                _SmallMetric(
                  label: 'Perfusion',
                  value: _metric(metrics['perfusion_index_percent'], suffix: '%'),
                ),
                _SmallMetric(
                  label: 'Systolic',
                  value: _metric(bloodPressure['systolic_mmHg'], suffix: ' mmHg'),
                ),
                _SmallMetric(
                  label: 'Diastolic',
                  value: _metric(bloodPressure['diastolic_mmHg'], suffix: ' mmHg'),
                ),
              ],
            ),
            if (ppgRateReason != null || bpReason != null) ...[
              const SizedBox(height: 12),
              if (ppgRateReason != null)
                _InfoLine(
                  icon: Icons.sensors,
                  text: ppgRateReason,
                ),
              if (bpReason != null)
                _InfoLine(
                  icon: Icons.monitor_heart_outlined,
                  text: bpReason,
                ),
            ],
            const SizedBox(height: 14),
            if (!hasEcgIssue) ...[
              _ConclusionRow(
                label: 'Arrhythmia risk',
                value: (summary['arrhythmia_risk'] ?? 'unknown').toString(),
              ),
              _ConclusionRow(
                label: 'Morphology model',
                value: (summary['morphology_status'] ?? 'unknown').toString(),
              ),
            ],
            _ConclusionRow(
              label: 'Blood pressure model',
              value: (summary['blood_pressure_status'] ?? 'unknown').toString(),
            ),
            const Divider(height: 24),
            _QualityView(quality: analysis!.signalQuality),
            if (!hasEcgIssue) ...[
              const SizedBox(height: 14),
              _AlertsView(alerts: analysis!.alerts),
            ],
          ],
          const SizedBox(height: 14),
          Text(
            analysis!.disclaimer,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class AiModelResultsPage extends StatelessWidget {
  final AnalysisResult analysis;

  const AiModelResultsPage({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final predictions = Map<String, dynamic>.from(analysis.predictions);
    final models = Map<String, dynamic>.from(
      (predictions['models'] as Map?) ?? const {},
    );
    final summary = Map<String, dynamic>.from(
      (predictions['summary'] as Map?) ?? const {},
    );
    final metrics = analysis.metrics;
    final ecg = Map<String, dynamic>.from(
      (models['ecg_arrhythmia_v31'] as Map?) ?? const {},
    );
    final morphology = Map<String, dynamic>.from(
      (models['morphology_heartbeat_v1'] as Map?) ?? const {},
    );
    final bloodPressure = Map<String, dynamic>.from(
      (models['blood_pressure_vital_meta'] as Map?) ?? const {},
    );

    return Scaffold(
      appBar: AppBar(title: const Text('AI Model Results')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology_alt_outlined, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Multi-model analysis',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    _StatusChip(label: analysis.status),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SmallMetric(label: 'Session', value: analysis.sessionId),
                    _SmallMetric(label: 'Pipeline', value: analysis.modelVersion),
                    _SmallMetric(label: 'Created', value: _formatDate(analysis.createdAt)),
                    _SmallMetric(
                      label: 'Arrhythmia risk',
                      value: (summary['arrhythmia_risk'] ?? 'unknown').toString(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  analysis.disclaimer,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Processed Metrics',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SmallMetric(
                      label: 'Heart rate',
                      value: _metric(metrics['heart_rate_bpm'], suffix: ' bpm'),
                    ),
                    _SmallMetric(
                      label: 'PPG rate',
                      value: _metric(metrics['ppg_rate_bpm'], suffix: ' bpm'),
                    ),
                    _SmallMetric(
                      label: 'SpO2',
                      value: _metric(metrics['spo2_percent'], suffix: '%'),
                    ),
                    _SmallMetric(
                      label: 'Perfusion',
                      value: _metric(metrics['perfusion_index_percent'], suffix: '%'),
                    ),
                    _SmallMetric(
                      label: 'ECG samples',
                      value: (metrics['ai_input'] is Map)
                          ? '${(metrics['ai_input'] as Map)['ecg_samples'] ?? '--'}'
                          : '--',
                    ),
                    _SmallMetric(
                      label: 'PPG samples',
                      value: (metrics['ai_input'] is Map)
                          ? '${(metrics['ai_input'] as Map)['ppg_samples'] ?? '--'}'
                          : '--',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ModelResultPanel(
            title: 'ECG Arrhythmia Model',
            subtitle: 'Record-level ECG classifier',
            model: ecg,
            unavailableIcon: Icons.monitor_heart_outlined,
            child: _ClassResultList(model: ecg),
          ),
          const SizedBox(height: 12),
          _ModelResultPanel(
            title: 'Heartbeat Morphology Model',
            subtitle: 'Beat-level ECG morphology classifier',
            model: morphology,
            unavailableIcon: Icons.timeline,
            child: _ClassResultList(model: morphology),
          ),
          const SizedBox(height: 12),
          _BloodPressureResultPanel(model: bloodPressure),
          const SizedBox(height: 12),
          _Panel(child: _QualityView(quality: analysis.signalQuality)),
          if (analysis.alerts.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Panel(child: _AlertsView(alerts: analysis.alerts)),
          ],
        ],
      ),
    );
  }
}

class _ModelResultPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Map<String, dynamic> model;
  final IconData unavailableIcon;
  final Widget child;

  const _ModelResultPanel({
    required this.title,
    required this.subtitle,
    required this.model,
    required this.unavailableIcon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final status = (model['status'] ?? 'unknown').toString();
    final available = model['model_available'] == true;
    final reason = model['reason']?.toString();
    final topClass = Map<String, dynamic>.from(
      (model['top_class'] as Map?) ?? const {},
    );
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(available ? Icons.check_circle_outline : unavailableIcon,
                  color: available ? const Color(0xFF2E7D32) : const Color(0xFFE65100)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(subtitle, style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              _StatusChip(label: status),
            ],
          ),
          const SizedBox(height: 12),
          if (reason != null) ...[
            _InfoLine(icon: Icons.info_outline, text: reason),
            const SizedBox(height: 8),
          ],
          if (topClass.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SmallMetric(label: 'Top class', value: '${topClass['code'] ?? '--'}'),
                _SmallMetric(
                  label: 'Probability',
                  value: _probabilityText(topClass['probability']),
                ),
                _SmallMetric(
                  label: 'Confidence',
                  value: _probabilityText(topClass['confidence']),
                ),
              ],
            ),
            const Divider(height: 24),
          ],
          child,
        ],
      ),
    );
  }
}

class _ClassResultList extends StatelessWidget {
  final Map<String, dynamic> model;

  const _ClassResultList({required this.model});

  @override
  Widget build(BuildContext context) {
    final classes = Map<String, dynamic>.from(
      (model['classes'] as Map?) ?? const {},
    );
    if (classes.isEmpty) {
      return const _InfoLine(
        icon: Icons.hourglass_empty,
        text: 'No class probabilities were returned for this model.',
      );
    }
    final entries = classes.entries.toList()
      ..sort((a, b) {
        final ap = _asDouble((a.value as Map?)?['probability']) ?? 0;
        final bp = _asDouble((b.value as Map?)?['probability']) ?? 0;
        return bp.compareTo(ap);
      });
    return Column(
      children: entries.map((entry) {
        final values = Map<String, dynamic>.from((entry.value as Map?) ?? const {});
        final probability = (_asDouble(values['probability']) ?? 0).clamp(0.0, 1.0);
        final detected = values['detected'] == true;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    detected ? 'detected' : 'not detected',
                    style: TextStyle(
                      color: detected ? const Color(0xFFC62828) : Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: probability,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 4),
              Text(
                'Probability ${_probabilityText(values['probability'])}  |  Confidence ${_probabilityText(values['confidence'])}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _BloodPressureResultPanel extends StatelessWidget {
  final Map<String, dynamic> model;

  const _BloodPressureResultPanel({required this.model});

  @override
  Widget build(BuildContext context) {
    final status = (model['status'] ?? 'unknown').toString();
    final available = model['model_available'] == true;
    final reason = model['reason']?.toString();
    final meta = Map<String, dynamic>.from(
      (model['meta_vector'] as Map?) ?? const {},
    );
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                available ? Icons.check_circle_outline : Icons.bloodtype_outlined,
                color: available ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Blood Pressure Model',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'PPG sequence plus patient weight, height, and BMI',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              _StatusChip(label: status),
            ],
          ),
          const SizedBox(height: 12),
          if (reason != null) ...[
            _InfoLine(icon: Icons.info_outline, text: reason),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallMetric(
                label: 'Systolic',
                value: _metric(model['systolic_mmHg'], suffix: ' mmHg'),
              ),
              _SmallMetric(
                label: 'Diastolic',
                value: _metric(model['diastolic_mmHg'], suffix: ' mmHg'),
              ),
              _SmallMetric(
                label: 'Confidence',
                value: _probabilityText(model['confidence']),
              ),
              _SmallMetric(
                label: 'Weight',
                value: _metric(meta['weight'], suffix: ' kg'),
              ),
              _SmallMetric(
                label: 'Height',
                value: _metric(meta['height'], suffix: ' cm'),
              ),
              _SmallMetric(label: 'BMI', value: _metric(meta['bmi'], suffix: '')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<double> values;
  final Color color;

  const _SignalChartCard({
    required this.title,
    required this.subtitle,
    required this.values,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(subtitle, style: const TextStyle(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: values.isEmpty
                ? const Center(child: Text('No signal samples available'))
                : CustomPaint(
                    painter: _SignalPainter(values: values, color: color),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SignalPainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _SignalPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final plotted = _downsample(values, 700);
    final minValue = plotted.reduce(min);
    final maxValue = plotted.reduce(max);
    final range = max(maxValue - minValue, 0.0001);
    final path = Path();
    for (int i = 0; i < plotted.length; i++) {
      final x = plotted.length == 1 ? 0.0 : size.width * i / (plotted.length - 1);
      final normalized = (plotted[i] - minValue) / range;
      final y = size.height - normalized * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  List<double> _downsample(List<double> input, int maxPoints) {
    if (input.length <= maxPoints) return input;
    final step = (input.length / maxPoints).ceil();
    return [
      for (int i = 0; i < input.length; i += step) input[i],
    ];
  }

  @override
  bool shouldRepaint(covariant _SignalPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

class _QualityView extends StatelessWidget {
  final Map<String, dynamic> quality;

  const _QualityView({required this.quality});

  @override
  Widget build(BuildContext context) {
    final ecg = Map<String, dynamic>.from((quality['ecg'] as Map?) ?? const {});
    final ppg = Map<String, dynamic>.from((quality['ppg'] as Map?) ?? const {});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Signal quality',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _QualityBar(label: 'ECG', quality: ecg)),
            const SizedBox(width: 12),
            Expanded(child: _QualityBar(label: 'PPG', quality: ppg)),
          ],
        ),
      ],
    );
  }
}

class _QualityBar extends StatelessWidget {
  final String label;
  final Map<String, dynamic> quality;

  const _QualityBar({required this.label, required this.quality});

  @override
  Widget build(BuildContext context) {
    final score = ((quality['score'] as num?) ?? 0).toDouble().clamp(0.0, 1.0);
    final text = (quality['label'] ?? 'unknown').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $text'),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: score,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }
}

class _AlertsView extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;

  const _AlertsView({required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const _InfoLine(
        icon: Icons.check_circle_outline,
        text: 'No alerts were generated for this analysis.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Alerts', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...alerts.map(
          (alert) => _InfoLine(
            icon: Icons.warning_amber_rounded,
            text: (alert['message'] ?? alert['code'] ?? 'Alert').toString(),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _SmallMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SmallMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final isActive = label == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ConclusionRow extends StatelessWidget {
  final String label;
  final String value;

  const _ConclusionRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFC62828)),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

Future<bool> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFC62828),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.delete_outline),
          label: Text(actionLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

String _metric(dynamic value, {required String suffix}) {
  if (value == null) return '--';
  if (value is num) return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}$suffix';
  return '$value$suffix';
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String _probabilityText(dynamic value) {
  final numeric = _asDouble(value);
  if (numeric == null) return '--';
  return '${(numeric * 100).toStringAsFixed(1)}%';
}

bool? _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is String) {
    final normalized = value.toLowerCase().trim();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return null;
}

int? _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _captureIssueForReadings(List<RawReading> readings) {
  if (readings.isEmpty) return null;
  final latest = readings.last;
  final fingerDetected = _boolValue(latest.metadataJson['finger_detected']);
  final ppgSensorReady = _boolValue(latest.metadataJson['ppg_sensor_ready']);
  if (latest.status == 'ppg_sensor_off' || ppgSensorReady == false) {
    return 'PPG sensor is offline. Check MAX30105 power, ground, SDA, and SCL wiring.';
  }
  if (latest.status == 'no_finger' || fingerDetected == false) {
    return 'Finger not detected on the PPG sensor. Place your finger over the sensor and keep still.';
  }
  return null;
}

bool _hasEcgIssueForReadings(List<RawReading> readings) {
  return readings.isNotEmpty && readings.last.status == 'leads_off';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
