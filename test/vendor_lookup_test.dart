import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_guardian_app/models/device_model.dart';
import 'package:wifi_guardian_app/services/vendor_lookup_service.dart';

DeviceCategory categoryOf(String hostname,
    {String ip = '192.168.1.50', List<int> ports = const []}) {
  return VendorLookupService.inferCategory(
    ip: ip,
    gatewayIp: '192.168.1.1',
    openPorts: ports,
    hostname: hostname,
  );
}

void main() {
  group('gateway detection', () {
    test('only the reported gateway IP is the router', () {
      expect(categoryOf('x', ip: '192.168.1.1'), DeviceCategory.gateway);
    });

    test('.11 / .101 / .201 / .254 are NOT routers (old endsWith bug)', () {
      for (final ip in ['192.168.1.11', '192.168.1.101', '192.168.1.201', '192.168.1.254']) {
        expect(categoryOf('Unknown Device', ip: ip), isNot(DeviceCategory.gateway),
            reason: ip);
      }
    });
  });

  group('hostname matching uses whole words', () {
    test('"mike-laptop" is a computer, not a Xiaomi', () {
      expect(categoryOf('mike-laptop'), DeviceCategory.computer);
      expect(VendorLookupService.inferVendor('mike-laptop', '192.168.1.50', '192.168.1.1'),
          isNot('Xiaomi'));
    });

    test('"spring-server" is not a Ring camera', () {
      expect(categoryOf('spring-server'), DeviceCategory.unknown);
    });

    test('real device names are still recognised', () {
      expect(categoryOf('Galaxy-S23.lan'), DeviceCategory.phoneOrTablet);
      expect(categoryOf('iPhone.lan'), DeviceCategory.phoneOrTablet);
      expect(categoryOf('HP3C2AF4.lan'), DeviceCategory.printer);
      expect(categoryOf('frontdoorcam'), DeviceCategory.smartCamera);
      expect(categoryOf('DESKTOP-4F2KQ1'), DeviceCategory.computer);
    });

    test('vendors', () {
      String vendor(String h) =>
          VendorLookupService.inferVendor(h, '192.168.1.50', '192.168.1.1');
      expect(vendor('Galaxy-S23.lan'), 'Samsung Electronics');
      expect(vendor('iPhone.lan'), 'Apple Inc.');
      expect(vendor('HP3C2AF4.lan'), 'HP Inc.');
      expect(vendor('Redmi-Note-12'), 'Xiaomi');
      expect(vendor('Unknown Device'), 'Network Connected Device');
    });
  });

  test('port evidence', () {
    expect(categoryOf('Unknown Device', ports: [554]), DeviceCategory.smartCamera);
    expect(categoryOf('Unknown Device', ports: [9100]), DeviceCategory.printer);
    expect(categoryOf('Unknown Device', ports: [62078]), DeviceCategory.phoneOrTablet);
    // SSH alone no longer means "computer"
    expect(categoryOf('Unknown Device', ports: [22]), DeviceCategory.unknown);
  });
}
