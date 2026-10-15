import 'dart:convert';
import 'dart:typed_data';

import 'package:biblio_track/api_service.dart';
import 'package:biblio_track/screens/admin_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  const sizes = [Size(320, 640), Size(600, 900), Size(1024, 768)];

  tearDown(() {
    ApiService.client.close();
    ApiService.client = http.Client();
    ApiService.currentToken = null;
    ApiService.currentUser = null;
  });

  for (final size in sizes) {
    testWidgets('report and user editor fit ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      ApiService.currentToken = 'responsive-test-token';
      ApiService.currentUser = {'id': 'admin-1', 'rol': 'Administrador'};
      ApiService.client = _AdminClient();

      await tester.pumpWidget(
        const MaterialApp(home: AdminManagementScreen(initialTab: 3)),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('admin-report-list')),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      expect(find.text('Préstamos por tipo de recurso'), findsOneWidget);
      expect(find.text('Usuarios con más préstamos'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('admin-tab-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar datos'));
      await tester.pumpAndSettle();
      expect(find.text('Editar datos del usuario'), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }
}

class _AdminClient extends http.BaseClient {
  static final _report = jsonEncode({
    'periodo': {
      'inicio': '2026-10-01T00:00:00.000Z',
      'fin': '2026-10-15T23:59:59.999Z',
    },
    'totales': {'usuarios': 8, 'recursos': 12, 'prestamos': 4, 'reservas': 5},
    'recursosMasSolicitados': [],
    'prestamosPorDia': [],
    'prestamosPorTipo': [
      {'tipo': 'Libro', 'prestamos': 3},
      {'tipo': 'Computadora', 'prestamos': 1},
    ],
    'usuariosConMasPrestamos': [
      {'nombre': 'Ana Pérez', 'carnet': 'A1', 'prestamos': 2},
    ],
  });
  static final _users = jsonEncode({
    'items': [
      {
        '_id': 'user-1',
        'nombre': 'Ana Pérez',
        'correo': 'ana@example.test',
        'carnet': 'A1',
        'carrera': 'Bibliotecología',
        'rol': 'Estudiante',
        'baneado': false,
      },
    ],
    'total': 1,
    'page': 1,
    'limit': 30,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request.url.path.endsWith('/reportes')
        ? _report
        : request.url.path.endsWith('/usuarios')
        ? _users
        : jsonEncode({'items': [], 'total': 0, 'page': 1, 'limit': 30});
    return http.StreamedResponse(
      Stream<Uint8List>.value(Uint8List.fromList(utf8.encode(body))),
      200,
    );
  }
}
