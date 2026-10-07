# Scoring Method

How Wi-Fi Security Guardian decides which ports to scan, how many points each finding costs, and how device and network scores are calculated. `test/scoring_method_test.dart` checks every entry in the knowledge base against these rules.

## 1. Which ports are scanned

A port is scored only if it meets all of these criteria:

1. **Common on home networks** – found on routers, cameras, TVs, smart-home hubs or computers.
2. **A recognised IoT weakness** – matches OWASP IoT Top 10 (2018) I1 *Weak, Guessable, or Hardcoded Passwords*, I2 *Insecure Network Services* or I7 *Insecure Data Transfer and Storage* [2].
3. **Against the consumer IoT baseline** – conflicts with ETSI EN 303 645 provision 5.1-1 (no universal default passwords) or 5.6-1 (disable unused network services) [3].
4. **Detectable and fixable** – visible to a TCP connect scan from a phone or PC, and fixable by a home user.

UDP-only services (TFTP 69, SNMP 161, mDNS 5353, CoAP 5683) are not scored because a TCP scan cannot see them. UPnP is detected with an SSDP query and scored only on a router that advertises an Internet Gateway Device.

Ports scanned only to **identify** devices (0 points): 22 SSH, 443 HTTPS, 7000 AirPlay, 8008 Google Cast, 62078 iPhone/iPad sync.

## 2. How a penalty is calculated

**Step 1 – CVSS v3.1 base score.** Each service's typical weakness is written as a CVSS v3.1 vector and scored with the official equations [1] (`lib/models/cvss.dart`). The Attack Vector is always **Adjacent (AV:A)**, because the attacker must already be on the same Wi-Fi. The score is mapped to the FIRST severity bands: Low 0.1–3.9, Medium 4.0–6.9, High 7.0–8.9, Critical 9.0–10.0.

**Step 2 – Threat adjustment.** FIRST states that CVSS measures severity, not risk [1]. A service is therefore **raised one level** when there is documented, large-scale automated exploitation of the service *in its default configuration*. Exploits that need an unpatched system (BlueKeep, EternalBlue) do not raise the level, because a port scan cannot tell whether a system is patched.

**Step 3 – Points by level.** Points are calibrated to the five security tiers, so one finding moves a perfect device (100) into the matching tier:

| Level | Points | A perfect device with only this finding |
| --- | --- | --- |
| Critical | 45 | 55 → POOR |
| High | 30 | 70 → FAIR |
| Medium | 15 | 85 → GOOD |
| Low | 5 | 95 → EXCELLENT |

Two Critical findings give 10 (CRITICAL tier).

**Rules for counting**

- The same weakness on several ports counts **once** per device (Telnet on 23 and 2323; web admin on 80, 8080 and 8888).
- A web port that only **redirects to HTTPS** is not penalised (checked with an HTTP request).

## 3. Scored ports

