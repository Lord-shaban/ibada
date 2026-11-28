import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone_finder/timezone_finder.dart' as zones;

import 'prayer_times.dart';

const _settingsKey = 'prayer-settings';
const _zonesKey = 'tz-data';
const _etagKey = 'tz-etag';
const _checkedKey = 'tz-checked';
const _zoneFeed =
    'https://raw.githubusercontent.com/dart-lang/labs/main/pkgs/timezone/lib/data/latest_all.tzf';

class LocalData {
  final _preferences = SharedPreferencesAsync();
  String? _appliedZones;

  Future<PrayerSettings> load({
    PrayerSettings defaultSettings = PrayerSettings.defaults,
  }) async {
    tzdata.initializeTimeZones();
    try {
      final bundled = await rootBundle.load('assets/data/timezones.tzf');
      tz.initializeDatabase(
        bundled.buffer.asUint8List(
          bundled.offsetInBytes,
          bundled.lengthInBytes,
        ),
      );
    } catch (_) {
      tzdata.initializeTimeZones();
    }
    final packed = await _preferences.getString(_zonesKey);
    if (packed != null) {
      try {
        tz.initializeDatabase(base64Decode(packed));
        _appliedZones = packed;
      } catch (_) {
        tzdata.initializeTimeZones();
      }
    }
    final saved = await _preferences.getString(_settingsKey);
    if (saved == null) return defaultSettings;
    try {
      final settings = PrayerSettings.fromJson(
        jsonDecode(saved) as Map<String, dynamic>,
      );
      tz.getLocation(settings.place.zone);
      return settings;
    } catch (_) {
      return defaultSettings;
    }
  }

  Future<void> save(PrayerSettings settings) =>
      _preferences.setString(_settingsKey, jsonEncode(settings.toJson()));

  Future<bool> refreshTimeZones(String activeZone) async {
    final cached = await _preferences.getString(_zonesKey);
    var changed = false;
    if (cached != null && cached != _appliedZones) {
      final data = base64Decode(cached);
      if (await compute(_validZones, (bytes: data, zone: activeZone))) {
        tz.initializeDatabase(data);
        _appliedZones = cached;
        changed = true;
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = await _preferences.getInt(_checkedKey);
    if (last != null &&
        now >= last &&
        now - last < Duration.millisecondsPerDay) {
      return changed;
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client.getUrl(Uri.parse(_zoneFeed));
      final etag = await _preferences.getString(_etagKey);
      if (etag != null) {
        request.headers.set(HttpHeaders.ifNoneMatchHeader, etag);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode == HttpStatus.notModified) {
        await _preferences.setInt(_checkedKey, now);
        return changed;
      }
      if (response.statusCode != HttpStatus.ok) return changed;
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 8))) {
        bytes.add(chunk);
        if (bytes.length > 1500000) return changed;
      }
      final data = bytes.takeBytes();
      if (!await compute(_validZones, (bytes: data, zone: activeZone))) {
        return changed;
      }
      final packed = base64Encode(data);
      final previous = await _preferences.getString(_zonesKey);
      if (previous != packed) await _preferences.setString(_zonesKey, packed);
      final nextTag = response.headers.value(HttpHeaders.etagHeader);
      if (nextTag != null) await _preferences.setString(_etagKey, nextTag);
      await _preferences.setInt(_checkedKey, now);
      if (_appliedZones == packed) return changed;
      tz.initializeDatabase(data);
      _appliedZones = packed;
      return true;
    } on Exception {
      return changed;
    } finally {
      client.close(force: true);
    }
  }
}

bool _validZones(({Uint8List bytes, String zone}) data) {
  try {
    tz.initializeDatabase(data.bytes);
    tz.getLocation(data.zone);
    return tz.timeZoneDatabase.locations.length > 500;
  } catch (_) {
    return false;
  }
}

typedef City = ({Place place, String search});

class CityDirectory {
  Future<List<City>>? _loading;

