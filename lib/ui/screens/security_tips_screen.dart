import 'package:flutter/material.dart';

class SecurityTipsScreen extends StatelessWidget {
  const SecurityTipsScreen({super.key});

  static const deepMocha = Color(0xFF4E342E);
  static const primaryWarm = Color(0xFF6D4C41);
  static const softBrown = Color(0xFF8D6E63);
  static const warmCream = Color(0xFFF5EFEB);

  final List<Map<String, dynamic>> tips = const [
    {
      'title': 'Put Smart Devices on Guest Wi-Fi',
      'icon': Icons.home_outlined,
      'color': Color(0xFF52796F), // Soft Sage
      'summary':
          'Cheap smart gadgets are often insecure. Keep them away from your phones and laptops.',
      'action': 'Router > Guest Network > On. Connect smart devices there.',
    },
    {
      'title': 'Turn Off UPnP on Your Router',
      'icon': Icons.lock_outline,
      'color': Color(0xFFC88A2E), // Warm Honey
      'summary':
          'UPnP lets devices open your router to the Internet without asking you.',
      'action': 'Router > Advanced > UPnP > Off.',
    },
    {
      'title': 'Use WPA2 or WPA3 Wi-Fi Security',
      'icon': Icons.wifi_password,
      'color': Color(0xFF2D6A4F), // Soft Forest Green
      'summary':
          'Old WEP or WPA can be cracked in minutes.',
      'action': 'Router > Wireless > Security > WPA2 (AES) or WPA3.',
    },
    {
      'title': 'Turn Off Telnet',
      'icon': Icons.terminal,
      'color': Color(0xFFC53030), // Soft Brick Red
      'summary':
          'Telnet sends passwords as plain text. Use SSH instead.',
      'action': 'Device settings > Remote Management > Telnet off.',
    },
    {
      'title': 'Change Default Passwords',
      'icon': Icons.key_outlined,
      'color': Color(0xFFD97706), // Warm Terracotta
      'summary':
          'Attackers try factory passwords like "admin / admin" first.',
      'action': 'Set a unique password of 14+ characters.',
    },
    {
      'title': 'Keep Router Firmware Updated',
      'icon': Icons.system_update_alt,
      'color': Color(0xFF8D6E63), // Warm Brown
      'summary':
          'Updates fix security holes. Turn on automatic updates if you can.',
      'action': 'Router > System > Firmware Upgrade.',
    },
    {
      'title': 'Close Remote Desktop and Printer Ports',
      'icon': Icons.print_outlined,
      'color': Color(0xFF6D8B74), // Muted Sage
      'summary':
          'Open Remote Desktop and printer ports invite password guessing.',
      'action': 'Windows Settings > Remote Desktop > Off.',
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
