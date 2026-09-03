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
  final bool isCancelled;

  ScannerProgress({
    required this.completedHosts,
    required this.totalHosts,
    required this.currentScanningIp,
    required this.devicesFound,
    this.isCancelled = false,
  });

  double get ratio => totalHosts == 0 ? 0 : completedHosts / totalHosts;
}

class ScannerService {
  // Probing ports for detection and security hygiene matching Phase 1 Table 3.5 & Table 4.10
  static const List<int> probePorts = [
    21,    // FTP (Plaintext)
    22,    // SSH
    23,    // Telnet (Unencrypted)
    69,    // TFTP
    80,    // HTTP Web
    161,   // SNMP
    443,   // HTTPS Secure
    445,   // SMB File Sharing
    554,   // RTSP Video
    1883,  // MQTT Smart Home
    1900,  // UPnP / SSDP
    2323,  // Mirai IoT Telnet
    3306,  // MySQL Database
    3389,  // RDP Remote Desktop
    5353,  // mDNS / ZeroConf
    5432,  // PostgreSQL
    5683,  // CoAP
    5900,  // VNC
    6379,  // Redis
    7000,  // AirPlay
    8008,  // Google Cast
    8080,  // HTTP-Alt
    8888,  // HTTP-Alt
    9100,  // RAW Printer
    27017, // MongoDB
  ];

  bool _isScanCancelled = false;

  void cancelScan() {
    _isScanCancelled = true;
  }

