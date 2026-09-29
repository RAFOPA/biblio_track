import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  // Esta dirección debe apuntar a la PC donde se ejecuta backend/index.js.
  static const String baseUrl = 'http://192.168.40.9:3000/api';
  static Map<String, dynamic>? currentUser;
  static String? currentToken;

  static bool correoValido(String correo) => RegExp(
    r'^[^\s@.][^\s@]*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$',
  ).hasMatch(correo.trim());

  static Future<Map<String, dynamic>> login({
    required String correo,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'correo': correo, 'password': password}),
    );
    final user = _readUser(response);
    currentUser = user;
    currentToken = jsonDecode(response.body)['token'] as String?;
    return user;
  }

  static Future<Map<String, dynamic>> register({
    required String nombre,
    required String correo,
    required String password,
    String carnet = '',
    String carrera = '',
    String rol = 'Estudiante',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre': nombre,
        'correo': correo,
        'password': password,
        'carnet': carnet,
        'carrera': carrera,
        'rol': rol,
      }),
    );
    return _readUser(response);
  }

  static Future<List<dynamic>> getRecursos({
    String query = '',
    String tipo = 'Todos',
  }) async {
    final apiType = switch (tipo) {
      'Libros' => 'Libro',
      'Computadoras' => 'Computadora',
      _ => tipo,
    };
    final uri = Uri.parse('$baseUrl/recursos').replace(
      queryParameters: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (apiType != 'Todos') 'tipo': apiType,
      },
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception(
      _errorMessage(response, 'No se pudieron cargar los recursos.'),
    );
  }

  static Future<Map<String, dynamic>> reservarRecurso({
    required String recursoId,
    required int duracionMinutos,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/recursos/$recursoId/reservas'),
      headers: _authHeaders,
      body: jsonEncode({'duracionMinutos': duracionMinutos}),
    );
    final body = _readBody(response);
    return body['reserva'] as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getMisReservas() async {
    final response = await http.get(
      Uri.parse('$baseUrl/reservas/mias'),
      headers: _authHeaders,
    );
    return _readList(response);
  }

  static Future<Map<String, dynamic>> crearPrestamoPendiente(
    String reservaId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/prestamos/pendientes'),
      headers: _authHeaders,
      body: jsonEncode({'reservaId': reservaId}),
    );
    return _readBody(response);
  }

  static Future<List<dynamic>> getMisPrestamos() async {
    final response = await http.get(
      Uri.parse('$baseUrl/prestamos/mios'),
      headers: _authHeaders,
    );
    return _readList(response);
  }

  static Future<Map<String, dynamic>> getMiPerfil() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: _authHeaders,
    );
    final body = _readBody(response);
    final user = body['usuario'] as Map<String, dynamic>;
    currentUser = {...?currentUser, ...user};
    return user;
  }

  static Future<void> guardarFotoPerfil(String fotoPerfil) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/me/photo'),
      headers: _authHeaders,
      body: jsonEncode({'fotoPerfil': fotoPerfil}),
    );
    _readBody(response);
    currentUser = {...?currentUser, 'fotoPerfil': fotoPerfil};
  }

  static Future<void> cambiarPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/password'),
      headers: _authHeaders,
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    _readBody(response);
  }

  static Future<String> solicitarRecuperacion(String correo) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'correo': correo}),
    );
    final body = _readBody(response);
    return body['mensaje']?.toString() ?? 'Revisa tu correo para continuar.';
  }

  static Future<String> restablecerPassword({
    required String correo,
    required String codigo,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'correo': correo,
        'codigo': codigo,
        'newPassword': newPassword,
      }),
    );
    final body = _readBody(response);
    return body['mensaje']?.toString() ?? 'Contraseña restablecida.';
  }

  static Future<List<dynamic>> getFavoritos() async {
    final response = await http.get(
      Uri.parse('$baseUrl/favoritos/mios'),
      headers: _authHeaders,
    );
    return _readList(response);
  }

  static Future<void> agregarFavorito(String recursoId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/favoritos/$recursoId'),
      headers: _authHeaders,
      body: jsonEncode({}),
    );
    _readBody(response);
  }

  static Future<void> quitarFavorito(String recursoId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/favoritos/$recursoId'),
      headers: _authHeaders,
    );
    _readBody(response);
  }

  static Future<List<dynamic>> getNotificaciones() async {
    final response = await http.get(
      Uri.parse('$baseUrl/notificaciones/mias'),
      headers: _authHeaders,
    );
    return _readList(response);
  }

  static Future<void> eliminarNotificacion(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/notificaciones/mias/$id'),
      headers: _authHeaders,
    );
    _readBody(response);
  }

  static Future<Map<String, dynamic>> getPrestamoPorQr(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/prestamos/qr/${Uri.encodeComponent(token)}'),
      headers: _authHeaders,
    );
    final body = _readBody(response);
    return body['prestamo'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> confirmarPrestamo({
    required String prestamoId,
    required int plazoDias,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/prestamos/$prestamoId/confirmar'),
      headers: _authHeaders,
      body: jsonEncode({'plazoDias': plazoDias}),
    );
    final body = _readBody(response);
    return body['prestamo'] as Map<String, dynamic>;
  }

  static Future<void> logout() async {
    try {
      if (currentToken != null) {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: _authHeaders,
        );
      }
    } catch (_) {
      // La sesión local se cierra aunque el servidor no responda.
    } finally {
      currentToken = null;
      currentUser = null;
    }
  }

  static Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    if (currentToken != null) 'Authorization': 'Bearer $currentToken',
  };

  static Map<String, dynamic> _readBody(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw Exception(
      body['error']?.toString() ?? 'No se pudo completar la solicitud.',
    );
  }

  static List<dynamic> _readList(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300)
      return body as List<dynamic>;
    if (body is Map<String, dynamic>) {
      throw Exception(
        body['error']?.toString() ?? 'No se pudo cargar la información.',
      );
    }
    throw Exception('No se pudo cargar la información.');
  }

  static Map<String, dynamic> _readUser(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body['usuario'] as Map<String, dynamic>;
    }
    throw Exception(
      body['error']?.toString() ?? 'No se pudo completar la solicitud.',
    );
  }

  static String _errorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['error']?.toString() ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
