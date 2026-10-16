// Cliente HTTP genérico: agrega el token de sesión, decodifica el JSON y
// convierte los errores del servidor en ApiException con mensajes legibles.
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String mensaje;
  final int? codigo;
  ApiException(this.mensaje, [this.codigo]);

  @override
  String toString() => mensaje;
}

class ApiService {
  // Se puede fijar al compilar:
  //   flutter run --dart-define=API_HOST=192.168.1.50
  //   flutter run --dart-define=API_HOST=10.0.2.2        (emulador Android)
  // Si no se define, usa el host desde el que se sirve la app (web) o 'localhost'.
  static const String _hostDefine = String.fromEnvironment('API_HOST');
  static const String _portDefine = String.fromEnvironment('API_PORT', defaultValue: '8081');
  static const String _pathDefine = String.fromEnvironment('API_PATH', defaultValue: '/KDS');

  /// Token de la sesión actual (lo entrega login.php).
  static String? token;

  /// Se llama cuando el servidor responde 401 con una sesión activa.
  static void Function()? onSesionExpirada;

  static String get baseUrl {
    final host = _hostDefine.isNotEmpty
        ? _hostDefine
        : (Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost');
    return 'http://$host:$_portDefine$_pathDefine';
  }

  static Uri _uri(String ruta, Map<String, dynamic>? query) {
    final params = <String, String>{};
    query?.forEach((k, v) {
      if (v != null) params[k] = v.toString();
    });
    final uri = Uri.parse('$baseUrl/$ruta');
    return params.isEmpty ? uri : uri.replace(queryParameters: params);
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Future<Map<String, dynamic>> get(String ruta, {Map<String, dynamic>? query}) =>
      _enviar('GET', ruta, query: query);

  static Future<Map<String, dynamic>> post(String ruta,
          {Map<String, dynamic>? query, Object? body}) =>
      _enviar('POST', ruta, query: query, body: body);

  static Future<Map<String, dynamic>> put(String ruta,
          {Map<String, dynamic>? query, Object? body}) =>
      _enviar('PUT', ruta, query: query, body: body);

  static Future<Map<String, dynamic>> delete(String ruta, {Map<String, dynamic>? query}) =>
      _enviar('DELETE', ruta, query: query);

  static Future<Map<String, dynamic>> _enviar(
    String metodo,
    String ruta, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    final uri = _uri(ruta, query);
    http.Response resp;
    try {
      final req = http.Request(metodo, uri);
      req.headers.addAll(_headers);
      if (body != null) req.body = jsonEncode(body);
      final streamed = await req.send().timeout(const Duration(seconds: 15));
      resp = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado en responder ($baseUrl).');
    } catch (_) {
      throw ApiException(
          'No se pudo conectar con el servidor ($baseUrl). Revisa que Apache/PHP estén encendidos y la red.');
    }

    final texto = utf8.decode(resp.bodyBytes);
    Map<String, dynamic> json;
    try {
      final dec = jsonDecode(texto);
      json = dec is Map<String, dynamic> ? dec : <String, dynamic>{'data': dec};
    } catch (_) {
      final muestra = texto.length > 160 ? texto.substring(0, 160) : texto;
      throw ApiException('Respuesta inválida del servidor (${resp.statusCode}): $muestra');
    }

    final fallo = resp.statusCode >= 400 || json['status'] == 'error';
    if (fallo) {
      final msg = (json['message'] ?? json['mensaje'] ?? 'Error ${resp.statusCode}').toString();
      if (resp.statusCode == 401 && token != null) {
        token = null;
        onSesionExpirada?.call();
      }
      throw ApiException(msg, resp.statusCode);
    }
    return json;
  }


  
}
