// vistas/menu.dart - POS: catálogo real, comanda por mesa y envío a cocina/barra.
import 'package:flutter/material.dart';
import '../modulos/conv.dart';
import '../modulos/orden.dart';
import '../modulos/producto.dart';
import '../modulos/usuario.dart';
import '../servicios/api_service.dart';
import '../servicios/db_service.dart';
import '../widgets/ui.dart';

/// Producto agregado a la comanda pero todavía no enviado.
class _Borrador {
  final Producto producto;
  int cantidad;
  String notas;
  _Borrador(this.producto) : notas = '', cantidad = 1;
}

class MenuVista extends StatefulWidget {
  final Map<String, dynamic>? usuario;
  final int? idMesaInicial;

  const MenuVista({super.key, this.usuario, this.idMesaInicial});

  @override
  State<MenuVista> createState() => _MenuVistaState();
}

class _MenuVistaState extends State<MenuVista> {
  List<Mesa> _mesas = [];
  List<Categoria> _categorias = [];
  List<Producto> _productos = [];
  int? _mesaId;
  int? _categoriaId; // null = todas
  String _busqueda = '';
  Orden? _orden;
  final Map<int, List<_Borrador>> _borradores = {};

  bool _cargando = true;
  bool _ocupado = false;
  String? _error;

  bool get _admin => esAdmin(widget.usuario);
  List<_Borrador> get _borrador => _borradores[_mesaId] ?? [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso && mounted) setState(() => _cargando = true);
    try {
      final res = await Future.wait([
        DbService.obtenerMesas(),
        DbService.obtenerCategorias(todas: _admin),
        DbService.obtenerProductos(todos: _admin),
      ]);
      if (!mounted) return;
      final mesas = res[0] as List<Mesa>;
      setState(() {
        _mesas = mesas;
        _categorias = res[1] as List<Categoria>;
        _productos = res[2] as List<Producto>;
        if (_mesaId == null || !mesas.any((m) => m.id == _mesaId)) {
          if (widget.idMesaInicial != null && mesas.any((m) => m.id == widget.idMesaInicial)) {
            _mesaId = widget.idMesaInicial;
          } else {
            _mesaId = mesas.isNotEmpty ? mesas.first.id : null;
          }
        }
        _error = null;
        _cargando = false;
      });
      await _cargarOrden();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }

  Future<void> _cargarOrden() async {
    final id = _mesaId;
    if (id == null) return;
    try {
      final o = await DbService.obtenerOrdenMesa(id);
      if (mounted && _mesaId == id) setState(() => _orden = o);
    } on ApiException catch (e) {
      if (mounted) mensaje(context, e.mensaje, error: true);
    }
  }