| Port | Service | Typical weakness | CVSS vector (AV:A) | Base | Threat adjustment | Level | Points |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 23, 2323 | Telnet | Cleartext login, default passwords | AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H | 8.8 | Mirai botnet [4] | Critical | 45 |
| 5555 | Android Debug Bridge | Root shell without authentication | AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H | 8.8 | ADB.Miner worm [5] | Critical | 45 |
| 27017 | MongoDB | No authentication in older defaults | AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H | 8.8 | 2017 ransom wave [6] | Critical | 45 |
| 6379 | Redis | Often run without a password | AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H | 8.8 | – | High | 30 |
| 3389 | Remote Desktop | Full control after login | AC:H/PR:N/UI:N/S:U/C:H/I:H/A:H | 7.5 | – (BlueKeep needs unpatched Windows [7]) | High | 30 |
| 5900 | VNC | Full control, often unencrypted | AC:H/PR:N/UI:N/S:U/C:H/I:H/A:H | 7.5 | – | High | 30 |
| 80, 8080, 8888 | Web admin page (no HTTPS redirect) | Cleartext admin login | AC:H/PR:N/UI:R/S:U/C:H/I:H/A:H | 7.1 | – | High | 30 |
| 3306, 5432 | MySQL / PostgreSQL | Cleartext login, password guessing | AC:H/PR:N/UI:N/S:U/C:H/I:H/A:N | 6.8 | – | Medium | 15 |
| 554 | RTSP camera stream | Video without a password | AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N | 6.5 | – | Medium | 15 |
| 21 | FTP | Cleartext password and files | AC:H/PR:N/UI:R/S:U/C:H/I:H/A:N | 6.4 | – | Medium | 15 |
| 1900 | UPnP IGD (router) | Any device can open firewall ports | AC:L/PR:N/UI:N/S:C/C:L/I:L/A:N | 6.1 | – (see CallStranger [8]) | Medium | 15 |
| 1883 | MQTT | No TLS, often no authentication | AC:L/PR:N/UI:N/S:U/C:L/I:L/A:N | 5.4 | – | Medium | 15 |
| 445 | SMB file sharing | Shares readable on the network | AC:H/PR:N/UI:N/S:U/C:H/I:N/A:N | 5.3 | – (EternalBlue needs unpatched Windows) | Medium | 15 |
| 9100 | Raw printing | Printing without authentication | AC:L/PR:N/UI:N/S:U/C:N/I:L/A:N | 4.3 | – | Medium | 15 |

18 ports, 15 distinct weaknesses.

## 4. Device and network score

    device score  = max(0, 100 − sum of penalties, one per weakness)
    network score = 0.7 × average device score + 0.3 × lowest device score
                    − 10 if more than 3 unidentified devices

| Score | Tier |
| --- | --- |
| 90–100 | EXCELLENT |
| 75–89 | GOOD |
| 60–74 | FAIR |
| 40–59 | POOR |
| 0–39 | CRITICAL |

**Demo network:** device scores 70, 10, 100, 55, 70, 100, 55, 55 → average 64.4, lowest 10 → **48 (POOR)**.

## 5. Limitations

- The method scores *exposed services*, not passwords, firmware versions or Wi-Fi encryption. A high score means no risky services were found, not that the network is guaranteed safe.
- CVSS vectors describe the *typical* weakness of each service; a specific device may be better or worse configured.
- The threat adjustment depends on published evidence; Redis is not raised because no source was cited here.

## References

1. FIRST. *Common Vulnerability Scoring System v3.1: Specification Document.* https://www.first.org/cvss/
2. OWASP. *Internet of Things Top 10 (2018).* https://owasp.org/www-project-internet-of-things/
3. ETSI. *EN 303 645 V2.1.1 (2020-06): Cyber Security for Consumer Internet of Things: Baseline Requirements.*
4. Antonakakis, M. et al. "Understanding the Mirai Botnet." *26th USENIX Security Symposium*, 2017, pp. 1093–1110. https://www.usenix.org/system/files/conference/usenixsecurity17/sec17-antonakakis.pdf
5. Netlab 360. "Early Warning: ADB.Miner, a Mining Botnet Utilizing Android ADB, Is Now Rapidly Spreading." 2018. https://blog.netlab.360.com/early-warning-adb-miner-a-mining-botnet-utilizing-android-adb-is-now-rapidly-spreading-en/
6. Krebs, B. "Extortionists Wipe Thousands of Databases, Victims Who Pay Up Get Stiffed." *Krebs on Security*, January 2017. https://krebsonsecurity.com/2017/01/extortionists-wipe-thousands-of-databases-victims-who-pay-up-get-stiffed/
7. CISA. *Alert AA19-168A: Microsoft Operating Systems BlueKeep Vulnerability.* 2019. https://us-cert.cisa.gov/ncas/alerts/AA19-168A
8. CERT/CC. *Vulnerability Note VU#339275 (CallStranger, CVE-2020-12695).* 2020. https://www.kb.cert.org/vuls/id/339275
