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
        return const Color(0xFFE6A800);
      case 'LISTO':
        return kVerde;
      case 'ENTREGADO':
        return Colors.grey;
      default:
        return const Color(0xFF6488E4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mesaSel = _mesas.where((m) => m.id == _mesaId).toList();
    final String tituloHeader = 'Menú - ${widget.usuario?['nombre'] ?? 'Cajero Principal'}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: const Color.fromARGB(255, 162, 139, 246),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(tituloHeader,
            style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.normal)),
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
                child: LinearProgressIndicator(minHeight: 3, color: kVerde))
            : null,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: kCafe))
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(_error!, textAlign: TextAlign.center)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: () => _cargar(), child: const Text('Reintentar')),
                  ]),
                )
              : Row(children: [
                  _buildColumnaMesas(),
                  Expanded(child: _buildCentro()),
                  _buildComanda(mesaSel.isEmpty ? null : mesaSel.first),
                ]),
    );
  }

  // 1. COLUMNA IZQUIERDA: MESAS
  Widget _buildColumnaMesas() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mesas Salón',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color.fromARGB(221, 161, 141, 141))),
          const SizedBox(height: 12),
          Expanded(
            child: _mesas.isEmpty
                ? Center(child: Text('No hay mesas', style: TextStyle(color: Colors.grey.shade500)))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _mesas.length,
                    itemBuilder: (context, index) {
                      final mesa = _mesas[index];
                      final bool isSelected = _mesaId == mesa.id;
                      final bool isOcupada = mesa.estado == 'ocupada';
                      return GestureDetector(
                        onTap: () => _seleccionarMesa(mesa.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? kVerde : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text('Mesa ${mesa.numero}',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? kVerde : Colors.black87)),
                                  ),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle, color: isOcupada ? Colors.orange : kVerde),
                                  )
                                ],
                              ),
                              Text('${mesa.capacidad} personas',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
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
                decoration: InputDecoration(
                  hintText: 'Buscar producto...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                ),
              ),
            ),
            if (_admin) ...[
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _editarProducto(),
                style: ElevatedButton.styleFrom(backgroundColor: kVerde, foregroundColor: Colors.white),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Producto'),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Todos', _categoriaId == null, () => setState(() => _categoriaId = null)),
                ..._categoriasVisibles.map((c) => _chip(
                      c.nombre,
                      _categoriaId == c.id,
                      () => setState(() => _categoriaId = c.id),
                      onLong: _admin ? () => _editarCategoria(c) : null,
                    )),
                if (_admin)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: const Text('Categoría'),
                      onPressed: _nuevaCategoria,
                    ),
                  ),
              ],
            ),
          ),
          if (_admin)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Mantén presionada una categoría para editarla u ocultarla.',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: productos.isEmpty
                ? Center(child: Text('No hay productos para mostrar', style: TextStyle(color: Colors.grey.shade500)))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      childAspectRatio: 0.85,
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
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onLongPress: onLong,
        child: ChoiceChip(
          label: Text(texto),
          selected: sel,
          selectedColor: kVerde,
          backgroundColor: Colors.white,
          labelStyle: TextStyle(color: sel ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
          onSelected: (_) => onTap(),
        ),
      ),
    );
  }

  Widget _buildProducto(Producto prod) {
    final bool vendible = prod.activo && prod.disponible;
    return GestureDetector(
      onTap: () => _agregar(prod),
      child: Opacity(
        opacity: vendible ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(!prod.activo ? 'Desactivado' : (!prod.disponible ? 'Agotado' : ''),
                        style: const TextStyle(fontSize: 10, color: kRojo, fontWeight: FontWeight.bold)),
                  ),
                  if (_admin)
                    InkWell(
                      onTap: () => _editarProducto(prod),
                      child: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                    ),
                ],
              ),
              Center(child: Text(prod.emoji, style: const TextStyle(fontSize: 38))),
              const Spacer(),
              Text(prod.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
              const SizedBox(height: 2),
              Text(prod.descripcion.isEmpty ? prod.categoria : prod.descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
              const SizedBox(height: 8),
              Text(dinero(prod.precio),
                  style: const TextStyle(color: kVerde, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  // 3. COLUMNA DERECHA: COMANDA
  Widget _buildComanda(Mesa? mesa) {
    final enviados = _orden?.items ?? <OrdenItem>[];
    final borrador = _borrador;
    final vacio = enviados.isEmpty && borrador.isEmpty;
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Comanda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              if (mesa != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
                  child: Text('Mesa ${mesa.numero}',
                      style: const TextStyle(color: kVerde, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
            ],
          ),
          if (_orden != null)
            Text(_orden!.folio, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 12),
          Expanded(
            child: vacio
                ? Center(
                    child: Text('Toca un producto para agregarlo a la comanda',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  )
                : ListView(
                    children: [
                      if (enviados.isNotEmpty) ...[
                        Text('ENVIADO', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                        ...enviados.map(_filaEnviada),
                        const Divider(),
                      ],
                      if (borrador.isNotEmpty) ...[
                        Text('POR ENVIAR', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                        ...borrador.map(_filaBorrador),
                      ],
                    ],
                  ),
          ),
          const Divider(),
          if (enviados.isNotEmpty)
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Ya enviado:', style: TextStyle(fontSize: 13, color: Colors.black54)),
              Text(dinero(_totalEnviado), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:', style: TextStyle(fontSize: 16, color: Colors.black54)),
              Text(dinero(_totalEnviado + _totalBorrador),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kVerde)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kVerde,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: (borrador.isEmpty || _ocupado) ? null : _enviar,
              child: const Text('Enviar a Cocina', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaEnviada(OrdenItem it) {
    final color = _colorEstadoItem(it.estado);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${it.cantidad} × ${it.nombre}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                if (it.notas.isNotEmpty)
                  Text(it.notas, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(etiquetaEstadoItem(it.estado),
                      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Text(dinero(it.subtotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          if (it.estado != 'ENTREGADO')
            InkWell(
              onTap: _ocupado ? null : () => _cancelarItem(it),
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.close, size: 16, color: kRojo),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filaBorrador(_Borrador b) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(b.producto.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.producto.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                InkWell(
                  onTap: () => _notaBorrador(b),
                  child: Text(b.notas.isEmpty ? '+ nota' : b.notas,
                      style: TextStyle(fontSize: 11, color: b.notas.isEmpty ? kVerde : Colors.grey.shade600)),
                ),
                Row(children: [
                  InkWell(
                    onTap: () => setState(() {
                      b.cantidad--;
                      if (b.cantidad <= 0) _borradores[_mesaId]?.remove(b);
                    }),
                    child: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.redAccent),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('${b.cantidad}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  InkWell(
                    onTap: () => setState(() => b.cantidad++),
                    child: const Icon(Icons.add_circle_outline, size: 20, color: kVerde),
                  ),
                ]),
              ],
            ),
          ),
          Text(dinero(b.producto.precio * b.cantidad), style: const TextStyle(fontWeight: FontWeight.bold)),
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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.producto == null ? 'Nuevo producto' : 'Editar producto'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nombre, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: _desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _precio,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Precio', prefixText: '\$ ', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _tiempo,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minutos prep.', border: OutlineInputBorder()),
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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.categoria == null ? 'Nueva categoría' : 'Editar categoría'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nombre, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder())),
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
