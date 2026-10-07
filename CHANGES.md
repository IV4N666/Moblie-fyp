# Code Review Changes (v1.1.0)

This file lists what was changed in the review, why, and what to update in the FYP report.

## 1. Scanning accuracy

**Hosts with no open ports were invisible.** A device only counted as present if one of the probed ports was *open*. Phones, laptops and many TVs have no open ports, so they were never listed. A *closed* port still proves the device exists, because its TCP stack answers with a reset ("connection refused"). The new `socket_probe.dart` classifies every connection attempt as open, closed (host alive) or filtered, using the OS error code (ECONNREFUSED 111 on Android, 61 on iOS) rather than English error text.

**UDP services were probed with TCP.** TFTP 69, SNMP 161, UPnP 1900, mDNS 5353 and CoAP 5683 are UDP services, but `Socket.connect` only speaks TCP, so they could never be detected. They were removed from the TCP list. UPnP is now detected properly with an SSDP M-SEARCH broadcast, and only a router advertising an *Internet Gateway Device* receives the UPnP penalty (TVs and speakers announcing themselves are normal). Port 62078 was added to recognise iPhones/iPads.

**Scheduling.** Fixed batches of 25 hosts waited for the slowest host each round. A pool of worker tasks now pulls the next IP as soon as one finishes. Timeout (default 300 ms) and concurrency (24 hosts) come from `AppSettingsService`, which existed before but was never used.

**Smaller scanner fixes.** Devices are sorted by numeric IP (text sorting put .100 before .2). "Response time" is now the fastest TCP reply, not the total probe time (which was always about the timeout). Reverse-DNS lookups only run for hosts that answered.

## 2. Network detection (`network_info_service.dart`)

- Operator-precedence bug: `!a && b || c || d` made the private-address filter accept public addresses.
- `startsWith('172.')` matched public 172.x addresses. Replaced by a proper RFC 1918 check (`isPrivateIpv4`).
- The interface fallback could pick the mobile-data interface (carriers often use 10.x). Cellular and VPN interfaces are now skipped.
- With no Wi-Fi, the app pretended to be on 192.168.1.105 and scanned a network that did not exist. It now reports "not connected" and the dashboard asks the user to connect or use Demo Mode.
- The gateway was always guessed as `.1`. It now uses `getWifiGatewayIP()` from network_info_plus.

## 3. Device classification (`vendor_lookup_service.dart`)

- `ip.endsWith('.1')` marked .11, .21, .101, .201 (and .254) as routers. Only the gateway reported by the OS is the router now.
- Substring matching caused false positives ("mike-laptop" → Xiaomi via "mi", "spring-server" → Ring camera). Short keywords now match whole words in the hostname, or the start/end of a word.
- SSH (22) alone no longer means "computer", because routers, NAS boxes and Raspberry Pis expose it too.

## 4. Scoring (`security_scoring_service.dart`)

The network score subtracted every penalty on every device from one 100. Any network with about five devices showing a web page on port 80 reached 0, and the demo network scored **0/100 CRITICAL** while the hand-written audit report described it as FAIR.

New formula:

    device score  = 100 − sum of that device's penalties   (clamped 0–100)
    network score = 0.7 × average(device scores) + 0.3 × min(device scores)
                    − 10 if more than 3 unidentified devices

The average reflects overall hygiene. The weakest-link term stops one critical camera from being hidden by many clean phones (1 camera at 10 + 9 clean devices = 67, not 91). With the penalties from section 13, the demo network scores **48 (POOR)**.

**Update Section 3.8 / Table 3.5 of the report to describe this formula.**

## 5. Anomaly detection (`isolation_forest.dart`, `anomaly_detection_service.dart`)

The screen said "AI / Unsupervised ML", but the code contained only fixed if-rules with invented confidence values (0.94, 0.91, ...). It is now a genuine hybrid:

1. **Isolation Forest** (Liu, Ting & Zhou, 2008), implemented without dependencies. It is trained on the devices of *the current network*, using each device's open ports as a binary feature vector. Score s(x) = 2^(−E[h(x)]/c(n)): 0.5 = typical, close to 1 = isolated quickly (unusual). 100 trees, fixed seed so the same network always gets the same result. Needs at least 4 devices.
2. **Expert rules** for known-bad combinations a statistic cannot judge (Telnet on a smart plug or camera, databases on IoT hardware, UPnP IGD on the router). A camera-with-Telnet rule was added.

Combination: `anomaly = 1 − (1 − rules) × (1 − 0.4 × isolation)`. Statistical rarity alone is capped at 0.4, because unusual does not automatically mean dangerous. Each device card now shows the rule part and the isolation score so the result can be explained.

## 6. Hidden camera check

The "deep scan" button waited 600 ms and re-ran the same analysis without touching the network. `probeHostForCameraPorts` was never called, and ports 37777/8000 were "checked" but never probed. The deep scan now actively probes every device on 554, 8554, 8000, 37777, 1935 and 8081. The "all clear" wording no longer claims the room is safe: it explains that cameras on mobile data, another network or a memory card cannot be seen.

## 7. Device details and the dashboard

- **Re-check reported offline devices as "fully secured 🎉".** `recheckHost` now returns `null` when the device does not answer, and the app says the fix could not be confirmed.
- **Re-check in Demo Mode** probed the real network, so the demo vulnerabilities disappeared during a presentation. It is now disabled in Demo Mode with an explanation.
- **Rename, trust and re-check changes never reached the dashboard**, and saved names were never read back. A callback now updates the list and recalculates the score, and saved names/trust are re-applied after every scan.
- An empty name now resets a device to its detected name.
- The scan is wrapped in try/catch (an error used to leave the spinner running forever), and `mounted` is checked after every await.

