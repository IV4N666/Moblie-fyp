import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/device_model.dart';
import '../models/security_model.dart';
import 'platform_support.dart';
import 'socket_probe.dart';
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

/// Internal result of probing one host.
class _HostProbe {
  final bool answered;
  final DiscoveredDevice device;
  const _HostProbe(this.answered, this.device);
}

class ScannerService {
  // TCP ports probed on every host (Phase 1 Table 3.5 & Table 4.10).
  //
  // UDP-only services (TFTP 69, SNMP 161, mDNS 5353, CoAP 5683) were removed:
  // Socket.connect() is TCP, so probing them could never detect anything and
  // the report would silently under-count those risks. UPnP (UDP 1900) is
  // detected properly with an SSDP M-SEARCH instead (see discoverUpnpHosts).
  static const List<int> probePorts = [
    21,    // FTP (Plaintext)
    22,    // SSH
    23,    // Telnet (Unencrypted)
    80,    // HTTP Web
    443,   // HTTPS Secure
    445,   // SMB File Sharing
    554,   // RTSP Video
    1883,  // MQTT Smart Home
    2323,  // Mirai IoT Telnet
    3306,  // MySQL Database
    3389,  // RDP Remote Desktop
    5432,  // PostgreSQL
    5555,  // Android Debug Bridge (ADB) over the network
    5900,  // VNC
    6379,  // Redis
    7000,  // AirPlay
    8008,  // Google Cast
    8080,  // HTTP-Alt
    8888,  // HTTP-Alt
    9100,  // RAW Printer
    27017, // MongoDB
    62078, // Apple iOS lockdown service (helps find iPhones/iPads)
  ];

  static const Set<int> _encryptedPorts = {22, 443};

  /// Web ports that are only a risk if they serve the login page over plain
  /// HTTP. A port that just redirects to HTTPS is not penalised.
  static const Set<int> _webPorts = {80, 8080, 8888};

  static const int defaultPortTimeoutMs = 300;
  static const int defaultConcurrentHosts = 24;

  bool _isScanCancelled = false;

  bool get isCancelled => _isScanCancelled;

  void cancelScan() {
    _isScanCancelled = true;
  }

  /// Scans the /24 subnet with a pool of [maxConcurrentHosts] workers.
  ///
  /// A host counts as present when ANY probed port is open *or actively
  /// refused* (TCP RST). This finds phones, laptops and TVs that have no
  /// open ports at all, which the previous "open port required" rule missed.
  Future<List<DiscoveredDevice>> scanSubnet({
    required String subnetPrefix,
    required String localIp,
    required String gatewayIp,
    void Function(ScannerProgress progress)? onProgress,
    int perPortTimeoutMs = defaultPortTimeoutMs,
    int maxConcurrentHosts = defaultConcurrentHosts,
  }) async {
    _isScanCancelled = false;
    final timeout = Duration(milliseconds: perPortTimeoutMs.clamp(50, 5000));
    final workerCount = maxConcurrentHosts.clamp(1, 64);

    final targets = <String>[for (var i = 1; i <= 254; i++) '$subnetPrefix.$i'];
    final discovered = <DiscoveredDevice>[];
    var nextIndex = 0;
    var completed = 0;

    // Runs in parallel with the TCP sweep; costs ~2 s of wall time at most.
    final ssdpFuture = discoverUpnpHosts();

    Future<void> worker() async {
      while (!_isScanCancelled && nextIndex < targets.length) {
        final ip = targets[nextIndex++];
        final isLocal = ip == localIp;
        final probe = await _probeHost(
          ip: ip,
          gatewayIp: gatewayIp,
          isLocalPhone: isLocal,
          timeout: timeout,
        );
        if (probe.answered || isLocal || ip == gatewayIp) {
          discovered.add(probe.device);
        }
        completed++;
        onProgress?.call(ScannerProgress(
          completedHosts: completed,
          totalHosts: targets.length,
          currentScanningIp: ip,
          devicesFound: discovered.length,
          isCancelled: _isScanCancelled,
        ));
      }
    }

    await Future.wait(List.generate(workerCount, (_) => worker()));

    if (_isScanCancelled) {
      onProgress?.call(ScannerProgress(
        completedHosts: completed,
        totalHosts: targets.length,
        currentScanningIp: '',
        devicesFound: discovered.length,
        isCancelled: true,
      ));
    } else {
      // Merge UPnP/SSDP answers: adds hosts that block every TCP probe but
      // still announce themselves, and flags routers exposing UPnP IGD.
      final upnpHosts = await ssdpFuture;
      for (final entry in upnpHosts.entries) {
        final ip = entry.key;
        if (!ip.startsWith('$subnetPrefix.')) continue;
        var index = discovered.indexWhere((d) => d.ip == ip);
        if (index == -1) {
          final probe = await _probeHost(
            ip: ip,
            gatewayIp: gatewayIp,
            isLocalPhone: ip == localIp,
            timeout: timeout,
            forceResolveName: true,
          );
          discovered.add(probe.device);
          index = discovered.length - 1;
        }
        discovered[index] =
            _withSsdp(discovered[index], isInternetGateway: entry.value);
      }
    }

    discovered.sort(compareDevices);
    return discovered;
  }

