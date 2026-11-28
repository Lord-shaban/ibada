<p align="center">
  <img src="assets/materials/ibada-icon.png" alt="Ibada app icon" width="88" height="88">
</p>

<h1 align="center">Ibada</h1>

<p align="center">Offline prayer times, adhan alerts, daily adhkar, and a tasbeeh counter.</p>

<p align="center">
  <a href="https://github.com/Lord-Labs/ibada/releases/latest/download/Ibada.apk"><img src="https://img.shields.io/badge/Download-Android_APK-285D46?logo=android&amp;logoColor=white" alt="Download the Android APK"></a>
  <a href="#development"><img src="https://img.shields.io/badge/Built_with-Flutter-286285?logo=flutter&amp;logoColor=white" alt="Built with Flutter"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-5B6470?logo=opensourceinitiative&amp;logoColor=white" alt="MIT license"></a>
</p>

<p align="center">
  <a href="https://ibada.lordlabs.tech/">Website</a> ·
  <a href="https://github.com/Lord-Labs/ibada/releases/latest">Release notes</a> ·
  <a href="#screenshots">Screenshots</a> ·
  <a href="#development">Development</a>
</p>

Ibada is a free, open-source app with an Arabic interface. Prayer calculations, city search, and daily devotion tools work offline. The app stores settings and progress on the device and contains no ads.

## Screenshots

<p align="center">
  <img src="docs/screenshots/today.webp" width="220" alt="Today screen with the next prayer, countdown, and weekly schedule entry">
  <img src="docs/screenshots/adhkar-reader.webp" width="220" alt="Adhkar reader with a progress bar and repetition controls at the bottom">
  <img src="docs/screenshots/tasbeeh.webp" width="220" alt="Dark-mode tasbeeh counter with a bead progress indicator, count button, and undo">
</p>

## Features

| Feature | What you can do |
| --- | --- |
| Prayer times | Find your city in the offline directory, use GPS, or enter coordinates. See the next prayer and browse the week. |
| Calculation settings | Select a calculation method and Asr convention, adjust individual prayer times, and choose 12-hour or 24-hour time. |
| Adhan alerts | Enable alerts per prayer, choose one of three bundled adhan clips, or import a sound and alert image. |
| Daily adhkar | Read morning, evening, post-prayer, and bedtime remembrances. Jump to a specific dhikr and pick up where you left off. |
| Tasbeeh counter | Count freely or set a goal of 33 or 99, see progress, and undo an accidental tap. |

## Download for Android

