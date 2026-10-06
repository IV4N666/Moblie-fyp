import '../models/device_model.dart';
import 'socket_probe.dart';

enum CameraRiskLevel { safe, warning, critical }

class DetectedCamera {
  final String ip;
  final String displayName;
  final String vendor;
  final int port;
  final String protocolName;
  final CameraRiskLevel riskLevel;
  final String riskExplanation;
  final List<String> remediationSteps;

  const DetectedCamera({
    required this.ip,
    required this.displayName,
    required this.vendor,
    required this.port,
    required this.protocolName,
    required this.riskLevel,
    required this.riskExplanation,
    required this.remediationSteps,
  });
}

class HiddenCameraScanReport {
  final int totalScanned;
  final List<DetectedCamera> detectedCameras;
  final DateTime timestamp;
  final bool hasHiddenCameras;

  /// True when the camera ports were actively probed on every device
  /// (deep scan), not just read from the main scan's inventory.
  final bool wasDeepScan;

  const HiddenCameraScanReport({
    required this.totalScanned,
    required this.detectedCameras,
    required this.timestamp,
    required this.hasHiddenCameras,
    this.wasDeepScan = false,
  });

  int get streamCount => detectedCameras.length;
}

class _CameraSignature {
  final String protocolName;
  final String? defaultVendor;
  final CameraRiskLevel riskLevel;
  final String riskExplanation;
  final List<String> remediationSteps;

  const _CameraSignature({
    required this.protocolName,
    this.defaultVendor,
    required this.riskLevel,
    required this.riskExplanation,
    required this.remediationSteps,
  });
}

class HiddenCameraService {
  /// Video/surveillance ports. Only 554 is part of the main subnet scan;
  /// the others are checked by [deepScan]. Previously 37777 and 8000 were
  /// "checked" in the inventory but never probed, so they could never match.
  static const Map<int, _CameraSignature> _signatures = {
    554: _CameraSignature(
      protocolName: 'RTSP (Real-Time Streaming Protocol)',
      riskLevel: CameraRiskLevel.critical,
      riskExplanation:
          'Active RTSP video service detected. Many IoT cameras stream live audio and video without a password.',
      remediationSteps: [
        'Open the camera app or admin page and set a strong password for RTSP streams.',
        'Move this camera to a Guest Wi-Fi or separate network so other devices cannot reach the video feed.',
        'Turn off UPnP and port forwarding on your router so the camera is not exposed to the Internet.',
      ],
    ),
    8554: _CameraSignature(
      protocolName: 'RTSP (alternate port 8554)',
      riskLevel: CameraRiskLevel.critical,
      riskExplanation:
          'RTSP video service on an alternate port. Often used by budget cameras and DIY camera software.',
      remediationSteps: [
        'Require a password for the video stream in the camera settings.',
        'Move the camera to a Guest Wi-Fi or separate network.',
      ],
    ),
    37777: _CameraSignature(
      protocolName: 'Dahua Private DVR/NVR Stream',
      defaultVendor: 'Dahua Surveillance Technology',
      riskLevel: CameraRiskLevel.critical,
      riskExplanation:
          'Proprietary surveillance protocol port open. In a rental room, this device may be recording continuously.',
      remediationSteps: [
        'If you are staying in a rental, ask the host where this device is and what it records.',
        'If it is your device, replace the default admin password.',
        'Block Internet (WAN) access to port 37777 in the router.',
      ],
    ),
    8000: _CameraSignature(
      protocolName: 'Hikvision SDK/Media Port',
      defaultVendor: 'Hikvision Digital Technology',
      riskLevel: CameraRiskLevel.warning,
      riskExplanation:
          'Hikvision service port detected. Older firmware had flaws that let anyone fetch snapshots without logging in. (Port 8000 is also used by some developer tools.)',
      remediationSteps: [
        'Update the camera firmware to the latest version.',
        'Allow access to the camera only from devices you trust.',
      ],
    ),
    1935: _CameraSignature(
      protocolName: 'RTMP Live Streaming',
      riskLevel: CameraRiskLevel.warning,
      riskExplanation:
          'Live video streaming service detected. Common on cameras and baby monitors that stream to a cloud service.',
      remediationSteps: [
        'Check which device this is and whether live streaming is expected.',
        'Turn on two-factor authentication in the camera\'s cloud app.',
      ],
    ),
    8081: _CameraSignature(
      protocolName: 'MJPEG / Webcam HTTP Stream',
      riskLevel: CameraRiskLevel.warning,
      riskExplanation:
          'Port often used by webcam software (motion, IP Webcam apps) to serve a live picture over plain HTTP.',
      remediationSteps: [
        'Open http://<device-ip>:8081 to see what is being served.',
        'Set a password in the webcam software, or turn the stream off when not needed.',
      ],
    ),
  };