  /// Gateway first, then devices with issues, then by numeric IP.
  /// (Plain string comparison put .100 before .2.)
  static int compareDevices(DiscoveredDevice a, DiscoveredDevice b) {
    final aGateway = a.category == DeviceCategory.gateway ? 0 : 1;
    final bGateway = b.category == DeviceCategory.gateway ? 0 : 1;
    if (aGateway != bGateway) return aGateway - bGateway;
    final aRisk = a.hasIssues ? 0 : 1;
    final bRisk = b.hasIssues ? 0 : 1;
    if (aRisk != bRisk) return aRisk - bRisk;
    return _ipToInt(a.ip).compareTo(_ipToInt(b.ip));
  }

  static int _ipToInt(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return 0;
    var value = 0;
    for (final p in parts) {
      value = value * 256 + (int.tryParse(p) ?? 0);
    }
    return value;
  }

  /// Re-checks a single host (used from Device Details).
  ///
  /// Returns `null` when the host did not answer at all. The old version
  /// returned a device with zero open ports in that case, so an offline
  /// device was reported as "fully secured".
  Future<DiscoveredDevice?> recheckHost({
    required String ip,
    String? mac,
    String? hostname,
    DeviceCategory? category,
    String? vendor,
    String gatewayIp = '',
    bool isLocalPhone = false,
    int perPortTimeoutMs = 500,
  }) async {
    final ssdpFuture = discoverUpnpHosts();
    final probe = await _probeHost(
      ip: ip,
      gatewayIp: gatewayIp,
      isLocalPhone: isLocalPhone,
      timeout: Duration(milliseconds: perPortTimeoutMs),
    );
    final upnpHosts = await ssdpFuture;
    final upnpAnswered = upnpHosts.containsKey(ip);

    if (!probe.answered && !upnpAnswered && !isLocalPhone) return null;

    var device = probe.device.copyWith(
      macAddress: mac,
      hostname: hostname,
      category: category,
      vendor: vendor,
    );
    if (upnpAnswered) {
      device = _withSsdp(device, isInternetGateway: upnpHosts[ip] ?? false);
    }
    return device;
  }

