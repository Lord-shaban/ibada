import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';

import 'alarms.dart';

enum _Permission {
  location('الموقع', 'لحساب مواقيت الصلاة حسب مكانك.', 'السماح بالموقع'),
  notifications('الإشعارات', 'لإظهار تنبيهات الصلاة.', 'السماح بالإشعارات'),
  exact(
    'المنبّه الدقيق',
    'لتشغيل التنبيه في موعد الصلاة.',
    'تفعيل المنبّه الدقيق',
  ),
  fullScreen(
    'ملء الشاشة',
    'لعرض تنبيه الصلاة على شاشة القفل.',
    'تفعيل ملء الشاشة',
  );

  const _Permission(this.title, this.description, this.action);

  final String title, description, action;
}

class StartupPermissions extends StatefulWidget {
  const StartupPermissions({
    super.key,
    required this.alarms,
    required this.child,
  });

  final PrayerAlarms alarms;
  final Widget child;

  @override
  State<StartupPermissions> createState() => _StartupPermissionsState();
}

class _StartupPermissionsState extends State<StartupPermissions> {
  late final AppLifecycleListener _lifecycle;
  _Permission? _missing;
  String? _error;
  bool _verified = false;
  bool _busy = false;
  bool _locationNeedsSettings = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_verify()));
    unawaited(_verify());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<_Permission?> _firstMissing() async {
    final location = await Geolocator.checkPermission();
    if (location != LocationPermission.whileInUse &&
        location != LocationPermission.always) {
      if (location == LocationPermission.deniedForever) {
        _locationNeedsSettings = true;
      }
      return _Permission.location;
    }
    _locationNeedsSettings = false;

    final status = await widget.alarms.status(permissionsOnly: true);
    if (!status.supported) {
      throw const FormatException('Missing alarm permissions');
    }
    if (!status.notifications) return _Permission.notifications;

    final android = defaultTargetPlatform == TargetPlatform.android;
    if ((android || status.alarmKit) && !status.exact) {
      return _Permission.exact;
    }
    if (android && !status.fullScreen) return _Permission.fullScreen;
    return null;
  }

  Future<void> _request(_Permission permission) async {
    if (permission != _Permission.location) {
      await widget.alarms.request(permission.name);
    } else if (_locationNeedsSettings) {
      if (!await Geolocator.openAppSettings()) {
        throw Exception('Could not open location settings');
      }
    } else {
      final result = await Geolocator.requestPermission();
      _locationNeedsSettings = result == LocationPermission.deniedForever;
    }
  }

  Future<void> _verify([_Permission? permission]) async {
    if (_busy) return;
    setState(() => _busy = true);
    String? error;
    try {
      if (permission != null) {
        try {
          await _request(permission);
        } on Exception {
          error = 'تعذّر طلب الإذن. حاول مرة أخرى.';
        }
      }
      final missing = await _firstMissing();
      if (mounted) {
        setState(() {
          _verified = true;
          _missing = missing;
          _error = error;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _verified = false;
          _missing = null;
          _error = 'تعذّر التحقق من الأذونات. حاول مرة أخرى.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final missing = _missing;
    final error = _error;
    if (_verified && missing == null) return widget.child;

    return Scaffold(
      backgroundColor: Color.alphaBlend(
        Colors.black54,
        Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: Center(
          child: AlertDialog(
            scrollable: true,
            title: const Text('أذونات تشغيل عبادة'),
            content: Semantics(
              liveRegion: true,
              child: Text(switch (missing) {
                null => error ?? 'جارٍ التحقق من الأذونات…',
                _ =>
                  '${missing.title}\n${missing.description}'
                      '${error == null ? '' : '\n\n$error'}',
              }),
            ),
            actions: [
              if (missing != null || error != null)
                FilledButton(
                  onPressed: _busy ? null : () => _verify(missing),
                  child: Text(
                    missing == _Permission.location && _locationNeedsSettings
                        ? 'فتح إعدادات الموقع'
                        : missing?.action ?? 'إعادة التحقق',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
