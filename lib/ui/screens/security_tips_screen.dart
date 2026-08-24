import 'package:flutter/material.dart';

class SecurityTipsScreen extends StatelessWidget {
  const SecurityTipsScreen({super.key});

  final List<Map<String, dynamic>> tips = const [
    {
      'title': 'Isolate Smart IoT Devices on a Guest Network',
      'icon': Icons.home_outlined,
      'color': Colors.blue,
      'summary':
          'Smart bulbs, robot vacuums, and cheap cameras often have weak security. Put them on your router\'s Guest Wi-Fi so they cannot spy on your laptops or phones.',
      'action': 'Log in to your router > Enable Guest Network > Connect all IoT appliances to the Guest SSID.',
    },
    {
      'title': 'Turn Off Router UPnP (Universal Plug and Play)',
      'icon': Icons.lock_outline,
      'color': Colors.orange,
      'summary':
          'UPnP lets any smart gadget punch holes through your router\'s firewall without asking you. Disabling it protects you from automated Internet attacks.',
      'action': 'Router Settings > Advanced / NAT > Turn UPnP to "Off".',
    },
    {
      'title': 'Use Strong WPA2-AES or WPA3 Wi-Fi Encryption',
      'icon': Icons.wifi_password,
      'color': Colors.green,
      'summary':
          'Older security standards like WEP or WPA (TKIP) can be cracked in minutes by free tools. Make sure your Wi-Fi uses WPA2-AES or modern WPA3.',
      'action': 'Router Wireless Settings > Security Mode > Select WPA2-Personal (AES) or WPA3.',
    },
    {
      'title': 'Change the Router Admin Password',
      'icon': Icons.key_outlined,
      'color': Colors.red,
      'summary':
          'Never leave the router login as "admin / admin" or the printed password on the bottom sticker. Hackers use automated databases of default passwords.',
      'action': 'Router Settings > Administration > Set a unique, 14+ character password.',
    },
    {
      'title': 'Keep Router Firmware Updated',
      'icon': Icons.system_update_alt,
      'color': Colors.purple,
      'summary':
          'Router manufacturers release patches to fix security holes. Check for firmware updates twice a year or enable automatic updates if supported.',
      'action': 'Router Settings > System Tools > Firmware Upgrade > Check for Updates.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi Security Tips'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tips.length,
        itemBuilder: (context, index) {
          final tip = tips[index];
          final color = tip['color'] as Color;

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withOpacity(0.15),
                        child: Icon(tip['icon'] as IconData, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tip['title'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tip['summary'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.touch_app_outlined, size: 18, color: Colors.indigo),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'How to do it: ${tip['action']}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
