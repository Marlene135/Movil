// vistas/cocina.dart - Pantalla KDS: comandas en vivo para cocina y barra.
import 'dart:async';
import 'package:flutter/material.dart';
import '../modulos/orden.dart';
import '../servicios/api_service.dart';
import '../servicios/db_service.dart';
import '../widgets/ui.dart';

class CocinaVista extends StatefulWidget {
  final Map<String, dynamic>? usuario;

  const CocinaVista({super.key, this.usuario});

  @override
  State<CocinaVista> createState() => _CocinaVistaState();
}

class _CocinaVistaState extends State<CocinaVista> {
  String? _estacion; // null = todas
  List<KdsItem> _items = [];
  bool _cargando = true;
  bool _ocupado = false;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _cargar(silencioso: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso && mounted) setState(() => _cargando = true);
    try {
      final items = await DbService.obtenerKds(estacion: _estacion);
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }

  Future<void> _cambiar(List<int> ids, String estado) async {
    setState(() => _ocupado = true);
    try {
      await DbService.cambiarEstadoItems(ids, estado);
    } on ApiException catch (e) {
      if (mounted) mensaje(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
    await _cargar(silencioso: true);
  }

  String? _siguiente(String estado) {
    switch (estado) {
      case 'PENDIENTE':
        return 'EN_PREPARACION';
      case 'EN_PREPARACION':
        return 'LISTO';
      case 'LISTO':
        return 'ENTREGADO';
      default:
        return null;
    }
  }

  String _textoAccion(String estado) {
    switch (estado) {
      case 'PENDIENTE':
        return 'Iniciar';
      case 'EN_PREPARACION':
        return 'Listo';
      default:
        return 'Entregar';
    }
  }

  Color _color(String e) {
    switch (e) {
      case 'EN_PREPARACION':
        return const Color(0xFFD99A00);
      case 'LISTO':
        return kEstadoLibre;
      default:
        return kEstadoLimpiar;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Agrupa por cuenta (ticket)
    final tickets = <int, List<KdsItem>>{};
    for (final it in _items) {
      tickets.putIfAbsent(it.idOrden, () => []).add(it);
    }

    return TemaSazon(
      child: Scaffold(
        backgroundColor: kFondo,
        appBar: AppBar(
          backgroundColor: kFondo,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 72,
          leadingWidth: 56,
          leading: BotonRedondo(
            icono: Icons.arrow_back_rounded,
            tooltip: 'Volver',
            onPressed: () => Navigator.maybePop(context),
          ),
          titleSpacing: 4,
          title: const TituloPagina(
            'KDS - Cocina / Barra',
            subtitulo: 'Control de comandas en cocina',
            icono: Icons.soup_kitchen_rounded,
            colorIcono: kAmbar,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: GestureDetector(
                  onTap: () => _cargar(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: kAmbar, borderRadius: BorderRadius.circular(30)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sync_rounded, size: 16, color: kTexto),
                        SizedBox(width: 6),
                        Text('Live 8s', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTexto)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          bottom: _ocupado
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(3),
                  child: LinearProgressIndicator(minHeight: 3, color: kAmbar),
                )
              : null,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 0,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _filtro('Todas', null),
                  _filtro('Cocina', 'cocina'),
                  _filtro('Barra', 'barra'),
                  const SizedBox(width: 6),
                  Text('${tickets.length} comandas · ${_items.length} platillos',
                      style: const TextStyle(color: kTextoSuave, fontSize: 12)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: const [
                    _Leyenda('< 10 min (Normal)', kCian, kTexto),
                    _Leyenda('10 – 20 min (Alerta)', kAmbar, kTexto),
                    _Leyenda('> 20 min (Urgente)', kEstadoOcupada, Colors.white),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator(color: kCafe))
                  : _error != null
                      ? ErrorConexion(mensajeError: _error!, onReintentar: () => _cargar())
                      : tickets.isEmpty
                          ? _buildVacio()
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Wrap(
                                spacing: 14,
                                runSpacing: 14,
                                crossAxisAlignment: WrapCrossAlignment.start,
                                children: tickets.values.map(_buildTicket).toList(),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVacio() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: kEstadoLibre,
            child: Icon(Icons.check_rounded, color: Colors.white, size: 36),
          ),
          SizedBox(height: 14),
          Text('¡Cocina al día!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF5E5850))),
          SizedBox(height: 6),
          Text('No hay órdenes pendientes.', style: TextStyle(fontSize: 14, color: kTextoSuave)),
        ],
      ),
    );
  }

  Widget _filtro(String texto, String? valor) {
    return PillChip(
      texto: texto,
      seleccionado: _estacion == valor,
      onTap: () {
        setState(() => _estacion = valor);
        _cargar();
      },
    );
  }

  Widget _buildTicket(List<KdsItem> items) {
    final primero = items.first;
    final espera = items.map((i) => i.minutos).reduce((a, b) => a > b ? a : b);
    final Color encabezado = espera >= 20 ? kEstadoOcupada : (espera >= 10 ? kAmbar : kCian);
    final Color textoEncabezado = espera >= 20 ? Colors.white : kTexto;
    final pendientes = items.where((i) => i.estado != 'LISTO').map((i) => i.idDetalle).toList();
    final listos = items.where((i) => i.estado == 'LISTO').map((i) => i.idDetalle).toList();

    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kBorde),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: encabezado,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mesa ${primero.mesa}',
                    style: TextStyle(color: textoEncabezado, fontWeight: FontWeight.w800, fontSize: 17)),
                Text('hace $espera min',
                    style: TextStyle(color: textoEncabezado, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
            child: Text(primero.folio, style: const TextStyle(fontSize: 11, color: kTextoSuave)),
          ),
          ...items.map(_buildItem),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (pendientes.isNotEmpty)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _ocupado ? null : () => _cambiar(pendientes, 'LISTO'),
                      child: const Text('Todo listo', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                if (pendientes.isNotEmpty && listos.isNotEmpty) const SizedBox(width: 8),
                if (listos.isNotEmpty)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _ocupado ? null : () => _cambiar(listos, 'ENTREGADO'),
                      style: ElevatedButton.styleFrom(backgroundColor: kEstadoLibre, foregroundColor: Colors.white),
                      child: const Text('Entregar listos', style: TextStyle(fontSize: 12)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(KdsItem it) {
    final color = _color(it.estado);
    final sig = _siguiente(it.estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBorde))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${it.cantidad} × ${it.nombre}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kTexto)),
                if (it.notas.isNotEmpty)
                  Text('» ${it.notas}',
                      style: const TextStyle(fontSize: 12, color: kRojo, fontStyle: FontStyle.italic)),
                const SizedBox(height: 4),
                EtiquetaEstado('${etiquetaEstadoItem(it.estado)} · ${it.estacion}', color, suave: true),
              ],
            ),
          ),
          if (sig != null)
            TextButton(
              onPressed: _ocupado ? null : () => _cambiar([it.idDetalle], sig),
              child: Text(_textoAccion(it.estado)),
            ),
        ],
      ),
    );
  }
}

/// Etiqueta de la leyenda de tiempos de espera.
class _Leyenda extends StatelessWidget {
  final String texto;
  final Color fondo;
  final Color colorTexto;
  const _Leyenda(this.texto, this.fondo, this.colorTexto);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(8)),
      child: Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorTexto)),
    );
  }
}
