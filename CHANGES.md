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

The network score subtracted every penalty on every device from one 100. Any network with about five devices showing a web page on port 80 reached 0, and the demo network scored **0/100 CRITICAL** while `audit_report.md` documents it as FAIR.

New formula:

    device score  = 100 − sum of that device's penalties   (clamped 0–100)
    network score = 0.7 × average(device scores) + 0.3 × min(device scores)
                    − 10 if more than 3 unidentified devices

The average reflects overall hygiene. The weakest-link term stops one critical camera from being hidden by many clean phones (1 camera at 35 + 9 clean devices = 76, not 93.5). The demo network now scores **62 (FAIR)**.

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

## Still to do / known limitations

- **`audit_report.md` and `audit_report.html` were written by hand and do not match the app.** They show anomaly scores for the MQTT hub and the PC that no rule produces, a 65.5 score the code never computed, and "IEEE OUI manufacturer resolution", which is impossible on Android 10+ (apps cannot read MAC addresses). Regenerate them from the app (Demo Mode → Export → Copy) or correct them.
- Only a /24 network is scanned; the subnet mask is not used yet.
- `multicast_dns` is in pubspec.yaml but unused. Remove it, or use it to read mDNS device names (on Android this also needs a multicast lock).
- The package ID is `com.example.wifi_guardian_app`; the Play Store rejects `com.example`.
- `CardTheme` in `main.dart` must become `CardThemeData` if you upgrade beyond Flutter 3.22 (CI is pinned to 3.22).
- Running `flutter create --overwrite` in CI on every build is fragile. Run it once locally and commit the `android/` folder.
- Custom names and trust are keyed by IP address, so they do not follow a device whose DHCP address changes.
