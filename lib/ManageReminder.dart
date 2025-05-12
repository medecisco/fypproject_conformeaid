import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class ManageReminderScreen extends StatefulWidget {
  final VoidCallback onNavigateToTimeline;
  const ManageReminderScreen({super.key, required this.onNavigateToTimeline});

  @override
  State<ManageReminderScreen> createState() => _ManageReminderScreenState();
}

class _ManageReminderScreenState extends State<ManageReminderScreen> {
  TimeOfDay reminderTime = const TimeOfDay(hour: 8, minute: 0);
  bool isReminderOn = true;
  bool isAutoReminderActive = false; // To track whether automatic reminder is activated
  bool alignWithCycle = false; // Whether the reminder should align with the cycle data
  DateTime? cycleStartDate;  // Store the predicted cycle start date
  int collectedDataMonths = 0; // Track months of collected menstruation data

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _getReminderData();  // Fetch the reminder data from Firestore when the app starts
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(initSettings);
    tz.initializeTimeZones();

    // Set up notification channels (required for Android 8.0 and above)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'reminder_channel', // id
      'Reminders', // name
      description: 'This channel is used for reminder notifications',
      importance: Importance.high,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Fetch reminder data from Firestore
  Future<void> _getReminderData() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get()
          .then((doc) {
        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            isReminderOn = data['isReminderOn'] ?? true;
            reminderTime = TimeOfDay(hour: data['reminderTimeHour'], minute: data['reminderTimeMinute']);
            alignWithCycle = data['alignWithCycle'] ?? false;
            isAutoReminderActive = data['isAutoReminderActive'] ?? false;
            collectedDataMonths = data['collectedDataMonths'] ?? 0;
          });
        }
      });
    }
  }

  // Store reminder data in Firestore
  Future<void> _storeReminderData() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      FirebaseFirestore.instance.collection('users').doc(userId).set({
        'isReminderOn': isReminderOn,
        'reminderTimeHour': reminderTime.hour,
        'reminderTimeMinute': reminderTime.minute,
        'alignWithCycle': alignWithCycle,
        'isAutoReminderActive': isAutoReminderActive,
        'collectedDataMonths': collectedDataMonths,
      });
    }
  }

  Future<void> _scheduleMenstrualCycleReminder(DateTime cycleStartDate) async {
    // Automatically adjust the reminder schedule based on the collected data (10 months)
    DateTime nextReminder = cycleStartDate.add(Duration(days: 5)); // Adjust based on prediction
    final tzTime = tz.TZDateTime.from(nextReminder, tz.local);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Contraceptive Reminder',
      'Time to take your contraceptive!',
      tzTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel', // Channel ID
          'Reminders', // Channel Name
          priority: Priority.high,
          importance: Importance.high,
          ticker: 'ticker',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exact,
      matchDateTimeComponents: DateTimeComponents.time, // Schedule based on time
    );
  }

  Future<void> _cancelReminder() async {
    await flutterLocalNotificationsPlugin.cancel(0);
  }

  // Check if the system has collected 10 months of data and if the user has agreed to activate auto reminders
  void checkAndActivateAutoReminder() {
    if (collectedDataMonths >= 10 && isAutoReminderActive) {
      // Trigger automatic reminder after collecting enough data
      if (cycleStartDate != null) {
        _scheduleMenstrualCycleReminder(cycleStartDate!);
      }
    }
  }

  void pickReminderTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: reminderTime,
    );
    if (picked != null && picked != reminderTime) {
      setState(() {
        reminderTime = picked;
      });
      if (isReminderOn) {
        _scheduleDailyReminder(picked);
      }
    }
  }

  Future<void> _scheduleDailyReminder(TimeOfDay time) async {
    final now = DateTime.now();
    final scheduledDate =
    DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final tzTime = tz.TZDateTime.from(
      scheduledDate.isBefore(now)
          ? scheduledDate.add(const Duration(days: 1))
          : scheduledDate,
      tz.local,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'ConformeAid Reminder',
      'Time to take your contraceptive!',
      tzTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel', // Channel ID
          'Reminders', // Channel Name
          priority: Priority.high,
          importance: Importance.high,
          ticker: 'ticker',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exact,
      matchDateTimeComponents: DateTimeComponents.time, // Schedule based on time
    );
  }

  void handleDeleteReminder() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Reminder"),
        content: const Text("Are you sure you want to delete this reminder?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              setState(() {
                isReminderOn = false;
              });
              _cancelReminder();
              Navigator.pop(ctx);
              _storeReminderData(); // Save the changes to Firestore
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Update cycle start date and set the reminder
  void updateCycleStartDate(DateTime newCycleStartDate) {
    setState(() {
      cycleStartDate = newCycleStartDate;
    });

    if (isReminderOn && cycleStartDate != null) {
      _scheduleMenstrualCycleReminder(cycleStartDate!);
      _storeReminderData(); // Save the changes to Firestore
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = reminderTime.format(context);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Manage reminder'),
        backgroundColor: Colors.orange.shade200,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange.shade200,
              Colors.red.shade300,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Reminder',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  child: Column(
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                timeLabel,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'ring once | take pill',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                          Switch(
                            value: isReminderOn,
                            onChanged: (value) {
                              setState(() {
                                isReminderOn = value;
                              });
                              if (value) {
                                _scheduleDailyReminder(reminderTime);
                              } else {
                                _cancelReminder();
                              }
                              _storeReminderData(); // Save reminder data to Firestore
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ElevatedButton.icon(
                            onPressed: pickReminderTime,
                            icon: const Icon(Icons.edit_calendar, color: Colors.white),
                            label: const Text('EDIT', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.lightGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.0),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: handleDeleteReminder,
                            icon: const Icon(Icons.delete, color: Colors.white),
                            label: const Text('DELETE', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade400,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.0),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.center,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      DateTime newCycleStartDate = DateTime.now().add(Duration(days: 3));  // Example: adjust for real data
                      updateCycleStartDate(newCycleStartDate); // Update reminder based on cycle prediction
                    },
                    icon: const Icon(Icons.notification_add_sharp, color: Colors.white),
                    label: const Text('ADD REMINDER', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        TextButton.icon(
                          onPressed: widget.onNavigateToTimeline,
                          icon: const Icon(Icons.calendar_month),
                          label: const Text('Timeline'),
                          style: TextButton.styleFrom(foregroundColor: Colors.grey),
                        ),
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.notifications),
                          label: const Text('Reminder'),
                          style: TextButton.styleFrom(foregroundColor: Colors.pink.shade200),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
