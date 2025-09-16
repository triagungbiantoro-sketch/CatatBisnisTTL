import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:get/get.dart'; // untuk multi-language
import 'screens/dashboard_screen.dart'; // sesuaikan path
import '../screens/lang.dart'; // file translation

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi AdMob SDK
  await MobileAds.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Aplikasi UMKM',
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(), // translation
      locale: const Locale('id', 'ID'), // default bahasa Indonesia
      fallbackLocale: const Locale('en', 'US'),
      theme: ThemeData(
        // Warna utama tomato
        primaryColor: const Color(0xFFFF6347),
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.white,
        canvasColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6347),
          primary: const Color(0xFFFF6347),
          secondary: const Color(0xFFFF6347),
          background: Colors.white,
          surface: Colors.white,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFF6347),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6347),
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFFF6347),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFFF6347),
          foregroundColor: Colors.white,
        ),
        listTileTheme: const ListTileThemeData(
          selectedColor: Color(0xFFFF6347),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFFFF6347),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
