import 'package:flutter/material.dart';
import 'package:medical/models/appointment_model.dart';
import 'package:medical/services/api_service.dart';
import 'package:medical/widgets/appointment_card.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<AppointmentModel> _appointments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final appointmentsData = await ApiService.getAppointments();
      final appointments = appointmentsData
          .map((json) => AppointmentModel.fromJson(json))
          .toList();

      if (mounted) {
        setState(() {
          _appointments = appointments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _loadAppointments();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1565C0)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading appointments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _refresh,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Group by date for display
    final today = _appointments.where((a) => a.date == 'Apr 5, 2026').toList();
    final upcoming = _appointments
        .where((a) => a.date != 'Apr 5, 2026')
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Appointments',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A2A3A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_appointments.length} scheduled this week',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 20),

                    // Summary chips
                    Row(
                      children: [
                        _summaryChip(
                          'Today',
                          today.length,
                          const Color(0xFF1565C0),
                        ),
                        const SizedBox(width: 10),
                        _summaryChip(
                          'Upcoming',
                          upcoming.length,
                          const Color(0xFF00695C),
                        ),
                        const SizedBox(width: 10),
                        _summaryChip(
                          'Urgent',
                          _appointments.where((a) => a.type == 'urgent').length,
                          const Color(0xFFE53935),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                  ],
                ),
              ),
            ),

            // Today section
            if (today.isNotEmpty) ...[
              _sliverSectionHeader("Today · Apr 5"),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => AppointmentCard(appointment: today[i]),
                    childCount: today.length,
                  ),
                ),
              ),
            ],

            // Upcoming section
            if (upcoming.isNotEmpty) ...[
              _sliverSectionHeader("Upcoming"),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => AppointmentCard(appointment: upcoming[i]),
                    childCount: upcoming.length,
                  ),
                ),
              ),
            ],

            // Empty state
            if (_appointments.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No appointments scheduled',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your appointments will appear here',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  SliverToBoxAdapter _sliverSectionHeader(String title) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A2A3A),
          letterSpacing: 0.3,
        ),
      ),
    ),
  );
}
