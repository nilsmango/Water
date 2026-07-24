# 7III Water

7III Water is an open-source foiling and water sports tracker for iPhone and Apple Watch. It records sessions in Apple Health and turns GPS, speed, heart-rate, wind, and foil-flight data into useful maps and statistics.

## Help make Water better

Water gets better when the people who use it help shape it.

- [Request a feature or report a bug](https://github.com/nilsmango/7III_Location_App/issues/new/choose)
- [Browse open issues](https://github.com/nilsmango/7III_Location_App/issues)
- Fork the project and open a pull request
- Point your AI coding assistant at this repository and ask it to help—but please review and test everything you submit

Ideas, design improvements, translations, bug fixes, tests, and new water-sport insights are all welcome. If you improve Water, please bring that improvement back to the community.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before sending your first pull request.

## What it does

- Tracks water sports on iPhone and Apple Watch
- Imports and exports GPX files, including sessions from Garmin and other watches
- Shows routes, speed, heart rate, wind, turns, jumps, time on foil, and individual flights
- Provides monthly, yearly, tag, location, and discipline statistics
- Keeps workout data on the user's device and in Apple Health

The App Store version is available from [project7iii.com/water](https://project7iii.com/water/).

## Building

Requirements:

- Xcode with the iOS 17.2 and watchOS 10.4 SDKs or newer
- An Apple development team for running HealthKit features on a physical device

Steps:

1. Clone the repository.
2. Duplicate `Config/Secrets.example.xcconfig` as `Config/Secrets.xcconfig`.
3. Add a Foildata API key if you need spot-submission features. The rest of the app can be explored without committing a key.
4. Open `7III Tracker.xcodeproj`.
5. Select the `7III Tracker` scheme and build.

Never commit `Config/Secrets.xcconfig`, signing credentials, personal workout data, or API keys.

## License

7III Water is licensed under the [Mozilla Public License 2.0](LICENSE).

You may use, study, modify, and distribute the code. When you distribute MPL-covered source files—or an executable built from modified MPL-covered files—you must keep those files and modifications available under the MPL 2.0. The license does not grant rights to the project7III name, 7III Water name, or their logos.

Copyright © 2024–2026 Simon Lang and contributors.
