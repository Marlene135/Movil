// selecion y estado de mesas interactivo con fusion
import 'package:flutter/material.dart';
import '../widgets/MesaWidget.dart';

class MesasScreen extends StatefulWidget {
  final Map<String, dynamic>? usuario;

  const MesasScreen({Key? key, this.usuario}) : super(key: key);

  @override
  State<MesasScreen> createState() => _MesasScreenState();
}

class _MesasScreenState extends State<MesasScreen> {
  int _personas = 2;
  String _areaSeleccionada = 'Terraza';
  int? _mesaSeleccionadaId = 3;

  final List<String> _areas = ['Terraza', 'Main room', 'Barra'];

  // Listado de mesas con coordenadas (x, y) y soporte de fusiones
  final List<Map<String, dynamic>> _mesas = [
    {'id': 1, 'numero': '1', 'x': 250.0, 'y': 220.0, 'grupoId': null},
    {'id': 2, 'numero': '2', 'x': 340.0, 'y': 220.0, 'grupoId': null},
    {'id': 3, 'numero': '3', 'x': 430.0, 'y': 220.0, 'grupoId': null},
  ];

  // Función para agregar una nueva mesa en el plano
  void _agregarMesa() {
    setState(() {
      final int nuevoId = _mesas.isEmpty ? 1 : (_mesas.map((m) => m['id'] as int).reduce((a, b) => a > b ? a : b)) + 1;
      _mesas.add({
        'id': nuevoId,
        'numero': '$nuevoId',
        'x': 200.0 + (_mesas.length * 20),
        'y': 200.0,
        'grupoId': null,
      });
      _mesaSeleccionadaId = nuevoId;
    });
  }

  // Detecta si dos mesas están lo suficientemente cerca como para unirse
  void _verificarCercaniaYJuntar(Map<String, dynamic> mesaArrastrada) {
    for (var otraMesa in _mesas) {
      if (otraMesa['id'] == mesaArrastrada['id']) continue;

      double dx = (mesaArrastrada['x'] as double) - (otraMesa['x'] as double);
      double dy = (mesaArrastrada['y'] as double) - (otraMesa['y'] as double);

      // Distancia euclidiana menor a 65 píxeles activa la fusión
      if (dx.abs() < 65 && dy.abs() < 65) {
        setState(() {
          int nuevoGrupo = otraMesa['grupoId'] ?? otraMesa['id'];
          mesaArrastrada['grupoId'] = nuevoGrupo;
          otraMesa['grupoId'] = nuevoGrupo;

          // Alineación magnética suave para pegarlas visualmente
          mesaArrastrada['x'] = otraMesa['x'] + (dx > 0 ? 62.0 : -62.0);
          mesaArrastrada['y'] = otraMesa['y'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Mesa ${mesaArrastrada['numero']} unida con Mesa ${otraMesa['numero']}!',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      }
    }
  }

  // Separa una mesa del grupo
  void _separarMesa(Map<String, dynamic> mesa) {
    setState(() {
      mesa['grupoId'] = null;
      mesa['x'] += 40.0; // La desplaza ligeramente para desatarla
    });
  }

  // Obtener la etiqueta formateada para el botón
  String _obtenerNombreMesaSeleccionada() {
    if (_mesaSeleccionadaId == null) return 'Selecciona una Mesa';
    final mesaActual = _mesas.firstWhere((m) => m['id'] == _mesaSeleccionadaId, orElse: () => {});
    if (mesaActual.isEmpty) return 'Selecciona una Mesa';

    if (mesaActual['grupoId'] != null) {
      final unidas = _mesas
          .where((m) => m['grupoId'] == mesaActual['grupoId'])
          .map((m) => m['numero'])
          .join('+');
      return 'Asignar Mesas Uniones ($unidas)';
    }

    return 'Asignar Mesa ${mesaActual['numero']}';
  }

  @override
  Widget build(BuildContext context) {
    final String tituloHeader = widget.usuario != null
        ? 'Mesas - ${widget.usuario!['nombre'] ?? 'Cajero Principal'}'
        : 'Mesas - Cajero Principal';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
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
      body: Row(
        children: [
          // -------------------------------------------------------------
          // PANEL IZQUIERDO
          // -------------------------------------------------------------
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Área / Zona',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _areaSeleccionada,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: _areas.map((area) {
                    return DropdownMenuItem(value: area, child: Text(area));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _areaSeleccionada = val);
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Personas (Covers)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
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
                      Text(
                        '$_personas personas',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
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
                            color: const Color(0xFF0F8A50),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _agregarMesa,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    side: const BorderSide(color: Color(0xFF0F8A50)),
                    foregroundColor: const Color(0xFF0F8A50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Agregar Mesa',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F8A50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _mesaSeleccionadaId == null
                        ? null
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${_obtenerNombreMesaSeleccionada()} asignada en $_areaSeleccionada para $_personas personas.',
                                ),
                              ),
                            );
                          },
                    child: Text(
                      _obtenerNombreMesaSeleccionada(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ),
                )
              ],
            ),
          ),

          // -------------------------------------------------------------
          // ÁREA DERECHA: PLANO INTERACTIVO
          // -------------------------------------------------------------
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Text(
                      _areaSeleccionada,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F8A50),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: _mesas.map((mesa) {
                          final bool isSelected = _mesaSeleccionadaId == mesa['id'];
                          final bool estaUnida = mesa['grupoId'] != null;

                          return Positioned(
                            left: mesa['x'],
                            top: mesa['y'],
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _mesaSeleccionadaId = mesa['id'];
                                });
                              },
                              onPanUpdate: (details) {
                                setState(() {
                                  mesa['x'] = (mesa['x'] + details.delta.dx)
                                      .clamp(0.0, constraints.maxWidth - 70);
                                  mesa['y'] = (mesa['y'] + details.delta.dy)
                                      .clamp(0.0, constraints.maxHeight - 70);
                                });
                              },
                              onPanEnd: (_) {
                                _verificarCercaniaYJuntar(mesa);
                              },
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  MesaWidget(
                                    numero: estaUnida ? 'M${mesa['numero']}' : mesa['numero'],
                                    isSelected: isSelected || (estaUnida && _mesas.any((m) => m['id'] == _mesaSeleccionadaId && m['grupoId'] == mesa['grupoId'])),
                                  ),
                                  // Botón opcional para separar mesa si está unida
                                  if (estaUnida)
                                    Positioned(
                                      top: -12,
                                      right: -12,
                                      child: GestureDetector(
                                        onTap: () => _separarMesa(mesa),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.link_off_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
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