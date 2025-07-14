// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart'; // For TimeOfDay, if needed for persistent notification body
import 'dart:io' show Platform; // Required for Platform.isAndroid check


class NotificationService {
  // Make the plugin instance private to control access
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static const String reminderChannelId = "menstruation_reminder_channel";
  static const String reminderChannelName = "Menstruation Reminders";
  static const String reminderChannelDescription = "Channel for daily menstruation cycle reminders";

  // You might want a separate channel for the persistent app status notification
  static const String appStatusChannelId = "app_status_channel";
  static const String appStatusChannelName = "App Status";
  static const String appStatusChannelDescription = "Persistent notification for app status";


  // Unique IDs for notifications
  static const int reminderNotificationId = 0; // For the daily scheduled reminder
  static const int appStatusNotificationId = 1; // For the persistent app status notification

  Future<void> init() async {
    // IMPORTANT: Initialize time zones ONLY ONCE at the very start of your app (e.g., in main.dart)
    // The flutter_local_notifications plugin's example often puts it here for simplicity,
    // but if you call NotificationService.init() from main.dart, this is the right place.
    tz.initializeTimeZones();

    // Set the local location for timezone.
    // For Malaysia, 'Asia/Kuala_Lumpur' is a valid IANA timezone name.
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
    } catch (e) {
      // Fallback to UTC if the specified timezone isn't found for some reason
      print("Warning: Could not set timezone to Asia/Kuala_Lumpur. Falling back to UTC. Error: $e");
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
    }

    const AndroidInitializationSettings androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      // No iOS settings included as per your request
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap here if needed (app is in foreground)
        if (response.payload != null) {
          debugPrint('notification payload: ${response.payload}');
        }
      },
      // For handling taps when the app is in the background or terminated
      onDidReceiveBackgroundNotificationResponse: handleBackgroundNotificationTap,
    );

    // Create notification channels for Android 8.0 (API 26) and above
    _createNotificationChannel(reminderChannelId, reminderChannelName, reminderChannelDescription);
    _createNotificationChannel(appStatusChannelId, appStatusChannelName, appStatusChannelDescription);
  }

  // Helper method to create notification channels
  void _createNotificationChannel(String id, String name, String description) async {
    final AndroidNotificationChannel androidChannel = AndroidNotificationChannel(
      id,
      name,
      description: description,
      importance: Importance.max, // Max importance for reminders
      // For app status, you might use Importance.low or .min
      // For 'appStatusChannelId', consider Importance.low or Importance.min for less intrusive persistent notifications.
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

  // Method to show a persistent reminder status notification (e.g., "Reminder is ON")
  Future<void> showReminderNotification({
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
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      appStatusNotificationId, // Use a unique ID for the persistent status notification
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // Method to cancel the persistent reminder status notification
  Future<void> cancelReminderNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(appStatusNotificationId);
  }

  // Method to schedule a daily reminder
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    String? payload,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      reminderChannelId,
      reminderChannelName,
      channelDescription: reminderChannelDescription,
      importance: Importance.max, // High importance for the actual reminder
      priority: Priority.high,
      ticker: 'Reminder',
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
      // This is crucial: Repeats daily at the same time (hour and minute)
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  // Helper method to cancel a specific notification by ID
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }
}

// Global instance of NotificationService
final NotificationService notificationService = NotificationService();

// A top-level function is required for onDidReceiveBackgroundNotificationResponse
@pragma('vm:entry-point')
void handleBackgroundNotificationTap(NotificationResponse notificationResponse) {
  debugPrint('Background notification tapped with payload: ${notificationResponse.payload}');
  // Implement your logic here for when a notification is tapped while the app is in the background or terminated.
  // You cannot directly update UI here. You might use shared preferences to store
  // navigation information, which can then be read when the app is foregrounded.
}