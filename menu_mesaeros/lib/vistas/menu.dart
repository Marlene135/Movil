// vistas/menu.dart
import 'package:flutter/material.dart';

class MenuVista extends StatefulWidget {
  final Map<String, dynamic>? usuario;

  const MenuVista({Key? key, this.usuario}) : super(key: key);

  @override
  State<MenuVista> createState() => _MenuVistaState();
}

class _MenuVistaState extends State<MenuVista> {
  int? _mesaSeleccionada = 1;
  String _categoriaSeleccionada = 'Entradas';

  // Lista de productos en la comanda
  final List<Map<String, dynamic>> _comandaActual = [];

  // Categorías
  final List<Map<String, String>> _categorias = [
    {'nombre': 'Entradas', 'emoji': '🥑'},
    {'nombre': 'Ensaladas', 'emoji': '🥗'},
    {'nombre': 'Hamburguesas', 'emoji': '🍔'},
    {'nombre': 'Bebidas', 'emoji': '🥤'},
  ];

  // Mesas del salón
  final List<Map<String, dynamic>> _mesas = [
    {'id': 1, 'personas': 2, 'estado': 'disponible'},
    {'id': 2, 'personas': 4, 'estado': 'disponible'},
    {'id': 3, 'personas': 4, 'estado': 'disponible'},
    {'id': 4, 'personas': 6, 'estado': 'ocupada'},
    {'id': 5, 'personas': 2, 'estado': 'disponible'},
    {'id': 6, 'personas': 4, 'estado': 'disponible'},
    {'id': 7, 'personas': 4, 'estado': 'disponible'},
    {'id': 8, 'personas': 6, 'estado': 'ocupada'},
  ];

  // Catálogo de productos
  final List<Map<String, dynamic>> _productos = [
    {
      'id': 1,
      'nombre': 'Alitas BBQ',
      'descripcion': '8 piezas con salsa BBQ',
      'precio': 129.00,
      'emoji': '🍗',
      'categoria': 'Entradas'
    },
    {
      'id': 2,
      'nombre': 'Nachos Supremos',
      'descripcion': 'Totopos, queso y frijoles',
      'precio': 99.00,
      'emoji': '🧀',
      'categoria': 'Entradas'
    },
    {
      'id': 3,
      'nombre': 'Guacamole',
      'descripcion': 'Aguacate fresco con pico de gallo',
      'precio': 89.00,
      'emoji': '🥑',
      'categoria': 'Entradas'
    },
    {
      'id': 4,
      'nombre': 'Aros de Cebolla',
      'descripcion': 'Crujientes con aderezo',
      'precio': 79.00,
      'emoji': '🧅',
      'categoria': 'Entradas'
    },
  ];

  void _agregarAComanda(Map<String, dynamic> producto) {
    setState(() {
      _comandaActual.add(producto);
    });
  }

  double get _totalComanda {
    return _comandaActual.fold(0.0, (sum, item) => sum + (item['precio'] as double));
  }

  @override
  Widget build(BuildContext context) {
    final String tituloHeader = widget.usuario != null
        ? 'Mesas - ${widget.usuario!['nombre'] ?? 'Cajero Principal'}'
        : 'Mesas - Cajero Principal';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),

      // -------------------------------------------------------------
      // APP BAR CON FLECHA Y TÍTULO CENTRADO (Igual a la imagen)
      // -------------------------------------------------------------
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
        ),
        title: Text(
          tituloHeader,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
        centerTitle: true,
      ),

      // -------------------------------------------------------------
      // ESTRUCTURA PRINCIPAL DE TRES COLUMNAS EN TEMA CLARO
      // -------------------------------------------------------------
      body: Row(
        children: [
          // 1. COLUMNA IZQUIERDA: LISTA DE MESAS
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mesas Salón',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(221, 161, 141, 141),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _mesas.length,
                    itemBuilder: (context, index) {
                      final mesa = _mesas[index];
                      final bool isSelected = _mesaSeleccionada == mesa['id'];
                      final bool isOcupada = mesa['estado'] == 'ocupada';

                      return GestureDetector(
                        onTap: () => setState(() => _mesaSeleccionada = mesa['id']),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF0F8A50)
                                  : Colors.grey.shade300,
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
                                  Text(
                                    'Mesa ${mesa['id']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? const Color(0xFF0F8A50)
                                          : Colors.black87,
                                    ),
                                  ),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isOcupada
                                          ? Colors.orange
                                          : const Color(0xFF0F8A50),
                                    ),
                                  )
                                ],
                              ),
                              Text(
                                '${mesa['personas']} personas',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
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
          ),

          // 2. COLUMNA CENTRAL: BÚSQUEDA Y MENÚ DE PRODUCTOS
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Campo de Búsqueda
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar producto...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Selector de Categorías (Chips)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categorias.map((cat) {
                        final bool isSel = _categoriaSeleccionada == cat['nombre'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text('${cat['emoji']} ${cat['nombre']}'),
                            selected: isSel,
                            selectedColor: const Color(0xFF0F8A50),
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (val) {
                              setState(() {
                                _categoriaSeleccionada = cat['nombre']!;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tarjetas de Productos
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: _productos.length,
                      itemBuilder: (context, index) {
                        final prod = _productos[index];
                        return GestureDetector(
                          onTap: () => _agregarAComanda(prod),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Text(
                                    prod['emoji'],
                                    style: const TextStyle(fontSize: 38),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  prod['nombre'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  prod['descripcion'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '\$${prod['precio'].toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Color(0xFF0F8A50),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
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
            ),
          ),

          // 3. COLUMNA DERECHA: RESUMEN DE COMANDA
          Container(
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
                    const Text(
                      'Comanda',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (_mesaSeleccionada != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Mesa $_mesaSeleccionada',
                          style: const TextStyle(
                            color: Color(0xFF0F8A50),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Lista de la Comanda
                Expanded(
                  child: _comandaActual.isEmpty
                      ? Center(
                          child: Text(
                            'Toca un producto para agregarlo a la comanda',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _comandaActual.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = _comandaActual[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Text(item['emoji'], style: const TextStyle(fontSize: 22)),
                              title: Text(
                                item['nombre'],
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              trailing: Text(
                                '\$${item['precio']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          },
                        ),
                ),

                const Divider(),
                const SizedBox(height: 8),

                // Total y Botón
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total:',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    Text(
                      '\$${_totalComanda.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F8A50),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F8A50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _comandaActual.isEmpty
                        ? null
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Comanda enviada a cocina para la Mesa $_mesaSeleccionada',
                                ),
                              ),
                            );
                            setState(() => _comandaActual.clear());
                          },
                    child: const Text(
                      'Enviar a Cocina',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}