  Future<_HostProbe> _probeHost({
    required String ip,
    required String gatewayIp,
    required bool isLocalPhone,
    required Duration timeout,
    bool forceResolveName = false,
  }) async {
    final results = await Future.wait(
      probePorts.map((port) => SocketProbe.probe(ip, port, timeout)),
    );

    final openPorts = <PortInfo>[];
    final detectedVulns = <SecurityVulnerability>[];
    var answered = false;
    int? fastestReplyMs;

    // Check open web ports once: do they only redirect to HTTPS?
    final redirectsToSecure = <int>{};
    await Future.wait(results
        .where((r) => r.state == PortState.open && _webPorts.contains(r.port))
        .map((r) async {
      if (await redirectsToHttps(ip, r.port)) redirectsToSecure.add(r.port);
    }));

    for (final r in results) {
      if (!r.hostAnswered) continue;
      answered = true;
      if (fastestReplyMs == null || r.elapsedMs < fastestReplyMs) {
        fastestReplyMs = r.elapsedMs;
      }
      if (r.state != PortState.open) continue;

      final redirects = redirectsToSecure.contains(r.port);
      openPorts.add(PortInfo(
        port: r.port,
        serviceName: _getPortServiceName(r.port),
        isSecure: redirects || _encryptedPorts.contains(r.port),
        description: redirects
            ? 'Redirects to the encrypted HTTPS page. No risk.'
            : _getPortDescription(r.port),
      ));
      if (redirects) continue;

      // One finding per weakness: 80, 8080 and 8888 share the same id.
      final vuln = VulnerabilityDatabase.getVulnerabilityForPort(r.port);
      if (vuln != null && !detectedVulns.any((v) => v.id == vuln.id)) {
        detectedVulns.add(vuln);
      }
    }

    final isGateway = ip == gatewayIp;
    String hostname = 'Unknown Device';
    if (answered || isLocalPhone || isGateway || forceResolveName) {
      hostname = await _reverseLookup(ip) ??
          (isLocalPhone
              ? PlatformSupport.localDeviceName
              : (isGateway ? 'Wi-Fi Gateway Router' : 'Unknown Device'));
    }

    final category = isLocalPhone
        ? (PlatformSupport.isMobile
            ? DeviceCategory.phoneOrTablet
            : DeviceCategory.computer)
        : VendorLookupService.inferCategory(
            ip: ip,
            gatewayIp: gatewayIp,
            openPorts: openPorts.map((p) => p.port).toList(),
            hostname: hostname,
          );

    final vendor = VendorLookupService.inferVendor(hostname, ip, gatewayIp);

    return _HostProbe(
      answered,
      DiscoveredDevice(
        ip: ip,
        hostname: hostname,
        vendor: vendor,
        category: category,
        openPorts: openPorts,
        vulnerabilities: detectedVulns,
        // Fastest TCP reply, not total probe time (which was always ~timeout).
        responseTimeMs: fastestReplyMs ?? 0,
      ),
    );
  }

  static Future<String?> _reverseLookup(String ip) async {
    try {
      final result = await InternetAddress(ip)
          .reverse()
          .timeout(const Duration(milliseconds: 600));
      final host = result.host.trim();
      if (host.isEmpty || host == ip) return null;
      return host;
    } catch (_) {
      return null;
    }
  }

  /// Sends an SSDP M-SEARCH (UDP multicast 239.255.255.250:1900) and returns
  /// every responder's IP, mapped to `true` when it advertised a UPnP
  /// Internet Gateway Device (the router feature that can open firewall
  /// ports automatically).
  ///
  /// Responses are unicast back to our socket, so no Android multicast lock
  /// is required. Networks with AP/client isolation simply return nothing.
  static Future<Map<String, bool>> discoverUpnpHosts({
    Duration listenFor = const Duration(seconds: 2),
  }) async {
    final responders = <String, bool>{};
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? subscription;
    try {
      final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket = s;
      subscription = s.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = s.receive();
        if (datagram == null) return;
        final text = utf8.decode(datagram.data, allowMalformed: true);
        final isIgd = text.contains('InternetGatewayDevice') ||
            text.contains('WANIPConnection') ||
            text.contains('WANPPPConnection');
        final ip = datagram.address.address;
        responders[ip] = (responders[ip] ?? false) || isIgd;
      });

      final request = utf8.encode(
        'M-SEARCH * HTTP/1.1\r\n'
        'HOST: 239.255.255.250:1900\r\n'
        'MAN: "ssdp:discover"\r\n'
        'MX: 1\r\n'
        'ST: ssdp:all\r\n'
        '\r\n',
      );
      final group = InternetAddress('239.255.255.250');
      s.send(request, group, 1900);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      s.send(request, group, 1900); // UDP is lossy: send twice.

