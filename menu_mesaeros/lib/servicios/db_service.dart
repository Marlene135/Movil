import 'dart:convert';
import 'package:http/http.dart' as http;

class DbService {
  static const String _baseUrl = 'http://192.168.1.34:8081/KDS';

  /// Valida el PIN contra el endpoint PHP
  static Future<Map<String, dynamic>?> validarPin(String pin) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pin': pin}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'ok') {
          return data['usuario'];
        }
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('Error al conectar con login.php: $e');
      rethrow;
    }
  }

  /// Obtiene la lista de mesas (puedes conectar un endpoint mesas.php más adelante)
  static Future<List<Map<String, dynamic>>> obtenerMesas() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/mesas.php'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
      throw Exception('No se pudieron obtener las mesas');
    } catch (e) {
      // ignore: avoid_print
      print('Error o fallback en mesas: $e');
      rethrow;
    }
  }
}