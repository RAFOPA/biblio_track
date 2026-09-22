import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Tu IP fija para que el teléfono hable con la PC
  static const String baseUrl = 'http://192.168.40.9:3000/api';

  // 1. Obtener recursos (libros/computadoras)
  static Future<List<dynamic>> getRecursos() async {
    final response = await http.get(Uri.parse('$baseUrl/recursos'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al cargar recursos');
    }
  }

  // 2. Aquí mismo puedes agregar después el Login, Préstamos, etc.
}