  Future<void> _seleccionarMesa(int id) async {
    setState(() {
      _mesaId = id;
      _orden = null;
    });
    await _cargarOrden();
  }

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
  }

  // ------------------------------------------------------- Comanda
  void _agregar(Producto p) {
    if (_mesaId == null) {
      mensaje(context, 'Selecciona una mesa primero.', error: true);
      return;
    }
    if (!p.activo || !p.disponible) {
      mensaje(context, '"${p.nombre}" no está disponible.', error: true);
      return;
    }
    setState(() {
      final lista = _borradores.putIfAbsent(_mesaId!, () => []);
      final existente = lista.where((b) => b.producto.id == p.id && b.notas.isEmpty).toList();
      if (existente.isNotEmpty) {
        existente.first.cantidad++;
      } else {
        lista.add(_Borrador(p));
      }
    });
  }

  Future<void> _notaBorrador(_Borrador b) async {
    final t = await pedirTexto(context, 'Nota para ${b.producto.nombre}', inicial: b.notas, etiqueta: 'Ej. sin cebolla');
    if (t != null) setState(() => b.notas = t);
  }

  double get _totalBorrador => _borrador.fold(0.0, (s, b) => s + b.producto.precio * b.cantidad);
  double get _totalEnviado => _orden?.total ?? 0;

  Future<void> _enviar() async {
    final id = _mesaId;
    if (id == null || _borrador.isEmpty) return;
    final mesa = _mesas.firstWhere((m) => m.id == id);
    await _run(() async {
      final o = await DbService.enviarComanda(
        id,
        _borrador
            .map((b) => {'id_producto': b.producto.id, 'cantidad': b.cantidad, 'notas': b.notas})
            .toList(),
      );
      _borradores.remove(id);
      if (mounted) setState(() => _orden = o);
    }, exito: 'Comanda enviada a cocina para la Mesa ${mesa.numero}');
    await _cargar(silencioso: true);
  }

  Future<void> _cancelarItem(OrdenItem it) async {
    final ok = await confirmar(context, 'Cancelar platillo', '¿Cancelar "${it.nombre}"?',
        aceptar: 'Cancelar platillo', peligro: true);
    if (!ok) return;
    await _run(() async {
      final o = await DbService.cancelarItem(it.idDetalle);
      if (mounted) setState(() => _orden = o);
    }, exito: 'Platillo cancelado.');
  }

  // ------------------------------------------------ Administración
  Future<void> _editarProducto([Producto? p]) async {
    final datos = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ProductoDialog(categorias: _categorias.where((c) => c.activa).toList(), producto: p, categoriaInicial: _categoriaId),
    );
    if (datos == null) return;
    await _run(() async {
      if (p == null) {
        await DbService.crearProducto(datos);
      } else {
        await DbService.actualizarProducto(p.id, datos);
      }
    }, exito: p == null ? 'Producto creado.' : 'Producto actualizado.');
    await _cargar(silencioso: true);
  }

  Future<void> _nuevaCategoria() async {
    final datos = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _CategoriaDialog());
    if (datos == null) return;
    await _run(() => DbService.crearCategoria(datos['nombre'] as String, datos['estacion'] as String),
        exito: 'Categoría creada.');
    await _cargar(silencioso: true);
  }

  Future<void> _editarCategoria(Categoria c) async {
    final datos = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _CategoriaDialog(categoria: c));
    if (datos == null) return;
    await _run(() => DbService.actualizarCategoria(c.id, datos), exito: 'Categoría actualizada.');
    if (_categoriaId == c.id && datos['activa'] == false) _categoriaId = null;
    await _cargar(silencioso: true);
  }

  // ------------------------------------------------------------ UI
  List<Categoria> get _categoriasVisibles {
    final conProductos = _productos.map((p) => p.idCategoria).toSet();
    return _categorias.where((c) => c.activa && (_admin || conProductos.contains(c.id))).toList();
  }

  List<Producto> get _productosFiltrados {
    final q = _busqueda.trim().toLowerCase();
    return _productos.where((p) {
      if (_categoriaId != null && p.idCategoria != _categoriaId) return false;
      if (q.isNotEmpty && !p.nombre.toLowerCase().contains(q) && !p.descripcion.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  Color _colorEstadoItem(String e) {
    switch (e) {
      case 'EN_PREPARACION':
        return const Color(0xFFD99A00);
      case 'LISTO':
        return kEstadoLibre;
      case 'ENTREGADO':
        return Colors.grey;
      default:
        return kEstadoLimpiar;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mesaSel = _mesas.where((m) => m.id == _mesaId).toList();
    final String tituloHeader = 'Venta rápida · ${widget.usuario?['nombre'] ?? 'Cajero Principal'}';

    return TemaSazon(
      child: Scaffold(
        backgroundColor: kFondo,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: kFondo,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 72,
          leadingWidth: 56,
          leading: BotonRedondo(
            icono: Icons.arrow_back_rounded,
            tooltip: 'Volver',
            onPressed: () => Navigator.pop(context),
          ),
          titleSpacing: 4,
          title: TituloPagina('Menú / Caja POS', subtitulo: tituloHeader, icono: Icons.point_of_sale_rounded),
          actions: [
            BotonRedondo(
              tooltip: 'Actualizar',
              icono: Icons.refresh_rounded,
              onPressed: () => _cargar(),
            ),
            const SizedBox(width: 8),
          ],
          bottom: _ocupado
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(3),
                  child: LinearProgressIndicator(minHeight: 3, color: kEstadoLibre))
              : null,
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator(color: kCafe))
            : _error != null
                ? ErrorConexion(mensajeError: _error!, onReintentar: () => _cargar())
                : Row(children: [
                    _buildColumnaMesas(),
                    Expanded(child: _buildCentro()),
                    _buildComanda(mesaSel.isEmpty ? null : mesaSel.first),
                  ]),
      ),
    );
  }

  Color _colorMesa(String estado) {
    switch (estado) {
      case 'ocupada':
        return kEstadoOcupada;
      case 'reservada':
        return kEstadoReservada;
      case 'por_limpiar':
        return kEstadoLimpiar;
      default:
        return kEstadoLibre;
    }
  }

  // 1. COLUMNA IZQUIERDA: MESAS
  Widget _buildColumnaMesas() {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: kPanel,
        border: Border(right: BorderSide(color: kBorde)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MESAS SALÓN',
              style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: kTextoSuave)),
          const SizedBox(height: 12),
          Expanded(
            child: _mesas.isEmpty
                ? const Center(child: Text('No hay mesas', style: TextStyle(color: kTextoSuave)))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.15,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _mesas.length,
                    itemBuilder: (context, index) {
                      final mesa = _mesas[index];
                      final bool isSelected = _mesaId == mesa.id;
                      final Color acento = _colorMesa(mesa.estado);
                      return GestureDetector(
                        onTap: () => _seleccionarMesa(mesa.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? kTexto : kBorde,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isSelected ? 0.10 : 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(height: 5, color: acento),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Mesa ${mesa.numero}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800, fontSize: 15, color: kTexto)),
                                      Row(
                                        children: [
                                          const Icon(Icons.groups_rounded, size: 14, color: kTextoSuave),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text('${mesa.capacidad} pers.',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 11, color: kTextoSuave)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 2. COLUMNA CENTRAL: BÚSQUEDA Y PRODUCTOS
  Widget _buildCentro() {
    final productos = _productosFiltrados;
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _busqueda = v),
                decoration: campo(null, hint: 'Buscar platillo...', icono: Icons.search),
              ),
            ),
            if (_admin) ...[
              const SizedBox(width: 10),
              BotonOscuro('Producto', icono: Icons.add, onPressed: () => _editarProducto()),
            ],
          ]),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Todas', _categoriaId == null, () => setState(() => _categoriaId = null)),
                ..._categoriasVisibles.map((c) => _chip(
                      c.nombre,
                      _categoriaId == c.id,
                      () => setState(() => _categoriaId = c.id),
                      onLong: _admin ? () => _editarCategoria(c) : null,
                    )),
                if (_admin) _chip('+ Categoría', false, _nuevaCategoria),
              ],
            ),
          ),
          if (_admin)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Mantén presionada una categoría para editarla u ocultarla.',
                  style: TextStyle(fontSize: 10, color: kTextoSuave)),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: productos.isEmpty
                ? const Center(child: Text('No hay productos para mostrar', style: TextStyle(color: kTextoSuave)))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 230,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: productos.length,
                    itemBuilder: (context, index) => _buildProducto(productos[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String texto, bool sel, VoidCallback onTap, {VoidCallback? onLong}) {
    return PillChip(texto: texto, seleccionado: sel, onTap: onTap, onLong: onLong);
  }

  Widget _buildProducto(Producto prod) {
    final bool vendible = prod.activo && prod.disponible;
    return GestureDetector(
      onTap: () => _agregar(prod),
      child: Opacity(
        opacity: vendible ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kPanel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBorde),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Insignia oscura con la categoría
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: kTexto, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        prod.categoria.isEmpty ? 'General' : prod.categoria,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_admin)
                    InkWell(
                      onTap: () => _editarProducto(prod),
                      child: const Icon(Icons.edit_outlined, size: 18, color: kTextoSuave),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prod.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(prod.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15, color: kTexto, height: 1.2)),
                  ),
                ],
              ),
              if (!vendible) ...[
                const SizedBox(height: 4),
                EtiquetaEstado(!prod.activo ? 'Desactivado' : 'Agotado', kRojo, suave: true),
              ] else if (prod.descripcion.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(prod.descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kTextoSuave, fontSize: 11)),
              ],
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(dinero(prod.precio),
                      style: const TextStyle(color: kPrecio, fontWeight: FontWeight.w800, fontSize: 19)),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: kBorde),
                    ),
                    child: const Icon(Icons.add_rounded, size: 18, color: kTexto),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 3. COLUMNA DERECHA: COMANDA (Orden actual)
  Widget _buildComanda(Mesa? mesa) {
    final enviados = _orden?.items ?? <OrdenItem>[];
    final borrador = _borrador;
    final vacio = enviados.isEmpty && borrador.isEmpty;
    const etiquetaSeccion =
        TextStyle(fontSize: 10, letterSpacing: 1.1, color: kTextoSuave, fontWeight: FontWeight.w700);
    return Container(
      width: 310,
      decoration: const BoxDecoration(
        color: kPanel,
        border: Border(left: BorderSide(color: kBorde)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, size: 24, color: kTexto),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Orden Actual',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTexto)),
              ),
              if (mesa != null) EtiquetaEstado('Mesa ${mesa.numero}', kEstadoLibre),
            ],
          ),
          if (_orden != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 32),
              child: Text(_orden!.folio, style: const TextStyle(fontSize: 11, color: kTextoSuave)),
            ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: vacio
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_rounded, size: 46, color: Color(0xFFB9B2A8)),
                        SizedBox(height: 12),
                        Text('La orden está vacía.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF5E5850), fontSize: 13, fontWeight: FontWeight.w500)),
                        Text('Selecciona productos o una mesa.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF5E5850), fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )
                : ListView(
                    children: [
                      if (enviados.isNotEmpty) ...[
                        const Text('ENVIADO', style: etiquetaSeccion),
                        ...enviados.map(_filaEnviada),
                        const Divider(),
                      ],
                      if (borrador.isNotEmpty) ...[
                        const Text('POR ENVIAR', style: etiquetaSeccion),
                        ...borrador.map(_filaBorrador),
                      ],
                    ],
                  ),
          ),
          const Divider(),
          if (enviados.isNotEmpty)
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Ya enviado', style: TextStyle(fontSize: 14, color: kTextoSuave)),
              Text(dinero(_totalEnviado), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Total a Pagar', style: TextStyle(fontSize: 15, color: kTextoSuave)),
              Text(dinero(_totalEnviado + _totalBorrador),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: kPrecio)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kTexto,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: (borrador.isEmpty || _ocupado) ? null : _enviar,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Enviar a Cocina', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaEnviada(OrdenItem it) {
    final color = _colorEstadoItem(it.estado);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${it.cantidad} × ${it.nombre}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTexto)),
                if (it.notas.isNotEmpty)
                  Text(it.notas,
                      style: const TextStyle(fontSize: 11, color: kTextoSuave, fontStyle: FontStyle.italic)),
                const SizedBox(height: 3),
                EtiquetaEstado(etiquetaEstadoItem(it.estado), color, suave: true),
              ],
            ),
          ),
          Text(dinero(it.subtotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          if (it.estado != 'ENTREGADO')
            InkWell(
              onTap: _ocupado ? null : () => _cancelarItem(it),
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.close_rounded, size: 18, color: kRojo),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filaBorrador(_Borrador b) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(b.producto.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.producto.nombre,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTexto)),
                InkWell(
                  onTap: () => _notaBorrador(b),
                  child: Text(b.notas.isEmpty ? '+ nota' : b.notas,
                      style: TextStyle(fontSize: 11, color: b.notas.isEmpty ? kVerde : kTextoSuave)),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  InkWell(
                    onTap: () => setState(() {
                      b.cantidad--;
                      if (b.cantidad <= 0) _borradores[_mesaId]?.remove(b);
                    }),
                    child: const Icon(Icons.remove_circle_outline, size: 22, color: kEstadoOcupada),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('${b.cantidad}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  InkWell(
                    onTap: () => setState(() => b.cantidad++),
                    child: const Icon(Icons.add_circle_outline, size: 22, color: kEstadoLibre),
                  ),
                ]),
              ],
            ),
          ),
          Text(dinero(b.producto.precio * b.cantidad), style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// =====================================================================
// Diálogo: crear / editar producto (solo administrador)
// =====================================================================
class _ProductoDialog extends StatefulWidget {
  final List<Categoria> categorias;
  final Producto? producto;
  final int? categoriaInicial;

  const _ProductoDialog({required this.categorias, this.producto, this.categoriaInicial});

  @override
  State<_ProductoDialog> createState() => _ProductoDialogState();
}

class _ProductoDialogState extends State<_ProductoDialog> {
  late final TextEditingController _nombre = TextEditingController(text: widget.producto?.nombre ?? '');
  late final TextEditingController _desc = TextEditingController(text: widget.producto?.descripcion ?? '');
  late final TextEditingController _precio =
      TextEditingController(text: widget.producto == null ? '' : widget.producto!.precio.toStringAsFixed(2));
  late final TextEditingController _tiempo =
      TextEditingController(text: '${widget.producto?.tiempoPreparacion ?? 15}');
  int? _categoria;
  bool _disponible = true;
  bool _activo = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _categoria = p?.idCategoria ?? widget.categoriaInicial ?? (widget.categorias.isNotEmpty ? widget.categorias.first.id : null);
    if (!widget.categorias.any((c) => c.id == _categoria)) {
      _categoria = widget.categorias.isNotEmpty ? widget.categorias.first.id : null;
    }
    _disponible = p?.disponible ?? true;
    _activo = p?.activo ?? true;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _desc.dispose();
    _precio.dispose();
    _tiempo.dispose();
    super.dispose();
  }

  void _guardar() {
    final nombre = _nombre.text.trim();
    final precio = leerNumero(_precio.text);
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe el nombre del producto.');
      return;
    }
    if (precio == null || precio < 0) {
      setState(() => _error = 'Escribe un precio válido.');
      return;
    }
    Navigator.pop(context, {
      'nombre': nombre,
      'descripcion': _desc.text.trim(),
      'precio': precio,
      'id_categoria': _categoria,
      'tiempo_preparacion_min': int.tryParse(_tiempo.text.trim()) ?? 15,
      'disponible': _disponible,
      if (widget.producto != null) 'activo': _activo,
    });
  }

  @override
  Widget build(BuildContext context) => TemaSazon(child: _dialogo());

  Widget _dialogo() {
    return AlertDialog(
      backgroundColor: kPanel,
      shape: kFormaDialogo,
      title: Text(widget.producto == null ? 'Nuevo producto' : 'Editar producto'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nombre, decoration: campo('Nombre')),
              const SizedBox(height: 12),
              TextField(controller: _desc, maxLines: 2, decoration: campo('Descripción')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _precio,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: campo('Precio', prefixText: '\$ '),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _tiempo,
                    keyboardType: TextInputType.number,
                    decoration: campo('Minutos prep.'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Selector<int>(
                etiqueta: 'Categoría',
                valor: _categoria,
                items: widget.categorias.map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.nombre))).toList(),
                onChanged: (v) => setState(() => _categoria = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Disponible (no agotado)'),
                value: _disponible,
                onChanged: (v) => setState(() => _disponible = v),
              ),
              if (widget.producto != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo en el menú'),
                  value: _activo,
                  onChanged: (v) => setState(() => _activo = v),
                ),
              if (_error != null) Text(_error!, style: const TextStyle(color: kRojo, fontSize: 12)),
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
// Diálogo: crear / editar categoría
// =====================================================================
class _CategoriaDialog extends StatefulWidget {
  final Categoria? categoria;
  const _CategoriaDialog({this.categoria});

  @override
  State<_CategoriaDialog> createState() => _CategoriaDialogState();
}

class _CategoriaDialogState extends State<_CategoriaDialog> {
  late final TextEditingController _nombre = TextEditingController(text: widget.categoria?.nombre ?? '');
  late String _estacion = widget.categoria?.estacion ?? 'cocina';
  bool _activa = true;

  @override
  void initState() {
    super.initState();
    _activa = widget.categoria?.activa ?? true;
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TemaSazon(child: _dialogo());

  Widget _dialogo() {
    return AlertDialog(
      backgroundColor: kPanel,
      shape: kFormaDialogo,
      title: Text(widget.categoria == null ? 'Nueva categoría' : 'Editar categoría'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nombre, decoration: campo('Nombre')),
            const SizedBox(height: 12),
            Selector<String>(
              etiqueta: 'Estación que la prepara',
              valor: _estacion,
              items: const [
                DropdownMenuItem(value: 'cocina', child: Text('Cocina')),
                DropdownMenuItem(value: 'barra', child: Text('Barra')),
              ],
              onChanged: (v) => setState(() => _estacion = v ?? 'cocina'),
            ),
            if (widget.categoria != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Visible'),
                value: _activa,
                onChanged: (v) => setState(() => _activa = v),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(
          onPressed: () {
            final n = _nombre.text.trim();
            if (n.isEmpty) return;
            Navigator.pop(context, {
              'nombre': n,
              'estacion': _estacion,
              if (widget.categoria != null) 'activa': _activa,
            });
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
