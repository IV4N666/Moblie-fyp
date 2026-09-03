# 🛡️ Wi-Fi Security Guardian

A standalone, non-technical friendly mobile application built with Flutter that detects all connected devices on your local Wi-Fi, computes a transparent **0–100 Security Hygiene Score**, identifies vulnerable open services, and provides **plain-English step-by-step interactive remediation checklists**, **unsupervised AI behavioral anomaly detection**, and **exportable audit reports**.

---

## 📥 Quick Download & Installation (Android)

| Official Release | Direct APK Download | Scan to Download (QR Code) |
| :---: | :---: | :---: |
| [![GitHub Release](https://img.shields.io/badge/Release-v1.0.0-2e7d32?style=for-the-badge&logo=github)](https://github.com/IV4N666/Moblie-fyp/releases/tag/v1.0.0) | [![Direct APK](https://img.shields.io/badge/Download-APK%20(21.2MB)-6D4C41?style=for-the-badge&logo=android)](https://github.com/IV4N666/Moblie-fyp/releases/download/v1.0.0/Wi-Fi-Security-Guardian-v1.0.0.apk) | <img src="download_qr_code.png" width="130" alt="Scan to Download APK"> |

- **Direct Download Link:** [Wi-Fi-Security-Guardian-v1.0.0.apk](https://github.com/IV4N666/Moblie-fyp/releases/download/v1.0.0/Wi-Fi-Security-Guardian-v1.0.0.apk)
- **Releases Page:** [GitHub Releases (v1.0.0)](https://github.com/IV4N666/Moblie-fyp/releases/tag/v1.0.0)
- **Compatibility:** Android 7.0+ (ARM64真机、手机、平板及 64 位模拟器)

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

## 📱 How to Build the Standalone APK

### Prerequisites
- Install [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.0.0 or higher).
- Android Studio or VS Code with Flutter extension.

### Step-by-Step Instructions

1. **Open the project folder:**
   ```bash
   cd "Mobile FYP"
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
   - Open the app, connect to your home Wi-Fi, and tap **Scan Connected Devices** (or tap the graduation cap icon for **Demo Mode**).

---

## 📂 Project Architecture

```
wifi_guardian_app/
├── lib/
│   ├── main.dart                         # Material 3 entrypoint
│   ├── models/
│   │   ├── device_model.dart             # DiscoveredDevice, PortInfo, DeviceCategory, custom alias & trust
│   │   └── security_model.dart           # SecurityVulnerability, RiskLevel, NetworkAuditResult, FixStep
│   ├── services/
│   │   ├── history_service.dart          # Audit history, score deltas, and device alias/trust store
│   │   ├── network_info_service.dart     # Wi-Fi SSID, Subnet prefix & Gateway lookup
│   │   ├── report_export_service.dart    # Professional Markdown/Text audit report generator
│   │   ├── scanner_service.dart          # Concurrency-batched subnet socket sweeper, cancellation & demo generator
│   │   ├── security_scoring_service.dart # Point-deduction evaluation engine (0-100)
│   │   ├── vendor_lookup_service.dart    # Device categorization & manufacturer heuristics
│   │   └── vulnerability_db.dart         # Comprehensive knowledge base with plain-English fix steps
│   └── ui/
│       ├── screens/
│       │   ├── dashboard_screen.dart     # Live scan gauge, demo mode, search, filter chips & device browser
│       │   ├── device_detail_screen.dart # Detailed port & vulnerability inspections, rename, trust & live re-test
│       │   └── security_tips_screen.dart # Educational home Wi-Fi hardening guides
│       └── widgets/
│           ├── report_modal.dart         # Bottom sheet report viewer & one-tap markdown copy
│           ├── score_gauge.dart          # Animated circular health score indicator
│           └── vulnerability_card.dart   # Interactive remediation card with checkable fix steps
├── android/app/src/main/AndroidManifest.xml
├── ios/Runner/Info.plist
└── pubspec.yaml
```
