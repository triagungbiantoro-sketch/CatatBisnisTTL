import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart'; // pastikan path sesuai struktur folder

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi UMKM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Warna utama tomato
        primaryColor: const Color(0xFFFF6347),
        scaffoldBackgroundColor: Colors.white, // background putih
        cardColor: Colors.white, // kartu putih juga
        canvasColor: Colors.white,

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6347),
          primary: const Color(0xFFFF6347),
          secondary: const Color(0xFFFF6347),
          background: Colors.white,
          surface: Colors.white,
        ),
        useMaterial3: true,

        // AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFF6347),
          foregroundColor: Colors.white, // teks & ikon
          elevation: 0,
        ),

        // ElevatedButton
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6347),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),

        // TextButton
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFFF6347),
          ),
        ),

        // FAB
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFFF6347),
          foregroundColor: Colors.white,
        ),

        // ListTile highlight
        listTileTheme: const ListTileThemeData(
          selectedColor: Color(0xFFFF6347),
        ),

        // ProgressBar & Slider
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFFFF6347),
        ),
      ),
      home: const DashboardScreen(), // dashboard sebagai halaman utama
    );
  }
}
