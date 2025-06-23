import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadReminderSettings();
    _initializeNotifications();
  }

  void _initializeNotifications() {
    tz.initializeTimeZones();
    final AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _boldText = prefs.getBool('boldText') ?? false;
      _fontSizeScale = prefs.getDouble('fontSizeScale') ?? 1.0;
    });
  }

  Future<void> _loadReminderSettings() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('reminder')
        .get();

    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      setState(() {
        isReminderEnabled = data['enabled'] ?? false;
        if (data['hour'] != null && data['minute'] != null) {
          reminderTime = TimeOfDay(
              hour: data['hour'], minute: data['minute']);
        }
      });
    }
  }

  Future<void> _saveReminderSettings() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('reminder')
        .set({
      'enabled': isReminderEnabled,
      'hour': reminderTime.hour,
      'minute': reminderTime.minute,
    });
  }

  Future<void> _scheduleNotification() async {
    await flutterLocalNotificationsPlugin.cancelAll(); // Cancel existing

    if (!isReminderEnabled) return;

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      reminderTime.hour,
      reminderTime.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'daily_reminder_channel',
      'Daily Menstruation Reminder',
      channelDescription: 'Reminds you about your menstruation cycle daily',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0, // Notification ID
      'Menstruation Reminder',
      'It\'s time to check your menstruation status!',
      scheduledDate,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  void _toggleReminder(bool value) {
    setState(() {
      isReminderEnabled = value;
    });
    _saveReminderSettings();
    if (isReminderEnabled) {
      _scheduleNotification();
    } else {
      flutterLocalNotificationsPlugin.cancelAll();
    }
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
      _saveReminderSettings();
      if (isReminderEnabled) {
        _scheduleNotification();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = reminderTime.format(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // BACK BUTTON
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.grey),
          onPressed: () {
            // Navigate to '/Homepage'
            Navigator.pushNamed(context, '/Homepage');
          },
        ),
        title:  Text(
          'Reminder',
          style: TextStyle(color: Colors.black, fontWeight: _boldText ? FontWeight.bold : FontWeight.normal, fontSize: 20 * _fontSizeScale,),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5C75E),
              Color(0xFFE67A82),
            ],
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
                            children:  [
                              Text(
                                'Daily Reminders',
                                style: TextStyle(
                                    fontSize: 18 * _fontSizeScale, fontWeight: _boldText ? FontWeight.bold : FontWeight.normal),
                              ),
                              SizedBox(height: 4),
                              Text('Reminders to check your status', style: TextStyle(fontSize: 14 * _fontSizeScale),),
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
                                fontSize: 18 * _fontSizeScale, fontWeight: _boldText ? FontWeight.bold : FontWeight.normal),
                          ),
                          TextButton(
                            onPressed: _selectTime,
                            child: Text(
                              timeLabel,
                              style: TextStyle(
                                  fontSize: 18 * _fontSizeScale, color: Colors.pink.shade200),
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
              icon:  Icon(Icons.calendar_month, size: 24 * _fontSizeScale,),
              label:  Text('Timeline', style: TextStyle(fontSize: 14 * _fontSizeScale, fontWeight: _boldText ? FontWeight.bold : FontWeight.normal),),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
            ),
            TextButton.icon(
              onPressed: () {},
              icon:  Icon(Icons.notifications, size: 24 * _fontSizeScale,),
              label: Text('Reminder', style: TextStyle(fontSize: 14 * _fontSizeScale, fontWeight: _boldText ? FontWeight.bold : FontWeight.normal),),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.pink.shade200), // Active color
            ),
          ],
        ),
      ),
    );
  }
}
