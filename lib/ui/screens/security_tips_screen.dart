import 'package:flutter/material.dart';

class SecurityTipsScreen extends StatelessWidget {
  const SecurityTipsScreen({super.key});

  static const deepMocha = Color(0xFF4E342E);
  static const primaryWarm = Color(0xFF6D4C41);
  static const softBrown = Color(0xFF8D6E63);
  static const warmCream = Color(0xFFF5EFEB);

  final List<Map<String, dynamic>> tips = const [
    {
      'title': 'Isolate Smart IoT Devices on a Guest Network',
      'icon': Icons.home_outlined,
      'color': Color(0xFF52796F), // Soft Sage
      'summary':
          'Smart bulbs, robot vacuums, and cheap cameras often have weak security. Put them on your router\'s Guest Wi-Fi so they cannot spy on your laptops or phones.',
      'action': 'Log in to your router > Enable Guest Network > Connect all IoT appliances to the Guest SSID.',
    },
    {
      'title': 'Turn Off Router UPnP (Universal Plug and Play)',
      'icon': Icons.lock_outline,
      'color': Color(0xFFC88A2E), // Warm Honey
      'summary':
          'UPnP lets any smart gadget punch holes through your router\'s firewall without asking you. Disabling it protects you from automated Internet attacks.',
      'action': 'Router Settings > Advanced / NAT > Turn UPnP to "Off".',
    },
    {
      'title': 'Use Strong WPA2-AES or WPA3 Wi-Fi Encryption',
      'icon': Icons.wifi_password,
      'color': Color(0xFF2D6A4F), // Soft Forest Green
      'summary':
          'Older security standards like WEP or WPA (TKIP) can be cracked in minutes by free tools. Make sure your Wi-Fi uses WPA2-AES or modern WPA3.',
      'action': 'Router Wireless Settings > Security Mode > Select WPA2-Personal (AES) or WPA3.',
    },
    {
      'title': 'Disable Legacy Telnet & Enforce Secure SSH',
      'icon': Icons.terminal,
      'color': Color(0xFFC53030), // Soft Brick Red
      'summary':
          'Telnet broadcasts usernames and passwords in plain readable text. Never allow Telnet on your home router or IoT devices—use encrypted SSH instead.',
      'action': 'Router or Device Portal > Remote Management > Uncheck Telnet and require SSH.',
    },
    {
      'title': 'Change Router & Camera Default Passwords',
      'icon': Icons.key_outlined,
      'color': Color(0xFFD97706), // Warm Terracotta
      'summary':
          'Never leave the router or camera login as "admin / admin" or default factory pins. Hackers and botnets scan LANs using lists of known default credentials.',
      'action': 'Device Settings > Administration > Set a unique, 14+ character password.',
    },
    {
      'title': 'Keep Router Firmware Updated',
      'icon': Icons.system_update_alt,
      'color': Color(0xFF8D6E63), // Warm Brown
      'summary':
          'Router manufacturers release patches to fix security holes. Check for firmware updates twice a year or enable automatic updates if supported.',
      'action': 'Router Settings > System Tools > Firmware Upgrade > Check for Updates.',
    },
    {
      'title': 'Restrict Remote Desktop & RAW Printer Ports',
      'icon': Icons.print_outlined,
      'color': Color(0xFF6D8B74), // Muted Sage
      'summary':
          'Open RDP (port 3389) and RAW printer queues (port 9100) allow anyone on Wi-Fi to attempt password attacks or intercept printed documents.',
      'action': 'Disable RDP in Windows Settings if unused, or enable Network Level Authentication (NLA).',
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
            elevation: 0.8,
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(tip['icon'] as IconData, color: color, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          tip['title'] as String,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: deepMocha,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tip['summary'] as String,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade700,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDFBF7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEFEBE9)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.touch_app_outlined,
                            size: 17, color: primaryWarm),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'How to do it: ${tip['action']}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5D4037),
                              height: 1.35,
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
