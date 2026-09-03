# 🛡️ IoT Security Audit Report

- **Project ID:** FYP01-CS-T2610-885
- **Course:** CPT6314 Project I & II (2530 Term)
- **Target Network:** `Demo-SmartHome-WiFi` (`192.168.1.0/24`)
- **Gateway Router IP:** `192.168.1.1`
- **Auditor Device IP:** `192.168.1.200`
- **Timestamp:** 2026-09-03 14:35:00

---

## 📊 Executive Summary

| Metric | Value |
| :--- | :--- |
| **Total Devices Scanned** | 8 connected devices |
| **Overall Security Score** | **65.5 / 100 — FAIR** (Moderate Risk) |
| **Vulnerable Devices** | 6 devices (75% of network) |
| **Total Open Vulnerabilities** | 11 open risk services |
| **Highest Risk Device** | `192.168.1.100` (TP-Link IP Camera) — Score: 35/100 (CRITICAL) |

### Risk Level Distribution (5-Tier Model - Section 3.8)
- 🟢 **EXCELLENT (90–100):** 2 devices (25%)
- 🟢 **GOOD (75–89):** 1 device (12.5%)
- 🟡 **FAIR (60–74):** 3 devices (37.5%)
- 🟠 **POOR (40–59):** 1 device (12.5%)
- 🔴 **CRITICAL (0–39):** 1 device (12.5%)

---

## 📱 Device Discovery & Scan Results (Matching Figure 4.8)

| # | IP Address | MAC Address | Manufacturer / Name | Score | Risk Level | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | `192.168.1.1` | `70:4F:57:12:34:56` | TP-Link Router | 65/100 | **FAIR** | ⚠️ 2 Risks |
| 2 | `192.168.1.100` | `1C:61:FB:AA:BB:CC` | TP-Link Tapo IP Camera | 35/100 | **CRITICAL** | 🚨 3 Risks |
| 3 | `192.168.1.50` | `C0:3F:0E:DD:EE:FF` | Samsung Smart TV 65" | 100/100 | **EXCELLENT** | ✅ Clean |
| 4 | `192.168.1.120` | `48:4C:A8:11:22:33` | Huawei Smart IoT Hub | 65/100 | **FAIR** | ⚠️ 2 Risks |
| 5 | `192.168.1.75` | `D8:6C:02:AA:BB:11` | Belkin WeMo IoT Plug | 80/100 | **GOOD** | ⚠️ 1 Risk |
| 6 | `192.168.1.200` | `00:1A:A8:AA:BB:22` | Apple iPhone (Local) | 100/100 | **EXCELLENT** | ✅ Clean |
| 7 | `192.168.1.101` | `B4:2E:99:11:22:33` | Home-Workstation-PC | 70/100 | **FAIR** | ⚠️ 2 Risks |
| 8 | `192.168.1.65` | `00:1B:A9:AA:BB:CC` | HP LaserJet Network Printer | 70/100 | **FAIR** | ⚠️ 2 Risks |

---

## 🔍 Detailed Device Assessments & Step-by-Step Fix Checklists

### Device 1: 192.168.1.1 — TP-Link Router
- **MAC:** `70:4F:57:12:34:56` | **Vendor:** TP-Link Technologies | **Score:** 65/100 (**FAIR**)
- **Open Ports:**
  - `Port 80` (HTTP): MEDIUM Risk (-20 pts)
  - `Port 8080` (HTTP-Alt): MEDIUM Risk (-15 pts)
- **Remediation Steps:**
  1. Access router management interface via browser.
  2. Under Administration > Security, enable "Redirect HTTP to HTTPS".
  3. Turn off secondary web port 8080.

### Device 2: 192.168.1.100 — TP-Link Tapo IP Camera
- **MAC:** `1C:61:FB:AA:BB:CC` | **Vendor:** TP-Link Technologies | **Score:** 35/100 (**CRITICAL**)
- **Open Ports:**
  - `Port 23` (Telnet): **CRITICAL Risk (-35 pts)**
  - `Port 80` (HTTP): MEDIUM Risk (-20 pts)
  - `Port 554` (RTSP Video): MEDIUM Risk (-10 pts)
- **Remediation Steps:**
  1. **URGENT:** Turn off Telnet service in camera web portal or advanced settings.
  2. Change default stream credentials (do not use admin/admin) and enforce RTSP authentication.
  3. Quarantine camera to a segregated Guest Wi-Fi network.

### Device 3: 192.168.1.50 — Samsung Smart TV
- **MAC:** `C0:3F:0E:DD:EE:FF` | **Vendor:** Samsung Electronics | **Score:** 100/100 (**EXCELLENT**)
- **Open Ports:** `443` (HTTPS), `8008` (Google Cast).
- **Status:** Compliant with baseline encryption standards.

### Device 4: 192.168.1.120 — Huawei Smart IoT Hub
- **MAC:** `48:4C:A8:11:22:33` | **Vendor:** Huawei Technologies | **Score:** 65/100 (**FAIR**)
- **Open Ports:**
  - `Port 80` (HTTP): MEDIUM Risk (-20 pts)
  - `Port 1883` (MQTT): MEDIUM Risk (-15 pts)
- **Remediation Steps:**
  1. Migrate MQTT broker to Port 8883 with TLS certificate encryption.
  2. Disable anonymous MQTT publishing/subscribing.

---

## 🤖 AI Behavioral Anomaly Detection (Section 5.2.2 Fulfillment)

| Device IP | Device Name | Anomaly Score | Confidence | Detected Baseline Deviation |
| :--- | :--- | :--- | :--- | :--- |
| `192.168.1.100` | TP-Link IP Camera | **0.85 (Critical)** | 94% | Active Telnet daemon on camera endpoint indicates Mirai botnet malware enrollment. |
| `192.168.1.120` | Huawei Smart Hub | **0.60 (Suspicious)** | 88% | Cleartext sensor telemetry broadcast on residential LAN. |
| `192.168.1.101` | Workstation PC | **0.50 (Suspicious)** | 75% | SMB and RDP listening without isolation on shared Wi-Fi. |

---

## 📋 Methodology & Standards Grounding
- **Discovery Engine:** Asynchronous RFC 793 TCP transport sweeps + IEEE OUI manufacturer resolution.
- **Port Catalogue:** 18 curated high-risk IoT ports defined in Phase 1 Report Table 3.5 & Table 4.10.
- **Scoring Model:** Deterministic additive penalty model derived from CVSS v3.1 qualitative severity ratings.
- **Remediation Grounding:** NIST SP 800-213 and CIS Network Hardening Benchmarks.
