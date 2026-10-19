  /* import 'package:flutter/material.dart';
import '../servicios/api_service.dart';

class CuentasVista extends StatefulWidget {
  const CuentasVista({Key? key}) : super(key: key);

  @override
  State<CuentasVista> createState() => _CuentasVistaState();
}

class _CuentasVistaState extends State<CuentasVista> {
  final ApiService _apiService = ApiService();
  List<dynamic> _cuentas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarCuentas();
  }

  Future<void> _cargarCuentas() async {
    setState(() => _cargando = true);
    final cuentas = await _apiService.obtenerCuentasPendientes();
    setState(() {
      _cuentas = cuentas;
      _cargando = false;
    });
  }

  void _mostrarModalCobro(Map<String, dynamic> cuenta) {
    String metodoSeleccionado = 'Efectivo';
    final TextEditingController montoController = TextEditingController(text: cuenta['total'].toString());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double total = double.tryParse(cuenta['total'].toString()) ?? 0.0;
            double recibido = double.tryParse(montoController.text) ?? 0.0;
            double cambio = recibido - total;

            return AlertDialog(
              title: Text('Cobrar Orden #${cuenta['id']} - Mesa ${cuenta['mesa_numero'] ?? 'N/A'}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total a Pagar: \$${total.toStringAsFixed(2)}', 
                         style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    const Text('Forma de Pago:'),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: metodoSeleccionado,
                      items: <String>['Efectivo', 'Tarjeta', 'Transferencia']
                          .map((String value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ))
                          .toList(),
                      onChanged: (String? nuevoValor) {
                        if (nuevoValor != null) {
                          setModalState(() => metodoSeleccionado = nuevoValor);
                        }
                      },
                    ),
                    if (metodoSeleccionado == 'Efectivo') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: montoController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Monto Recibido',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) => setModalState(() {}),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Cambio: \$${cambio >= 0 ? cambio.toStringAsFixed(2) : '0.00'}',
                        style: TextStyle(
                          fontSize: 16,
                          color: cambio >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    bool ok = await _apiService.cobrarCuenta(
                      int.parse(cuenta['id'].toString()),
                      metodoSeleccionado.toLowerCase(),
                      recibido,
                    );
                    if (ok) {
                      Navigator.pop(context);
                      _cargarCuentas();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cuenta cobrada con éxito')),
                      );
                    }
                  },
                  child: const Text('Confirmar Cobro'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas por Cobrar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarCuentas,
          )
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _cuentas.isEmpty
              ? const Center(child: Text('No hay cuentas pendientes por cobrar'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _cuentas.length,
                  itemBuilder: (context, index) {
                    final cuenta = _cuentas[index];
                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () => _mostrarModalCobro(cuenta),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Mesa ${cuenta['mesa_numero'] ?? 'N/A'}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              Text('Orden #${cuenta['id']}'),
                              const SizedBox(height: 10),
                              Text(
                                '\$${double.tryParse(cuenta['total'].toString())?.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Chip(
                                label: Text('Pendiente', style: TextStyle(color: Colors.white)),
                                backgroundColor: Colors.orange,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

*/