//this part is a functional mockup every function that are mention in this page has been put in the report recommendation for future development
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- State Variables for Settings ---
  bool _vibrateOnNotification = true;
  String _notificationSound = 'Default Alert';
  String _alarmSound = 'Gentle Wake';
  bool _vibrateForAlarms = true;
  int _snoozeDuration = 10;

  final List<String> _availableNotificationSounds = [
    'Default Alert',
    'Chime',
    'Ding',
    'Bell',
    'Pulse',
    'Silent',
  ];
  final List<String> _availableAlarmSounds = [
    'Gentle Wake',
    'Standard Alarm',
    'Loud Bell',
    'Bird Song',
    'Sunrise Melody',
  ];

  double _fontSizeScale = 1.0;
  bool _boldText = false;
  // --- End State Variables ---

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('Settings', style: TextStyle(color: Color(0xFFE67A82))),
        centerTitle: false,
        actions: [],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              labelColor: Color(0xFFE67A82),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFFE67A82),
              tabs: const [
                Tab(text: 'Sounds & Alerts'),
                Tab(text: 'Display'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSoundsAlertsTab(),
          _buildDisplaySettingsTab(),
        ],
      ),
    );
  }

  Widget _buildSoundsAlertsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('APP NOTIFICATIONS', style: TextStyle(color:Color(0xFFE67A82), fontSize: 13)),
          ListTile(
            title: const Text('Notification Sound'),
            subtitle: Text(_notificationSound),
            onTap: () {
              _showSoundPickerDialog(context, _notificationSound, _availableNotificationSounds, (newSound) {
                setState(() {
                  _notificationSound = newSound;
                });
              });
            },
          ),
          const Divider(color: Colors.white12),
          SwitchListTile(
            title: const Text('Vibrate for Notifications'),
            value: _vibrateOnNotification,
            onChanged: (bool value) {
              setState(() {
                _vibrateOnNotification = value;
              });
            },
          ),
          const Divider(color: Colors.white12, height: 40),
          const Text('ALARMS', style: TextStyle(color: Color(0xFFE67A82), fontSize: 13)),
          ListTile(
            title: const Text('Alarm Sound'),
            subtitle: Text(_alarmSound),
            onTap: () {
              _showSoundPickerDialog(context, _alarmSound, _availableAlarmSounds, (newSound) {
                setState(() {
                  _alarmSound = newSound;
                });
              });
            },
          ),
          const Divider(color: Colors.white12),
          SwitchListTile(
            title: const Text('Vibrate for Alarms'),
            value: _vibrateForAlarms,
            onChanged: (bool value) {
              setState(() {
                _vibrateForAlarms = value;
              });
            },
          ),
          const Divider(color: Colors.white12),
          ListTile(
            title: const Text('Snooze Duration'),
            subtitle: Text('$_snoozeDuration minutes'),
            onTap: () {
              _showSnoozeDurationDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDisplaySettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FONT SIZE', style: TextStyle(color: Color(0xFFE67A82), fontSize: 13)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Adjust App Font Size', style: TextStyle(color: Colors.black38)),
                Slider(
                  value: _fontSizeScale,
                  min: 0.7,
                  max: 1.3,
                  divisions: 6,
                  label: (_fontSizeScale * 100).round().toString(),
                  onChanged: (double value) {
                    setState(() {
                      _fontSizeScale = value;
                    });
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Example text with current font size.',
                    style: TextStyle(fontSize: 16 * _fontSizeScale, color: Colors.black38),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12),
          SwitchListTile(
            title: const Text('Bold Text'),
            subtitle: const Text('Make all text bold for better readability.'),
            value: _boldText,
            onChanged: (bool value) async {
              setState(() {
                _boldText = value;
              });
              final prefs = await SharedPreferences.getInstance();
              prefs.setBool('boldText', _boldText);
            },
          ),
          const Divider(color: Colors.white12),
          const SizedBox(height: 20),
          const Text(
            'Changes will apply across the app and may require a restart for full effect.',
            style: TextStyle(color: Color(0xFFE67A82), fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showSoundPickerDialog(BuildContext context, String currentSound, List<String> availableSounds, Function(String) onSoundSelected) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Sound', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.grey[850],
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: availableSounds.map((sound) {
                return RadioListTile<String>(
                  title: Text(sound, style: const TextStyle(color: Colors.white)),
                  value: sound,
                  groupValue: currentSound,
                  onChanged: (String? value) {
                    if (value != null) {
                      onSoundSelected(value);
                      Navigator.of(context).pop();
                    }
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showSnoozeDurationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Snooze Duration', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.grey[850],
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [5, 10, 15, 20, 30].map((minutes) {
              return RadioListTile<int>(
                title: Text('$minutes minutes', style: const TextStyle(color: Colors.white)),
                value: minutes,
                groupValue: _snoozeDuration,
                onChanged: (int? value) {
                  if (value != null) {
                    setState(() {
                      _snoozeDuration = value;
                    });
                    Navigator.of(context).pop();
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
