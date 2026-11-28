import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ibada/alarms.dart';
import 'package:ibada/local_data.dart';
import 'package:ibada/main.dart';
import 'package:ibada/prayer_times.dart';
import 'package:ibada/screens.dart';
import 'package:ibada/startup_permissions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

class _MobileAlarms extends PrayerAlarms {
  @override
  bool get supported => true;
}

class _LocalData extends LocalData {
  @override
  Future<bool> refreshTimeZones(String activeZone) async => false;
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  for (final alarmKit in [false, true]) {
    testWidgets(
      'iOS ${alarmKit ? 'requires' : 'skips'} AlarmKit permission when '
      '${alarmKit ? 'available' : 'unavailable'}',
      (tester) async {
        var exact = false;
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/geolocator'),
          (call) async => LocationPermission.whileInUse.index,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('app.ibada/alarms'),
          (call) async {
            if (call.method == 'status') {
              return {
                'notifications': true,
                'exact': exact,
                'fullScreen': false,
                'alarmKit': alarmKit,
              };
            }
            expect(call.method, 'request');
            expect(call.arguments, 'exact');
            exact = true;
            return null;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            builder: (_, child) =>
                StartupPermissions(alarms: _MobileAlarms(), child: child!),
            home: const Scaffold(body: Text('Home')),
          ),
        );
        await tester.pumpAndSettle();
        if (alarmKit) {
          expect(find.text('Home'), findsNothing);
          await tester.tap(find.text('تفعيل المنبّه الدقيق'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Home'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
      },
      variant: const TargetPlatformVariant({TargetPlatform.iOS}),
    );
  }

  testWidgets(
    'an existing install stays locked until permissions are granted',
    (tester) async {
      final preferences = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = preferences);
      final data = _LocalData();
      final saved = PrayerSettings.defaults.copyWith(confirmedPlace: true);
      await data.save(saved);

      var location = LocationPermission.denied;
      var requestedLocation = LocationPermission.denied;
      var notifications = false;
      var exact = false;
      var fullScreen = false;
      var openedLocationSettings = false;
      final alarmRequests = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      const locationChannel = MethodChannel('flutter.baseflow.com/geolocator');
      const alarmChannel = MethodChannel('app.ibada/alarms');
      messenger.setMockMethodCallHandler(locationChannel, (call) async {
        return switch (call.method) {
          'checkPermission' => location.index,
          'requestPermission' => requestedLocation.index,
          'openAppSettings' => openedLocationSettings = true,
          _ => throw MissingPluginException(call.method),
        };
      });
      messenger.setMockMethodCallHandler(alarmChannel, (call) async {
        switch (call.method) {
          case 'status':
            return {
              'notifications': notifications,
              'exact': exact,
              'fullScreen': fullScreen,
              'alarmKit': false,
            };
          case 'request':
            alarmRequests.add(call.arguments as String);
            if (call.arguments == 'notifications') notifications = true;
          case 'replace':
            break;
          default:
            throw MissingPluginException(call.method);
        }
        return null;
      });

      Future<void> tap(String label) async {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      Future<void> resume() async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        IbadaApp(data: data, settings: saved, alarms: _MobileAlarms()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(TodayScreen), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);

      await tap('السماح بالموقع');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(TodayScreen), findsNothing);

      requestedLocation = LocationPermission.deniedForever;
      await tap('السماح بالموقع');
      await tap('فتح إعدادات الموقع');
      expect(openedLocationSettings, isTrue);
      location = LocationPermission.whileInUse;
      await resume();

      await tap('السماح بالإشعارات');
      await tap('تفعيل المنبّه الدقيق');
      expect(find.byType(TodayScreen), findsNothing);
      exact = true;
      await resume();

      await tap('تفعيل ملء الشاشة');
      expect(find.byType(TodayScreen), findsNothing);
      fullScreen = true;
      await resume();

      expect(alarmRequests, ['notifications', 'exact', 'fullScreen']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TodayScreen), findsOneWidget);

      notifications = false;
      await resume();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(TodayScreen), findsNothing);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );
}
