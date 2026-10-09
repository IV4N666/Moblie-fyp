# 🛡️ Wi-Fi Security Guardian

A standalone, non-technical friendly mobile application built with Flutter that detects all connected devices on your local Wi-Fi, computes a transparent **0–100 Security Hygiene Score**, identifies vulnerable open services, and provides **plain-English step-by-step interactive remediation checklists**, **Isolation Forest anomaly detection (unsupervised ML + expert rules)**, and **exportable audit reports**.

---

## 📥 Download & Install

| Official Release | Download | Scan to Download (QR Code) |
| :---: | :---: | :---: |
| [![GitHub Release](https://img.shields.io/github/v/release/IV4N666/Moblie-fyp?style=for-the-badge&logo=github&color=2e7d32)](https://github.com/IV4N666/Moblie-fyp/releases/latest) | [![Download](https://img.shields.io/badge/Download-Android%20%26%20Windows-6D4C41?style=for-the-badge&logo=github)](https://github.com/IV4N666/Moblie-fyp/releases/latest) | <img src="download_qr_code.png" width="130" alt="Scan to open the latest release"> |

Every release contains an Android APK and a Windows zip. Each push to `main` publishes a release named after `version:` in `pubspec.yaml`.

### 📱 Android (7.0 or newer)

1. On your phone, open the [latest release](https://github.com/IV4N666/Moblie-fyp/releases/latest) and download `Wi-Fi-Security-Guardian-v….apk`.
2. Open the file. When asked, allow **Install unknown apps** for your browser or file manager.
3. Connect to your Wi-Fi, open the app and tap **Scan Connected Devices** (or the graduation-cap icon for **Demo Mode**).

If you installed an early test build (app ID `com.example.wifi_guardian_app`), uninstall it first.

Phones warn about apps downloaded outside Google Play. To share without this warning, publish through Google Play testing: see [docs/google-play.md](docs/google-play.md).

### 💻 Windows 10 / 11 (64-bit)

1. Download `Wi-Fi-Security-Guardian-Windows-v….zip` from the [latest release](https://github.com/IV4N666/Moblie-fyp/releases/latest).
2. Extract the whole zip to a folder (keep the `.exe`, the `.dll` files and the `data` folder together).
3. Run `WiFiSecurityGuardian.exe`.
4. If Windows SmartScreen says "Windows protected your PC", click **More info → Run anyway** (the app is not code-signed).
5. If Windows Firewall asks, allow access on **Private networks** so device discovery (UPnP) works.

### 🔒 Privacy & Responsible Use

- Everything stays on your device: scan results, history and device names are never uploaded. The app only talks to devices on your own local network. Full [privacy policy](docs/privacy-policy.md).
- Only scan networks you own or have permission to test. The custom port scanner only accepts private (local) addresses.
- The score reflects exposed services. It does not check passwords, firmware versions or Wi-Fi encryption, so a high score is not a guarantee of safety.

---

## ✨ Key Features

1. **Zero External Tools & No Root Required:**
   - Runs 100% in standard mobile user space via asynchronous socket sweeps and local service discovery.
   - Requires no terminal tools, no nmap, and no device rooting/jailbreaking.

2. **Full Device Discovery & Categorization:**
   - Discovers gateways/routers, smartphones, laptops, smart TVs, IoT sensors, network printers, and IP security cameras.
   - Real-time response latency measurement (ms), vendor detection heuristics, and reverse DNS.

3. **5-Tier Qualitative Risk Classification (Phase 1 Report Section 3.8):**
   - Exact mathematical deduction matching Table 3.5 & Table 4.10:
     - 🟢 **EXCELLENT (90–100)**: Protected & Optimal Security
     - 🟢 **GOOD (75–89)**: Minor Configuration Tweaks Needed
     - 🟡 **FAIR (60–74)**: Moderate Risk - Attention Recommended
     - 🟠 **POOR (40–59)**: Elevated Risk - Remediation Required
     - 🔴 **CRITICAL (0–39)**: Critical Threat Exposure - Immediate Action
   - Historical audit tracking: displays score improvement trends between scans.

4. **Expanded Vulnerability Knowledge Base & Interactive Fix Guides:**
   - **Telnet (Port 23):** Why unencrypted credentials are a danger + 3-step fix to switch to SSH.
   - **Mirai / IoT Alternate Telnet (Port 2323):** Backdoor console mitigation for cheap smart cameras and DVRs.
   - **Plaintext FTP (Port 21):** Plaintext file transfer risks + how to enforce SFTP/FTPS.
   - **Exposed Camera Video Streams (Port 554):** RTSP credentials and isolating cameras onto Guest Wi-Fi.
   - **UPnP / SSDP (Port 1900):** Preventing unauthorized firewall pinhole forwarding.
   - **Unencrypted MQTT Broker (Port 1883):** Securing smart home sensor feeds with TLS authentication.
   - **Remote Desktop / RDP (Port 3389):** Network Level Authentication (NLA) enforcement.
   - **HTTP Router Portal (Port 80/8080):** Enforcing HTTPS redirection on administration panels.
   - **SMB (Port 445):** Guidance on disabling vulnerable legacy SMBv1 protocols.
   - **RAW JetDirect Printing (Port 9100):** Restricting unauthenticated printer queues.
   - **Interactive Checklists:** Tap checkable step-by-step boxes directly within vulnerability cards to track fix progress.

5. **🎓 Viva / Presentation Demo Mode:**
   - Built-in simulation toggle on the dashboard loads a realistic 8-device home network scenario (vulnerable camera, Telnet router, smart TV, IoT hub, and safe devices).
   - Guarantees a seamless live demonstration for academic project presentations even if university Wi-Fi blocks LAN socket traffic (AP isolation).

6. **📄 Security Audit Report Generation:**
   - Generates a formatted, shareable Markdown and plain-text Network Audit Report containing the executive summary, connected device inventory table, risk breakdown, and prioritized action plan.
   - One-tap "Copy Markdown" button to paste into project documentation or send to stakeholders.

7. **Device Customization & Per-Host Re-Testing:**
   - Assign friendly custom aliases (e.g. "Living Room TV") and toggle "Trusted Device" status.
   - Single-device quick re-probe: verify if a patched port has closed without having to re-scan the entire 254-host subnet.

8. **Search & Quick Filters:**
   - Live search by device name, IP address, or manufacturer.
   - Filter chips: `All`, `Risky`, `Safe`, `Routers`, `Cameras`, `Smart Home IoT`.

---

## 📐 How the Score Is Calculated

Each risky service is scored with CVSS v3.1 (attacker on the same Wi-Fi), raised one level when it is attacked at scale in its default configuration, and deducted once per device: Critical −45, High −30, Medium −15, Low −5. The network score is 0.7 × the average device score + 0.3 × the lowest device score. Full method, port list and references: [docs/scoring-method.md](docs/scoring-method.md).

---

## 🛠️ Building From Source

GitHub Actions builds both apps automatically (`.github/workflows/build_apk.yml`). To build locally:

1. Install [Flutter](https://docs.flutter.dev/get-started/install) **3.22.x** (the version CI uses). For Windows builds you also need Visual Studio 2022 with "Desktop development with C++".
2. Generate the platform folders once (only `AndroidManifest.xml` is kept in the repository), then remove the sample test it creates:
   ```bash
   flutter create . --project-name wifi_guardian_app --org com.iv4n666 --platforms=android,windows
   rm test/widget_test.dart        # Windows: del test\widget_test.dart
   ```
3. Install dependencies and generate the app icons:
   ```bash
   flutter pub get
   dart run flutter_launcher_icons -f launcher_icons_android.yaml
   dart run flutter_launcher_icons -f launcher_icons_windows.yaml
   ```
4. Build:
   ```bash
   flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk
   flutter build windows --release  # build/windows/x64/runner/Release/
   ```

To sign Android releases with your own key (needed so people can update without uninstalling), follow [docs/release-signing.md](docs/release-signing.md).

---

## 🧪 Running the Tests

```
flutter analyze
flutter test
```

Unit tests cover the scoring formula, device classification, the Isolation Forest, report escaping and IP validation (`test/`). CI runs both before building the APK.

---

## 📂 Project Architecture

```
wifi_guardian_app/
├── lib/
│   ├── main.dart                          # Entrypoint (loads saved history, Material 3 theme)
│   ├── models/
│   │   ├── device_model.dart              # DiscoveredDevice, PortInfo, DeviceCategory, alias & trust
│   │   └── security_model.dart            # SecurityVulnerability, RiskLevel, NetworkAuditResult, FixStep
│   ├── services/
│   │   ├── anomaly_detection_service.dart # Isolation Forest + expert rules (hybrid anomaly score)
│   │   ├── app_settings_service.dart      # Normal/Expert mode, scan timeout & concurrency
│   │   ├── hidden_camera_service.dart     # Camera/video port signatures + active deep scan
│   │   ├── history_service.dart           # Persistent audit history, aliases & trusted devices
│   │   ├── isolation_forest.dart          # Dependency-free Isolation Forest (Liu et al., 2008)
│   │   ├── network_info_service.dart      # Wi-Fi IP, SSID, real gateway, RFC 1918 checks
│   │   ├── ping_service.dart              # TCP RTT, jitter & packet-loss diagnostics
│   │   ├── platform_support.dart          # Phone vs computer helpers (Android / Windows)
│   │   ├── report_export_service.dart     # Escaped Markdown & HTML audit reports
│   │   ├── scanner_service.dart           # Worker-pool TCP sweep, SSDP/UPnP discovery, demo network
│   │   ├── security_scoring_service.dart  # Device & network scores (average + weakest link)
│   │   ├── socket_probe.dart              # TCP probe: open / closed (host alive) / filtered
│   │   ├── vendor_lookup_service.dart     # Category & manufacturer heuristics (word matching)
│   │   └── vulnerability_db.dart          # Knowledge base with plain-English fix steps
│   └── ui/
│       ├── screens/                       # Dashboard, expert view, device detail, tools
│       └── widgets/                       # Report modal, score gauge, vulnerability card
├── test/                                  # Unit tests (run with `flutter test`)
├── docs/                                  # Scoring method, release signing, Windows readme
├── assets/icon/                           # App icon (Android adaptive + Windows)
├── tool/ci/                               # CI helper: Android release signing
├── android/app/src/main/AndroidManifest.xml
└── pubspec.yaml
```
