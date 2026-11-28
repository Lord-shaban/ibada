import 'dart:io';

import 'package:flutter/services.dart';

import 'prayer_times.dart';

typedef AlarmStatus = ({
  bool supported,
  bool notifications,
  bool exact,
  bool fullScreen,
  bool alarmKit,
});

typedef AlarmMedia = ({
  String? sound,
  String? image,
  String? imageScope,
  bool systemSounds,
  bool soundPreset,
  Map<String, String> soundPresets,
  bool imageSupported,
  bool imagePreset,
});

class PrayerAlarms {
  const PrayerAlarms();

  static const _channel = MethodChannel('app.ibada/alarms');

  static const unknown = (
    supported: false,
    notifications: false,
    exact: false,
    fullScreen: false,
    alarmKit: false,
  );

  Future<AlarmStatus> status({bool permissionsOnly = false}) async {
    final state = await _channel.invokeMapMethod<String, bool>(
      'status',
      permissionsOnly,
    );
    return state == null
        ? unknown
        : (
            supported: true,
            notifications: state['notifications'] ?? false,
            exact: state['exact'] ?? false,
            fullScreen: state['fullScreen'] ?? false,
            alarmKit: state['alarmKit'] ?? false,
          );
  }

  Future<void> request(String permission) =>
      _channel.invokeMethod<void>('request', permission);

  Future<AlarmMedia?> media() async {
    final state = await _channel.invokeMapMethod<String, Object?>(
      'mediaStatus',
    );
    if (state == null) return null;
    final soundPresets = state['soundPresets'];
    return (
      sound: state['sound'] as String?,
      image: state['image'] as String?,
      imageScope: state['imageScope'] as String?,
      systemSounds: state['systemSounds'] == true,
      soundPreset: state['soundPreset'] == true,
      soundPresets: soundPresets is Map
          ? Map<String, String>.from(soundPresets)
          : const <String, String>{},
      imageSupported: state['imageSupported'] == true,
      imagePreset: state['imagePreset'] == true,
    );
  }

  Future<void> changeMedia(String action, [String? preset]) =>
      _channel.invokeMethod<void>(action, preset);

  Future<void> replace(PrayerCalculator calculator, DateTime now) async {
    final settings = calculator.settings;
    final events = settings.alarms && settings.confirmedPlace
        ? calculator.upcomingAlerts(
            now.subtract(const Duration(minutes: 2)),
            400,
          )
        : <PrayerEvent>[];
    await _channel.invokeMethod<void>('replace', {
      'fullScreen': settings.fullScreen,
      'events': [
        for (final event in events)
          {
            'time': event.time.millisecondsSinceEpoch,
            'label': event.prayer.label,
            'prayer': event.prayer.index,
          },
      ],
    });
  }

  Future<void> test(bool fullScreen) =>
      _channel.invokeMethod<void>('test', fullScreen);

  bool get supported => Platform.isAndroid || Platform.isIOS;
}
