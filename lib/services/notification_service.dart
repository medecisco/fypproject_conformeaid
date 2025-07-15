// lib/services/notification_service.dart
import 'dart:io' show Platform; // Required for Platform.isAndroid
import 'package:flutter/foundation.dart'; // Required for debugPrint
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;


@pragma('vm:entry-point')
void handleBackgroundNotificationTap(NotificationResponse notificationResponse) {
  debugPrint('Background notification tapped with payload: ${notificationResponse.payload}');
}

class NotificationService {
  // Make the plugin instance private to control access
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static const String reminderChannelId = "menstruation_reminder_channel";
  static const String reminderChannelName = "Menstruation Reminders";
  static const String reminderChannelDescription = "Channel for daily menstruation cycle reminders";


  static const String appStatusChannelId = "app_status_channel";
  static const String appStatusChannelName = "App Status";
  static const String appStatusChannelDescription = "Persistent notification for app status";

  // Unique IDs for notifications
  static const int reminderNotificationId = 0; // For the daily scheduled reminder
  static const int appStatusNotificationId = 1; // For the persistent app status notification

  /// Initializes the notification service.
  Future<void> init() async {

    tz.initializeTimeZones();


    try {

      tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
    } catch (e) {
      // Fallback to UTC if the specified timezone isn't found for some reason
      debugPrint("Warning: Could not set timezone to Asia/Kuala_Lumpur. Falling back to UTC. Error: $e");
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
    }

    // Android initialization settings
    const AndroidInitializationSettings androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');


    final InitializationSettings initializationSettings = InitializationSettings(
      android: androidInitializationSettings,

    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap here when the app is in the foreground
        if (response.payload != null) {
          debugPrint('Foreground notification tapped with payload: ${response.payload}');
        }
      },
      onDidReceiveBackgroundNotificationResponse: handleBackgroundNotificationTap,
    );

    // Create notification channels for Android 8.0 (API 26) and above
    _createNotificationChannel(reminderChannelId, reminderChannelName, reminderChannelDescription, Importance.max);
    _createNotificationChannel(appStatusChannelId, appStatusChannelName, appStatusChannelDescription, Importance.low); // Lower importance for persistent status
  }

  // Helper method to create notification channels
  void _createNotificationChannel(String id, String name, String description, Importance importance) async {
    final AndroidNotificationChannel androidChannel = AndroidNotificationChannel(
      id,
      name,
      description: description,
      importance: importance,
      // playSound: true, // You can control sound here if needed
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  // Method to request the SCHEDULE_EXACT_ALARM permission for Android 12+
  // This will open the system settings screen for the user to grant the permission.
  Future<bool?> requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        return await androidImplementation.requestExactAlarmsPermission();
      }
    }
    return false; // Not an Android platform or implementation not found
  }

  /// Shows a persistent reminder status notification (e.g., "Reminder is ON").
  /// This notification stays in the notification shade until explicitly cancelled.
  Future<void> showReminderStatusNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      appStatusChannelId, // Use the app status channel
      appStatusChannelName,
      channelDescription: appStatusChannelDescription,
      importance: Importance.low, // Lower importance for persistent status
      priority: Priority.low,
      ongoing: true, // Makes it a persistent notification
      autoCancel: false, // Does not disappear when tapped
      showWhen: false, // Don't show timestamp
      visibility: NotificationVisibility.public,
    );
    final NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics, iOS: const DarwinNotificationDetails()); // Include iOS details

    await _flutterLocalNotificationsPlugin.show(
      appStatusNotificationId, // Use a unique ID for the persistent status notification
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Cancels the persistent reminder status notification.
  Future<void> cancelReminderStatusNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(appStatusNotificationId);
  }

  /// Schedules a daily reminder notification.
  /// The notification will repeat daily at the specified time.
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
    String? sound,
  }) async {
    // Calculate the next scheduled date/time
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      reminderChannelId,
      reminderChannelName,
      channelDescription: reminderChannelDescription,
      importance: Importance.max, // High importance for the actual reminder
      priority: Priority.high,
      ticker: 'Reminder',
      sound: sound != null ? RawResourceAndroidNotificationSound(sound) : null, // Custom sound
    );


    final NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Request exact alarm if possible
      matchDateTimeComponents: DateTimeComponents.time, // Repeats daily at the same time
      payload: payload,
    );
  }

  // Helper to get the next instance of a specific time today or tomorrow
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Cancels a specific notification by its ID.
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Cancels all pending notifications.
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}

// Global instance of NotificationService for easy access throughout the app
final NotificationService notificationService = NotificationService();