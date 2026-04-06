import 'dart:math';
import 'package:flutter/material.dart';
import 'package:medical/functions/app_colors.dart';
import 'package:medical/functions/custom_text.dart';
import 'package:medical/home_pages/profile.dart';
import 'package:medical/Ai_bot/chatbot_widget.dart';
import 'package:medical/home_pages/scheduled.dart';
import 'package:medical/home_pages/contacts.dart';
import 'package:medical/home_pages/help.dart';
import 'package:medical/services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ROOT SHELL (bottom nav stays here)
// ─────────────────────────────────────────────────────────────────────────────
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const ContactsPage(),
    const ScheduledPage(),
    const HelpPage(),
    const ProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(0),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white.withOpacity(0.6),
            selectedFontSize: 13,
            unselectedFontSize: 13,
            iconSize: 28,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.contacts_outlined),
                  activeIcon: Icon(Icons.contacts),
                  label: 'Contacts'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today_outlined),
                  activeIcon: Icon(Icons.calendar_today),
                  label: 'Scheduled'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.help_outline),
                  activeIcon: Icon(Icons.help),
                  label: 'Help'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HOME PAGE
// ─────────────────────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userName = 'User';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final profile = await ApiService.getUserProfile();
      if (mounted) {
        setState(() {
          userName =
              profile['username'] ?? profile['email'].split('@')[0];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // ── Greeting bar ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 25, vertical: 25),
              margin:
                  const EdgeInsets.only(top: 20, left: 20, right: 20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                    color: Colors.white.withOpacity(0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: CustomText(
                text: 'Hi, $userName !',
                color: Colors.white,
                size: 22,
                weight: FontWeight.bold,
              ),
            ),

            // ── Chatbot ───────────────────────────────────────────────────
            const ChatbotWidget(),

            // ── Section header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Row(
                children: [
                  Icon(Icons.monitor_heart_outlined,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Vital Signs',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A2A3A),
                    ),
                  ),
                ],
              ),
            ),

            // ── Blood Pressure widget (full width) ────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: BloodPressureWidget(),
            ),

            // ── Heart Rate + SpO2 (side by side) ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Row(
                children: const [
                  Expanded(child: HeartRateWidget()),
                  SizedBox(width: 14),
                  Expanded(child: SpO2Widget()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  BLOOD PRESSURE WIDGET  – animated left-right needle gauge
// ═════════════════════════════════════════════════════════════════════════════
class BloodPressureWidget extends StatefulWidget {
  const BloodPressureWidget({super.key});

  @override
  State<BloodPressureWidget> createState() => _BloodPressureWidgetState();
}

class _BloodPressureWidgetState extends State<BloodPressureWidget>
    with TickerProviderStateMixin {
  late final AnimationController _needleCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _needleAnim;
  late final Animation<double> _pulseAnim;

  // Demo values
  final int systolic = 120;
  final int diastolic = 80;

  @override
  void initState() {
    super.initState();

    // Needle swings side-to-side
    _needleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _needleAnim = CurvedAnimation(
      parent: _needleCtrl,
      curve: Curves.easeInOut,
    );

    // Subtle outer glow pulse
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _needleCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_needleAnim, _pulseAnim]),
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0D47A1),
                AppColors.primary,
                const Color(0xFF26C6DA),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.45 * _pulseAnim.value),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bloodtype,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Blood Pressure',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Normal',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Gauge
              Center(
                child: CustomPaint(
                  size: const Size(double.infinity, 110),
                  painter: _BPGaugePainter(_needleAnim.value),
                ),
              ),

              const SizedBox(height: 16),

              // Readings
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _bpValue('$systolic', 'SYS', 'mmHg'),
                  Container(
                    height: 40,
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    color: Colors.white.withOpacity(0.35),
                  ),
                  _bpValue('$diastolic', 'DIA', 'mmHg'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bpValue(String val, String label, String unit) {
    return Column(
      children: [
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$label · $unit',
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Custom painter for the blood-pressure arc gauge with moving needle
class _BPGaugePainter extends CustomPainter {
  final double progress; // 0 → 1

  _BPGaugePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height - 12;
    final radius = size.width * 0.42;

    const startAngle = pi; // 180°
    const sweepAngle = pi; // 180° arc

    // ── Track arc (background) ───────────────────────────────────────────
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.18);

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // ── Colour zones (low → normal → high) ───────────────────────────────
    final zones = [
      (Colors.lightBlue[200]!, 0.0, pi / 3),       // low – blue
      (Colors.green[400]!, pi / 3, pi / 3),         // normal – green
      (Colors.orange[400]!, 2 * pi / 3, pi / 6),   // elevated – orange
      (Colors.red[400]!, 5 * pi / 6, pi / 6),       // high – red
    ];

    for (final z in zones) {
      final zPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.butt
        ..color = z.$1.withOpacity(0.6);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle + z.$2,
        z.$3,
        false,
        zPaint,
      );
    }

    // ── Tick marks ───────────────────────────────────────────────────────
    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1.5;

    for (int i = 0; i <= 8; i++) {
      final angle = startAngle + (i / 8) * sweepAngle;
      final inner = radius - 10;
      final outer = radius + 10;
      canvas.drawLine(
        Offset(cx + inner * cos(angle), cy + inner * sin(angle)),
        Offset(cx + outer * cos(angle), cy + outer * sin(angle)),
        tickPaint,
      );
    }

    // ── Animated needle ──────────────────────────────────────────────────
    // maps from ~0.3 (normal low) to ~0.55 (normal high) swinging
    final normalizedPos = 0.30 + progress * 0.25;
    final needleAngle = startAngle + normalizedPos * sweepAngle;

    final needlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(cx, cy),
      Offset(
        cx + (radius - 8) * cos(needleAngle),
        cy + (radius - 8) * sin(needleAngle),
      ),
      needlePaint,
    );

    // pivot dot
    canvas.drawCircle(
      Offset(cx, cy),
      7,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      4,
      Paint()..color = AppColors.primary,
    );

    // Label min / max
    final labelStyle = TextStyle(
      color: Colors.white.withOpacity(0.8),
      fontSize: 11,
    );

    _drawText(canvas, '60', Offset(cx - radius - 4, cy + 6), labelStyle);
    _drawText(canvas, '180', Offset(cx + radius - 12, cy + 6), labelStyle);
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_BPGaugePainter old) => old.progress != progress;
}

