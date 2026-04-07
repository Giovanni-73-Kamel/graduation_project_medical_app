import 'package:flutter/material.dart';
import 'package:medical/models/patient_model.dart';
import 'package:medical/widgets/vital_card.dart';

class PatientDetailsScreen extends StatelessWidget {
  final PatientModel patient;

  const PatientDetailsScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF1565C0);

    final List<Color> avatarColors = [
      const Color(0xFF1565C0),
      const Color(0xFF00695C),
      const Color(0xFF6A1B9A),
      const Color(0xFFAD1457),
      const Color(0xFF558B2F),
      const Color(0xFF4527A0),
    ];
    final avatarColor = avatarColors[patient.id % avatarColors.length];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // ── Big hero header ───────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: accentColor,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor, const Color(0xFF26C6DA)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: avatarColor,
                        child: Text(
                          patient.avatarInitials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      patient.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Age ${patient.age}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body content ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact info card
                  _sectionTitle('Contact Information'),
                  const SizedBox(height: 10),
                  _infoCard([
                    _infoRow(Icons.email_outlined, 'Email', patient.email),
                    const Divider(height: 1),
                    _infoRow(Icons.phone_outlined, 'Phone', patient.phone),
                  ]),
                  const SizedBox(height: 24),

                  // Vital signs
                  _sectionTitle('Vital Signs'),
                  const SizedBox(height: 10),
                  VitalCard(
                    icon: Icons.favorite_rounded,
                    label: 'Heart Rate',
                    value: '${patient.heartRate}',
                    unit: 'bpm',
                    color: const Color(0xFFE53935),
                  ),
                  const SizedBox(height: 12),
                  VitalCard(
                    icon: Icons.monitor_heart_outlined,
                    label: 'Blood Pressure',
                    value: patient.bloodPressure,
                    unit: 'mmHg',
                    color: accentColor,
                  ),
                  const SizedBox(height: 12),
                  VitalCard(
                    icon: Icons.thermostat_rounded,
                    label: 'Body Temperature',
                    value: '${patient.temperature}',
                    unit: '°C',
                    color: const Color(0xFFFF8F00),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A2A3A),
          letterSpacing: 0.3,
        ),
      );

  Widget _infoCard(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(children: children),
      );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF1565C0)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2A3A))),
              ],
            ),
          ],
        ),
      );
}