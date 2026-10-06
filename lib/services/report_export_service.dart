import 'dart:convert';
import '../models/device_model.dart';
import '../models/security_model.dart';
import 'security_scoring_service.dart';

class ReportExportService {
  /// Escapes text for HTML. Hostnames come from reverse DNS, which any
  /// device on the LAN controls: a device named `<script>...` would
  /// otherwise inject script into the exported report (stored XSS).
  static final _htmlEscape = const HtmlEscape().convert;

  /// Keeps device names from breaking Markdown table rows, and stops raw
  /// HTML in a device name from being rendered by Markdown viewers.
  static String _md(String? text) => (text ?? '')
      .replaceAll('|', r'\|')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll(RegExp(r'[\r\n]+'), ' ');

  static String _h(String? text) => _htmlEscape(text ?? '');

  /// The device-specific finding for [port], if any (falls back to "info").
  static SecurityVulnerability? _findingFor(DiscoveredDevice dev, int port) {
    for (final v in dev.vulnerabilities) {
      if (v.affectedPort == port) return v;
    }
    return null;
  }

  /// Generates a comprehensive, professional Markdown Network Security Audit Report
  static String generateMarkdownReport(NetworkAuditResult audit) {
    final buffer = StringBuffer();
    final dateStr = audit.scanTimestamp.toLocal().toString().split('.')[0];

    buffer.writeln('# 🛡️ IoT Security Audit Report');
    buffer.writeln();
    buffer.writeln('**Generated on:** $dateStr');
    buffer.writeln('**Target Network (SSID):** ${_md(audit.wifiSsid ?? "Unknown")}');
    buffer.writeln('**Subnet:** ${audit.subnet}.0/24');
    buffer.writeln('**Gateway Router IP:** ${audit.gatewayIp ?? "N/A"}');
    buffer.writeln('**Auditor Device IP:** ${audit.localIp}');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    // Executive Summary
    buffer.writeln('## 📊 Executive Summary');
    buffer.writeln();
    buffer.writeln('- **Overall Security Score:** **${audit.overallScore} / 100**');
    buffer.writeln('- **Risk Classification:** **${audit.scoreHealthRating}** (${audit.scoreDescription})');
    buffer.writeln('- **Total Devices Scanned:** ${audit.devices.length}');
    buffer.writeln('- **Vulnerable Devices:** ${audit.devices.where((d) => d.hasIssues).length}');
    buffer.writeln('- **Total Findings:** ${audit.totalFindingCount} (${audit.allIssues.length} distinct issue types)');
    buffer.writeln('  - Critical Risks: ${audit.criticalIssueCount}');
    buffer.writeln('  - High Risks: ${audit.highIssueCount}');
    buffer.writeln('  - Medium Risks: ${audit.mediumIssueCount}');
    buffer.writeln('  - Low Risks: ${audit.lowIssueCount}');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    // Device Inventory Table
    buffer.writeln('## 📱 Device Discovery & Scan Results');
    buffer.writeln();
    buffer.writeln('| # | IP Address | MAC Address | Manufacturer / Vendor | Score | Risk Level |');
    buffer.writeln('| :--- | :--- | :--- | :--- | :--- | :--- |');

    int counter = 1;
    for (final device in audit.devices) {
      final devScore = SecurityScoringService.calculateDeviceScore(device);
      final tier = SecurityTierExtension.fromScore(devScore);
      final mac = device.macAddress ?? 'N/A';
      buffer.writeln('| $counter | ${device.ip} | ${_md(mac)} | ${_md(device.vendor)} (${_md(device.displayName)}) | $devScore/100 | ${tier.displayName} |');
      counter++;
    }
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    // Detailed Device Assessments
    buffer.writeln('## 🔍 Detailed Device Assessments');
    buffer.writeln();

    final riskyDevices = audit.devices.where((d) => d.hasIssues).toList();

    if (riskyDevices.isEmpty) {
      buffer.writeln('🎉 **No security risks or unencrypted services were identified on your network!**');
      buffer.writeln();
    } else {
      int itemCounter = 1;
      for (final device in riskyDevices) {
        final devScore = SecurityScoringService.calculateDeviceScore(device);
        final tier = SecurityTierExtension.fromScore(devScore);

        buffer.writeln('### Device $itemCounter: ${device.ip} (${_md(device.displayName)})');
        buffer.writeln('- **MAC Address:** ${device.macAddress ?? "Unknown"}');
        buffer.writeln('- **Manufacturer:** ${device.vendor}');
        buffer.writeln('- **Security Score:** **$devScore / 100**');
        buffer.writeln('- **Risk Level:** **${tier.displayName}**');
        buffer.writeln();

        buffer.writeln('**Open Ports & Identified Risks:**');
        buffer.writeln('| Port | Service | Risk Level | Severity Penalty |');
        buffer.writeln('| :--- | :--- | :--- | :--- |');
        for (final vuln in device.vulnerabilities) {
          buffer.writeln('| ${vuln.affectedPort} | ${vuln.title} | ${vuln.riskLevel.displayName} | -${vuln.penaltyPoints} |');
        }
        buffer.writeln();

        buffer.writeln('**Actionable Remediation Recommendations:**');
        for (final vuln in device.vulnerabilities) {
          for (final step in vuln.howToFixSteps) {
            buffer.writeln('  - **${step.action}**: ${step.details}');
          }
        }
        buffer.writeln();
        itemCounter++;
        buffer.writeln('---');
      }
    }

    buffer.writeln('## 🛡️ General Home Network Hardening');
    buffer.writeln('1. Change default administrative passwords on all routers, cameras, and IoT bridges.');
    buffer.writeln('2. Disable unnecessary management services (Telnet, unencrypted HTTP, UPnP, RAW printing).');
    buffer.writeln('3. Isolate IoT appliances and cameras onto a segregated Guest Wi-Fi / VLAN.');
    buffer.writeln('4. Enforce encrypted protocols (SSH, HTTPS, SFTP, MQTTS with TLS).');
    buffer.writeln('5. Apply manufacturer security patches and firmware updates regularly.');
    buffer.writeln();
    buffer.writeln('*Report generated by Wi-Fi Security Guardian (Mobile FYP).*');

    return buffer.toString();
  }

