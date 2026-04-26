import 'dart:async';
import 'package:flutter/material.dart';
import 'package:medical/functions/app_colors.dart';
import 'package:medical/models/ecg_classification_model.dart';
import 'package:medical/services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MY HEART PAGE  →  Heart Condition Info
// ─────────────────────────────────────────────────────────────────────────────
class MyHeartPage extends StatefulWidget {
  const MyHeartPage({super.key});

  @override
  State<MyHeartPage> createState() => _MyHeartPageState();
}

class _MyHeartPageState extends State<MyHeartPage> {
  // Loaded from ApiService → GET /ecg/current-condition
  EcgClassification? _currentCondition;

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final Map<String, dynamic> data =
          await ApiService.getCurrentHeartCondition();

      if (!mounted) return;
      setState(() {
        _currentCondition = EcgClassification.fromJson(data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'Could not load data',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadData();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page header ──────────────────────────────────────────────
              _PageHeader(),
              const SizedBox(height: 16),

              // ── Heart Tips Widget ─────────────────────────────────────────
              const _HeartTipsWidget(),
              const SizedBox(height: 24),

              // ── Current Condition Widget ──────────────────────────────────
              if (_currentCondition != null)
                _CurrentConditionCard(condition: _currentCondition!),
              const SizedBox(height: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Utility – parse "#RRGGBB" hex string → Color (with safe fallback)
// ─────────────────────────────────────────────────────────────────────────────
Color _hexColor(String? hex, Color fallback) {
  if (hex == null || hex.length < 7) return fallback;
  try {
    return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
  } catch (_) {
    return fallback;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Utility – resolve icon_name string → IconData
// ─────────────────────────────────────────────────────────────────────────────
IconData _resolveIcon(String? name) {
  switch (name) {
    case 'check_circle_outline':
      return Icons.check_circle_outline;
    case 'warning_amber_rounded':
      return Icons.warning_amber_rounded;
    case 'show_chart':
      return Icons.show_chart;
    case 'electric_bolt_outlined':
      return Icons.electric_bolt_outlined;
    case 'favorite_border':
      return Icons.favorite_border;
    default:
      return Icons.help_outline;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Fallback colors used when backend doesn't supply color_hex
// ─────────────────────────────────────────────────────────────────────────────
const List<Color> _defaultClassColors = [
  Color(0xFF00C853),
  Color(0xFFE53935),
  Color(0xFFFF6F00),
  Color(0xFF7B1FA2),
  Color(0xFF0288D1),
];

// ─────────────────────────────────────────────────────────────────────────────
//  PAGE HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _PageHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, const Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.monitor_heart, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Heart Condition Guide',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'ECG Classification Reference',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGET – CURRENT CONDITION CARD
// ─────────────────────────────────────────────────────────────────────────────
class _CurrentConditionCard extends StatelessWidget {
  final EcgClassification condition;

  const _CurrentConditionCard({required this.condition});

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(condition.colorHex, const Color(0xFF00C853));
    final icon = _resolveIcon(condition.iconName);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 48),
                ),
                const SizedBox(height: 16),
                Text(
                  'CURRENT STATUS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[600],
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  condition.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Code: ${condition.code}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Description section
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[400], size: 28),
                const SizedBox(height: 12),
                Text(
                  condition.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Heart Tips Widget (Animated & Auto-scrolling)
// ─────────────────────────────────────────────────────────────────────────────
class _HeartTipsWidget extends StatefulWidget {
  const _HeartTipsWidget({Key? key}) : super(key: key);

  @override
  State<_HeartTipsWidget> createState() => _HeartTipsWidgetState();
}

class _HeartTipsWidgetState extends State<_HeartTipsWidget> {
  final List<String> _tips = [
    "Stay Active: Aim for at least 30 minutes of moderate exercise every day.",
    "Eat Heart-Healthy: Focus on fruits, vegetables, whole grains, and lean proteins.",
    "Manage Stress: Practice relaxation techniques like meditation or deep breathing.",
    "Get Enough Sleep: Ensure 7-9 hours of quality sleep each night.",
    "Control BP: Monitor your blood pressure and keep it in a healthy range.",
    "Limit Salt: Reduce sodium intake to help prevent high blood pressure.",
    "Stay Hydrated: Drink plenty of water throughout the day for better circulation.",
    "Quit Smoking: Avoid tobacco to significantly lower your risk of heart disease.",
    "Limit Alcohol: Drink in moderation to protect your heart and blood vessels.",
    "Regular Check-ups: Visit your doctor annually to monitor your heart health."
  ];

  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _nextTip();
    });
  }

  void _nextTip() {
    if (!mounted) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _tips.length;
    });
  }

  void _prevTip() {
    if (!mounted) return;
    setState(() {
      _currentIndex = (_currentIndex - 1 + _tips.length) % _tips.length;
    });
    _startTimer(); // reset timer on manual interaction
  }

  void _handleNextManual() {
    _nextTip();
    _startTimer(); // reset timer on manual interaction
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF0F0),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite, color: Color(0xFFE53935), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Heart Health Tip',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: Text(
                    _tips[_currentIndex],
                    key: ValueKey<int>(_currentIndex),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4A4A4A),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _prevTip,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.chevron_left, size: 22, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _handleNextManual,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.chevron_right, size: 22, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
