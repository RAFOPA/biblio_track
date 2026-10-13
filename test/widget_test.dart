import 'package:biblio_track/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login screen validates missing credentials', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('BiblioTrack'), findsOneWidget);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ingresa tu correo.'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
  });
}
