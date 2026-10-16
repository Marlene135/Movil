// vistas/mesas.dart - Plano de mesas conectado a la base de datos:
// asignación, fusión/movimiento en conjunto (se guarda), cobro y administración.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../modulos/conv.dart';
import '../modulos/orden.dart';
import '../modulos/usuario.dart';
import '../servicios/api_service.dart';
import '../servicios/db_service.dart';
import '../widgets/MesaWidget.dart';
import '../widgets/ui.dart';
import 'menu.dart';

class MesasScreen extends StatefulWidget {
  final Map<String, dynamic>? usuario;

  const MesasScreen({super.key, this.usuario});

  @override
  State<MesasScreen> createState() => _MesasScreenState();
}

class _MesasScreenState extends State<MesasScreen> {
  int _personas = 2;
  int? _areaId;
  int? _mesaSeleccionadaId;

  List<Area> _areas = [];
  List<Mesa> _mesas = [];
  bool _cargando = true;
  bool _ocupado = false;
  bool _huboMovimiento = false;
  String? _error;

  bool get _admin => esAdmin(widget.usuario);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // ------------------------------------------------------------ Datos
  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso && mounted) setState(() => _cargando = true);
    try {
      final res = await Future.wait([DbService.obtenerAreas(), DbService.obtenerMesas()]);
      if (!mounted) return;
      final areas = res[0] as List<Area>;
      final mesas = res[1] as List<Mesa>;
      _acomodarPorDefecto(mesas);
      setState(() {
        _areas = areas;
        _mesas = mesas;
        if (_areaId == null || !areas.any((a) => a.id == _areaId)) {
          _areaId = areas.isNotEmpty ? areas.first.id : null;
        }
        if (_mesaSeleccionadaId != null && !mesas.any((m) => m.id == _mesaSeleccionadaId)) {
          _mesaSeleccionadaId = null;
        }
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

  /// Las mesas que todavía no tienen posición (0,0) se acomodan en una cuadrícula.
  void _acomodarPorDefecto(List<Mesa> mesas) {
    final porArea = <int?, int>{};
    for (final m in mesas) {
      if (m.x == 0 && m.y == 0) {
        final i = porArea[m.idArea] ?? 0;
        m.x = 30.0 + (i % 5) * 110;
        m.y = 30.0 + (i ~/ 5) * 110;
        porArea[m.idArea] = i + 1;
      }
    }
  }

  /// Ejecuta una acción contra el servidor mostrando el error si falla y recargando después.
  Future<void> _run(Future<void> Function() accion, {String? exito}) async {
    setState(() => _ocupado = true);
    try {
      await accion();
      if (exito != null && mounted) mensaje(context, exito);
    } on ApiException catch (e) {
      if (mounted) mensaje(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
    await _cargar(silencioso: true);
  }

  List<Mesa> get _mesasArea => _mesas.where((m) => m.idArea == _areaId).toList();

  Mesa? get _mesaSel {
    if (_mesaSeleccionadaId == null) return null;
    for (final m in _mesas) {
      if (m.id == _mesaSeleccionadaId) return m;
    }
    return null;
  }

  List<Mesa> _grupoDe(Mesa m) =>
      m.grupo == null ? [m] : _mesas.where((x) => x.grupo == m.grupo).toList();

  // ------------------------------------------- Movimiento y fusión
  void _moverMesaOGrupo(Mesa principal, Offset delta, BoxConstraints c) {
    _huboMovimiento = true;
    setState(() {
      for (final m in _grupoDe(principal)) {
        m.x = (m.x + delta.dx).clamp(4.0, math.max(4.0, c.maxWidth - 70)).toDouble();
        m.y = (m.y + delta.dy).clamp(4.0, math.max(4.0, c.maxHeight - 70)).toDouble();
      }
    });
  }

  Future<void> _soltarMesa(Mesa mesa) async {
    if (!_huboMovimiento) return;
    _huboMovimiento = false;

    Mesa? cercana;
    for (final otra in _mesasArea) {
      if (otra.id == mesa.id) continue;
      if (mesa.grupo != null && otra.grupo == mesa.grupo) continue; // ya están unidas
      if ((mesa.x - otra.x).abs() < 65 && (mesa.y - otra.y).abs() < 65) {
        cercana = otra;
        break;
      }
    }

    List<Mesa> afectadas;
    if (cercana != null) {
      final otra = cercana;
      final nuevoGrupo = otra.grupo ?? otra.id;
      final miembrosMesa = _grupoDe(mesa);
      final miembrosOtra = _grupoDe(otra);
      // Ajuste magnético: la mesa (y su grupo) se pega junto a la otra
      final destinoX = otra.x + ((mesa.x - otra.x) > 0 ? 62.0 : -62.0);
      final ddx = destinoX - mesa.x;
      final ddy = otra.y - mesa.y;
      setState(() {
        for (final m in miembrosMesa) {
          m.x = math.max(4.0, m.x + ddx);
          m.y = math.max(4.0, m.y + ddy);
          m.grupo = nuevoGrupo;
        }
        for (final m in miembrosOtra) {
          m.grupo = nuevoGrupo;
        }
      });
      afectadas = [...miembrosMesa, ...miembrosOtra];
      if (mounted) mensaje(context, '¡Mesa ${mesa.numero} unida con Mesa ${otra.numero}!');
    } else {
      afectadas = _grupoDe(mesa);
    }

    try {
      await DbService.guardarLayout(afectadas);
    } on ApiException catch (e) {
      if (mounted) mensaje(context, 'No se pudo guardar la posición: ${e.mensaje}', error: true);
      await _cargar(silencioso: true);
    }
  }

  Future<void> _separarGrupo(Mesa mesa) async {
    final miembros = _grupoDe(mesa);
    if (miembros.length < 2) return;
    double desplazamiento = 0;
    for (final m in miembros) {
      m.grupo = null;
      m.x += desplazamiento;
      desplazamiento += 25;
    }
    setState(() {});
    await _run(() => DbService.guardarLayout(miembros), exito: 'Las mesas se separaron.');
  }

  // --------------------------------------------------------- Acciones
  Future<void> _asignar(Mesa mesa) async {
    final miembros = _grupoDe(mesa);
    await _run(() async {
      await DbService.abrirMesa(mesa.id, _personas);
      for (final m in miembros) {
        if (m.id != mesa.id && m.estado != 'ocupada') {
          await DbService.actualizarMesa(m.id, {'estado': 'ocupada'});
        }
      }
    });
    if (!mounted) return;
    final nombre = miembros.length > 1 ? 'Mesas unidas' : 'Mesa ${mesa.numero}';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$nombre asignada para $_personas personas.'),
        action: SnackBarAction(label: 'Tomar comanda', onPressed: () => _irAMenu(mesa)),
      ));
  }

  void _irAMenu(Mesa mesa) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MenuVista(usuario: widget.usuario, idMesaInicial: mesa.id)),
    ).then((_) => _cargar(silencioso: true));
  }

  Future<void> _cobrar(Mesa mesa) async {
    final miembros = _grupoDe(mesa).where((m) => m.idOrden != null).toList();
    final total = miembros.fold<double>(0, (s, m) => s + m.totalActual);
    if (miembros.isEmpty || total <= 0) {
      mensaje(context, 'La cuenta no tiene consumo. Para liberar la mesa usa el menú ⋮ → Disponible.', error: true);
      return;
    }
    final etiqueta = miembros.map((m) => m.numero).join(' + ');
    final datos = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PagoDialog(total: total, etiqueta: etiqueta),
    );
    if (datos == null) return;

    setState(() => _ocupado = true);
    try {
      final r = await DbService.pagar(
        idsOrden: miembros.map((m) => m.idOrden!).toList(),
        metodoPago: datos['metodo'] as String,
        montoRecibido: datos['recibido'] as double,
        propina: datos['propina'] as double,
      );
      if (mounted) {
        final cambio = toDouble(r['cambio']);
        mensaje(context, cambio > 0
            ? '¡Cuenta pagada! Cambio: ${dinero(cambio)}. Mesas liberadas.'
            : '¡Cuenta pagada! Las mesas quedaron disponibles.');
      }
    } on ApiException catch (e) {
      if (mounted) mensaje(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
    await _cargar(silencioso: true);
  }

  Future<void> _cambiarEstado(Mesa mesa, String estado) async {
    await _run(() => DbService.actualizarMesa(mesa.id, {'estado': estado}));
  }

  Future<void> _cancelarCuenta(Mesa mesa) async {
    final ok = await confirmar(context, 'Cancelar cuenta',
        '¿Cancelar la cuenta de la Mesa ${mesa.numero}? Se anularán todos sus platillos.',
        aceptar: 'Cancelar cuenta', peligro: true);
    if (!ok || mesa.idOrden == null) return;
    await _run(() => DbService.cancelarOrden(mesa.idOrden!), exito: 'Cuenta cancelada.');
  }

  // ----------------------------------------------- Administración
  Future<void> _nuevaMesa() async {
    final datos = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _MesaDialog(areas: _areas, areaInicial: _areaId, sugerencia: '${_mesas.length + 1}'),
    );
    if (datos == null) return;
    await _run(() async {
      final m = await DbService.crearMesa(
        numero: datos['numero'] as String,
        capacidad: datos['capacidad'] as int,
        idArea: datos['id_area'] as int?,
      );
      _mesaSeleccionadaId = m.id;
      if (datos['id_area'] != null) _areaId = datos['id_area'] as int?;
    }, exito: 'Mesa agregada.');
  }

  Future<void> _editarMesa(Mesa mesa) async {
    final datos = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _MesaDialog(areas: _areas, areaInicial: mesa.idArea, mesa: mesa),
    );
    if (datos == null) return;
    await _run(() => DbService.actualizarMesa(mesa.id, datos), exito: 'Mesa actualizada.');
  }

  Future<void> _eliminarMesa(Mesa mesa) async {
    final ok = await confirmar(context, 'Eliminar mesa', '¿Eliminar la Mesa ${mesa.numero}? Esta acción no se puede deshacer.',
        aceptar: 'Eliminar', peligro: true);
    if (!ok) return;
    _mesaSeleccionadaId = null;
    await _run(() => DbService.eliminarMesa(mesa.id), exito: 'Mesa eliminada.');
  }

  Future<void> _nuevaArea() async {
    final nombre = await pedirTexto(context, 'Nueva área', etiqueta: 'Nombre del área');
    if (nombre == null) return;
    await _run(() async {
      final a = await DbService.crearArea(nombre);
      _areaId = a.id;
    }, exito: 'Área creada.');
  }

  Future<void> _renombrarArea() async {
    final area = _areas.where((a) => a.id == _areaId).toList();
    if (area.isEmpty) return;
    final nombre = await pedirTexto(context, 'Renombrar área', inicial: area.first.nombre, etiqueta: 'Nombre del área');
    if (nombre == null) return;
    await _run(() => DbService.renombrarArea(area.first.id, nombre), exito: 'Área actualizada.');
  }

  Future<void> _eliminarArea() async {
    final area = _areas.where((a) => a.id == _areaId).toList();
    if (area.isEmpty) return;
    final ok = await confirmar(context, 'Eliminar área', '¿Eliminar el área "${area.first.nombre}"?',
        aceptar: 'Eliminar', peligro: true);
    if (!ok) return;
    _areaId = null;
    await _run(() => DbService.eliminarArea(area.first.id), exito: 'Área eliminada.');
  }

  // ------------------------------------------------------------ UI
  String _etiquetaEstado(String e) {
    switch (e) {
      case 'ocupada':
        return 'Ocupada';
      case 'por_limpiar':
        return 'Por limpiar';
      case 'reservada':
        return 'Reservada';
      default:
        return 'Disponible';
    }
  }

  Color _colorEstado(String e) {
    switch (e) {
      case 'ocupada':
        return const Color(0xFFE65100);
      case 'por_limpiar':
        return const Color(0xFF6B645C);
      case 'reservada':
        return const Color(0xFF3F6FD8);
      default:
        return kVerde;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String tituloHeader = widget.usuario != null
        ? 'Mesas - ${widget.usuario!['nombre'] ?? 'Cajero Principal'}'
        : 'Mesas - Cajero Principal';

    final mesa = _mesaSel;
    final bool tieneGrupoUnido = mesa != null && mesa.grupo != null && _grupoDe(mesa).length > 1;
    final miembros = mesa == null ? <Mesa>[] : _grupoDe(mesa);
    final double totalCuenta = miembros.fold<double>(0, (s, m) => s + m.totalActual);
    final bool hayCuenta = miembros.any((m) => m.idOrden != null);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tituloHeader,
          style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.normal),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
            onPressed: () => _cargar(),
          ),
        ],
        bottom: _ocupado
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3, color: kVerde),
              )
            : null,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: kCafe))
          : _error != null
              ? _buildError()
              : Row(
                  children: [
                    // -------------------------------------------------------------
                    // PANEL IZQUIERDO: CONFIGURACIÓN Y PAGO
                    // -------------------------------------------------------------
                    Container(
                      width: 310,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(right: BorderSide(color: Colors.grey.shade300)),
                      ),
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text('Área / Zona',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                      ),
                                      if (_admin) ...[
                                        IconButton(
                                          tooltip: 'Nueva área',
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(Icons.add_circle_outline, size: 20),
                                          onPressed: _nuevaArea,
                                        ),
                                        PopupMenuButton<String>(
                                          tooltip: 'Opciones del área',
                                          icon: const Icon(Icons.more_vert, size: 20),
                                          onSelected: (v) => v == 'renombrar' ? _renombrarArea() : _eliminarArea(),
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(value: 'renombrar', child: Text('Renombrar área')),
                                            PopupMenuItem(value: 'eliminar', child: Text('Eliminar área')),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Selector<int>(
                                    valor: _areaId,
                                    items: _areas
                                        .map((a) => DropdownMenuItem<int>(value: a.id, child: Text(a.nombre)))
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() => _areaId = v);
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  const Text('Personas (Covers)',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('$_personas personas',
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        Row(
                                          children: [
                                            IconButton(
                                              onPressed: _personas > 1 ? () => setState(() => _personas--) : null,
                                              icon: const Icon(Icons.remove_circle_outline),
                                              color: Colors.redAccent,
                                            ),
                                            IconButton(
                                              onPressed: () => setState(() => _personas++),
                                              icon: const Icon(Icons.add_circle_outline),
                                              color: kVerde,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_admin) ...[
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: _nuevaMesa,
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(double.infinity, 44),
                                        side: const BorderSide(color: kVerde),
                                        foregroundColor: kVerde,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('Agregar Mesa', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                  if (mesa != null) ...[
                                    const SizedBox(height: 20),
                                    _buildFichaMesa(mesa, miembros, totalCuenta),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Separar mesas unidas
                          if (tieneGrupoUnido) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: _ocupado ? null : () => _separarGrupo(mesa),
                                icon: const Icon(Icons.call_split_rounded, size: 18),
                                label: const Text('Separar mesas'),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Cobro (mesa individual con cuenta o grupo unido)
                          if (mesa != null && hayCuenta) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kCafe,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _ocupado ? null : () => _cobrar(mesa),
                                icon: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 20),
                                label: Text(
                                  tieneGrupoUnido
                                      ? 'Pagar Cuenta y Separar (${dinero(totalCuenta)})'
                                      : 'Cobrar Cuenta (${dinero(totalCuenta)})',
                                  style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // BOTÓN PRINCIPAL
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kVerde,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: (mesa == null || _ocupado)
                                  ? null
                                  : () {
                                      if (mesa.ocupada) {
                                        _irAMenu(mesa);
                                      } else {
                                        _asignar(mesa);
                                      }
                                    },
                              child: Text(
                                _textoBotonPrincipal(mesa, tieneGrupoUnido, miembros),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // -------------------------------------------------------------
                    // ÁREA DERECHA: PLANO CON MOVIMIENTO EN CONJUNTO
                    // -------------------------------------------------------------
                    Expanded(child: _buildPlano()),
                  ],
                ),
    );
  }

  String _textoBotonPrincipal(Mesa? mesa, bool unidas, List<Mesa> miembros) {
    if (mesa == null) return 'Selecciona una Mesa';
    if (mesa.ocupada) {
      return unidas ? 'Tomar comanda (Mesas ${miembros.map((m) => m.numero).join('+')})' : 'Tomar comanda · Mesa ${mesa.numero}';
    }
    if (unidas) return 'Mesas Unidas (${miembros.map((m) => m.numero).join('+')})';
    return 'Asignar Mesa ${mesa.numero}';
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_error ?? '', textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => _cargar(), child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _buildFichaMesa(Mesa mesa, List<Mesa> miembros, double totalCuenta) {
    final color = _colorEstado(mesa.estado);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  miembros.length > 1 ? 'Mesas ${miembros.map((m) => m.numero).join('+')}' : 'Mesa ${mesa.numero}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones de la mesa',
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (v) {
                  switch (v) {
                    case 'editar':
                      _editarMesa(mesa);
                      break;
                    case 'eliminar':
                      _eliminarMesa(mesa);
                      break;
                    case 'cancelar':
                      _cancelarCuenta(mesa);
                      break;
                    default:
                      _cambiarEstado(mesa, v);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'disponible', child: Text('Marcar disponible')),
                  const PopupMenuItem(value: 'por_limpiar', child: Text('Marcar por limpiar')),
                  const PopupMenuItem(value: 'reservada', child: Text('Marcar reservada')),
                  if (mesa.idOrden != null && esCajaOAdmin(widget.usuario))
                    const PopupMenuItem(value: 'cancelar', child: Text('Cancelar cuenta')),
                  if (_admin) const PopupMenuItem(value: 'editar', child: Text('Editar mesa')),
                  if (_admin) const PopupMenuItem(value: 'eliminar', child: Text('Eliminar mesa')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_etiquetaEstado(mesa.estado),
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Text('Capacidad: ${mesa.capacidad}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ],
          ),
          if (mesa.idOrden != null) ...[
            const SizedBox(height: 8),
            Text('Cuenta: ${dinero(totalCuenta)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (mesa.comensales > 0)
              Text('${mesa.comensales} comensales', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            if (mesa.mesero != null)
              Text('Atiende: ${mesa.mesero}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ],
        ],
      ),
    );
  }

  Widget _buildPlano() {
    final enArea = _mesasArea;
    final areaNombre = _areas.where((a) => a.id == _areaId).map((a) => a.nombre).join();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(areaNombre.isEmpty ? 'Sin áreas' : areaNombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: kVerde)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    for (final e in ['disponible', 'ocupada', 'por_limpiar', 'reservada'])
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(color: _colorEstado(e), shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text(_etiquetaEstado(e), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: enArea.isEmpty
              ? Center(
                  child: Text(
                    _admin ? 'No hay mesas en esta área. Usa "Agregar Mesa".' : 'No hay mesas en esta área.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: enArea.map((mesa) {
                        final bool isSelected = _mesaSeleccionadaId == mesa.id;
                        final bool estaUnida = mesa.grupo != null && _grupoDe(mesa).length > 1;
                        final sel = _mesaSel;
                        final bool esGrupoSeleccionado =
                            estaUnida && sel != null && sel.grupo == mesa.grupo;

                        return Positioned(
                          left: mesa.x,
                          top: mesa.y,
                          child: GestureDetector(
                            onTap: () => setState(() => _mesaSeleccionadaId = mesa.id),
                            onPanStart: (_) => setState(() => _mesaSeleccionadaId = mesa.id),
                            onPanUpdate: (d) => _moverMesaOGrupo(mesa, d.delta, constraints),
                            onPanEnd: (_) => _soltarMesa(mesa),
                            child: MesaWidget(
                              numero: estaUnida ? 'M${mesa.numero}' : mesa.numero,
                              isSelected: isSelected || esGrupoSeleccionado,
                              estado: mesa.estado,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// =====================================================================
// Diálogo: crear / editar mesa
// =====================================================================
class _MesaDialog extends StatefulWidget {
  final List<Area> areas;
  final int? areaInicial;
  final Mesa? mesa; // null = crear
  final String sugerencia;

  const _MesaDialog({required this.areas, this.areaInicial, this.mesa, this.sugerencia = ''});

  @override
  State<_MesaDialog> createState() => _MesaDialogState();
}

class _MesaDialogState extends State<_MesaDialog> {
  late final TextEditingController _numero =
      TextEditingController(text: widget.mesa?.numero ?? widget.sugerencia);
  late final TextEditingController _capacidad =
      TextEditingController(text: '${widget.mesa?.capacidad ?? 4}');
  int? _area;
  String? _error;

  @override
  void initState() {
    super.initState();
    _area = widget.areaInicial ?? (widget.areas.isNotEmpty ? widget.areas.first.id : null);
  }

  @override
  void dispose() {
    _numero.dispose();
    _capacidad.dispose();
    super.dispose();
  }

  void _guardar() {
    final numero = _numero.text.trim();
    final cap = int.tryParse(_capacidad.text.trim());
    if (numero.isEmpty) {
      setState(() => _error = 'Escribe el número o nombre de la mesa.');
      return;
    }
    if (cap == null || cap < 1) {
      setState(() => _error = 'La capacidad debe ser al menos 1.');
      return;
    }
    Navigator.pop(context, {'numero': numero, 'capacidad': cap, 'id_area': _area});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.mesa == null ? 'Nueva mesa' : 'Editar mesa'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _numero,
                decoration: const InputDecoration(labelText: 'Número / nombre (ej. 4, T1, B2)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _capacidad,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Capacidad (personas)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Selector<int>(
                etiqueta: 'Área',
                valor: _area,
                items: widget.areas.map((a) => DropdownMenuItem<int>(value: a.id, child: Text(a.nombre))).toList(),
                onChanged: (v) => setState(() => _area = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: kRojo, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}

// =====================================================================
// Diálogo: cobro de cuenta
// =====================================================================
class _PagoDialog extends StatefulWidget {
  final double total;
  final String etiqueta;

  const _PagoDialog({required this.total, required this.etiqueta});

  @override
  State<_PagoDialog> createState() => _PagoDialogState();
}

class _PagoDialogState extends State<_PagoDialog> {
  static const Map<String, String> _metodos = {
    'EFECTIVO': 'Efectivo',
    'TARJETA_CREDITO': 'Tarjeta de crédito',
    'TARJETA_DEBITO': 'Tarjeta de débito',
    'TRANSFERENCIA': 'Transferencia',
  };

  String _metodo = 'EFECTIVO';
  late final TextEditingController _recibido =
      TextEditingController(text: widget.total.toStringAsFixed(2));
  final TextEditingController _propina = TextEditingController(text: '0');
  String? _error;

  @override
  void dispose() {
    _recibido.dispose();
    _propina.dispose();
    super.dispose();
  }

  double get _recibidoNum => leerNumero(_recibido.text) ?? 0;
  double get _cambio => math.max(0, _recibidoNum - widget.total);

  void _cobrar() {
    final propina = leerNumero(_propina.text) ?? 0;
    final recibido = _metodo == 'EFECTIVO' ? _recibidoNum : widget.total;
    if (propina < 0) {
      setState(() => _error = 'La propina no puede ser negativa.');
      return;
    }
    if (recibido + 0.001 < widget.total) {
      setState(() => _error = 'El monto recibido es menor al total.');
      return;
    }
    Navigator.pop(context, {'metodo': _metodo, 'recibido': recibido, 'propina': propina});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Cobrar Mesa ${widget.etiqueta}'),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total a pagar', style: TextStyle(fontSize: 14)),
                  Text(dinero(widget.total),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kVerde)),
                ],
              ),
              const SizedBox(height: 16),
              Selector<String>(
                etiqueta: 'Método de pago',
                valor: _metodo,
                items: _metodos.entries
                    .map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _metodo = v ?? 'EFECTIVO'),
              ),
              if (_metodo == 'EFECTIVO') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _recibido,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Efectivo recibido', prefixText: '\$ ', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 8),
                Text('Cambio: ${dinero(_cambio)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _propina,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Propina (opcional)', prefixText: '\$ ', border: OutlineInputBorder()),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: kRojo, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kVerde, foregroundColor: Colors.white),
          onPressed: _cobrar,
          child: const Text('Cobrar'),
        ),
      ],
    );
  }
}
