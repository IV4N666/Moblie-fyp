import 'dart:io';
import '../models/device_model.dart';

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

  const HiddenCameraScanReport({
    required this.totalScanned,
    required this.detectedCameras,
    required this.timestamp,
    required this.hasHiddenCameras,
  });

  int get streamCount => detectedCameras.length;
}

class HiddenCameraService {
  static const List<int> surveillancePorts = [
    554,   // RTSP Default Video Stream
    8554,  // RTSP Alternative
    8000,  // Hikvision Media Port
    37777, // Dahua Private Video Protocol
    1935,  // RTMP Streaming
    8081,  // Motion JPEG / WebCam Stream
  ];

  /// Analyzes discovered devices from the subnet scan to isolate all video surveillance equipment.
  static HiddenCameraScanReport analyzeFromInventory(List<DiscoveredDevice> devices) {
    final List<DetectedCamera> cameras = [];

    for (final dev in devices) {
      final openPortSet = dev.openPorts.map((p) => p.port).toSet();

      // Check 1: RTSP Default stream (Port 554)
      if (openPortSet.contains(554)) {
        cameras.add(DetectedCamera(
          ip: dev.ip,
          displayName: dev.displayName,
          vendor: dev.vendor,
          port: 554,
          protocolName: 'RTSP (Real-Time Streaming Protocol)',
          riskLevel: CameraRiskLevel.critical,
          riskExplanation:
              'Active RTSP broadcast detected. Many IoT cameras stream live audio and video feeds without password authentication.',
          remediationSteps: [
            'Check camera administration dashboard to enforce a strong WPA3/Digest password on RTSP streams.',
            'Isolate this camera to an isolated VLAN or Guest Wi-Fi so local devices cannot tap the video feed.',
            'Disable UPnP and port forwarding on your router to avoid exposing this camera to the public Internet.',
          ],
        ));
      }

      // Check 2: Dahua Private Surveillance (Port 37777)
      if (openPortSet.contains(37777)) {
        cameras.add(DetectedCamera(
          ip: dev.ip,
          displayName: dev.displayName,
          vendor: dev.vendor.contains('Generic') ? 'Dahua Surveillance Technology' : dev.vendor,
          port: 37777,
          protocolName: 'Dahua Private DVR/NVR Stream',
          riskLevel: CameraRiskLevel.critical,
          riskExplanation:
              'Proprietary surveillance protocol port open. If placed in an Airbnb or rental room, this device may record continuously.',
          remediationSteps: [
            'Verify device ownership with property hosts if staying in a rental accommodation.',
            'Ensure default admin/admin credentials have been replaced.',
            'Block WAN access on port 37777 in firewall settings.',
          ],
        ));
      }

      // Check 3: Hikvision Media Management (Port 8000)
      if (openPortSet.contains(8000)) {
        cameras.add(DetectedCamera(
          ip: dev.ip,
          displayName: dev.displayName,
          vendor: dev.vendor.contains('Generic') ? 'Hikvision Digital Technology' : dev.vendor,
          port: 8000,
          protocolName: 'Hikvision SDK/Media Port',
          riskLevel: CameraRiskLevel.warning,
          riskExplanation:
              'Hikvision service port detected. Known legacy firmware vulnerabilities have allowed unauthenticated remote snapshot retrieval.',
          remediationSteps: [
            'Update camera firmware to the latest security patch.',
            'Enforce IP whitelist filtering on the camera switch port.',
          ],
        ));
      }

      // Check 4: General Category heuristic or vendor
      if (dev.category == DeviceCategory.smartCamera && cameras.every((c) => c.ip != dev.ip)) {
        cameras.add(DetectedCamera(
          ip: dev.ip,
          displayName: dev.displayName,
          vendor: dev.vendor,
          port: dev.openPorts.isNotEmpty ? dev.openPorts.first.port : 80,
          protocolName: 'Smart Security Camera Interface',
          riskLevel: CameraRiskLevel.warning,
          riskExplanation:
              'Identified as a surveillance camera via vendor/mDNS signatures. Ensure private physical spaces are not monitored without consent.',
          remediationSteps: [
            'Ensure 2-Factor Authentication (2FA) is enabled on the cloud camera app (Tapo, Ring, Wyze, Eufy).',
            'Cover camera lens physically when privacy is expected.',
          ],
        ));
      }
    }

    return HiddenCameraScanReport(
      totalScanned: devices.length,
      detectedCameras: cameras,
      timestamp: DateTime.now(),
      hasHiddenCameras: cameras.isNotEmpty,
    );
  }

  /// Actively probes a specific IP address across all known camera streaming ports
  static Future<List<int>> probeHostForCameraPorts(String ip, {int timeoutMs = 200}) async {
    final openSurveillancePorts = <int>[];

    await Future.wait(surveillancePorts.map((port) async {
      try {
        final socket = await Socket.connect(
          ip,
          port,
          timeout: Duration(milliseconds: timeoutMs),
        );
        socket.destroy();
        openSurveillancePorts.add(port);
      } catch (_) {}
    }));

    return openSurveillancePorts;
  }
}
