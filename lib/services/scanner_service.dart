import 'dart:async';
import 'dart:io';
import '../models/device_model.dart';
import '../models/security_model.dart';
import 'vulnerability_db.dart';
import 'vendor_lookup_service.dart';

class ScannerProgress {
  final int completedHosts;
  final int totalHosts;
  final String currentScanningIp;
  final int devicesFound;

  ScannerProgress({
    required this.completedHosts,
    required this.totalHosts,
    required this.currentScanningIp,
    required this.devicesFound,
  });

  double get ratio => totalHosts == 0 ? 0 : completedHosts / totalHosts;
}

class ScannerService {
  // Probing ports for detection and security hygiene
  static const List<int> probePorts = [80, 443, 23, 21, 554, 445, 8080, 5353, 7000];

  /// Scans the entire /24 subnet using an async parallel worker pool
  Future<List<DiscoveredDevice>> scanSubnet({
    required String subnetPrefix,
    required String localIp,
    required String gatewayIp,
    Function(ScannerProgress progress)? onProgress,
  }) async {
    final List<DiscoveredDevice> discovered = [];
    const int totalHosts = 254;
    int completed = 0;

    // Concurrency batch size
    const int batchSize = 25;

    for (int batchStart = 1; batchStart <= totalHosts; batchStart += batchSize) {
      final int batchEnd = (batchStart + batchSize - 1 > totalHosts)
          ? totalHosts
          : batchStart + batchSize - 1;

      final futures = <Future<DiscoveredDevice?>>[];

      for (int i = batchStart; i <= batchEnd; i++) {
        final ip = '$subnetPrefix.$i';
        futures.add(_probeHost(
          ip: ip,
          gatewayIp: gatewayIp,
          isLocalPhone: (ip == localIp),
        ));
      }

      final results = await Future.wait(futures);

      for (var device in results) {
        if (device != null) {
          discovered.add(device);
        }
      }

      completed += (batchEnd - batchStart + 1);

      if (onProgress != null) {
        onProgress(ScannerProgress(
          completedHosts: completed,
          totalHosts: totalHosts,
          currentScanningIp: '$subnetPrefix.$batchEnd',
          devicesFound: discovered.length,
        ));
      }
    }

    // Sort: Gateway first, then vulnerable devices, then by IP
    discovered.sort((a, b) {
      if (a.category == DeviceCategory.gateway) return -1;
      if (b.category == DeviceCategory.gateway) return 1;
      if (a.hasIssues && !b.hasIssues) return -1;
      if (!a.hasIssues && b.hasIssues) return 1;
      return a.ip.compareTo(b.ip);
    });

    return discovered;
  }

  Future<DiscoveredDevice?> _probeHost({
    required String ip,
    required String gatewayIp,
    required bool isLocalPhone,
  }) async {
    final stopwatch = Stopwatch()..start();
    final List<PortInfo> openPorts = [];
    final List<SecurityVulnerability> detectedVulns = [];

    // Probe common ports with quick timeouts (120ms)
    await Future.wait(probePorts.map((port) async {
      try {
        final socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(milliseconds: 120),
        );
        
        final isSecure = (port == 443);
        final vuln = VulnerabilityDatabase.getVulnerabilityForPort(port);
        if (vuln != null) {
          detectedVulns.add(vuln);
        }

        openPorts.add(PortInfo(
          port: port,
          serviceName: _getPortServiceName(port),
          isSecure: isSecure,
          description: _getPortDescription(port),
        ));

        socket.destroy();
      } catch (_) {
        // Closed / unreachable
      }
    }));

    stopwatch.stop();

    // If no ports open and not the local device or gateway, consider host inactive
    if (openPorts.isEmpty && !isLocalPhone && ip != gatewayIp) {
      return null;
    }

    // Attempt reverse hostname resolution
    String hostname = 'Unknown Device';
    try {
      final hostLookup = await InternetAddress(ip).reverse().timeout(
            const Duration(milliseconds: 150),
          );
      hostname = hostLookup.host;
    } catch (_) {
      if (isLocalPhone) {
        hostname = 'This Mobile Device';
      } else if (ip == gatewayIp) {
        hostname = 'Wi-Fi Gateway Router';
      }
    }

    final category = isLocalPhone
        ? DeviceCategory.phoneOrTablet
        : VendorLookupService.inferCategory(
            ip: ip,
            gatewayIp: gatewayIp,
            openPorts: openPorts.map((p) => p.port).toList(),
            hostname: hostname,
          );

    final vendor = VendorLookupService.inferVendor(hostname, ip, gatewayIp);

    return DiscoveredDevice(
      ip: ip,
      hostname: hostname,
      vendor: vendor,
      category: category,
      openPorts: openPorts,
      vulnerabilities: detectedVulns,
      responseTimeMs: stopwatch.elapsedMilliseconds,
    );
  }

  String _getPortServiceName(int port) {
    switch (port) {
      case 21:
        return 'FTP (Plaintext)';
      case 23:
        return 'Telnet (Unencrypted)';
      case 80:
        return 'HTTP Web';
      case 443:
        return 'HTTPS Secure Web';
      case 445:
        return 'SMB File Sharing';
      case 554:
        return 'RTSP Video Feed';
      case 5353:
        return 'mDNS / ZeroConf';
      case 7000:
        return 'AirPlay / Media';
      case 8080:
        return 'HTTP-Alt Web';
      default:
        return 'Port $port';
    }
  }

  String _getPortDescription(int port) {
    switch (port) {
      case 21:
        return 'File transfer protocol without transport security.';
      case 23:
        return 'Legacy terminal protocol sending credentials unencrypted.';
      case 80:
        return 'Standard web management interface.';
      case 443:
        return 'TLS encrypted secure web server.';
      case 445:
        return 'Local network folder and file sharing.';
      case 554:
        return 'Streaming video protocol commonly used by security cameras.';
      case 5353:
        return 'Local service discovery broadcasting device existence.';
      case 7000:
        return 'Media streaming receiver service.';
      case 8080:
        return 'Secondary web portal or administration interface.';
      default:
        return 'Network service.';
    }
  }
}