      await Future<void>.delayed(listenFor);
    } catch (_) {
      // Multicast blocked or no Wi-Fi: treat as "no UPnP responders".
    } finally {
      await subscription?.cancel();
      socket?.close();
    }
    return responders;
  }

  static DiscoveredDevice _withSsdp(
    DiscoveredDevice device, {
    required bool isInternetGateway,
  }) {
    if (device.openPorts.any((p) => p.port == 1900)) return device;

    final ports = [
      ...device.openPorts,
      PortInfo(
        port: 1900,
        serviceName: isInternetGateway
            ? 'UPnP Internet Gateway (UDP 1900)'
            : 'UPnP / SSDP Discovery (UDP 1900)',
        isSecure: !isInternetGateway,
        description: isInternetGateway
            ? 'UPnP service capable of automatically opening router firewall ports.'
            : 'Announces itself to other devices on the network. Normal for TVs, speakers and media players.',
      ),
    ];

    final vulns = [...device.vulnerabilities];
    final upnpVuln = VulnerabilityDatabase.getVulnerabilityForPort(1900);
    if (isInternetGateway &&
        upnpVuln != null &&
        !vulns.any((v) => v.id == upnpVuln.id)) {
      vulns.add(upnpVuln);
    }

    return device.copyWith(openPorts: ports, vulnerabilities: vulns);
  }

  String _getPortServiceName(int port) {
    switch (port) {
      case 21:
        return 'FTP (Plaintext File Transfer)';
      case 22:
        return 'SSH (Encrypted Remote Access)';
      case 23:
        return 'Telnet (Unencrypted Terminal)';
      case 80:
        return 'HTTP (Unencrypted Web Interface)';
      case 443:
        return 'HTTPS (Encrypted Web Interface)';
      case 445:
        return 'SMB (Windows File Sharing)';
      case 554:
        return 'RTSP (Camera Video Feed)';
      case 1883:
        return 'MQTT (IoT Messaging - No TLS)';
      case 2323:
        return 'IoT Telnet (Mirai Target)';
      case 3306:
        return 'MySQL (Relational Database)';
      case 3389:
        return 'RDP (Remote Desktop)';
      case 5432:
        return 'PostgreSQL (Database Service)';
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
      case 5555:
        return 'ADB (Android Debug Bridge)';
      case 27017:
        return 'MongoDB (NoSQL Database)';
      case 62078:
        return 'Apple Device Sync (iOS lockdown)';
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
      case 80:
        return 'Standard web management interface without HTTPS.';
      case 443:
        return 'TLS encrypted secure web server.';
      case 445:
        return 'Local network folder and file sharing.';
      case 554:
        return 'Streaming video protocol commonly used by security cameras.';
      case 1883:
        return 'IoT telemetry broker without SSL/TLS encryption.';
      case 2323:
        return 'Alternate Telnet debug console frequently exploited by IoT botnets.';
      case 3306:
        return 'Direct SQL database port listening on local network.';
      case 3389:
        return 'Windows Remote Desktop protocol listening for logons.';
      case 5432:
        return 'Direct PostgreSQL database connection endpoint.';
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
      case 5555:
        return 'Android debugging interface. Gives full control of the device without a password.';
      case 27017:
        return 'Direct NoSQL document database listening on local network.';
      case 62078:
        return 'Wi-Fi sync service found on iPhones and iPads. Normal for Apple devices.';
      default:
        return 'Network service.';
    }
  }

  static List<SecurityVulnerability> _lookupVulns(List<int> ports) {
    final found = <SecurityVulnerability>[];
    for (final p in ports) {
      final v = VulnerabilityDatabase.getVulnerabilityForPort(p);
      if (v != null && !found.any((f) => f.id == v.id)) found.add(v);
    }
    return found;
  }

  /// True when http://ip:port/ answers with a redirect to an https:// URL,
  /// i.e. the login page itself is only served encrypted.
  static Future<bool> redirectsToHttps(
    String ip,
    int port, {
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client
          .getUrl(Uri(scheme: 'http', host: ip, port: port, path: '/'))
          .timeout(timeout);
      request.followRedirects = false;
      final response = await request.close().timeout(timeout);
      final location = response.headers.value(HttpHeaders.locationHeader) ?? '';
      return response.isRedirect &&
          location.trim().toLowerCase().startsWith('https://');
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
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