// ═════════════════════════════════════════════════════════════════════════════
//  HEART RATE WIDGET  – animated ECG / waveform line
// ═════════════════════════════════════════════════════════════════════════════
class HeartRateWidget extends StatefulWidget {
  const HeartRateWidget({super.key});

  @override
  State<HeartRateWidget> createState() => _HeartRateWidgetState();
}

class _HeartRateWidgetState extends State<HeartRateWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.linear);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6A0572), Color(0xFFE91E63)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE91E63).withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + label
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.favorite,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Heart Rate',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ECG wave
              SizedBox(
                height: 60,
                child: CustomPaint(
                  painter: _EcgPainter(_anim.value),
                  size: const Size(double.infinity, 60),
                ),
              ),

              const SizedBox(height: 10),

              // Value
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: '72',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    TextSpan(
                      text: ' bpm',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Normal range',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ECG waveform painter – the offset shifts on each frame to simulate movement
class _EcgPainter extends CustomPainter {
  final double progress; // 0..1

  _EcgPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final h = size.height;
    final w = size.width;
    final mid = h / 2;

    // One full ECG cycle normalised to width 1.0
    // Points: (x, y) fractions of size
    List<Offset> ecgPattern(double offsetX) {
      return [
        Offset(offsetX + 0.00 * w, mid),
        Offset(offsetX + 0.08 * w, mid),
        Offset(offsetX + 0.10 * w, mid - h * 0.12),
        Offset(offsetX + 0.12 * w, mid),
        Offset(offsetX + 0.15 * w, mid + h * 0.08),
        Offset(offsetX + 0.20 * w, mid - h * 0.80), // R-peak (tall spike)
        Offset(offsetX + 0.25 * w, mid + h * 0.30), // S-trough
        Offset(offsetX + 0.30 * w, mid),
        Offset(offsetX + 0.45 * w, mid + h * 0.05),
        Offset(offsetX + 0.55 * w, mid - h * 0.10),
        Offset(offsetX + 0.65 * w, mid),
        Offset(offsetX + 1.00 * w, mid),
      ];
    }

    // Two cycles offset by progress for seamless scrolling
    for (int cycle = -1; cycle <= 1; cycle++) {
      final ox = (-progress + cycle) * w;
      final pts = ecgPattern(ox);
      for (int i = 0; i < pts.length - 1; i++) {
        canvas.drawLine(pts[i], pts[i + 1], glowPaint);
        canvas.drawLine(pts[i], pts[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(_EcgPainter old) => old.progress != progress;
}

// ═════════════════════════════════════════════════════════════════════════════
//  SpO2 WIDGET  – animated circular arc progress
// ═════════════════════════════════════════════════════════════════════════════
class SpO2Widget extends StatefulWidget {
  const SpO2Widget({super.key});

  @override
  State<SpO2Widget> createState() => _SpO2WidgetState();
}

class _SpO2WidgetState extends State<SpO2Widget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _arc;
  late final Animation<double> _glow;

  // Demo value
  final double spo2 = 0.98; // 98 %

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _arc = Tween<double>(begin: spo2 - 0.01, end: spo2 + 0.005)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _glow = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF004D7A), Color(0xFF00B4D8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00B4D8).withOpacity(0.35 * _glow.value),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + label
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.air, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'SpO₂',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Circular arc
              Center(
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: CustomPaint(
                    painter: _CircleArcPainter(_arc.value, _glow.value),
                    child: Center(
                      child: Text(
                        '${(_arc.value * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Oxygen Level',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),

              const SizedBox(height: 2),

              const Text(
                'Excellent',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CircleArcPainter extends CustomPainter {
  final double value; // 0..1
  final double glow;

  _CircleArcPainter(this.value, this.glow);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );

    // Glow arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * value,
      false,
      Paint()
        ..color = Colors.white.withOpacity(0.30 * glow)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Main arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * value,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CircleArcPainter old) =>
      old.value != value || old.glow != glow;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Unused legacy pages kept to avoid tree-shake warnings
// ─────────────────────────────────────────────────────────────────────────────
class _UnusedHelpPage extends StatelessWidget {
  const _UnusedHelpPage();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CustomText(
                text: 'Help',
                color: Colors.black87,
                size: 28,
                weight: FontWeight.bold),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                  child: Icon(Icons.help, size: 100, color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnusedProfilePage extends StatelessWidget {
  const _UnusedProfilePage();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CustomText(
                text: 'Profile',
                color: Colors.black87,
                size: 28,
                weight: FontWeight.bold),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                  child:
                      Icon(Icons.person, size: 100, color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}