Ibada supports **Android 8 or later**. [Download the latest APK](https://github.com/Lord-Labs/ibada/releases/latest/download/Ibada.apk)

1. Open the APK from your downloads. Android may ask you to allow installation from the source you used.
2. Open Ibada and follow the prompts to grant location, notification, and alarm permissions as required by your Android version.
3. Ibada uses your current location to calculate prayer times. You can change the city and try a test alert in Settings.

## How prayer times work

Ibada calculates prayer times from your coordinates, local date, time zone, and selected method. Your local mosque or published timetable may use different conventions. Use per-prayer minute adjustments to align the app with that timetable.

At high latitudes, Ibada applies your selected rule when twilight is absent. If there is no sunrise or sunset, it uses the nearest latitude that can be calculated and marks the times as estimates.

The app bundles the IANA time zone database and periodically checks for updates while online. It keeps the latest valid data on your device for offline use.

## Alerts by platform

| Platform | How alerts work |
| --- | --- |
| Android 8+ | Local notifications support adhan audio and an optional full-screen lock-screen alert. Exact timing and full-screen display depend on system permissions. |
| iOS 15–25 | Up to 60 upcoming local notifications can be scheduled when notifications are allowed. A custom image can appear in an expanded notification. |
| iOS 26+ | With AlarmKit permission, Ibada schedules up to 25 upcoming system alarms, followed by up to 60 local notifications if allowed. Local notifications are the fallback when AlarmKit is unavailable. |

Ibada refreshes the schedule when you open the app and when the operating system allows background updates. On Android, it also reschedules after a reboot or a clock change. The device must be powered on, and operating system sound and background settings can affect delivery.

## Development

Use Flutter with Dart 3.12 or later. Android builds need the Android SDK and JDK 17. iOS builds with AlarmKit need Xcode 26.

Download Thmanyah Sans and place `thmanyahsans-Regular.otf`, `thmanyahsans-Medium.otf`, and `thmanyahsans-Bold.otf` in `assets/fonts/`. [Thmanyah Fonts](https://font.thmanyah.com/)

On Windows, build Android from an ASCII-only path such as `C:\src\ibada`.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

To build the Android APK, run `flutter build apk --release`. The default build uses development signing. Store distribution requires a distribution signing configuration.

| Path | Contents |
| --- | --- |
| [`lib/`](lib/) | Flutter screens, prayer calculations, and local storage |
| [`android/`](android/) and [`ios/`](ios/) | Native alarm, notification, and platform integrations |
| [`assets/data/`](assets/data/) | Bundled city directory and time zone data |
| [`test/`](test/) | Prayer-time and interface tests |
| [`website/`](website/) | Arabic download site hosted on Vercel |

The website uses `thmanyahsans-Regular.woff2`, `thmanyahsans-Bold.woff2`, and `thmanyahserifdisplay-Regular.woff2` in `website/assets/`. Run `python -m http.server 8000 --directory website` to serve it locally.

Git exports omit these separately supplied fonts. For a Vercel deployment from a Git export, copy all three files into its `website/assets/` directory before uploading it. After deployment, check that the browser successfully loads all three fonts on the download page.

## Contributing

When reporting a problem, include your Ibada version, device, and operating system. For a prayer-time discrepancy, include the city, date, calculation method, and the timetable you compared it with. [Report an issue](https://github.com/Lord-Labs/ibada/issues)

## License and credits

Ibada's original source code is available under the MIT License. Fonts, data, and bundled recordings have their own licenses. [MIT License](LICENSE)

- Prayer calculations use Adhan Dart. Umm al-Qura's Ramadan Isha adjustment uses Hijri data. [Adhan Dart](https://pub.dev/packages/adhan_dart) · [hijri_core](https://pub.dev/packages/hijri_core)
- The offline city directory uses processed GeoNames data under CC BY 4.0. [GeoNames](https://www.geonames.org/export/) · [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- Civil time uses the IANA Time Zone Database through the Dart timezone package. [IANA Time Zone Database](https://www.iana.org/time-zones) · [Dart timezone](https://github.com/dart-lang/labs/tree/main/pkgs/timezone)
- Time zone boundaries use OpenStreetMap data processed by Timezone Boundary Builder. [OpenStreetMap contributors](https://www.openstreetmap.org/copyright) · [Timezone Boundary Builder](https://github.com/evansiroky/timezone-boundary-builder) · [timezone_finder](https://pub.dev/packages/timezone_finder)
- The app and website use Thmanyah Sans and Thmanyah Serif Display. [Thmanyah Fonts](https://font.thmanyah.com/) · [Font licenses](https://font.thmanyah.com/licenses)

### Adhan recordings

The bundled clips are short excerpts from the starts of the recordings. They were normalized and converted for offline playback.

| Recording | Creator | License |
| --- | --- | --- |
| [Prophet's Mosque adhan](https://commons.wikimedia.org/wiki/File:33937_ejaz215_call-to-prayer-from-the-prophet-s-mo.ogg) | ejaz215 | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| [Adam's adhan](https://commons.wikimedia.org/wiki/File:Beautiful_adhan.ogg) | Adam-synagda | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| [Asim Javed's adhan](https://archive.org/details/icr-friday-prayer-2nd-adhan-17th-may-2024-9th-dhul-qadah-1445-by-asim-javed) | Asim Javed | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
