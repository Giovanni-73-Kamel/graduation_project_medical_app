import 'package:flutter/material.dart';
import 'package:medical/models/appointment_model.dart';
import 'package:medical/widgets/appointment_card.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Group by date for display
    final today = dummyAppointments.where((a) => a.date == 'Apr 5, 2026').toList();
    final upcoming = dummyAppointments.where((a) => a.date != 'Apr 5, 2026').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
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
                      '${dummyAppointments.length} scheduled this week',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 20),

                    // Summary chips
                    Row(
                      children: [
                        _summaryChip('Today', today.length, const Color(0xFF1565C0)),
                        const SizedBox(width: 10),
                        _summaryChip('Upcoming', upcoming.length, const Color(0xFF00695C)),
                        const SizedBox(width: 10),
                        _summaryChip(
                          'Urgent',
                          dummyAppointments.where((a) => a.type == 'urgent').length,
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
                  color: color, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600),
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