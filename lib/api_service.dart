import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'session_store.dart';

class ApiService {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static final String _defaultBaseUrl = kIsWeb
      ? 'http://${Uri.base.host.isEmpty ? 'localhost' : Uri.base.host}:3000/api'
      : 'http://192.168.40.9:3000/api';
  static final String baseUrl = resolveBaseUrl(
    _configuredBaseUrl.isEmpty ? _defaultBaseUrl : _configuredBaseUrl,
    requireHttps: kReleaseMode || kProfileMode,
  );
  static http.Client client = http.Client();
  static final ValueNotifier<int> availabilityVersion = ValueNotifier(0);
  static Map<String, dynamic>? currentUser;
  static String? currentToken;
  static void Function(String message)? onSessionInvalidated;

  static String resolveBaseUrl(String value, {required bool requireHttps}) {
    final normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme)) {
      throw StateError('API_BASE_URL debe ser una URL HTTP o HTTPS completa.');
    }
    if (requireHttps && uri.scheme != 'https') {
      throw StateError(
        'Las compilaciones de producción requieren API_BASE_URL con HTTPS.',
      );
    }
    return normalized;
  }

  static bool correoValido(String correo) => RegExp(
    r'^[^\s@.][^\s@]*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$',
  ).hasMatch(correo.trim());

  static Future<Map<String, dynamic>> login({
    required String correo,
    required String password,
  }) async {
    late final http.Response response;
    try {
      response = await client
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'correo': correo, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception(
        'El servidor no respondió. Verifica que la API esté iniciada y que la URL sea correcta.',
      );
    }
    final user = _readUser(response);
    currentUser = user;
    currentToken = jsonDecode(response.body)['token'] as String?;
    final token = currentToken;
    if (token == null || token.isEmpty) {
      currentToken = null;
      currentUser = null;
      throw Exception('El servidor no devolvió una sesión válida.');
    }
    try {
      await SessionStore.saveSession(token: token, user: user);
    } catch (_) {
      await logout();
      rethrow;
    }
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
    final response = await client.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre': nombre,
        'correo': correo,
        'password': password,
        if (carnet.trim().isNotEmpty) 'carnet': carnet.trim(),
        if (carrera.trim().isNotEmpty) 'carrera': carrera.trim(),
        'rol': rol,
      }),
    );
    return _readUser(response);
  }

  static Future<List<dynamic>> getRecursos({
    String query = '',
    String tipo = 'Todos',
    int page = 1,
    int limit = 100,
  }) async {
    final apiType = switch (tipo) {
      'Libros' => 'Libro',
      'Computadoras' => 'Computadora',
      'Equipos' => 'Equipo',
      'Otros' => 'Otro',
      _ => tipo,
    };
    final uri = Uri.parse('$baseUrl/recursos').replace(
      queryParameters: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (apiType != 'Todos') 'tipo': apiType,
        'page': '$page',
        'limit': '$limit',
      },
    );
    final response = await client.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception(
      _errorMessage(response, 'No se pudieron cargar los recursos.'),
    );
  }

  static Future<Map<String, dynamic>> getAdminRecursos({
    String query = '',
    String autor = '',
    String anio = '',
    String editorial = '',
    String categoria = '',
    String tipo = '',
    int page = 1,
    int limit = 30,
  }) async {
    final response = await client.get(
      Uri.parse('$baseUrl/admin/recursos').replace(
        queryParameters: {
          if (query.trim().isNotEmpty) 'q': query.trim(),
          if (autor.trim().isNotEmpty) 'autor': autor.trim(),
          if (anio.trim().isNotEmpty) 'anio': anio.trim(),
          if (editorial.trim().isNotEmpty) 'editorial': editorial.trim(),
          if (categoria.trim().isNotEmpty) 'categoria': categoria.trim(),
          if (tipo.trim().isNotEmpty) 'tipo': tipo.trim(),
          'page': '$page',
          'limit': '$limit',
        },
      ),
      headers: _authHeaders,
    );
    return _readAdminPage(response, page: page, limit: limit);
  }

  static Future<Map<String, dynamic>> saveAdminRecurso(
    Map<String, dynamic> recurso, {
    String? id,
  }) async {
    final response = id == null
        ? await client.post(
            Uri.parse('$baseUrl/admin/recursos'),
            headers: _authHeaders,
            body: jsonEncode(recurso),
          )
        : await client.put(
            Uri.parse('$baseUrl/admin/recursos/$id'),
            headers: _authHeaders,
            body: jsonEncode(recurso),
          );
    final result = _readBody(response);
    availabilityVersion.value++;
    return result;
  }

  static Future<void> darDeBajaRecurso(String id) async {
    final response = await client.delete(
      Uri.parse('$baseUrl/admin/recursos/$id'),
      headers: _authHeaders,
    );
    _readBody(response);
    availabilityVersion.value++;
  }

  static Future<Map<String, dynamic>> getAdminUsuarios({
    String query = '',
    String rol = '',
    String estado = '',
    int page = 1,
    int limit = 30,
  }) async {
    final response = await client.get(
      Uri.parse('$baseUrl/admin/usuarios').replace(
        queryParameters: {
          if (query.trim().isNotEmpty) 'q': query.trim(),
          if (rol.isNotEmpty) 'rol': rol,
          if (estado.isNotEmpty) 'estado': estado,
          'page': '$page',
          'limit': '$limit',
        },
      ),
      headers: _authHeaders,
    );
    return _readAdminPage(response, page: page, limit: limit);
  }

  static Future<void> cambiarRolUsuario(String id, String rol) async {
    final response = await client.patch(
      Uri.parse('$baseUrl/admin/usuarios/$id/rol'),
      headers: _authHeaders,
      body: jsonEncode({'rol': rol}),
    );
    _readBody(response);
  }

  static Future<Map<String, dynamic>> editarUsuario({
    required String id,
    required String nombre,
    required String correo,
    required String carnet,
    required String carrera,
  }) async {
    final response = await client.put(
      Uri.parse('$baseUrl/admin/usuarios/$id'),
      headers: _authHeaders,
      body: jsonEncode({
        'nombre': nombre.trim(),
        'correo': correo.trim(),
        'carnet': carnet.trim(),
        'carrera': carrera.trim(),
      }),
    );
    final body = _readBody(response);
    final user = body['usuario'] as Map<String, dynamic>;
    final currentId =
        currentUser?['id']?.toString() ?? currentUser?['_id']?.toString();
    if (currentId == id) currentUser = {...?currentUser, ...user};
    return user;
  }

  static Future<void> cambiarSuspensionUsuario(String id, bool baneado) async {
    final response = await client.patch(
      Uri.parse('$baseUrl/admin/usuarios/$id/suspension'),
      headers: _authHeaders,
      body: jsonEncode({'baneado': baneado}),
    );
    _readBody(response);
  }

  static Future<Map<String, dynamic>> getAdminPrestamosActivos({
    String query = '',
    int page = 1,
    int limit = 30,
  }) async {
    final response = await client.get(
      Uri.parse('$baseUrl/admin/prestamos/activos').replace(
        queryParameters: {
          if (query.trim().isNotEmpty) 'q': query.trim(),
          'page': '$page',
          'limit': '$limit',
        },
      ),
      headers: _authHeaders,
    );
    return _readAdminPage(response, page: page, limit: limit);
  }

  static Future<Map<String, dynamic>> devolverPrestamoAdmin(String id) async {
    final response = await client.patch(
      Uri.parse('$baseUrl/admin/prestamos/$id/devolver'),
      headers: _authHeaders,
    );
    final body = _readBody(response);
    availabilityVersion.value++;
    return body['prestamo'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getAdminReporte({
    DateTime? start,
    DateTime? end,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/reportes').replace(
      queryParameters: {
        if (start != null)
          'start':
              '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
        if (end != null)
          'end':
              '${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}',
      },
    );
    final response = await client.get(uri, headers: _authHeaders);
    return _readBody(response);
  }

  static Future<List<dynamic>> getAdminCatalogoReportes() async {
    final response = await client.get(
      Uri.parse('$baseUrl/admin/reportes/catalogo'),
      headers: _authHeaders,
    );
    return _readList(response);
  }

  static Future<Map<String, dynamic>> getAdminReporteDetallado({
    required String type,
    DateTime? start,
    DateTime? end,
  }) async {
    final response = await client.get(
      Uri.parse('$baseUrl/admin/reportes/detalle').replace(
        queryParameters: {
          'type': type,
          if (start != null) 'start': _dateQueryValue(start),
          if (end != null) 'end': _dateQueryValue(end),
        },
      ),
      headers: _authHeaders,
    );
    return _readBody(response);
  }

  static String _dateQueryValue(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static Future<Map<String, dynamic>> reservarRecurso({
    required String recursoId,
    required int duracionMinutos,
  }) async {
    final response = await client.post(
      Uri.parse('$baseUrl/recursos/$recursoId/reservas'),
      headers: _authHeaders,
      body: jsonEncode({'duracionMinutos': duracionMinutos}),
    );
    final body = _readBody(response);
    availabilityVersion.value++;
    return body['reserva'] as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getMisReservas() async {
    final response = await client.get(
      Uri.parse('$baseUrl/reservas/mias'),
      headers: _authHeaders,
    );
    return _readList(response);
  }

  static Future<Map<String, dynamic>> crearPrestamoPendiente(
    String reservaId,
  ) async {
    final response = await client.post(
      Uri.parse('$baseUrl/prestamos/pendientes'),
      headers: _authHeaders,
      body: jsonEncode({'reservaId': reservaId}),
    );
    final result = _readBody(response);
    return result;
  }

  static Future<List<dynamic>> getMisPrestamos() async {
    final response = await client.get(
      Uri.parse('$baseUrl/prestamos/mios'),
      headers: _authHeaders,
    );
    return _readList(response);
  }

  static Future<Map<String, dynamic>> getMiPerfil() async {
    final response = await client.get(
      Uri.parse('$baseUrl/users/me'),
      headers: _authHeaders,
    );
    final body = _readBody(response);
    final user = body['usuario'] as Map<String, dynamic>;
    currentUser = {...?currentUser, ...user};
    return user;
  }

  static Future<void> guardarFotoPerfil(String fotoPerfil) async {
    final response = await client.put(
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
    final response = await client.post(
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
    final response = await client.post(
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
    final response = await client.post(
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
    final response = await client.get(
      Uri.parse('$baseUrl/favoritos/mios'),
      headers: _authHeaders,
    );
    return _readList(response);
  }

  static Future<void> agregarFavorito(String recursoId) async {
    final response = await client.post(
      Uri.parse('$baseUrl/favoritos/$recursoId'),
      headers: _authHeaders,
      body: jsonEncode({}),
    );
    _readBody(response);
  }

  static Future<void> quitarFavorito(String recursoId) async {
    final response = await client.delete(
      Uri.parse('$baseUrl/favoritos/$recursoId'),
      headers: _authHeaders,
    );
    _readBody(response);
  }

  static Future<List<dynamic>> getNotificaciones() async {
    final response = await client.get(
      Uri.parse('$baseUrl/notificaciones/mias'),
      headers: _authHeaders,
    );
    return _readList(response);
  }

  static Future<List<dynamic>> getAdminNotificacionesVencidas() async {
    final response = await client.get(
      Uri.parse('$baseUrl/admin/notificaciones/vencidas'),
      headers: _authHeaders,
    );
    return _readList(response);
  }

  static Future<void> eliminarNotificacion(String id) async {
    final response = await client.delete(
      Uri.parse('$baseUrl/notificaciones/mias/$id'),
      headers: _authHeaders,
    );
    _readBody(response);
  }

  static Future<Map<String, dynamic>> getPrestamoPorQr(String token) async {
    final response = await client.get(
      Uri.parse('$baseUrl/admin/prestamos/qr/${Uri.encodeComponent(token)}'),
      headers: _authHeaders,
    );
    final body = _readBody(response);
    return body['prestamo'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> confirmarPrestamo({
    required String prestamoId,
    required String plazoUnidad,
    required int plazoValor,
  }) async {
    final response = await client.post(
      Uri.parse('$baseUrl/admin/prestamos/$prestamoId/confirmar'),
      headers: _authHeaders,
      body: jsonEncode({'plazoUnidad': plazoUnidad, 'plazoValor': plazoValor}),
    );
    final body = _readBody(response);
    availabilityVersion.value++;
    return body['prestamo'] as Map<String, dynamic>;
  }

  static Future<void> rechazarPrestamoAdmin(String prestamoId) async {
    final response = await client.post(
      Uri.parse('$baseUrl/admin/prestamos/$prestamoId/rechazar'),
      headers: _authHeaders,
    );
    _readBody(response);
    availabilityVersion.value++;
  }

  static Future<void> logout() async {
    try {
      if (currentToken != null) {
        await client
            .post(Uri.parse('$baseUrl/auth/logout'), headers: _authHeaders)
            .timeout(const Duration(seconds: 4));
      }
    } catch (_) {
    } finally {
      currentToken = null;
      currentUser = null;
      try {
        await SessionStore.clearSession();
      } catch (_) {}
    }
  }

  static void _invalidateSessionIfUnauthorized(http.Response response) {
    if (response.statusCode != 401 || currentToken == null) return;
    currentToken = null;
    currentUser = null;
    onSessionInvalidated?.call(
      'Tu sesión se cerró porque se inició con esta cuenta en otro dispositivo o dejó de ser válida.',
    );
  }

  static Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    if (currentToken != null) 'Authorization': 'Bearer $currentToken',
  };

  static Map<String, dynamic> _readBody(http.Response response) {
    _invalidateSessionIfUnauthorized(response);
    final decoded = _decodeResponseBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('El servidor devolvió una respuesta JSON inválida.');
    }
    final body = decoded;
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw Exception(
      body['error']?.toString() ?? 'No se pudo completar la solicitud.',
    );
  }

  static List<dynamic> _readList(http.Response response) {
    _invalidateSessionIfUnauthorized(response);
    final body = _decodeResponseBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300)
      return body as List<dynamic>;
    if (body is Map<String, dynamic>) {
      throw Exception(
        body['error']?.toString() ?? 'No se pudo cargar la información.',
      );
    }
    throw Exception('No se pudo cargar la información.');
  }

  static Map<String, dynamic> _readAdminPage(
    http.Response response, {
    required int page,
    required int limit,
  }) {
    _invalidateSessionIfUnauthorized(response);
    final body = _decodeResponseBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is Map<String, dynamic> && body['items'] is List<dynamic>) {
        return body;
      }
      // Keep the app compatible while an already-running backend is restarted.
      if (body is List<dynamic>) {
        final start = ((page - 1) * limit).clamp(0, body.length).toInt();
        final end = (start + limit).clamp(start, body.length).toInt();
        return {
          'items': body.sublist(start, end),
          'total': body.length,
          'page': page,
          'limit': limit,
        };
      }
      throw Exception(
        'El servidor devolvió una lista administrativa inválida.',
      );
    }
    if (body is Map<String, dynamic>) {
      throw Exception(
        body['error']?.toString() ?? 'No se pudo cargar la información.',
      );
    }
    throw Exception('No se pudo cargar la información.');
  }

  static Map<String, dynamic> _readUser(http.Response response) {
    _invalidateSessionIfUnauthorized(response);
    final decoded = _decodeResponseBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('El servidor devolvió una respuesta JSON inválida.');
    }
    final body = decoded;
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

  static dynamic _decodeResponseBody(http.Response response) {
    try {
      return jsonDecode(response.body);
    } on FormatException {
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      final bodyStart = response.body.trimLeft().toLowerCase();
      if (contentType.contains('text/html') ||
          bodyStart.startsWith('<html') ||
          bodyStart.startsWith('<!doctype html')) {
        throw Exception(
          'El servidor respondió una página HTML en vez del reporte JSON (HTTP ${response.statusCode}). Reinicia el backend actualizado y vuelve a intentarlo.',
        );
      }
      throw Exception(
        'El servidor devolvió una respuesta inválida (HTTP ${response.statusCode}).',
      );
    }
  }
}
