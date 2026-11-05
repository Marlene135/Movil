// Cliente HTTP genérico: agrega el token de sesión, decodifica el JSON y
// convierte los errores del servidor en ApiException con mensajes legibles.
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String mensaje;
  final int? codigo;
  ApiException(this.mensaje, [this.codigo]);

  @override
  String toString() => mensaje;
}

class ApiService {
<<<<<<< HEAD
  // Valores por defecto (se pueden fijar al compilar con --dart-define).
  // Desde la app se cambian en "Configuración" y se guardan en el dispositivo.
  static const String _hostDefine = String.fromEnvironment('API_HOST', defaultValue: 'sazont.tech');
  static const String _portDefine = String.fromEnvironment('API_PORT', defaultValue: '');
  static const String _pathDefine = String.fromEnvironment('API_PATH', defaultValue: '/api');

  static const String _kHost = 'cfg_host';
  static const String _kPuerto = 'cfg_puerto';
  static const String _kRuta = 'cfg_ruta';
  static const String _kHttps = 'cfg_https';

  /// Configuración actual del servidor (editable desde la app).
  static String host = _hostDefine;
  static String puerto = _portDefine;
  static String ruta = _pathDefine;
  static bool https = false;

  /// Carga la configuración guardada. Llamar una vez antes de runApp().
  static Future<void> cargarConfig() async {
    try {
      final p = await SharedPreferences.getInstance();
      host = p.getString(_kHost) ?? _hostDefine;
      puerto = p.getString(_kPuerto) ?? _portDefine;
      ruta = p.getString(_kRuta) ?? _pathDefine;
      https = p.getBool(_kHttps) ?? false;
    } catch (_) {
      // Si no se puede leer, se usan los valores por defecto.
    }
  }

  /// Guarda la configuración del servidor en el dispositivo.
  static Future<void> guardarConfig({
    required String host,
    required String puerto,
    required String ruta,
    required bool https,
  }) async {
    ApiService.host = host.trim();
    ApiService.puerto = puerto.trim();
    var r = ruta.trim();
    if (r.isNotEmpty && !r.startsWith('/')) r = '/$r';
    if (r.endsWith('/')) r = r.substring(0, r.length - 1);
    ApiService.ruta = r;
    ApiService.https = https;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kHost, ApiService.host);
    await p.setString(_kPuerto, ApiService.puerto);
    await p.setString(_kRuta, ApiService.ruta);
    await p.setBool(_kHttps, https);
  }

  /// Vuelve a los valores por defecto.
  static Future<void> restablecerConfig() async {
    final p = await SharedPreferences.getInstance();
    for (final k in [_kHost, _kPuerto, _kRuta, _kHttps]) {
      await p.remove(k);
    }
    host = _hostDefine;
    puerto = _portDefine;
    ruta = _pathDefine;
    https = false;
  }
=======
  // Se puede fijar al compilar
 // Cambia la IP local por tu dominio en Hostinger
static const String _hostDefine = String.fromEnvironment('API_HOST', defaultValue: 'sazont.tech');

// Como usaremos HTTPS/HTTP estándar en el servidor web, asegúrate de dejar el puerto vacío o en blanco
static const String _portDefine = String.fromEnvironment('API_PORT', defaultValue: ''); 

// Ajusta la ruta de la carpeta donde subiste tu API en el servidor (por ejemplo, '/api')
static const String _pathDefine = String.fromEnvironment('API_PATH', defaultValue: '/api');
>>>>>>> 59cc9c6 (modificacion en config.php y api_service.dart)

  /// Token de la sesión actual (lo entrega login.php).
  static String? token;

  /// Se llama cuando el servidor responde 401 con una sesión activa.
  static void Function()? onSesionExpirada;

  /// Host efectivo (si está vacío, usa el de la página web o un valor de respaldo).
  static String get hostEfectivo =>
      host.isNotEmpty ? host : (Uri.base.host.isNotEmpty ? Uri.base.host : '10.0.10.16');

  static String get baseUrl {
<<<<<<< HEAD
    final esquema = https ? 'https' : 'http';
    final pto = puerto.isEmpty ? '' : ':$puerto';
    return '$esquema://$hostEfectivo$pto$ruta';
=======
    final host = _hostDefine.isNotEmpty 
        ? _hostDefine 
        : (Uri.base.host.isNotEmpty ? Uri.base.host : '10.0.10.16');
        
    if (_portDefine.isEmpty) {
      return 'http://$host$_pathDefine';
    }
    return 'http://$host:$_portDefine$_pathDefine';
>>>>>>> 59cc9c6 (modificacion en config.php y api_service.dart)
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

