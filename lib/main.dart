import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Clean, soft status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const WifiGuardianApp());
}

class WifiGuardianApp extends StatelessWidget {
  const WifiGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Soft, friendly warm-neutral palette (Cocoa brown, warm cream, soft sage)
    const primaryWarmBrown = Color(0xFF6D4C41); // Warm Mocha / Cocoa
    const warmSurface = Color(0xFFFAF8F5);      // Soft Warm Cream / Off-White
    const cardColor = Colors.white;

    return MaterialApp(
      title: 'Wi-Fi Security Guardian',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: warmSurface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryWarmBrown,
          primary: primaryWarmBrown,
          secondary: const Color(0xFFA1887F), // Soft Warm Caramel
          surface: cardColor,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: warmSurface,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          iconTheme: IconThemeData(color: Color(0xFF4E342E)),
          titleTextStyle: TextStyle(
            color: Color(0xFF4E342E), // Deep Warm Espresso
            fontSize: 19,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
        ),
        cardTheme: CardTheme(
          color: cardColor,
          elevation: 0.8,
          shadowColor: const Color(0x146D4C41),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryWarmBrown,
            foregroundColor: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryWarmBrown,
            side: const BorderSide(color: Color(0xFFD7CCC8), width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
