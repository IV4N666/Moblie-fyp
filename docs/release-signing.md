# Android Release Signing (one-time setup)

Android only installs an update over an existing app if both are signed with the **same key**. Without this setup, CI signs every build with a new temporary debug key, so people you share the app with must uninstall the old version before installing a new one (and lose their saved history).

Do this once, before sharing the app widely.

## 1. Create an upload keystore

You need `keytool`, which comes with any Java JDK or with Android Studio (`C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe`).

```
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Choose a strong password and remember the alias (`upload`).

**Back up `upload-keystore.jks` and the passwords somewhere safe. If you lose them, existing users can never receive updates. Never commit the keystore to Git.**

## 2. Add four GitHub secrets

GitHub → repository **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | The keystore file encoded as Base64 (see below) |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | Key password (same as the keystore password if you did not set a separate one) |

Encode the keystore on Windows (PowerShell) and copy it to the clipboard:

```
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
```

On macOS/Linux: `base64 -i upload-keystore.jks | pbcopy` (macOS) or `base64 -w0 upload-keystore.jks` (Linux).

## 3. Run the workflow

When the secrets exist, `tool/ci/configure_android_signing.py` switches the release build to your key. The workflow shows a warning if the secrets are missing. Secrets are masked in logs and the keystore is written only to the runner's temporary folder.

Note: the app ID is `com.iv4n666.wifi_guardian_app`. Older test builds used `com.example.wifi_guardian_app` and must be uninstalled once.