  Future<List<City>> load() => _loading ??= () async {
    final bytes = await rootBundle.load('assets/data/cities.json.gz');
    return compute(
      _decodeCities,
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  }();

  Future<Place> current({required bool askPermission}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationProblem('شغّل خدمة الموقع أو اختر مدينتك يدويًا.');
    }
    final permission = askPermission
        ? await requestPermission()
        : await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      throw const LocationProblem(
        'اسمح للتطبيق بالموقع من إعدادات الهاتف أو اختر مدينة.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return coordinates(position.latitude, position.longitude, usesGps: true);
  }

  Future<LocationPermission> requestPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.denied
        ? Geolocator.requestPermission()
        : permission;
  }

  Future<Place> coordinates(
    double latitude,
    double longitude, {
    bool usesGps = false,
  }) async {
    final cities = await load();
    return compute(_lookupCoordinate, (
      coordinate: (lat: latitude, lon: longitude),
      cities: cities,
      usesGps: usesGps,
    ));
  }
}

class LocationProblem implements Exception {
  const LocationProblem(this.message);
  final String message;
}

List<City> _decodeCities(Uint8List bytes) {
  final rows = jsonDecode(utf8.decode(gzip.decode(bytes))) as List<dynamic>;
  return [
    for (final row in rows.cast<List>())
      (
        place: Place(
          row[0] as String,
          row[1] as String,
          (row[2] as num).toDouble(),
          (row[3] as num).toDouble(),
          row[4] as String,
        ),
        search: searchKey('${row[0]} ${row[1]} ${row[5]}'),
      ),
  ];
}

Place _lookupCoordinate(
  ({({double lat, double lon}) coordinate, List<City> cities, bool usesGps})
  input,
) {
  tzdata.initializeTimeZones();
  final point = input.coordinate;
  final zone = zones.findLocation(point.lon, point.lat)?.name;
  Place? closest;
  var shortest = double.infinity;
  for (final city in input.cities) {
    final place = city.place;
    if (zone != null && place.zone != zone) continue;
    final distance = Geolocator.distanceBetween(
      point.lat,
      point.lon,
      place.latitude,
      place.longitude,
    );
    if (distance < shortest) {
      shortest = distance;
      closest = place;
    }
  }
  final oceanOffset = (point.lon / 15).round().clamp(-12, 12);
  final oceanZone = oceanOffset == 0
      ? 'Etc/UTC'
      : 'Etc/GMT${oceanOffset > 0 ? '-' : '+'}${oceanOffset.abs()}';
  return Place(
    shortest < 120000
        ? closest!.name
        : (input.usesGps ? 'موقعي الحالي' : 'موقع مخصص'),
    zone == null ? '' : closest?.country ?? '',
    point.lat,
    point.lon,
    zone ?? oceanZone,
    usesGps: input.usesGps,
  );
}

String searchKey(String text) => text
    .toLowerCase()
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp('[\u0640\u064b-\u065f]'), '')
    .trim();

const countryLabels = {
  'EG': 'مصر',
  'SA': 'السعودية',
  'AE': 'الإمارات',
  'KW': 'الكويت',
  'QA': 'قطر',
  'OM': 'عُمان',
  'BH': 'البحرين',
  'JO': 'الأردن',
  'PS': 'فلسطين',
  'LB': 'لبنان',
  'SY': 'سوريا',
  'IQ': 'العراق',
  'YE': 'اليمن',
  'MA': 'المغرب',
  'DZ': 'الجزائر',
  'TN': 'تونس',
  'LY': 'ليبيا',
  'SD': 'السودان',
  'TR': 'تركيا',
  'GB': 'بريطانيا',
  'FR': 'فرنسا',
  'DE': 'ألمانيا',
  'US': 'الولايات المتحدة',
  'CA': 'كندا',
  'AU': 'أستراليا',
  'NZ': 'نيوزيلندا',
  'IT': 'إيطاليا',
  'NO': 'النرويج',
  'SE': 'السويد',
  'ES': 'إسبانيا',
  'PK': 'باكستان',
  'IN': 'الهند',
  'ID': 'إندونيسيا',
  'MY': 'ماليزيا',
  'JP': 'اليابان',
  'CN': 'الصين',
  'SG': 'سنغافورة',
  'IR': 'إيران',
  'RU': 'روسيا',
};
