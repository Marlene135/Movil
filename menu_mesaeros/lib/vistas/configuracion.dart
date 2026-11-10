// vistas/configuracion.dart - Configuración del servidor (IP / dominio, puerto y ruta).
// Se guarda en el dispositivo; ya no hay que modificar el código para cambiar la IP.
import 'package:flutter/material.dart';
import '../servicios/api_service.dart';
import '../widgets/ui.dart';

class ConfiguracionVista extends StatefulWidget {
  const ConfiguracionVista({super.key});

  @override
  State<ConfiguracionVista> createState() => _ConfiguracionVistaState();
}

class _ConfiguracionVistaState extends State<ConfiguracionVista> {
  final _host = TextEditingController(text: ApiService.host);
  final _puerto = TextEditingController(text: ApiService.puerto);
  final _ruta = TextEditingController(text: ApiService.ruta);
  bool _https = ApiService.https;
  bool _probando = false;
  String? _resultado;
  bool _resultadoOk = false;

  @override
  void dispose() {
    _host.dispose();
    _puerto.dispose();
    _ruta.dispose();
    super.dispose();
  }

  /// Quita "http://", "https://" y rutas si el usuario pega una URL completa.
  String _limpiarHost(String v) {
    var h = v.trim();
    h = h.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    final i = h.indexOf('/');
    if (i >= 0) h = h.substring(0, i);
    return h;
  }

  Future<void> _aplicar() async {
    // Si pegaron "192.168.1.50:8081" se separa el puerto automáticamente.
    var host = _limpiarHost(_host.text);
    var puerto = _puerto.text.trim();
    final partes = host.split(':');
    if (partes.length == 2 && int.tryParse(partes[1]) != null) {
      host = partes[0];
      if (puerto.isEmpty) puerto = partes[1];
    }
    await ApiService.guardarConfig(host: host, puerto: puerto, ruta: _ruta.text, https: _https);
    if (!mounted) return;
    _host.text = ApiService.host;
    _puerto.text = ApiService.puerto;
    _ruta.text = ApiService.ruta;
  }

  Future<void> _guardar() async {
    if (_limpiarHost(_host.text).isEmpty) {
      mensaje(context, 'Escribe la IP o el dominio del servidor.', error: true);
      return;
    }
    await _aplicar();
    if (!mounted) return;
    mensaje(context, 'Configuración guardada.');
    Navigator.pop(context);
  }

  Future<void> _probar() async {
    if (_limpiarHost(_host.text).isEmpty) {
      mensaje(context, 'Escribe la IP o el dominio del servidor.', error: true);
      return;
    }
    await _aplicar();
    setState(() {
      _probando = true;
      _resultado = null;
    });
    try {
      // login.php sin PIN responde si el servidor y la base de datos están bien.
      await ApiService.post('login.php', body: {});
      _resultadoOk = true;
      _resultado = 'Conexión correcta con ${ApiService.baseUrl}';
    } on ApiException catch (e) {
      // Si el servidor contestó con un error de la API, sí hay conexión.
      if (e.codigo != null) {
        _resultadoOk = true;
        _resultado = 'El servidor respondió (${ApiService.baseUrl}).';
      } else {
        _resultadoOk = false;
        _resultado = e.mensaje;
      }
    } catch (e) {
      _resultadoOk = false;
      _resultado = 'No se pudo conectar: $e';
    } finally {
      if (mounted) setState(() => _probando = false);
    }
  }

  Future<void> _restablecer() async {
    final ok = await confirmar(context, 'Restablecer', '¿Volver a la configuración original del servidor?',
        aceptar: 'Restablecer');
    if (!ok) return;
    await ApiService.restablecerConfig();
    if (!mounted) return;
    setState(() {
      _host.text = ApiService.host;
      _puerto.text = ApiService.puerto;
      _ruta.text = ApiService.ruta;
      _https = ApiService.https;
      _resultado = null;
    });
    mensaje(context, 'Configuración restablecida.');
  }

  InputDecoration _deco(String etiqueta, {String? ayuda, IconData? icono}) => InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        prefixIcon: icono == null ? null : Icon(icono, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBorde)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBorde)),
      );

  @override
  Widget build(BuildContext context) {
    return TemaSazon(
      child: Scaffold(
        backgroundColor: kFondo,
        appBar: AppBar(
          backgroundColor: kFondo,
          elevation: 0,
          foregroundColor: kTexto,
          title: const Text('Configuración', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TarjetaSazon(
                      radio: 24,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Servidor',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTexto)),
                          const SizedBox(height: 4),
                          const Text('Dirección donde está el sistema (PHP / base de datos).',
                              style: TextStyle(fontSize: 12, color: kTextoSuave)),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _host,
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            decoration: _deco('IP o dominio', ayuda: 'Ej. 192.168.1.50 o sazont.tech', icono: Icons.dns_rounded),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _puerto,
                                  keyboardType: TextInputType.number,
                                  decoration: _deco('Puerto', ayuda: 'Vacío = estándar'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _ruta,
                                  autocorrect: false,
                                  decoration: _deco('Ruta de la API', ayuda: 'Ej. /api o /KDS/api'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _https,
                            activeThumbColor: kVerde,
                            onChanged: (v) => setState(() => _https = v),
                            title: const Text('Usar HTTPS', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          const Divider(height: 24),
                          Text('URL resultante:', style: TextStyle(fontSize: 11, color: kTexto.withValues(alpha: 0.6))),
                          const SizedBox(height: 2),
                          ListenableBuilder(
                            listenable: Listenable.merge([_host, _puerto, _ruta]),
                            builder: (_, __) {
                              final h = _limpiarHost(_host.text);
                              final p = _puerto.text.trim();
                              var r = _ruta.text.trim();
                              if (r.isNotEmpty && !r.startsWith('/')) r = '/$r';
                              return SelectableText(
                                '${_https ? 'https' : 'http'}://${h.isEmpty ? '…' : h}${p.isEmpty ? '' : ':$p'}$r',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: kTexto),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    if (_resultado != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_resultadoOk ? kVerde : kRojo).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(_resultadoOk ? Icons.check_circle : Icons.error_outline,
                                color: _resultadoOk ? kVerde : kRojo),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_resultado!,
                                  style: TextStyle(color: _resultadoOk ? kVerde : kRojo, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _probando ? null : _probar,
                      icon: _probando
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.wifi_tethering_rounded, size: 20),
                      label: const Text('Probar conexión'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kTexto,
                        minimumSize: const Size.fromHeight(50),
                        side: const BorderSide(color: kBordePill),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _guardar,
                      icon: const Icon(Icons.save_rounded, size: 20),
                      label: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w800)),
                      style: FilledButton.styleFrom(
                        backgroundColor: kTexto,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    TextButton(
                      onPressed: _restablecer,
                      child: const Text('Restablecer valores originales', style: TextStyle(color: kTextoSuave)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}