import 'package:flutter/material.dart';

import 'screens/login_screen.dart';

void main() {
  runApp(const BiblioTrackApp());
}

class BiblioTrackApp extends StatelessWidget {
  const BiblioTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF09144D);
    const canvas = Color(0xFFF5F7FB);
    const surface = Colors.white;
    return MaterialApp(
      title: 'Biblio Track',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: blue, surface: surface),
        useMaterial3: true,
        scaffoldBackgroundColor: canvas,
        appBarTheme: const AppBarTheme(
          backgroundColor: canvas,
          foregroundColor: blue,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: blue.withAlpha(24)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: blue, width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: const LoginScreen(), // Aquí es donde llamamos a tu pantalla
    );
  }
}
