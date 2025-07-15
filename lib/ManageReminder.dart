import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'actual_cycle_manager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/notification_service.dart'; //import for access to global notification service


class ManageReminderScreen extends StatefulWidget {
  final VoidCallback onNavigateToTimeline;

  const ManageReminderScreen({super.key, required this.onNavigateToTimeline});

  @override
  State<ManageReminderScreen> createState() => _ManageReminderScreenState();
}

class _ManageReminderScreenState extends State<ManageReminderScreen> {
  TimeOfDay reminderTime = TimeOfDay.now();
  bool isReminderEnabled = false;
  bool _boldText = false;
  double _fontSizeScale = 1.0;


  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadReminderSettings();
    _checkAndPromptContraceptivePreference();
  }


  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _boldText = prefs.getBool('boldText') ?? false;
      _fontSizeScale = prefs.getDouble('fontSizeScale') ?? 1.0;
    });
  }


  Future<void> _checkAndPromptContraceptivePreference() async {
    List<Map<String, dynamic>> cycleEvents = await ActualCycleManager.readActualCycles();

    // Check if the contraceptive info is already set
    bool hasSetPreference = cycleEvents.any((event) => event['type'] == 'contraceptive');

    if (!hasSetPreference) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Contraceptive Use"),
          content: const Text("Are you currently taking contraceptive pills?"),
          actions: [
            TextButton(
              onPressed: () async {
                DateTime currentDate = DateTime.now();
                await ActualCycleManager.addContraceptiveInfo(false); // User says 'No'
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/Homepage');
              },
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () async {
                DateTime currentDate = DateTime.now();
                await ActualCycleManager.addContraceptiveInfo(true); // User says 'Yes'
                Navigator.of(context).pop();
              },
              child: const Text("Yes"),
            ),
          ],
        ),
      );
    }
  }


  Future<void> _loadReminderSettings() async {
    // Load exclusively from local JSON
    final localReminderData = await ActualCycleManager.readReminderInfo();

    if (localReminderData != null) {
      setState(() {
        isReminderEnabled = localReminderData['enabled'] ?? false;
        if (localReminderData['hour'] != null && localReminderData['minute'] != null) {
          reminderTime = TimeOfDay(hour: localReminderData['hour'], minute: localReminderData['minute']);
        }
      });
      print("Loaded reminder settings from JSON: Enabled: $isReminderEnabled, Time: ${reminderTime.format(context)}");
    } else {
      print("No reminder settings found in JSON. Using default values.");
    }

    // Update persistent notification based on loaded state
    _updatePersistentReminderNotification(isReminderEnabled, reminderTime);
  }


  Future<void> _saveReminderSettings() async {
    // Save exclusively to local JSON using ActualCycleManager
    await ActualCycleManager.addReminderInfo(reminderTime, isReminderEnabled);
    print("Saved reminder settings to JSON: Enabled: $isReminderEnabled, Time: ${reminderTime.format(context)}");

    // Update the persistent notification and schedule the daily notification
    _updatePersistentReminderNotification(isReminderEnabled, reminderTime);
    if (isReminderEnabled) {
      await _scheduleNotification();
    } else {
      // Cancel both persistent and scheduled daily reminder
      await notificationService.cancelReminderStatusNotification(); // Fixed: Use cancelReminderStatusNotification
      await notificationService.cancelNotification(NotificationService.reminderNotificationId);// Cancels scheduled daily
      print("All reminders cancelled.");
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder settings saved!')),
    );
  }


