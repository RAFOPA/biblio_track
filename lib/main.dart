import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const BiblioTrackApp());
}

class BiblioTrackApp extends StatelessWidget {
  const BiblioTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biblio Track',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF09144D)),
        useMaterial3: true,
      ),
      home: const LoginScreen(), // Aquí es donde llamamos a tu pantalla
    );
  }
}