# 🛡️ Wi-Fi Security Guardian

A standalone, non-technical friendly mobile application built with Flutter that detects all connected devices on your local Wi-Fi, computes a transparent **0–100 Security Hygiene Score**, identifies vulnerable open services, and provides **plain-English step-by-step remediation checklists**.

---

## ✨ Key Features

1. **Zero External Tools & No Root Required:**
   - Runs 100% in standard mobile user space via asynchronous socket sweeps and local service discovery.
   - Requires no terminal tools, no nmap, and no device rooting/jailbreaking.

2. **Full Device Discovery & Categorization:**
   - Discovers gateways/routers, smartphones, laptops, smart TVs, IoT sensors, network printers, and IP security cameras.
   - Real-time response latency measurement (ms).

3. **0–100 Security Score Gauge:**
   - Color-coded security rating:
     - 🟢 **85–100**: Protected & Safe
     - 🟡 **70–84**: Minor Tweaks
     - 🟠 **50–69**: Needs Attention
     - 🔴 **0–49**: High Risk / Action Required

4. **Plain-English Vulnerability & Fix Guides:**
   - **Telnet (Port 23):** Why unencrypted credentials are a danger + 3-step fix to switch to SSH.
   - **FTP (Port 21):** Plaintext file transfer risks + how to enforce SFTP.
   - **HTTP Router Portal (Port 80/8080):** How to enable HTTPS redirection on your router.
   - **Exposed RTSP Camera Streams (Port 554):** How to isolate cameras onto a Guest Wi-Fi network.
   - **SMB (Port 445):** Guidance on disabling vulnerable legacy SMBv1 protocols.

5. **Wi-Fi Hardening Tips Screen:**
   - Practical, non-technical advice for home Wi-Fi owners (Guest network isolation, WPA3 upgrades, disabling UPnP).

---

## 📱 How to Build the Standalone APK

### Prerequisites
- Install [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.0.0 or higher).
- Android Studio or VS Code with Flutter extension.

### Step-by-Step Instructions

1. **Open the project folder:**
   ```bash
   cd wifi_guardian_app
   ```

2. **Fetch all dependencies:**
   ```bash
   flutter pub get
   ```

3. **Build the Standalone APK:**
   ```bash
   flutter build apk --release
   ```
   The resulting standalone installer will be located at:
   `build/app/outputs/flutter-apk/app-release.apk`

4. **Install on any Android phone:**
   - Transfer `app-release.apk` to your phone via USB, Google Drive, or email.
   - Tap the APK file on your phone and select **Install**.
   - Open the app, connect to your home Wi-Fi, and tap **Scan Connected Devices**.

---

## 📂 Project Architecture

```
wifi_guardian_app/
├── lib/
│   ├── main.dart                         # Material 3 entrypoint
│   ├── models/
│   │   ├── device_model.dart             # DiscoveredDevice, PortInfo, DeviceCategory
│   │   └── security_model.dart           # SecurityVulnerability, RiskLevel, NetworkAuditResult
│   ├── services/
│   │   ├── network_info_service.dart     # Wi-Fi SSID, Subnet prefix & Gateway lookup
│   │   ├── scanner_service.dart          # Concurrency-batched subnet socket sweeper
│   │   ├── security_scoring_service.dart # Point-deduction evaluation engine (0-100)
│   │   ├── vulnerability_db.dart         # Knowledge base with plain-English fix steps
│   │   └── vendor_lookup_service.dart    # Device categorization heuristics
│   └── ui/
│       ├── screens/
│       │   ├── dashboard_screen.dart     # Live scan gauge & device browser
│       │   ├── device_detail_screen.dart # Detailed port & vulnerability inspections
│       │   └── security_tips_screen.dart # Educational home Wi-Fi hardening guides
│       └── widgets/
│           ├── score_gauge.dart          # Circular health score indicator
│           └── vulnerability_card.dart   # Interactive remediation card
├── android/app/src/main/AndroidManifest.xml
├── ios/Runner/Info.plist
└── pubspec.yaml
```