## 8. History (`history_service.dart`)

History, names and trusted devices were kept in memory only, so the "score trend" was lost every time the app closed. They are now saved with `shared_preferences` (last 50 audits). Demo scans and stopped (partial) scans are no longer recorded, and the trend compares scans of the same Wi-Fi only.

## 9. Security of exports

- **HTML report:** hostnames come from reverse DNS, which any device on the network controls. A device named `<script>…</script>` was inserted unescaped (stored XSS). All dynamic values are now HTML-escaped.
- **Markdown report:** `|` and `<`/`>` in names are escaped so tables do not break and raw HTML is not rendered.
- **CSV export:** quotes were not escaped (the demo device `Samsung Smart TV 65"` broke the file), and names starting with `=`, `+`, `-` or `@` would run as spreadsheet formulas. Both fixed.
- **Custom port scanner** accepted any IP, including Internet hosts. It is now limited to private (RFC 1918) addresses. Stop now really stops and no longer shows "finished".

## 10. Project and CI

- `analysis_options.yaml` added; `NetworkAuditResult.devices` typed as `List<DiscoveredDevice>` (removed casts).
- Unit tests in `test/` (scoring, classification, Isolation Forest, anomaly rules, report escaping, IP validation).
- CI runs `flutter analyze` and `flutter test` before building, keeps `test/` and `analysis_options.yaml` through the `flutter create --overwrite` step, and tags releases from `version:` in `pubspec.yaml` instead of overwriting `v1.0.0` every push. Version bumped to 1.1.0+2.
- README download links point to the latest release; QR code regenerated for that link.

## 11. Windows (PC) version

The app now also builds for Windows, so the same scanner runs on a phone and on a computer.

- CI has a second job (`build-windows`) that runs after the Android job passes. It generates the `windows/` folder, builds a release, and uploads `Wi-Fi-Security-Guardian-Windows-v<version>.zip` as an artifact and to the GitHub release.
- `network_info_service.dart` now ranks network adapters by name. Windows has virtual adapters with private addresses ("vEthernet (WSL)", VirtualBox, VMware, Docker); without this the app could scan a virtual network instead of the real one. A PC on a cable uses its Ethernet address.
- The location-permission request (only needed on phones to read the Wi-Fi name) is skipped on computers. Without a Wi-Fi name, a computer shows "Local Network".
- The device running the app is labelled "This Computer" and categorised as a computer on desktop.
- In a wide desktop window, content is limited to 760 px wide so the phone-style layout stays readable.
- New test: adapter ranking (Wi-Fi first, Ethernet second, virtual/VPN/mobile-data adapters never used).

## 12. Repository cleanup

Files and code that nothing used were removed, so the repository only holds what the app needs.

- `audit_report.md` and `audit_report.html` removed. They were written by hand and did not match the app: anomaly scores no rule produces, a 65.5 score the code never computed, and "IEEE OUI manufacturer resolution", which Android 10+ does not allow. The app generates the real report (Export → Copy).
- `ios/Runner/Info.plist` removed: the app is built for Android and Windows only, and no iOS project existed.
- `CHANGES.zh.md` removed (duplicate of this file in Chinese).
- Unused dependencies `multicast_dns` and `cupertino_icons` removed from `pubspec.yaml`.
- Dead code removed: unused settings (`enableVibration`, `setMode`, `updateSettings`), unused history getters, `RiskLevel.priority`, `getAllKnownVulnerabilities`, unused anomaly labels, and port names for UDP ports no longer probed over TCP.
- `*.patch` added to `.gitignore` so patch files used locally are never committed.

## 13. Scoring method based on CVSS v3.1 and published attacks

The old penalties had no documented basis and were inconsistent (HTTP was MEDIUM but cost as much as HIGH items; the LOW printer port cost as much as the MEDIUM camera stream). They are now derived by one rule, documented in `docs/scoring-method.md`:

1. Each service's typical weakness has a CVSS v3.1 vector with Attack Vector = Adjacent; the score is computed by `lib/models/cvss.dart` with the official equations.
2. The level is raised once when the service is attacked at scale in its default configuration (Mirai, ADB.Miner, the 2017 MongoDB ransom wave).
3. Points by level: Critical 45, High 30, Medium 15, Low 5, calibrated so one finding moves a perfect device into the matching tier.

Other changes:

- Port 5555 (Android Debug Bridge) added; UDP-only and 0-point entries removed from the knowledge base (18 scored ports, 15 weaknesses).
- The same weakness on several ports is deducted once (Telnet 23/2323; web admin 80/8080/8888).
- Web ports that only redirect to HTTPS are not penalised.
- Each finding shows its basis in the app and in the Markdown report (CVSS score, threat adjustment, points).
- New `test/scoring_method_test.dart` checks every knowledge-base entry against the method.
- The demo network now scores **48 (POOR)** instead of 62 (FAIR).

## Still to do / known limitations

- Only a /24 network is scanned; the subnet mask is not used yet.
- The package ID is `com.example.wifi_guardian_app`; the Play Store rejects `com.example`.
- `CardTheme` in `main.dart` must become `CardThemeData` if you upgrade beyond Flutter 3.22 (CI is pinned to 3.22).
- Running `flutter create --overwrite` in CI on every build is fragile. Run it once locally and commit the `android/` folder.
- Custom names and trust are keyed by IP address, so they do not follow a device whose DHCP address changes.