  static List<int> get surveillancePorts => _signatures.keys.toList();

  static bool _isGenericVendor(String vendor) =>
      vendor.contains('Generic') || vendor == 'Network Connected Device';

  /// Builds the camera report from the scan inventory, plus any extra open
  /// ports found by [deepScan] ([extraOpenPorts]: ip -> open camera ports).
  static HiddenCameraScanReport analyzeFromInventory(
    List<DiscoveredDevice> devices, {
    Map<String, Set<int>> extraOpenPorts = const {},
    bool wasDeepScan = false,
  }) {
    final cameras = <DetectedCamera>[];

    for (final dev in devices) {
      final openPortSet = <int>{
        ...dev.openPorts.map((p) => p.port),
        ...?extraOpenPorts[dev.ip],
      };

      var matched = false;
      for (final entry in _signatures.entries) {
        if (!openPortSet.contains(entry.key)) continue;
        final sig = entry.value;
        matched = true;
        cameras.add(DetectedCamera(
          ip: dev.ip,
          displayName: dev.displayName,
          vendor: (sig.defaultVendor != null && _isGenericVendor(dev.vendor))
              ? sig.defaultVendor!
              : dev.vendor,
          port: entry.key,
          protocolName: sig.protocolName,
          riskLevel: sig.riskLevel,
          riskExplanation: sig.riskExplanation,
          remediationSteps: sig.remediationSteps,
        ));
      }

      // Identified as a camera by name/vendor, but no video port seen.
      if (!matched && dev.category == DeviceCategory.smartCamera) {
        cameras.add(DetectedCamera(
          ip: dev.ip,
          displayName: dev.displayName,
          vendor: dev.vendor,
          port: dev.openPorts.isNotEmpty ? dev.openPorts.first.port : 0,
          protocolName: 'Smart Security Camera Interface',
          riskLevel: CameraRiskLevel.warning,
          riskExplanation:
              'Identified as a camera from its network name or services. Make sure private spaces are not being recorded without consent.',
          remediationSteps: const [
            'Turn on two-factor authentication (2FA) in the camera\'s cloud app (Tapo, Ring, Wyze, Eufy).',
            'Cover the lens when privacy is expected.',
          ],
        ));
      }
    }

    return HiddenCameraScanReport(
      totalScanned: devices.length,
      detectedCameras: cameras,
      timestamp: DateTime.now(),
      hasHiddenCameras: cameras.isNotEmpty,
      wasDeepScan: wasDeepScan,
    );
  }

  /// Actively probes every device for all surveillance ports, then builds
  /// the report. (The old "deep scan" button only waited 600 ms and re-ran
  /// the inventory analysis without touching the network.)
  static Future<HiddenCameraScanReport> deepScan(
    List<DiscoveredDevice> devices, {
    int timeoutMs = 400,
  }) async {
    final extra = <String, Set<int>>{};
    await Future.wait(devices.map((d) async {
      extra[d.ip] =
          (await probeHostForCameraPorts(d.ip, timeoutMs: timeoutMs)).toSet();
    }));
    return analyzeFromInventory(
      devices,
      extraOpenPorts: extra,
      wasDeepScan: true,
    );
  }

  /// Probes one IP address across all known camera streaming ports.
  static Future<List<int>> probeHostForCameraPorts(
    String ip, {
    int timeoutMs = 400,
  }) async {
    final results = await Future.wait(surveillancePorts.map((port) =>
        SocketProbe.probe(ip, port, Duration(milliseconds: timeoutMs))));
    return [
      for (final r in results)
        if (r.state == PortState.open) r.port,
    ];
  }
}
