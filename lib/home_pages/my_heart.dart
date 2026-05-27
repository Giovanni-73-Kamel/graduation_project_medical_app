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
  String? _error;
  List<MonitoringSession> _sessions = const [];

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
      final sessions = await ApiService.getSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
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
            else if (_sessions.isEmpty)
              const _StatePanel(
                icon: Icons.timeline,
                title: 'No sessions yet',
                message: 'Upload ECG/PPG readings from the device to see them here.',
              )
            else
              ..._sessions.map(
                (session) => _SessionTile(
                  session: session,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SessionDetailsPage(
                          sessionId: session.sessionId,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
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
  bool _analyzing = false;
  String? _error;

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
        ApiService.getSession(widget.sessionId),
        ApiService.getSessionReadings(widget.sessionId, limit: 1000),
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

  List<double> get _ecg =>
      _readings.expand((reading) => reading.ecg).toList(growable: false);

  List<double> get _ppg =>
      _readings.expand((reading) => reading.ppg).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final latestAnalysis = _analysis.isNotEmpty ? _analysis.first : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sessionId),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
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
  final VoidCallback onTap;

  const _SessionTile({required this.session, required this.onTap});

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
        trailing: const Icon(Icons.chevron_right),
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
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalysisSection extends StatelessWidget {
  final AnalysisResult? analysis;
  final bool isAnalyzing;
  final VoidCallback onAnalyze;

  const _AnalysisSection({
    required this.analysis,
    required this.isAnalyzing,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
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
            const Text('No analysis result has been stored for this session yet.'),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: isAnalyzing ? null : onAnalyze,
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
    final risk = Map<String, dynamic>.from(
      (analysis!.predictions['arrhythmia_risk'] as Map?) ?? const {},
    );
    final stress = Map<String, dynamic>.from(
      (analysis!.predictions['stress_fatigue_indicator'] as Map?) ?? const {},
    );

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
              ElevatedButton.icon(
                onPressed: isAnalyzing ? null : onAnalyze,
                icon: const Icon(Icons.refresh),
                label: Text(isAnalyzing ? 'Running' : 'Re-run'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallMetric(
                label: 'Heart rate',
                value: _metric(metrics['heart_rate_bpm'], suffix: ' bpm'),
              ),
              _SmallMetric(
                label: 'HRV RMSSD',
                value: _metric(metrics['hrv_rmssd_ms'], suffix: ' ms'),
              ),
              _SmallMetric(
                label: 'PPG rate',
                value: _metric(metrics['ppg_rate_bpm'], suffix: ' bpm'),
              ),
              _SmallMetric(
                label: 'Perfusion',
                value: _metric(metrics['perfusion_index_percent'], suffix: '%'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ConclusionRow(
            label: 'Arrhythmia risk',
            value: (risk['level'] ?? 'unknown').toString(),
          ),
          _ConclusionRow(
            label: 'Stress/fatigue',
            value: (stress['level'] ?? 'unknown').toString(),
          ),
          const Divider(height: 24),
          _QualityView(quality: analysis!.signalQuality),
          const SizedBox(height: 14),
          _AlertsView(alerts: analysis!.alerts),
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

String _metric(dynamic value, {required String suffix}) {
  if (value == null) return '--';
  if (value is num) return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}$suffix';
  return '$value$suffix';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
