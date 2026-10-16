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
        return const Color(0xFFE6A800);
      case 'LISTO':
        return kVerde;
      default:
        return const Color(0xFF6488E4);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Agrupa por cuenta (ticket)
    final tickets = <int, List<KdsItem>>{};
    for (final it in _items) {
      tickets.putIfAbsent(it.idOrden, () => []).add(it);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1B1612),
      appBar: AppBar(
        backgroundColor: kCafe,
        foregroundColor: Colors.white,
        title: const Text('Cocina / Barra (KDS)', style: TextStyle(fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh_rounded), onPressed: () => _cargar()),
        ],
        bottom: _ocupado
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3), child: LinearProgressIndicator(minHeight: 3, color: kVerde))
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _filtro('Todas', null),
                _filtro('Cocina', 'cocina'),
                _filtro('Barra', 'barra'),
                const Spacer(),
                Text('${tickets.length} comandas · ${_items.length} platillos',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _error != null
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.white54),
                          const SizedBox(height: 12),
                          Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: () => _cargar(), child: const Text('Reintentar')),
                        ]),
                      )
                    : tickets.isEmpty
                        ? const Center(
                            child: Text('No hay comandas pendientes 🎉',
                                style: TextStyle(color: Colors.white54, fontSize: 16)))
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.start,
                              children: tickets.values.map(_buildTicket).toList(),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _filtro(String texto, String? valor) {
    final sel = _estacion == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto),
        selected: sel,
        selectedColor: kVerde,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(color: sel ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
        onSelected: (_) {
          setState(() => _estacion = valor);
          _cargar();
        },
      ),
    );
  }

  Widget _buildTicket(List<KdsItem> items) {
    final primero = items.first;
    final espera = items.map((i) => i.minutos).reduce((a, b) => a > b ? a : b);
    final Color encabezado = espera >= 20
        ? const Color(0xFFC62828)
        : (espera >= 10 ? const Color(0xFFE6A800) : const Color(0xFF3A7D44));
    final pendientes = items.where((i) => i.estado != 'LISTO').map((i) => i.idDetalle).toList();
    final listos = items.where((i) => i.estado == 'LISTO').map((i) => i.idDetalle).toList();

    return Container(
      width: 290,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: encabezado,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mesa ${primero.mesa}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('hace $espera min', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Text(primero.folio, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ),
          ...items.map(_buildItem),
          Padding(
            padding: const EdgeInsets.all(10),
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
                      style: ElevatedButton.styleFrom(backgroundColor: kVerde, foregroundColor: Colors.white),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${it.cantidad} × ${it.nombre}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                if (it.notas.isNotEmpty)
                  Text('» ${it.notas}', style: const TextStyle(fontSize: 12, color: Color(0xFFC62828), fontStyle: FontStyle.italic)),
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text('${etiquetaEstadoItem(it.estado)} · ${it.estacion}',
                      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                ),
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
