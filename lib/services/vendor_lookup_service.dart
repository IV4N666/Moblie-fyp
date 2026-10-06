import '../models/device_model.dart';

/// Keyword rule used for hostname matching.
///
/// Plain `contains()` caused false positives: "mike-laptop" was a Xiaomi
/// ("mi"), "spring-pc" a Ring camera ("ring"), "honest-tv" a Nest camera.
/// Short keywords are therefore matched against whole words in the hostname
/// (split on '-', '.', '_' etc.), or only at the start/end of a word.
class HostnameRule {
  final List<String> substrings;
  final List<String> words;
  final List<String> wordPrefixes;
  final List<String> wordSuffixes;

  const HostnameRule({
    this.substrings = const [],
    this.words = const [],
    this.wordPrefixes = const [],
    this.wordSuffixes = const [],
  });

  bool matches(String hostname) {
    final lower = hostname.toLowerCase();
    if (substrings.any(lower.contains)) return true;
    for (final w in VendorLookupService.tokenize(hostname)) {
      if (words.contains(w)) return true;
      if (wordPrefixes.any(w.startsWith)) return true;
      if (wordSuffixes.any(w.endsWith)) return true;
    }
    return false;
  }
}

class VendorLookupService {
  /// "Galaxy-S23.lan" -> ["galaxy", "s23", "lan"]
  static List<String> tokenize(String hostname) => hostname
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.isNotEmpty)
      .toList();

  static const _cameraNames = HostnameRule(
    substrings: ['camera', 'dahua', 'hikvision', 'reolink', 'wyze', 'eufy', 'ezviz', 'imou', 'amcrest', 'foscam', 'arlo', 'ringdoorbell'],
    words: ['ring', 'dvr', 'nvr'],
    wordPrefixes: ['ipc'],
    wordSuffixes: ['cam'],
  );

  static const _printerNames = HostnameRule(
    substrings: ['printer', 'epson', 'canon', 'brother', 'xerox', 'laserjet', 'officejet', 'deskjet', 'kyocera', 'lexmark', 'ricoh'],
    wordPrefixes: ['hp', 'npi'],
  );

  static const _mediaNames = HostnameRule(
    substrings: ['roku', 'chromecast', 'appletv', 'apple-tv', 'bravia', 'firetv', 'fire-tv', 'shield', 'smarttv', 'androidtv', 'webos', 'tizen', 'sonos'],
    words: ['tv'],
    wordSuffixes: ['tv'],
  );

  static const _computerNames = HostnameRule(
    substrings: ['macbook', 'imac', 'thinkpad', 'surface', 'workstation', 'vivobook', 'zenbook', 'ideapad'],
    words: ['pc', 'dell'],
    wordPrefixes: ['desktop', 'laptop'],
  );

  static const _mobileNames = HostnameRule(
    wordPrefixes: ['iphone', 'ipad', 'android', 'galaxy', 'pixel', 'oneplus', 'redmi', 'oppo', 'vivo', 'poco'],
  );

  static const _iotNames = HostnameRule(
    substrings: ['tuya', 'sonoff', 'tasmota', 'shelly', 'raspberry', 'homeassistant', 'wemo', 'kasa', 'smartthings', 'alexa', 'philips-hue'],
    words: ['nest', 'hue', 'echo'],
    wordPrefixes: ['esp'],
  );

  /// Heuristically classifies the device from the gateway address, open
  /// ports and hostname. Strong port evidence is checked before hostnames.
  static DeviceCategory inferCategory({
    required String ip,
    required String? gatewayIp,
    required List<int> openPorts,
    required String hostname,
  }) {
    bool hasPort(List<int> ports) => ports.any(openPorts.contains);

    // 1. Gateway: only the router address reported by the OS.
    //    The old `ip.endsWith('.1')` also matched .11, .21, .101, .201 ...
    if (gatewayIp != null && gatewayIp.isNotEmpty && ip == gatewayIp) {
      return DeviceCategory.gateway;
    }

    // 2. Smart cameras
    if (hasPort(const [554, 2323]) || _cameraNames.matches(hostname)) {
      return DeviceCategory.smartCamera;
    }

    // 3. Network printers
    if (hasPort(const [515, 631, 9100]) || _printerNames.matches(hostname)) {
      return DeviceCategory.printer;
    }

    // 4. iPhones / iPads expose the lockdown sync service on 62078
    if (hasPort(const [62078])) {
      return DeviceCategory.phoneOrTablet;
    }

    // 5. Smart TV / media streaming
    if (hasPort(const [7000, 8008, 8009]) || _mediaNames.matches(hostname)) {
      return DeviceCategory.entertainment;
    }

    // 6. Computers. SSH (22) alone is no longer treated as "computer":
    //    routers, NAS boxes and Raspberry Pis expose it too.
    if (hasPort(const [445, 3389, 5900]) || _computerNames.matches(hostname)) {
      return DeviceCategory.computer;
    }

    // 7. Phones & tablets by name
    if (_mobileNames.matches(hostname)) {
      return DeviceCategory.phoneOrTablet;
    }

    // 8. Generic IoT / smart home
    if (hasPort(const [1883, 80, 8080]) || _iotNames.matches(hostname)) {
      return DeviceCategory.iotDevice;
    }

    return DeviceCategory.unknown;
  }

  static const List<MapEntry<String, HostnameRule>> _vendorRules = [
    MapEntry('Apple Inc.', HostnameRule(substrings: ['apple', 'macbook', 'imac'], wordPrefixes: ['iphone', 'ipad'])),
    MapEntry('Samsung Electronics', HostnameRule(substrings: ['samsung'], wordPrefixes: ['galaxy'])),
    MapEntry('Google LLC', HostnameRule(substrings: ['google', 'chromecast'], words: ['nest'], wordPrefixes: ['pixel'])),
    MapEntry('Amazon', HostnameRule(substrings: ['amazon', 'kindle', 'firetv', 'fire-tv'], words: ['echo'])),
    MapEntry('TP-Link Technologies', HostnameRule(substrings: ['tplink', 'tp-link', 'tapo', 'kasa'])),
    MapEntry('ASUS', HostnameRule(substrings: ['asus', 'vivobook', 'zenbook'])),
    MapEntry('NETGEAR', HostnameRule(substrings: ['netgear'])),
    MapEntry('Ubiquiti Networks', HostnameRule(substrings: ['ubiquiti', 'unifi'])),
    MapEntry('NAS Storage System', HostnameRule(substrings: ['synology', 'qnap'])),
    MapEntry('Sonos Audio', HostnameRule(substrings: ['sonos'])),
    MapEntry('Philips Hue Smart Lighting', HostnameRule(substrings: ['philips'], words: ['hue'])),
    MapEntry('Xiaomi', HostnameRule(substrings: ['xiaomi', 'mijia'], words: ['mi'], wordPrefixes: ['redmi', 'poco'])),
    MapEntry('Hikvision Digital', HostnameRule(substrings: ['hikvision'])),
    MapEntry('Dahua Technology', HostnameRule(substrings: ['dahua'])),
    MapEntry('Reolink Security', HostnameRule(substrings: ['reolink'])),
    MapEntry('Wyze Labs', HostnameRule(substrings: ['wyze'])),
    MapEntry('Epson', HostnameRule(substrings: ['epson'])),
    MapEntry('Brother Industries', HostnameRule(substrings: ['brother'])),
    MapEntry('Canon', HostnameRule(substrings: ['canon'])),
    MapEntry('HP Inc.', HostnameRule(substrings: ['hewlett', 'laserjet', 'officejet', 'deskjet'], wordPrefixes: ['hp', 'npi'])),
    MapEntry('Raspberry Pi Foundation', HostnameRule(substrings: ['raspberry'])),
  ];

  /// Identifies the manufacturer from hostname cues.
  ///
  /// Note: real MAC/OUI lookup is not possible on Android 10+ (the ARP table
  /// is no longer readable by apps), so this stays a hostname heuristic.
  static String inferVendor(String hostname, String ip, String? gatewayIp) {
    for (final rule in _vendorRules) {
      if (rule.value.matches(hostname)) return rule.key;
    }
    if (gatewayIp != null && gatewayIp.isNotEmpty && ip == gatewayIp) {
      return 'Router / Network Gateway';
    }
    return 'Network Connected Device';
  }
}
