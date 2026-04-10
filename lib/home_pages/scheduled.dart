import 'package:flutter/material.dart';
import 'package:medical/functions/app_colors.dart';
import 'package:medical/functions/custom_text.dart';
import 'package:medical/functions/txtfield.dart';
import 'package:medical/services/api_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:math';

/// Global notification plugin instance
final fln.FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    fln.FlutterLocalNotificationsPlugin();

/// Main Scheduled Page - Displays and manages medicine and appointment reminders
class ScheduledPage extends StatefulWidget {
  const ScheduledPage({super.key});

  @override
  State<ScheduledPage> createState() => _ScheduledPageState();
}

class _ScheduledPageState extends State<ScheduledPage> {
  List<ScheduleItem> scheduleItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _initializeNotifications();
      await _loadScheduleItems();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  // Notification initialization
  // ─────────────────────────────────────────────

  Future<void> _initializeNotifications() async {
    const fln.AndroidInitializationSettings initializationSettingsAndroid =
        fln.AndroidInitializationSettings('@mipmap/ic_launcher');

    final fln.DarwinInitializationSettings initializationSettingsIOS =
        fln.DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    final fln.InitializationSettings initializationSettings =
        fln.InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    await _createNotificationChannel();

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));

    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          fln.AndroidFlutterLocalNotificationsPlugin
        >();

    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          fln.IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _createNotificationChannel() async {
    const fln.AndroidNotificationChannel channel =
        fln.AndroidNotificationChannel(
          'medical_reminders',
          'Medical Reminders',
          description:
              'Notifications for medicine reminders and doctor appointments',
          importance: fln.Importance.max,
          enableVibration: true,
          playSound: true,
        );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          fln.AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  // ─────────────────────────────────────────────
  // Load reminders from backend
  // ─────────────────────────────────────────────

  Future<void> _loadScheduleItems() async {
    setState(() => _isLoading = true);
    try {
      final List<dynamic> backendItems = await ApiService.getReminders();
      print('Backend items received: $backendItems'); // Debug log
      final now = DateTime.now();

      final allItems = backendItems.map((item) {
        print('Parsing item: $item'); // Debug log
        return ScheduleItem.fromJson(item);
      }).toList();

      print('Parsed ${allItems.length} items'); // Debug log

      // Auto-remove 'once' items that have already passed
      final List<ScheduleItem> validItems = [];
      for (final item in allItems) {
        if (item.frequency.toLowerCase() == 'once') {
          final scheduledDateTime = DateTime(
            item.date.year,
            item.date.month,
            item.date.day,
            item.time.hour,
            item.time.minute,
          );
          // Only delete if it's more than 5 minutes in the past (to avoid deleting newly created items)
          final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
          if (scheduledDateTime.isBefore(fiveMinutesAgo)) {
            await ApiService.deleteReminder(item.id);
            await flutterLocalNotificationsPlugin.cancel(item.id);
            continue;
          }
        }
        validItems.add(item);
      }

      setState(() {
        scheduleItems = validItems;
        _isLoading = false;
      });

      for (final item in scheduleItems) {
        await _scheduleNotification(item);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load reminders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  // Open add / edit bottom sheet
  // ─────────────────────────────────────────────

  void _openScheduleSheet({ScheduleItem? existingItem}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddScheduleSheet(
        existingItem: existingItem,
        onAdd: (item) async {
          try {
            if (existingItem != null) {
              // Update existing reminder
              await ApiService.updateReminder(existingItem.id, item.toJson());
              await flutterLocalNotificationsPlugin.cancel(existingItem.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reminder updated successfully'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } else {
              // Create new reminder
              await ApiService.createReminder(item.toJson());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reminder added successfully'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            }
            // Refresh list from backend to get correct IDs
            await _loadScheduleItems();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to save reminder: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Delete reminder
  // ─────────────────────────────────────────────

  Future<void> _deleteItem(int index) async {
    final item = scheduleItems[index];

    try {
      await ApiService.deleteReminder(item.id);
      await flutterLocalNotificationsPlugin.cancel(item.id);

      setState(() => scheduleItems.removeAt(index));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.title} deleted'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete reminder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  // Schedule local notification
  // ─────────────────────────────────────────────

  Future<void> _scheduleNotification(ScheduleItem item) async {
    try {
      DateTime scheduledDateTime = DateTime(
        item.date.year,
        item.date.month,
        item.date.day,
        item.time.hour,
        item.time.minute,
      );

      String notificationTitle;
      String notificationBody;
      DateTime notificationTime;

      if (item.type == 'medicine') {
        notificationTime = scheduledDateTime;
        notificationTitle = 'Medicine Reminder';
        notificationBody = 'Time to take your medicine: ${item.title}';
      } else {
        notificationTime = scheduledDateTime.subtract(const Duration(hours: 1));
        notificationTitle = 'Appointment Reminder';
        notificationBody =
            'Your appointment "${item.title}" is in 1 hour at ${item.time.format(context)}';
      }

      final now = DateTime.now();
      if (notificationTime.isBefore(now)) {
        if (item.frequency.toLowerCase() == 'daily') {
          notificationTime = notificationTime.add(const Duration(days: 1));
        } else if (item.frequency.toLowerCase() == 'weekly') {
          notificationTime = notificationTime.add(const Duration(days: 7));
        } else if (item.frequency.toLowerCase() == 'monthly') {
          int newMonth = notificationTime.month + 1;
          int newYear = notificationTime.year;
          if (newMonth > 12) {
            newMonth = 1;
            newYear++;
          }
          int lastDay = DateTime(newYear, newMonth + 1, 0).day;
          int newDay = min(notificationTime.day, lastDay);
          notificationTime = DateTime(
            newYear,
            newMonth,
            newDay,
            notificationTime.hour,
            notificationTime.minute,
          );
        } else {
          // 'once' in the past — skip
          return;
        }
      }

      final tz.TZDateTime tzNotificationTime = tz.TZDateTime.from(
        notificationTime,
        tz.local,
      );

      const fln.NotificationDetails
      notificationDetails = fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          'medical_reminders',
          'Medical Reminders',
          channelDescription:
              'Notifications for medicine reminders and doctor appointments',
          importance: fln.Importance.max,
          priority: fln.Priority.high,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: fln.DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      switch (item.frequency.toLowerCase()) {
        case 'once':
          await flutterLocalNotificationsPlugin.zonedSchedule(
            item.id,
            notificationTitle,
            notificationBody,
            tzNotificationTime,
            notificationDetails,
            androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
          );
          break;
        case 'daily':
          await flutterLocalNotificationsPlugin.zonedSchedule(
            item.id,
            notificationTitle,
            notificationBody,
            tzNotificationTime,
            notificationDetails,
            androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: fln.DateTimeComponents.time,
          );
          break;
        case 'weekly':
          await flutterLocalNotificationsPlugin.zonedSchedule(
            item.id,
            notificationTitle,
            notificationBody,
            tzNotificationTime,
            notificationDetails,
            androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: fln.DateTimeComponents.dayOfWeekAndTime,
          );
          break;
        case 'monthly':
          await flutterLocalNotificationsPlugin.zonedSchedule(
            item.id,
            notificationTitle,
            notificationBody,
            tzNotificationTime,
            notificationDetails,
            androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: fln.DateTimeComponents.dayOfMonthAndTime,
          );
          break;
      }
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scheduling notification: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SafeArea(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final medicineItems = scheduleItems
        .where((item) => item.type.toLowerCase() == 'medicine')
        .toList();
    final appointmentItems = scheduleItems
        .where((item) => item.type.toLowerCase() == 'appointment')
        .toList();

    print('Total items: ${scheduleItems.length}');
    print('Medicine items: ${medicineItems.length}');
    print('Appointment items: ${appointmentItems.length}');
    for (var item in scheduleItems) {
      print(
        'Item: ${item.title} - Type: ${item.type} - Frequency: ${item.frequency}',
      );
    }

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const CustomText(
                  text: 'Medical Reminders',
                  color: Colors.black87,
                  size: 28,
                  weight: FontWeight.bold,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: CustomText(
                    text: '${scheduleItems.length} total',
                    color: AppColors.primary,
                    size: 14,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: scheduleItems.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadScheduleItems,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Medicine section
                          if (medicineItems.isNotEmpty) ...[
                            _buildSectionHeader(
                              'Medicine Reminders',
                              Icons.medication,
                              Colors.blue,
                              medicineItems.length,
                            ),
                            const SizedBox(height: 12),
                            ...medicineItems.map((item) {
                              final index = scheduleItems.indexOf(item);
                              return ScheduleCard(
                                item: item,
                                onDelete: () => _deleteItem(index),
                                onEdit: () =>
                                    _openScheduleSheet(existingItem: item),
                              );
                            }),
                            const SizedBox(height: 24),
                          ],

                          // Appointments section
                          if (appointmentItems.isNotEmpty) ...[
                            _buildSectionHeader(
                              'Doctor Appointments',
                              Icons.medical_services,
                              Colors.green,
                              appointmentItems.length,
                            ),
                            const SizedBox(height: 12),
                            ...appointmentItems.map((item) {
                              final index = scheduleItems.indexOf(item);
                              return ScheduleCard(
                                item: item,
                                onDelete: () => _deleteItem(index),
                                onEdit: () =>
                                    _openScheduleSheet(existingItem: item),
                              );
                            }),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
          ),

          // Add button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => _openScheduleSheet(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 5,
                  shadowColor: AppColors.primary.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 24),
                    SizedBox(width: 8),
                    CustomText(
                      text: 'Add Reminder',
                      color: Colors.white,
                      size: 16,
                      weight: FontWeight.w600,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color color,
    int count,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        CustomText(
          text: title,
          color: Colors.black87,
          size: 18,
          weight: FontWeight.bold,
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: CustomText(
            text: count.toString(),
            color: color,
            size: 12,
            weight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          CustomText(
            text: 'No reminders scheduled',
            color: Colors.grey[500]!,
            size: 16,
            weight: FontWeight.normal,
          ),
          const SizedBox(height: 8),
          CustomText(
            text: 'Tap the + button to add your first reminder',
            color: Colors.grey[400]!,
            size: 14,
            weight: FontWeight.normal,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ScheduleItem model
// Fields match backend Reminder / ReminderOut schemas exactly
// ─────────────────────────────────────────────

class ScheduleItem {
  final int id;
  final String title;
  final String type;
  final DateTime date;
  final TimeOfDay time;
  final String frequency;
  final String notes;

  ScheduleItem({
    int? id,
    required this.title,
    required this.type,
    required this.date,
    required this.time,
    required this.frequency,
    String? notes,
  }) : id = id ?? Random().nextInt(2147483647),
       notes = notes ?? '';

  /// Matches backend Reminder schema fields exactly
  Map<String, dynamic> toJson() => {
    'title': title,
    'type': type,
    'date': date.toIso8601String(),
    'time_hour': time.hour,
    'time_minute': time.minute,
    'frequency': frequency,
    'notes': notes,
  };

  /// Matches backend ReminderOut schema fields exactly
  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    print('JSON received: $json'); // Debug log
    print(
      'Reminder ID: ${json['id']}, Title: ${json['title']}, Type: ${json['type']}, Frequency: ${json['frequency']}',
    );

    try {
      // Handle date parsing - backend might send different formats
      DateTime parsedDate;
      final dateStr = json['date'] as String?;
      if (dateStr == null) {
        print('Date is null, using current date');
        parsedDate = DateTime.now();
      } else {
        print('Parsing date: $dateStr');
        // Try different date formats
        try {
          parsedDate = DateTime.parse(dateStr);
        } catch (e) {
          print('Failed to parse as ISO date, trying other formats: $e');
          // Try format like "2026-04-22"
          try {
            final parts = dateStr.split('-');
            parsedDate = DateTime(
              int.parse(parts[0]), // year
              int.parse(parts[1]), // month
              int.parse(parts[2]), // day
            );
          } catch (e2) {
            print('Failed to parse date format, using current date: $e2');
            parsedDate = DateTime.now();
          }
        }
      }

      return ScheduleItem(
        id: json['id'],
        title: json['title'] ?? '',
        type: json['type']?.toLowerCase() ?? 'medicine',
        date: parsedDate,
        time: TimeOfDay(
          hour: json['time_hour'] ?? 0,
          minute: json['time_minute'] ?? 0,
        ),
        frequency: json['frequency']?.toLowerCase() ?? 'once',
        notes: json['notes'] ?? '',
      );
    } catch (e) {
      print('Error parsing ScheduleItem: $e');
      // Return a default item if parsing fails
      return ScheduleItem(
        title: json['title'] ?? 'Unknown',
        type: json['type']?.toLowerCase() ?? 'medicine',
        date: DateTime.now(),
        time: TimeOfDay(hour: 0, minute: 0),
        frequency: json['frequency']?.toLowerCase() ?? 'once',
        notes: json['notes'] ?? '',
      );
    }
  }
}

// ─────────────────────────────────────────────
// ScheduleCard widget
// ─────────────────────────────────────────────

class ScheduleCard extends StatelessWidget {
  final ScheduleItem item;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  const ScheduleCard({
    super.key,
    required this.item,
    required this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isMedicine = item.type.toLowerCase() == 'medicine';
    final icon = isMedicine ? Icons.medication : Icons.medical_services;
    final color = isMedicine ? Colors.blue : Colors.green;

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      text: item.title,
                      color: Colors.black87,
                      size: 16,
                      weight: FontWeight.w600,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        CustomText(
                          text:
                              '${item.time.format(context)} • ${_formatDate(item.date)}',
                          color: Colors.grey[600]!,
                          size: 13,
                          weight: FontWeight.normal,
                        ),
                      ],
                    ),
                    if (item.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      CustomText(
                        text: item.notes,
                        color: Colors.grey[500]!,
                        size: 12,
                        weight: FontWeight.normal,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Frequency badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getFrequencyIcon(item.frequency),
                                size: 12,
                                color: color,
                              ),
                              const SizedBox(width: 4),
                              CustomText(
                                text: item.frequency.toUpperCase(),
                                color: color,
                                size: 11,
                                weight: FontWeight.w600,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Notification timing badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.notifications_active,
                                size: 12,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              CustomText(
                                text: isMedicine ? 'On time' : '1h before',
                                color: Colors.orange,
                                size: 11,
                                weight: FontWeight.w500,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                tooltip: 'Delete reminder',
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFrequencyIcon(String frequency) {
    switch (frequency) {
      case 'once':
        return Icons.lens;
      case 'daily':
        return Icons.today;
      case 'weekly':
        return Icons.calendar_view_week;
      case 'monthly':
        return Icons.calendar_month;
      default:
        return Icons.schedule;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final scheduleDate = DateTime(date.year, date.month, date.day);

    if (scheduleDate == today) return 'Today';
    if (scheduleDate == tomorrow) return 'Tomorrow';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ─────────────────────────────────────────────
// AddScheduleSheet — handles both add and edit
// ─────────────────────────────────────────────

class AddScheduleSheet extends StatefulWidget {
  final Function(ScheduleItem) onAdd;
  final ScheduleItem? existingItem;

  const AddScheduleSheet({super.key, required this.onAdd, this.existingItem});

  @override
  State<AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends State<AddScheduleSheet> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedType = 'medicine';
  String _selectedFrequency = 'once';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    // Pre-fill fields when editing
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _titleController.text = item.title;
      _notesController.text = item.notes;
      _selectedType = item.type;
      _selectedFrequency = item.frequency;
      _selectedDate = item.date;
      _selectedTime = item.time;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _saveSchedule() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final item = ScheduleItem(
      id: widget.existingItem?.id,
      title: _titleController.text.trim(),
      type: _selectedType,
      date: _selectedDate,
      time: _selectedTime,
      frequency: _selectedFrequency,
      notes: _notesController.text.trim(),
    );

    await widget.onAdd(item);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomText(
                    text: _isEditing ? 'Edit Reminder' : 'Add Reminder',
                    color: Colors.black87,
                    size: 22,
                    weight: FontWeight.bold,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Type selection
              const CustomText(
                text: 'Type',
                color: Colors.black87,
                size: 14,
                weight: FontWeight.w600,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeButton(
                      'Medicine',
                      'medicine',
                      Icons.medication,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTypeButton(
                      'Appointment',
                      'appointment',
                      Icons.medical_services,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Title
              CustomText(
                text: _selectedType == 'medicine'
                    ? 'Medicine Name'
                    : 'Appointment Title',
                color: Colors.black87,
                size: 14,
                weight: FontWeight.w600,
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CustomTxtfield(
                  controller: _titleController,
                  hint: _selectedType == 'medicine'
                      ? 'Medicine Name'
                      : 'Appointment Title',
                  isPassword: false,
                ),
              ),
              const SizedBox(height: 20),

              // Date and Time
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CustomText(
                          text: 'Date',
                          color: Colors.black87,
                          size: 14,
                          weight: FontWeight.w600,
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _selectDate,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                CustomText(
                                  text:
                                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                  color: Colors.black87,
                                  size: 14,
                                  weight: FontWeight.normal,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CustomText(
                          text: 'Time',
                          color: Colors.black87,
                          size: 14,
                          weight: FontWeight.w600,
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _selectTime,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                CustomText(
                                  text: _selectedTime.format(context),
                                  color: Colors.black87,
                                  size: 14,
                                  weight: FontWeight.normal,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Frequency selection
              const CustomText(
                text: 'Frequency',
                color: Colors.black87,
                size: 14,
                weight: FontWeight.w600,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildFrequencyButton('Once', 'once', Icons.lens),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFrequencyButton('Daily', 'daily', Icons.today),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildFrequencyButton(
                      'Weekly',
                      'weekly',
                      Icons.calendar_view_week,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFrequencyButton(
                      'Monthly',
                      'monthly',
                      Icons.calendar_month,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Notes
              const CustomText(
                text: 'Notes (Optional)',
                color: Colors.black87,
                size: 14,
                weight: FontWeight.w600,
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CustomTxtfield(
                  controller: _notesController,
                  hint: 'Notes',
                  isPassword: false,
                ),
              ),
              const SizedBox(height: 20),

              // Notification info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomText(
                        text: _selectedType == 'medicine'
                            ? 'You\'ll be reminded at the exact time'
                            : 'You\'ll be reminded 1 hour before the appointment',
                        color: Colors.orange,
                        size: 13,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Save / Update button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSchedule,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : CustomText(
                          text: _isEditing ? 'Save Changes' : 'Save Reminder',
                          color: Colors.white,
                          size: 16,
                          weight: FontWeight.w600,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(
    String label,
    String type,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedType == type;
    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 28,
            ),
            const SizedBox(height: 8),
            CustomText(
              text: label,
              color: isSelected ? Colors.white : Colors.grey[600]!,
              size: 13,
              weight: FontWeight.w600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyButton(String label, String frequency, IconData icon) {
    final isSelected = _selectedFrequency == frequency;
    return InkWell(
      onTap: () => setState(() => _selectedFrequency = frequency),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 18,
            ),
            const SizedBox(width: 6),
            CustomText(
              text: label,
              color: isSelected ? Colors.white : Colors.grey[600]!,
              size: 12,
              weight: FontWeight.w600,
            ),
          ],
        ),
      ),
    );
  }
}
