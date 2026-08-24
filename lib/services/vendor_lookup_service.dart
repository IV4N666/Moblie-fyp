import '../models/device_model.dart';

class VendorLookupService {
  /// Heuristically classifies the device and detects brand from IP position, open ports, and hostnames
  static DeviceCategory inferCategory({
    required String ip,
    required String? gatewayIp,
    required List<int> openPorts,
    required String hostname,
  }) {
    final lowerHost = hostname.toLowerCase();

    // 1. Gateway Detection
    if (ip == gatewayIp || ip.endsWith('.1') || ip.endsWith('.254')) {
      return DeviceCategory.gateway;
    }

    // 2. Smart Cameras
    if (openPorts.contains(554) ||
        lowerHost.contains('cam') ||
        lowerHost.contains('dahua') ||
        lowerHost.contains('hikvision') ||
        lowerHost.contains('reolink') ||
        lowerHost.contains('ring') ||
        lowerHost.contains('nest')) {
      return DeviceCategory.smartCamera;
    }

    // 3. Network Printers
    if (openPorts.contains(515) ||
        openPorts.contains(631) ||
        openPorts.contains(9100) ||
        lowerHost.contains('printer') ||
        lowerHost.contains('epson') ||
        lowerHost.contains('hp') ||
        lowerHost.contains('canon') ||
        lowerHost.contains('brother')) {
      return DeviceCategory.printer;
    }

    // 4. Smart TV / Media streaming
    if (openPorts.contains(7000) ||
        openPorts.contains(8008) ||
        openPorts.contains(8009) ||
        lowerHost.contains('tv') ||
        lowerHost.contains('roku') ||
        lowerHost.contains('chromecast') ||
        lowerHost.contains('apple-tv') ||
        lowerHost.contains('bravia') ||
        lowerHost.contains('shield')) {
      return DeviceCategory.entertainment;
    }

    // 5. Workstations / Computers
    if (openPorts.contains(445) ||
        openPorts.contains(3389) ||
        openPorts.contains(22) ||
        lowerHost.contains('macbook') ||
        lowerHost.contains('pc') ||
        lowerHost.contains('desktop') ||
        lowerHost.contains('laptop') ||
        lowerHost.contains('thinkpad')) {
      return DeviceCategory.computer;
    }

    // 6. Mobile Devices
    if (lowerHost.contains('iphone') ||
        lowerHost.contains('ipad') ||
        lowerHost.contains('android') ||
        lowerHost.contains('galaxy') ||
        lowerHost.contains('pixel')) {
      return DeviceCategory.phoneOrTablet;
    }

    // 7. Generic IoT
    if (openPorts.contains(1883) ||
        openPorts.contains(80) ||
        openPorts.contains(8080) ||
        lowerHost.contains('esp') ||
        lowerHost.contains('tuya') ||
        lowerHost.contains('sonoff') ||
        lowerHost.contains('hue') ||
        lowerHost.contains('tasmota')) {
      return DeviceCategory.iotDevice;
    }

    return DeviceCategory.unknown;
  }

  /// Identifies manufacturer name from hostname cues
  static String inferVendor(String hostname, String ip, String? gatewayIp) {
    if (ip == gatewayIp || ip.endsWith('.1')) {
      return 'Router / Network Gateway';
    }

    final lower = hostname.toLowerCase();
    if (lower.contains('apple') || lower.contains('iphone') || lower.contains('macbook') || lower.contains('ipad')) {
      return 'Apple Inc.';
    }
    if (lower.contains('samsung') || lower.contains('galaxy')) {
      return 'Samsung Electronics';
    }
    if (lower.contains('google') || lower.contains('pixel') || lower.contains('nest') || lower.contains('chromecast')) {
      return 'Google LLC';
    }
    if (lower.contains('amazon') || lower.contains('echo') || lower.contains('kindle') || lower.contains('firetv')) {
      return 'Amazon';
    }
    if (lower.contains('tplink') || lower.contains('tp-link')) {
      return 'TP-Link';
    }
    if (lower.contains('asus')) {
      return 'ASUS';
    }
    if (lower.contains('synology') || lower.contains('qnap')) {
      return 'NAS Storage Provider';
    }
    if (lower.contains('sonos')) {
      return 'Sonos Sound';
    }
    if (lower.contains('philips') || lower.contains('hue')) {
      return 'Philips Hue';
    }
    if (lower.contains('xiaomi') || lower.contains('mi')) {
      return 'Xiaomi';
    }

    return 'Network Connected Device';
  }
}
