// selecion y estado de mesas
import 'package:flutter/material.dart';
import '../servicios/db_service.dart';

class MesasScreen extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const MesasScreen({super.key, required this.usuario});

  @override
  State<MesasScreen> createState() => _MesasScreenState();
}

class _MesasScreenState extends State<MesasScreen> {
  late Future<List<Map<String, dynamic>>> _mesasFuture;
  String _filtroEstado = 'todas'; // 'todas', 'libre', 'ocupada'

  @override
  void initState() {
    super.initState();
    _cargarMesas();
  }

  void _cargarMesas() {
    setState(() {
      _mesasFuture = _obtenerMesasConFallback();
    });
  }

  // Consulta a Postgres con datos de prueba de respaldo
  Future<List<Map<String, dynamic>>> _obtenerMesasConFallback() async {
    try {
      return await DbService.obtenerMesas();
    } catch (_) {
      // Datos mock si no hay conexión en ese momento
      return [
        {'id': 1, 'numero': 1, 'capacidad': 4, 'estado': 'libre', 'mesero': null, 'total_actual': 0.0},
        {'id': 2, 'numero': 2, 'capacidad': 2, 'estado': 'ocupada', 'mesero': 'Nancy', 'total_actual': 345.50},
        {'id': 3, 'numero': 3, 'capacidad': 6, 'estado': 'libre', 'mesero': null, 'total_actual': 0.0},
        {'id': 4, 'numero': 4, 'capacidad': 4, 'estado': 'cuenta', 'mesero': 'Nancy', 'total_actual': 520.00},
        {'id': 5, 'numero': 5, 'capacidad': 4, 'estado': 'libre', 'mesero': null, 'total_actual': 0.0},
        {'id': 6, 'numero': 6, 'capacidad': 8, 'estado': 'ocupada', 'mesero': 'Carlos', 'total_actual': 1180.00},
      ];
    }
  }

  Color _getColorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'libre':
        return const Color(0xFF2E7D32); // Verde
      case 'ocupada':
        return const Color(0xFFC62828); // Rojo
      case 'cuenta':
        return const Color(0xFFE65100); // Naranja
      default:
        return const Color(0xFF6B645C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String nombreMesero = widget.usuario['nombre'] ?? 'Mesero';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F4EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF8F5),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SazónTrack',
              style: TextStyle(
                fontFamily: 'serif',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF26201B),
              ),
            ),
            Text(
              'Mesero: $nombreMesero',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8C847B),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF26201B)),
            onPressed: _cargarMesas,
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFC62828)),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Cerrar Turno',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filtros rápidos
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _buildFiltroChip('Todas', 'todas'),
                  const SizedBox(width: 8),
                  _buildFiltroChip('Libres', 'libre'),
                  const SizedBox(width: 8),
                  _buildFiltroChip('Ocupadas', 'ocupada'),
                ],
              ),
            ),

            // Cuadrícula de Mesas
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _mesasFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF26201B)),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error al cargar mesas: ${snapshot.error}'),
                    );
                  }

                  final todasLasMesas = snapshot.data ?? [];
                  final mesasFiltradas = todasLasMesas.where((m) {
                    if (_filtroEstado == 'todas') return true;
                    return m['estado'] == _filtroEstado;
                  }).toList();

                  if (mesasFiltradas.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay mesas en esta categoría',
                        style: TextStyle(color: Color(0xFF8C847B)),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: mesasFiltradas.length,
                    itemBuilder: (context, index) {
                      final mesa = mesasFiltradas[index];
                      return _buildMesaCard(mesa);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltroChip(String label, String valor) {
    final bool seleccionado = _filtroEstado == valor;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: seleccionado ? Colors.white : const Color(0xFF26201B),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: seleccionado,
      selectedColor: const Color(0xFF26201B),
      backgroundColor: const Color(0xFFECE7DF),
      onSelected: (selected) {
        if (selected) {
          setState(() => _filtroEstado = valor);
        }
      },
    );
  }

  Widget _buildMesaCard(Map<String, dynamic> mesa) {
    final estado = mesa['estado'] ?? 'libre';
    final colorEstado = _getColorEstado(estado);
    final int numero = mesa['numero'] ?? 0;
    final int capacidad = mesa['capacidad'] ?? 4;
    final double total = (mesa['total_actual'] != null)
        ? double.tryParse(mesa['total_actual'].toString()) ?? 0.0
        : 0.0;

    return Material(
      color: const Color(0xFFFAF8F5),
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          // Navegar a la toma de comanda / menú pasando la mesa seleccionada
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mesa $numero seleccionada'),
              duration: const Duration(milliseconds: 600),
            ),
          );
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(
          //     builder: (_) => MenuScreen(mesa: mesa, usuario: widget.usuario),
          //   ),
          // );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5DFD4), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mesa $numero',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF26201B),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorEstado.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      estado.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorEstado,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.people_outline, size: 16, color: Color(0xFF8C847B)),
                  const SizedBox(width: 4),
                  Text(
                    'Cap. $capacidad pers.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8C847B)),
                  ),
                ],
              ),
              if (estado != 'libre')
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF26201B),
                  ),
                )
              else
                const Text(
                  'Disponible',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF8C847B),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}