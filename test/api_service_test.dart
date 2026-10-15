import 'dart:convert';

import 'package:biblio_track/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(storageChannel, (_) async => null);

  tearDown(() {
    ApiService.client.close();
    ApiService.client = http.Client();
    ApiService.currentUser = null;
    ApiService.currentToken = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (_) async => null);
  });

  test('normalizes configured API URLs and requires HTTPS for production', () {
    expect(
      ApiService.resolveBaseUrl(
        ' https://api.example.test/api/ ',
        requireHttps: true,
      ),
      'https://api.example.test/api',
    );
    expect(
      () => ApiService.resolveBaseUrl(
        'http://api.example.test/api',
        requireHttps: true,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'login sends credentials to the configured endpoint and stores the session',
    () async {
      final fake = _FakeClient();
      ApiService.client = fake;

      final user = await ApiService.login(
        correo: 'ana@example.test',
        password: 'secret123',
      );

      expect(fake.request!.url, Uri.parse('${ApiService.baseUrl}/auth/login'));
      expect(fake.request!.method, 'POST');
      expect(jsonDecode(fake.request!.body), {
        'correo': 'ana@example.test',
        'password': 'secret123',
      });
      expect(user['nombre'], 'Ana');
      expect(ApiService.currentToken, 'persistent-token');
    },
  );

  test(
    'resource requests translate categories and include pagination',
    () async {
      final fake = _FakeClient(responseBody: '[]');
      ApiService.client = fake;

      final resources = await ApiService.getRecursos(
        query: 'equipo',
        tipo: 'Equipos',
        page: 2,
      );

      expect(resources, isEmpty);
      expect(
        fake.request!.url.path,
        '${Uri.parse(ApiService.baseUrl).path}/recursos',
      );
      expect(fake.request!.url.queryParameters, {
        'q': 'equipo',
        'tipo': 'Equipo',
        'page': '2',
        'limit': '100',
      });
    },
  );

  test('admin profile edits send and return personal fields', () async {
    final fake = _FakeClient(
      responseBody: jsonEncode({
        'usuario': {
          'id': 'u1',
          'nombre': 'Ana Pérez',
          'correo': 'ana@example.test',
          'carnet': 'A1',
          'carrera': 'Bibliotecología',
        },
      }),
    );
    ApiService.client = fake;
    ApiService.currentToken = 'admin-token';
    ApiService.currentUser = {'id': 'admin-1', 'rol': 'Administrador'};

    final user = await ApiService.editarUsuario(
      id: 'u1',
      nombre: ' Ana Pérez ',
      correo: ' ana@example.test ',
      carnet: ' A1 ',
      carrera: ' Bibliotecología ',
    );

    expect(fake.request!.method, 'PUT');
    expect(
      fake.request!.url,
      Uri.parse('${ApiService.baseUrl}/admin/usuarios/u1'),
    );
    expect(fake.request!.headers['authorization'], 'Bearer admin-token');
    expect(jsonDecode(fake.request!.body), {
      'nombre': 'Ana Pérez',
      'correo': 'ana@example.test',
      'carnet': 'A1',
      'carrera': 'Bibliotecología',
    });
    expect(user['nombre'], 'Ana Pérez');
  });
}

class _FakeClient extends http.BaseClient {
  _FakeClient({this.responseBody});

  final String? responseBody;
  http.Request? request;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    this.request = request as http.Request;
    final body =
        responseBody ??
        jsonEncode({
          'usuario': {'id': 'u1', 'nombre': 'Ana', 'rol': 'Estudiante'},
          'token': 'persistent-token',
        });
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
