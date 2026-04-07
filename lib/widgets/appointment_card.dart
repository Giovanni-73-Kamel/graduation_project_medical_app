import 'package:flutter/material.dart';
import 'package:medical/models/appointment_model.dart';

class AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;

  const AppointmentCard({super.key, required this.appointment});

  Color _typeColor(String type) {
    switch (type) {
      case 'urgent':
        return const Color(0xFFE53935);
      case 'follow-up':
        return const Color(0xFF1E88E5);
      default:
        return const Color(0xFF43A047);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'urgent':
        return Icons.priority_high_rounded;
      case 'follow-up':
        return Icons.repeat_rounded;
      default:
        return Icons.calendar_today_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(appointment.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left colour accent + icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_typeIcon(appointment.type), color: color, size: 24),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          appointment.patientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFF1A2A3A),
                          ),
                        ),
                      ),
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          appointment.type.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Date & time
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        '${appointment.date}  ·  ${appointment.time}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Note
                  Text(
                    appointment.note,
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}