// New method to control the persistent reminder notification
  void _updatePersistentReminderNotification(bool enabled, TimeOfDay time) {
    if (enabled) {
      notificationService.showReminderStatusNotification( // Fixed: Use showReminderStatusNotification
        title: 'ConformeAid Reminder Active',
        body: 'Daily reminder set for ${time.format(context)}',
        payload: 'reminder_active',
      );
      print("Persistent reminder notification shown.");
    } else {
      notificationService.cancelReminderStatusNotification(); // Fixed: Use cancelReminderStatusNotification
      print("Persistent reminder notification cancelled.");
    }
  }




  Future<void> _scheduleNotification() async {

    tz.setLocalLocation(tz.getLocation(tz.local.name));

    List<Map<String, dynamic>> cycleEvents = await ActualCycleManager.readActualCycles();


    final contraceptiveEvent = cycleEvents.firstWhere(
          (event) => event['type'] == 'contraceptive',
      orElse: () => {'usesContraceptive': false}, // Default if not found
    );
    bool usesContraceptive = contraceptiveEvent['usesContraceptive'];

    // Cancel any previously scheduled reminder to avoid duplicates
    await notificationService.cancelNotification(NotificationService.reminderNotificationId);

    if (isReminderEnabled) { // Only schedule if reminder is enabled
      // Determine the notification body based on contraceptive use
      String notificationBody;
      if (usesContraceptive) {
        notificationBody = 'It\'s time for your daily contraceptive reminder!';
      } else {
        notificationBody = 'It\'s time to check your menstruation status!';
      }

      // Schedule the daily reminder using the notification service
      // The `notificationService.scheduleDailyReminder` method will handle
      // calculating the next suitable time and setting it to repeat daily
      // based on the provided hour and minute.
      await notificationService.scheduleDailyReminder(
        id: NotificationService.reminderNotificationId, // Using centralized notification ID
        title: 'ConformeAid Reminder',
        body: notificationBody,
        hour: reminderTime.hour,
        minute: reminderTime.minute,
        payload: 'scheduled_daily_reminder',

      );
      print('Daily reminder scheduled for ${reminderTime.format(context)}');
    } else {
      // If reminder is disabled, cancel any scheduled notifications with this ID
      await notificationService.cancelNotification(NotificationService.reminderNotificationId);
      print('Daily reminder cancelled (due to reminder being disabled).');
    }
  }

  void _toggleReminder(bool value) async {
    setState(() {
      isReminderEnabled = value;
    });
    if (value) {
      // Request exact alarm permission specifically for Android
      // This will prompt the user to grant the "Alarms & reminders" permission
      // if they are on Android 12+ and haven't granted it yet.
      final bool? granted = await notificationService.requestExactAlarmPermission();
      if (granted == false) {
        print("Exact alarm permission was denied. Scheduled notifications may not work reliably.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exact alarm permission was denied. Scheduled notifications may not work reliably.')),
        );
      }
    }
    _saveReminderSettings(); // This handles saving and notification updates
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: reminderTime,
    );
    if (picked != null && picked != reminderTime) {
      setState(() {
        reminderTime = picked;
      });
      _saveReminderSettings(); // This handles saving and notification updates
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = reminderTime.format(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.grey),
          onPressed: () {
            Navigator.pushNamed(context, '/Homepage');
          },
        ),
        title: Text(
          'Reminder',
          style: TextStyle(
            color: Colors.black,
            fontWeight: _boldText ? FontWeight.bold : FontWeight.normal,
            fontSize: 20 * _fontSizeScale,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5C75E), Color(0xFFE67A82)],
            stops: [0.3, 0.7],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily Reminders',
                                style: TextStyle(
                                  fontSize: 18 * _fontSizeScale,
                                  fontWeight: _boldText ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text('Reminders to check your status', style: TextStyle(fontSize: 14 * _fontSizeScale)),
                            ],
                          ),
                          Switch(
                            value: isReminderEnabled,
                            onChanged: _toggleReminder,
                            activeColor: Colors.pink.shade200,
                          ),
                        ],
                      ),
                      const Divider(height: 30, thickness: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Time',
                            style: TextStyle(
                              fontSize: 18 * _fontSizeScale,
                              fontWeight: _boldText ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          TextButton(
                            onPressed: _selectTime,
                            child: Text(
                              timeLabel,
                              style: TextStyle(fontSize: 18 * _fontSizeScale, color: Colors.pink.shade200),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            TextButton.icon(
              onPressed: widget.onNavigateToTimeline,
              icon: Icon(Icons.calendar_month, size: 24 * _fontSizeScale),
              label: Text(
                'Timeline',
                style: TextStyle(fontSize: 14 * _fontSizeScale, fontWeight: _boldText ? FontWeight.bold : FontWeight.normal),
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: Icon(Icons.notifications, size: 24 * _fontSizeScale),
              label: Text(
                'Reminder',
                style: TextStyle(fontSize: 14 * _fontSizeScale, fontWeight: _boldText ? FontWeight.bold : FontWeight.normal),
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.pink.shade200),
            ),
          ],
        ),
      ),
    );
  }
}