  /// Generates a standalone, beautiful HTML Audit Report matching Figures 4.7–4.10
  /// from the Phase 1 FYP Report with inline CSS and colored risk badges.
  static String generateHtmlReport(NetworkAuditResult audit) {
    final dateStr = audit.scanTimestamp.toLocal().toString().split('.')[0];
    final devices = audit.devices;

    int excellentCount = 0;
    int goodCount = 0;
    int fairCount = 0;
    int poorCount = 0;
    int criticalCount = 0;

    for (final d in devices) {
      final s = SecurityScoringService.calculateDeviceScore(d);
      if (s >= 90) excellentCount++;
      else if (s >= 75) goodCount++;
      else if (s >= 60) fairCount++;
      else if (s >= 40) poorCount++;
      else criticalCount++;
    }

    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="en">');
    buffer.writeln('<head>');
    buffer.writeln('<meta charset="UTF-8">');
    buffer.writeln('<meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buffer.writeln('<title>IoT Security Audit Report</title>');
    buffer.writeln('<style>');
    buffer.writeln('body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background-color: #faf8f5; color: #3e2723; margin: 0; padding: 24px; }');
    buffer.writeln('.container { max-width: 900px; margin: 0 auto; background: #fff; border-radius: 18px; box-shadow: 0 4px 20px rgba(109,76,65,0.08); overflow: hidden; border: 1px solid #eae2dc; }');
    buffer.writeln('.header { background: linear-gradient(135deg, #6d4c41 0%, #8d6e63 100%); color: #fff; padding: 28px; text-align: center; }');
    buffer.writeln('.header h1 { margin: 0 0 6px 0; font-size: 24px; letter-spacing: -0.3px; }');
    buffer.writeln('.header p { margin: 0; font-size: 13px; opacity: 0.9; }');
    buffer.writeln('.content { padding: 26px; }');
    buffer.writeln('h2 { font-size: 17px; color: #4e342e; border-bottom: 2px solid #f5efeb; padding-bottom: 8px; margin-top: 24px; }');
    buffer.writeln('table { width: 100%; border-collapse: collapse; margin-top: 12px; margin-bottom: 20px; font-size: 13px; }');
    buffer.writeln('th, td { padding: 10px 12px; text-align: left; border-bottom: 1px solid #eae2dc; }');
    buffer.writeln('th { background-color: #faf8f5; color: #5d4037; font-weight: 600; }');
    buffer.writeln('.badge { display: inline-block; padding: 3px 8px; border-radius: 6px; font-size: 11px; font-weight: bold; color: #fff; }');
    buffer.writeln('.badge-excellent { background-color: #2d6a4f; }');
    buffer.writeln('.badge-good { background-color: #52796f; }');
    buffer.writeln('.badge-fair { background-color: #c88a2e; }');
    buffer.writeln('.badge-poor { background-color: #d97706; }');
    buffer.writeln('.badge-critical { background-color: #c53030; }');
    buffer.writeln('.badge-low { background-color: #52796f; }');
    buffer.writeln('.badge-medium { background-color: #d97706; }');
    buffer.writeln('.badge-high { background-color: #c53030; }');
    buffer.writeln('.bar-row { display: flex; align-items: center; margin-bottom: 8px; font-size: 12px; }');
    buffer.writeln('.bar-label { width: 130px; font-weight: 600; }');
    buffer.writeln('.bar-track { flex-grow: 1; height: 10px; background: #eae2dc; border-radius: 5px; overflow: hidden; margin: 0 10px; }');
    buffer.writeln('.bar-fill { height: 100%; border-radius: 5px; }');
    buffer.writeln('.device-card { background: #fff; border: 1px solid #eae2dc; border-radius: 14px; padding: 16px; margin-bottom: 16px; }');
    buffer.writeln('.device-title { font-size: 15px; font-weight: bold; color: #4e342e; margin-bottom: 6px; }');
    buffer.writeln('.rec-list { margin: 8px 0 0 16px; padding: 0; font-size: 13px; line-height: 1.5; color: #5d4037; }');
    buffer.writeln('</style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');
    buffer.writeln('<div class="container">');

    // Header
    buffer.writeln('<div class="header">');
    buffer.writeln('<h1>🛡️ IoT Security Audit Report</h1>');
    buffer.writeln('<p>Generated: $dateStr | Network: ${_h(audit.wifiSsid ?? "Local Wi-Fi")} (${_h(audit.subnet)}.0/24)</p>');
    buffer.writeln('</div>');

    buffer.writeln('<div class="content">');

    // Executive Summary
    buffer.writeln('<h2>📊 Executive Summary</h2>');
    buffer.writeln('<table>');
    buffer.writeln('<tr><td><strong>Total Devices Scanned</strong></td><td>${devices.length}</td></tr>');
    buffer.writeln('<tr><td><strong>Overall Security Score</strong></td><td><strong>${audit.overallScore}/100 — ${audit.scoreHealthRating}</strong></td></tr>');
    buffer.writeln('<tr><td>Excellent (90–100)</td><td>$excellentCount</td></tr>');
    buffer.writeln('<tr><td>Good (75–89)</td><td>$goodCount</td></tr>');
    buffer.writeln('<tr><td>Fair (60–74)</td><td>$fairCount</td></tr>');
    buffer.writeln('<tr><td>Poor (40–59)</td><td>$poorCount</td></tr>');
    buffer.writeln('<tr><td>Critical (&lt;40)</td><td>$criticalCount</td></tr>');
    buffer.writeln('</table>');

    // Risk Level Distribution
    final totalDevs = devices.isEmpty ? 1 : devices.length;
    buffer.writeln('<h2>📈 Risk Level Distribution</h2>');
    buffer.writeln('<div class="bar-row"><span class="bar-label" style="color:#2d6a4f">Excellent (90-100)</span><div class="bar-track"><div class="bar-fill" style="width:${(excellentCount/totalDevs*100).toInt()}%; background:#2d6a4f"></div></div><span>$excellentCount</span></div>');
    buffer.writeln('<div class="bar-row"><span class="bar-label" style="color:#52796f">Good (75-89)</span><div class="bar-track"><div class="bar-fill" style="width:${(goodCount/totalDevs*100).toInt()}%; background:#52796f"></div></div><span>$goodCount</span></div>');
    buffer.writeln('<div class="bar-row"><span class="bar-label" style="color:#c88a2e">Fair (60-74)</span><div class="bar-track"><div class="bar-fill" style="width:${(fairCount/totalDevs*100).toInt()}%; background:#c88a2e"></div></div><span>$fairCount</span></div>');
    buffer.writeln('<div class="bar-row"><span class="bar-label" style="color:#d97706">Poor (40-59)</span><div class="bar-track"><div class="bar-fill" style="width:${(poorCount/totalDevs*100).toInt()}%; background:#d97706"></div></div><span>$poorCount</span></div>');
    buffer.writeln('<div class="bar-row"><span class="bar-label" style="color:#c53030">Critical (&lt;40)</span><div class="bar-track"><div class="bar-fill" style="width:${(criticalCount/totalDevs*100).toInt()}%; background:#c53030"></div></div><span>$criticalCount</span></div>');

    // Device Discovery & Scan Results
    buffer.writeln('<h2>Device Discovery & Scan Results</h2>');
    buffer.writeln('<table>');
    buffer.writeln('<tr><th>#</th><th>IP Address</th><th>MAC Address</th><th>Manufacturer</th><th>Score</th><th>Risk Level</th></tr>');
    int devIdx = 1;
    for (final dev in devices) {
      final s = SecurityScoringService.calculateDeviceScore(dev);
      final tier = SecurityTierExtension.fromScore(s);
      final badgeClass = 'badge-${tier.name.toLowerCase()}';
      buffer.writeln('<tr><td>$devIdx</td><td><code>${_h(dev.ip)}</code></td><td>${_h(dev.macAddress ?? "Unknown")}</td><td>${_h(dev.vendor)}</td><td>$s/100</td><td><span class="badge $badgeClass">${tier.displayName}</span></td></tr>');
      devIdx++;
    }
    buffer.writeln('</table>');

    // Detailed Device Assessments
    buffer.writeln('<h2>Detailed Device Assessments</h2>');
    for (int i = 0; i < devices.length; i++) {
      final dev = devices[i];
      final s = SecurityScoringService.calculateDeviceScore(dev);
      final tier = SecurityTierExtension.fromScore(s);
      final badgeClass = 'badge-${tier.name.toLowerCase()}';

      buffer.writeln('<div class="device-card">');
      buffer.writeln('<div class="device-title">Device ${i+1}: ${_h(dev.ip)} (${_h(dev.displayName)})</div>');
      buffer.writeln('<p style="margin:4px 0 10px 0; font-size:12px; color:#64748b;">MAC: ${_h(dev.macAddress ?? "N/A")} | Manufacturer: ${_h(dev.vendor)} | Score: <strong>$s/100</strong> <span class="badge $badgeClass" style="margin-left:6px">${tier.displayName}</span></p>');

      if (dev.openPorts.isNotEmpty) {
        buffer.writeln('<table>');
        buffer.writeln('<tr><th>Port</th><th>Service</th><th>Risk Level</th><th>Description</th></tr>');
        for (final p in dev.openPorts) {
          final vuln = _findingFor(dev, p.port);
          final riskName = vuln != null ? vuln.riskLevel.displayName : 'INFO';
          final rBadge = vuln != null ? 'badge-${vuln.riskLevel.name.toLowerCase()}' : 'badge-low';
          buffer.writeln('<tr><td><strong>${p.port}</strong></td><td>${_h(p.serviceName)}</td><td><span class="badge $rBadge">$riskName</span></td><td>${_h(p.description)}</td></tr>');
        }
        buffer.writeln('</table>');
      }

      if (dev.vulnerabilities.isNotEmpty) {
        buffer.writeln('<strong>Remediation Recommendations:</strong>');
        buffer.writeln('<ul class="rec-list">');
        for (final vuln in dev.vulnerabilities) {
          for (final step in vuln.howToFixSteps) {
            buffer.writeln('<li><strong>${_h(step.action)}:</strong> ${_h(step.details)}</li>');
          }
        }
        buffer.writeln('</ul>');
      } else {
        buffer.writeln('<p style="margin:4px 0 0 0; color:#2e7d32; font-size:12px;">✅ No unencrypted or vulnerable services found on this device.</p>');
      }

      buffer.writeln('</div>');
    }

    buffer.writeln('</div>'); // content
    buffer.writeln('</div>'); // container
    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }
}
