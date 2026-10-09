# Publishing on Google Play (removes the "unsafe app" warning)

Phones warn about APKs downloaded from websites, especially new apps from unknown developers. Apps installed from Google Play do not show this warning.

## Fastest: internal testing (up to 100 testers, no review wait)

1. Create a Google Play developer account (one-time US$25): https://play.google.com/console
2. Set up release signing first: [release-signing.md](release-signing.md). CI then also builds `app-release.aab` (artifact **Wi-Fi-Security-Guardian-GooglePlay-AAB**).
3. In Play Console: **Create app** → **Testing → Internal testing** → create a release → upload `app-release.aab`. Opt in to **Play App Signing** when asked.
4. Add testers' Google account emails, then send them the opt-in link. They install from the Play Store with no warning.

## Public release (personal accounts)

New personal accounts must first run a **closed test with at least 12 testers for 14 days in a row**, then apply for production access.

## Store forms you will be asked to fill in

- **Privacy policy URL:** https://github.com/IV4N666/Moblie-fyp/blob/main/docs/privacy-policy.md
- **Data safety:** no data collected, no data shared.
- **Permissions:** location is used only to read the Wi-Fi name.

## Every new upload

Increase the number after `+` in `version:` in `pubspec.yaml` (e.g. `1.1.0+2` → `1.1.0+3`). Google Play rejects a bundle with a version code it has already seen.