  /// Scans the entire /24 subnet using an async parallel worker pool
  Future<List<DiscoveredDevice>> scanSubnet({
    required String subnetPrefix,
    required String localIp,
    required String gatewayIp,
    Function(ScannerProgress progress)? onProgress,
  }) async {
    _isScanCancelled = false;
    final List<DiscoveredDevice> discovered = [];
    const int totalHosts = 254;
    int completed = 0;

    // Concurrency batch size
    const int batchSize = 25;

    for (int batchStart = 1; batchStart <= totalHosts; batchStart += batchSize) {
      if (_isScanCancelled) {
        if (onProgress != null) {
          onProgress(ScannerProgress(
            completedHosts: completed,
            totalHosts: totalHosts,
            currentScanningIp: '$subnetPrefix.$completed',
            devicesFound: discovered.length,
            isCancelled: true,
          ));
        }
        break;
      }

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
          isCancelled: _isScanCancelled,
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

  /// Re-checks a single host specifically (used from Device Details)
  Future<DiscoveredDevice?> recheckHost({
    required String ip,
    required String gatewayIp,
    required bool isLocalPhone,
  }) async {
    return _probeHost(
      ip: ip,
      gatewayIp: gatewayIp,
      isLocalPhone: isLocalPhone,
      perPortTimeoutMs: 250,
    );
  }

  Future<DiscoveredDevice?> _probeHost({
    required String ip,
    required String gatewayIp,
    required bool isLocalPhone,
    int perPortTimeoutMs = 120,
  }) async {
    final stopwatch = Stopwatch()..start();
    final List<PortInfo> openPorts = [];
    final List<SecurityVulnerability> detectedVulns = [];

    // Probe common ports with quick timeouts
    await Future.wait(probePorts.map((port) async {
      try {
        final socket = await Socket.connect(
          ip,
          port,
          timeout: Duration(milliseconds: perPortTimeoutMs),
        );

        final isSecure = (port == 443 || port == 22);
        final vuln = VulnerabilityDatabase.getVulnerabilityForPort(port);
        if (vuln != null && vuln.penaltyPoints > 0) {
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
        return 'FTP (Plaintext File Transfer)';
      case 22:
        return 'SSH (Encrypted Remote Access)';
      case 23:
        return 'Telnet (Unencrypted Terminal)';
      case 69:
        return 'TFTP (Trivial File Transfer)';
      case 80:
        return 'HTTP (Unencrypted Web Interface)';
      case 161:
        return 'SNMP v1/v2 (Network Management)';
      case 443:
        return 'HTTPS (Encrypted Web Interface)';
      case 445:
        return 'SMB (Windows File Sharing)';
      case 554:
        return 'RTSP (Camera Video Feed)';
      case 1883:
        return 'MQTT (IoT Messaging - No TLS)';
      case 1900:
        return 'UPnP / SSDP (Plug & Play)';
      case 2323:
        return 'IoT Telnet (Mirai Target)';
      case 3306:
        return 'MySQL (Relational Database)';
      case 3389:
        return 'RDP (Remote Desktop)';
      case 5353:
        return 'mDNS / ZeroConf Discovery';
      case 5432:
        return 'PostgreSQL (Database Service)';
      case 5683:
        return 'CoAP (Constrained IoT Protocol)';
      case 5900:
        return 'VNC (Remote Desktop)';
      case 6379:
        return 'Redis (In-Memory Database)';
      case 7000:
        return 'AirPlay (Media Streaming)';
      case 8008:
        return 'Google Cast Service';
      case 8080:
        return 'HTTP-Alt (Secondary Web Portal)';
      case 8888:
        return 'HTTP-Alt (Alternate Web Port)';
      case 9100:
        return 'RAW JetDirect (Network Printer)';
      case 27017:
        return 'MongoDB (NoSQL Database)';
      default:
        return 'Port $port';
    }
  }

  String _getPortDescription(int port) {
    switch (port) {
      case 21:
        return 'Unencrypted file transfer protocol exposing credentials.';
      case 22:
        return 'Encrypted administrative terminal shell.';
      case 23:
        return 'Legacy terminal protocol sending cleartext passwords.';
      case 69:
        return 'Trivial file transfer without authentication.';
      case 80:
        return 'Standard web management interface without HTTPS.';
      case 161:
        return 'Simple Network Management Protocol with weak community strings.';
      case 443:
        return 'TLS encrypted secure web server.';
      case 445:
        return 'Local network folder and file sharing.';
      case 554:
        return 'Streaming video protocol commonly used by security cameras.';
      case 1883:
        return 'IoT telemetry broker without SSL/TLS encryption.';
      case 1900:
        return 'UPnP service capable of automatically opening router firewall ports.';
      case 2323:
        return 'Alternate Telnet debug console frequently exploited by IoT botnets.';
      case 3306:
        return 'Direct SQL database port listening on local network.';
      case 3389:
        return 'Windows Remote Desktop protocol listening for logons.';
      case 5353:
        return 'Local service discovery broadcasting device identity metadata.';
      case 5432:
        return 'Direct PostgreSQL database connection endpoint.';
      case 5683:
        return 'Constrained Application Protocol IoT messaging service.';
      case 5900:
        return 'Graphical remote desktop without transport encryption.';
      case 6379:
        return 'In-memory database server frequently lacking authentication.';
      case 7000:
        return 'Apple AirPlay audio/video streaming receiver service.';
      case 8008:
        return 'Chromecast audio/video casting endpoint.';
      case 8080:
        return 'Secondary web portal or administration interface.';
      case 8888:
        return 'Secondary development or HTTP proxy port.';
      case 9100:
        return 'Unauthenticated direct network printing queue.';
      case 27017:
        return 'Direct NoSQL document database listening on local network.';
      default:
        return 'Network service.';
    }
  }

  static List<SecurityVulnerability> _lookupVulns(List<int> ports) {
    return ports
        .map((p) => VulnerabilityDatabase.getVulnerabilityForPort(p))
        .whereType<SecurityVulnerability>()
        .toList();
  }

  /// Provides the exact representative testbed home network from FYP1 Report
  /// (Figures 4.4, 4.8, 4.9, 4.10) for academic consistency during evaluations.
  static List<DiscoveredDevice> getDemoDevices(String subnetPrefix) {
    return [
      // Device 1: Figure 4.8 - 192.168.1.1 (MAC: 70:4F:57:12:34:56) TP-Link Router
      DiscoveredDevice(
        ip: '$subnetPrefix.1',
        macAddress: '70:4F:57:12:34:56',
        hostname: 'TP-Link Archer Router',
        vendor: 'TP-Link Technologies',
        category: DeviceCategory.gateway,
        responseTimeMs: 2,
        openPorts: [
          const PortInfo(
            port: 80,
            serviceName: 'HTTP (Unencrypted Web Interface)',
            isSecure: false,
            description: 'Standard web management interface without HTTPS.',
          ),
          const PortInfo(
            port: 8080,
            serviceName: 'HTTP-Alt (Secondary Web Portal)',
            isSecure: false,
            description: 'Secondary web portal or administration interface.',
          ),
        ],
        vulnerabilities: _lookupVulns([80, 8080]),
      ),

      // Device 2: Figure 4.8 & 4.9 - 192.168.1.100 (MAC: 1C:61:FB:AA:BB:CC) TP-Link IP Camera
      DiscoveredDevice(
        ip: '$subnetPrefix.100',
        macAddress: '1C:61:FB:AA:BB:CC',
        hostname: 'TP-Link Tapo IP Camera',
        vendor: 'TP-Link Technologies',
        category: DeviceCategory.smartCamera,
        responseTimeMs: 14,
        openPorts: [
          const PortInfo(
            port: 23,
            serviceName: 'Telnet (Unencrypted Terminal)',
            isSecure: false,
            description: 'Legacy terminal protocol sending cleartext passwords.',
          ),
          const PortInfo(
            port: 80,
            serviceName: 'HTTP (Unencrypted Web Interface)',
            isSecure: false,
            description: 'Standard web management interface without HTTPS.',
          ),
          const PortInfo(
            port: 554,
            serviceName: 'RTSP (Camera Video Feed)',
            isSecure: false,
            description: 'Streaming video protocol commonly used by security cameras.',
          ),
        ],
        vulnerabilities: _lookupVulns([23, 80, 554]),
      ),

      // Device 3: Figure 4.8 & 4.9 - 192.168.1.50 (MAC: C0:3F:0E:DD:EE:FF) Samsung Smart TV
      DiscoveredDevice(
        ip: '$subnetPrefix.50',
        macAddress: 'C0:3F:0E:DD:EE:FF',
        hostname: 'Samsung Smart TV 65"',
        vendor: 'Samsung Electronics',
        category: DeviceCategory.entertainment,
        responseTimeMs: 11,
        openPorts: [
          const PortInfo(
            port: 443,
            serviceName: 'HTTPS (Encrypted Web Interface)',
            isSecure: true,
            description: 'TLS encrypted secure web server.',
          ),
          const PortInfo(
            port: 8008,
            serviceName: 'Google Cast Service',
            isSecure: true,
            description: 'Chromecast audio/video casting endpoint.',
          ),
        ],
        vulnerabilities: const [],
        isTrusted: true,
      ),

      // Device 4: Figure 4.8 - 192.168.1.120 (MAC: 48:4C:A8:11:22:33) Huawei Smart Hub
      DiscoveredDevice(
        ip: '$subnetPrefix.120',
        macAddress: '48:4C:A8:11:22:33',
        hostname: 'Huawei Smart IoT Hub',
        vendor: 'Huawei Technologies',
        category: DeviceCategory.iotDevice,
        responseTimeMs: 8,
        openPorts: [
          const PortInfo(
            port: 80,
            serviceName: 'HTTP (Unencrypted Web Interface)',
            isSecure: false,
            description: 'Standard web management interface without HTTPS.',
          ),
          const PortInfo(
            port: 1883,
            serviceName: 'MQTT (IoT Messaging - No TLS)',
            isSecure: false,
            description: 'IoT telemetry broker without SSL/TLS encryption.',
          ),
        ],
        vulnerabilities: _lookupVulns([80, 1883]),
      ),

      // Device 5: Figure 4.8 - 192.168.1.75 (MAC: D8:6C:02:AA:BB:11) Belkin IoT Plug
      DiscoveredDevice(
        ip: '$subnetPrefix.75',
        macAddress: 'D8:6C:02:AA:BB:11',
        hostname: 'Belkin WeMo Smart Plug',
        vendor: 'Belkin International',
        category: DeviceCategory.iotDevice,
        responseTimeMs: 7,
        openPorts: [
          const PortInfo(
            port: 80,
            serviceName: 'HTTP (Unencrypted Web Interface)',
            isSecure: false,
            description: 'Standard web management interface without HTTPS.',
          ),
        ],
        vulnerabilities: _lookupVulns([80]),
      ),

      // Device 6: Figure 4.8 - 192.168.1.200 (MAC: 00:1A:A8:AA:BB:22) Apple iPhone
      DiscoveredDevice(
        ip: '$subnetPrefix.200',
        macAddress: '00:1A:A8:AA:BB:22',
        hostname: 'This Mobile Device (iPhone)',
        vendor: 'Apple Inc.',
        category: DeviceCategory.phoneOrTablet,
        responseTimeMs: 1,
        openPorts: [
          const PortInfo(
            port: 443,
            serviceName: 'HTTPS (Encrypted Web Interface)',
            isSecure: true,
            description: 'TLS encrypted secure web server.',
          ),
        ],
        vulnerabilities: const [],
        isTrusted: true,
      ),

      // Device 7: Supplementary Workstation with SMB & RDP
      DiscoveredDevice(
        ip: '$subnetPrefix.101',
        macAddress: 'B4:2E:99:11:22:33',
        hostname: 'Home-Workstation-PC',
        vendor: 'Generic Device',
        category: DeviceCategory.computer,
        responseTimeMs: 4,
        openPorts: [
          const PortInfo(
            port: 445,
            serviceName: 'SMB (Windows File Sharing)',
            isSecure: false,
            description: 'Local network folder and file sharing.',
          ),
          const PortInfo(
            port: 3389,
            serviceName: 'RDP (Remote Desktop)',
            isSecure: false,
            description: 'Windows Remote Desktop protocol listening for logons.',
          ),
        ],
        vulnerabilities: _lookupVulns([445, 3389]),
      ),

      // Device 8: Supplementary Network Printer
      DiscoveredDevice(
        ip: '$subnetPrefix.65',
        macAddress: '00:1B:A9:AA:BB:CC',
        hostname: 'HP LaserJet Network Printer',
        vendor: 'HP Inc.',
        category: DeviceCategory.printer,
        responseTimeMs: 9,
        openPorts: [
          const PortInfo(
            port: 9100,
            serviceName: 'RAW JetDirect (Network Printer)',
            isSecure: false,
            description: 'Unauthenticated direct network printing queue.',
          ),
          const PortInfo(
            port: 80,
            serviceName: 'HTTP (Unencrypted Web Interface)',
            isSecure: false,
            description: 'Standard web management interface without HTTPS.',
          ),
        ],
        vulnerabilities: _lookupVulns([9100, 80]),
      ),
    ];
  }
}
