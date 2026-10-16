// vistas/reservaciones.dart - Calendario y detalle de reservas (datos reales)
import 'package:flutter/material.dart';
import '../modulos/orden.dart';
import '../modulos/reserva.dart';
import '../servicios/api_service.dart';
import '../servicios/db_service.dart';
import '../widgets/ui.dart';

const Color _kGranate = Color(0xFF8B0000);
const List<String> _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
];
const List<String> _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

String _fechaLarga(DateTime d) => '${_dias[d.weekday - 1]}, ${d.day} de ${_meses[d.month - 1]} de ${d.year}';

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

Color _colorEstado(String e) {
  switch (e) {
    case 'confirmada':
      return Colors.green;
    case 'pendiente':
      return Colors.amber.shade700;
    case 'cancelada':
      return Colors.grey;
    case 'completada':
      return Colors.teal;
    default:
      return Colors.blue;
  }
}

class ReservacionesVista extends StatefulWidget {
  final Map<String, dynamic>? usuario;

  const ReservacionesVista({super.key, this.usuario});

  @override
  State<ReservacionesVista> createState() => _ReservacionesVistaState();
}

class _ReservacionesVistaState extends State<ReservacionesVista> {
  late DateTime _mes; // primer día del mes mostrado
  late DateTime _diaSeleccionado;
  List<Reserva> _reservas = [];
  List<Mesa> _mesas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _mes = DateTime(hoy.year, hoy.month, 1);
    _diaSeleccionado = DateTime(hoy.year, hoy.month, hoy.day);
    _cargar();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso && mounted) setState(() => _cargando = true);
    try {
      final res = await Future.wait([
        DbService.obtenerReservasMes(_mes.year, _mes.month),
        DbService.obtenerMesas(),
      ]);
      if (!mounted) return;
      setState(() {
        _reservas = res[0] as List<Reserva>;
        _mesas = res[1] as List<Mesa>;
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

  void _cambiarMes(int delta) {
    setState(() {
      _mes = DateTime(_mes.year, _mes.month + delta, 1);
      _diaSeleccionado = _mes;
    });
    _cargar();
  }

  void _irAHoy() {
    final hoy = DateTime.now();
    final cambioMes = hoy.year != _mes.year || hoy.month != _mes.month;
    setState(() {
      _mes = DateTime(hoy.year, hoy.month, 1);
      _diaSeleccionado = DateTime(hoy.year, hoy.month, hoy.day);
    });
    if (cambioMes) _cargar();
  }

  List<Reserva> _delDia(DateTime d) => _reservas
      .where((r) => r.fecha.year == d.year && r.fecha.month == d.month && r.fecha.day == d.day)
      .toList();

  Future<void> _accion(Future<void> Function() f, String exito) async {
    try {
      await f();
      if (mounted) mensaje(context, exito);
    } on ApiException catch (e) {
      if (mounted) mensaje(context, e.mensaje, error: true);
    }
    await _cargar(silencioso: true);
  }

  Future<void> _formulario([Reserva? r]) async {
    final datos = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ReservaDialog(mesas: _mesas, reserva: r, fechaInicial: _diaSeleccionado),
    );
    if (datos == null) return;
    if (r == null) {
      await _accion(() => DbService.crearReserva(datos), 'Reserva agendada.');
    } else {
      await _accion(() => DbService.actualizarReserva(r.id, datos), 'Reserva actualizada.');
    }
    // si la fecha cae en otro mes, saltar a ese mes
    final f = DateTime.tryParse('${datos['fecha_reserva']}');
    if (f != null && (f.year != _mes.year || f.month != _mes.month)) {
      setState(() {
        _mes = DateTime(f.year, f.month, 1);
        _diaSeleccionado = DateTime(f.year, f.month, f.day);
      });
      await _cargar();
    } else if (f != null) {
      setState(() => _diaSeleccionado = DateTime(f.year, f.month, f.day));
    }
  }

  Future<void> _eliminar(Reserva r) async {
    final ok = await confirmar(context, 'Eliminar reserva', '¿Eliminar la reserva de ${r.cliente}?',
        aceptar: 'Eliminar', peligro: true);
    if (ok) await _accion(() => DbService.eliminarReserva(r.id), 'Reserva eliminada.');
  }

  @override
  Widget build(BuildContext context) {
    final reservasDelDia = _delDia(_diaSeleccionado);
    final activasDelDia = reservasDelDia.where((r) => r.estado != 'cancelada').toList();
    final hoy = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Calendario de Reservas',
            style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: Text(_cap(_fechaLarga(hoy)), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
            onPressed: () => _cargar(),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: kCafe))
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Text(_error!, textAlign: TextAlign.center)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: () => _cargar(), child: const Text('Reintentar')),
                  ]),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: _buildCalendario(hoy)),
                      const SizedBox(width: 16),
                      Expanded(flex: 4, child: _buildPanelDia(reservasDelDia, activasDelDia)),
                    ],
                  ),
                ),
    );
  }

  Widget _tarjeta({required Widget child}) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: child,
      );

  Widget _buildCalendario(DateTime hoy) {
    final primerDia = DateTime(_mes.year, _mes.month, 1);
    final diasMes = DateTime(_mes.year, _mes.month + 1, 0).day;
    final offset = primerDia.weekday % 7; // domingo = 0
    final celdas = ((offset + diasMes + 6) ~/ 7) * 7;

    return _tarjeta(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(children: [
                Icon(Icons.calendar_month_outlined, color: _kGranate, size: 20),
                SizedBox(width: 8),
                Text('Calendario de Reservas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              Row(children: [
                OutlinedButton(
                  onPressed: _irAHoy,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('Hoy', style: TextStyle(color: Colors.black87)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _formulario(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGranate,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text('Agendar', style: TextStyle(color: Colors.white)),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _cambiarMes(-1)),
              Text('${_cap(_meses[_mes.month - 1])} de ${_mes.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _cambiarMes(1)),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              _DiaHeader('DOM'), _DiaHeader('LUN'), _DiaHeader('MAR'),
              _DiaHeader('MIÉ'), _DiaHeader('JUE'), _DiaHeader('VIE'), _DiaHeader('SÁB'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.15,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: celdas,
              itemBuilder: (context, index) {
                final dia = index - offset + 1;
                final valido = dia >= 1 && dia <= diasMes;
                if (!valido) return const SizedBox.shrink();
                final fecha = DateTime(_mes.year, _mes.month, dia);
                final sel = fecha == _diaSeleccionado;
                final esHoy = fecha.year == hoy.year && fecha.month == hoy.month && fecha.day == hoy.day;
                final delDia = _delDia(fecha);
                final activas = delDia.where((r) => r.estado != 'cancelada').length;

                return GestureDetector(
                  onTap: () => setState(() => _diaSeleccionado = fecha),
                  child: Container(
                    decoration: BoxDecoration(
                      color: esHoy ? const Color(0xFFFFF3E0) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? _kGranate : Colors.grey.shade200, width: sel ? 2 : 1),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$dia',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12, color: sel ? _kGranate : Colors.black87)),
                            if (activas > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                child: Text('$activas',
                                    style: const TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Wrap(
                          spacing: 3,
                          children: delDia
                              .take(4)
                              .map((r) => Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(color: _colorEstado(r.estado), shape: BoxShape.circle)))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Row(children: [
            _LeyendaDot(Colors.green, 'Confirmada'),
            _LeyendaDot(Colors.amber.shade700, 'Pendiente'),
            _LeyendaDot(Colors.blue, 'Reservada'),
            _LeyendaDot(Colors.grey, 'Cancelada'),
            const Spacer(),
            Text('En el mes: ${_reservas.length}', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          ]),
        ],
      ),
    );
  }

  Widget _buildPanelDia(List<Reserva> delDia, List<Reserva> activas) {
    final comensales = activas.fold<int>(0, (s, r) => s + r.personas);
    return _tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('RESERVAS DEL DÍA',
                        style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text(_cap(_fechaLarga(_diaSeleccionado)),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _formulario(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGranate,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add, size: 14, color: Colors.white),
                label: const Text('Nueva', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: delDia.isEmpty
                ? Center(
                    child: Text('No hay reservas para el ${_diaSeleccionado.day} de ${_meses[_diaSeleccionado.month - 1]}',
                        style: TextStyle(color: Colors.grey.shade500), textAlign: TextAlign.center))
                : ListView.builder(
                    itemCount: delDia.length,
                    itemBuilder: (context, index) => _buildReserva(delDia[index]),
                  ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${activas.length} reserva(s) activa(s)', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
              Text('$comensales comensales previstos', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReserva(Reserva r) {
    final color = _colorEstado(r.estado);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(r.cliente,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: r.estado == 'cancelada' ? TextDecoration.lineThrough : null)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Text(r.estadoEtiqueta, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones',
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (v) {
                  switch (v) {
                    case 'editar':
                      _formulario(r);
                      break;
                    case 'eliminar':
                      _eliminar(r);
                      break;
                    default:
                      _accion(() => DbService.actualizarReserva(r.id, {'estado': v}), 'Reserva ${_etiquetaAccion(v)}.');
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'confirmada', child: Text('Confirmar')),
                  PopupMenuItem(value: 'pendiente', child: Text('Marcar pendiente')),
                  PopupMenuItem(value: 'completada', child: Text('Marcar completada (llegó)')),
                  PopupMenuItem(value: 'cancelada', child: Text('Cancelar')),
                  PopupMenuItem(value: 'editar', child: Text('Editar')),
                  PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          _linea(Icons.access_time, r.hora),
          const SizedBox(height: 4),
          _linea(Icons.people_outline, '${r.personas} personas'),
          const SizedBox(height: 4),
          _linea(Icons.place_outlined, r.mesa.isEmpty ? 'Sin mesa asignada' : 'Mesa ${r.mesa}${r.area.isEmpty ? '' : ' · ${r.area}'}'),
          if (r.telefono.isNotEmpty) ...[
            const SizedBox(height: 4),
            _linea(Icons.phone_outlined, r.telefono),
          ],
          if (r.tipoEvento.isNotEmpty && r.tipoEvento != 'Normal') ...[
            const SizedBox(height: 6),
            Text(r.tipoEvento, style: const TextStyle(fontSize: 11, color: _kGranate, fontWeight: FontWeight.w600)),
          ],
          if (r.notas.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(r.notas, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  String _etiquetaAccion(String estado) {
    switch (estado) {
      case 'confirmada':
        return 'confirmada';
      case 'cancelada':
        return 'cancelada';
      case 'completada':
        return 'marcada como completada';
      default:
        return 'actualizada';
    }
  }

  Widget _linea(IconData icono, String texto) => Row(children: [
        Icon(icono, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Expanded(child: Text(texto, style: const TextStyle(fontSize: 12, color: Colors.black87))),
      ]);
}

// =====================================================================
// Diálogo: nueva / editar reserva
// =====================================================================
class _ReservaDialog extends StatefulWidget {
  final List<Mesa> mesas;
  final Reserva? reserva;
  final DateTime fechaInicial;

  const _ReservaDialog({required this.mesas, this.reserva, required this.fechaInicial});

  @override
  State<_ReservaDialog> createState() => _ReservaDialogState();
}

class _ReservaDialogState extends State<_ReservaDialog> {
  static const List<String> _eventos = ['Normal', 'Cumpleaños', 'Aniversario', 'Negocios', 'Otro'];

  late final TextEditingController _cliente = TextEditingController(text: widget.reserva?.cliente ?? '');
  late final TextEditingController _telefono = TextEditingController(text: widget.reserva?.telefono ?? '');
  late final TextEditingController _personas = TextEditingController(text: '${widget.reserva?.personas ?? 2}');
  late final TextEditingController _notas = TextEditingController(text: widget.reserva?.notas ?? '');
  late DateTime _fecha;
  late TimeOfDay _hora;
  int? _mesa;
  String _evento = 'Normal';
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = widget.reserva;
    _fecha = r?.fecha ?? widget.fechaInicial;
    final partes = (r?.hora ?? '13:00').split(':');
    _hora = TimeOfDay(hour: int.tryParse(partes[0]) ?? 13, minute: partes.length > 1 ? int.tryParse(partes[1]) ?? 0 : 0);
    _mesa = r?.idMesa;
    if (_mesa != null && !widget.mesas.any((m) => m.id == _mesa)) _mesa = null;
    _evento = _eventos.contains(r?.tipoEvento) ? r!.tipoEvento : (r == null ? 'Normal' : 'Otro');
  }

  @override
  void dispose() {
    _cliente.dispose();
    _telefono.dispose();
    _personas.dispose();
    _notas.dispose();
    super.dispose();
  }

  String get _fechaIso =>
      '${_fecha.year.toString().padLeft(4, '0')}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}';
  String get _horaTxt => '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';

  Future<void> _elegirFecha() async {
    final f = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (f != null) setState(() => _fecha = f);
  }

  Future<void> _elegirHora() async {
    final h = await showTimePicker(context: context, initialTime: _hora);
    if (h != null) setState(() => _hora = h);
  }

  void _guardar() {
    final personas = int.tryParse(_personas.text.trim());
    if (_cliente.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el nombre del cliente.');
      return;
    }
    if (personas == null || personas < 1) {
      setState(() => _error = 'El número de personas debe ser al menos 1.');
      return;
    }
    Navigator.pop(context, {
      'nombre_cliente': _cliente.text.trim(),
      'telefono': _telefono.text.trim(),
      'fecha_reserva': _fechaIso,
      'hora_reserva': _horaTxt,
      'num_personas': personas,
      'id_mesa': _mesa,
      'tipo_evento': _evento,
      'alergias_notas': _notas.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.reserva == null ? 'Nueva reserva' : 'Editar reserva'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _cliente, decoration: const InputDecoration(labelText: 'Cliente', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                controller: _telefono,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _elegirFecha,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(_fechaIso),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _elegirHora,
                    icon: const Icon(Icons.access_time, size: 16),
                    label: Text(_horaTxt),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _personas,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Personas', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Selector<int?>(
                etiqueta: 'Mesa',
                valor: _mesa,
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Sin mesa asignada')),
                  ...widget.mesas.map((m) => DropdownMenuItem<int?>(
                      value: m.id, child: Text('Mesa ${m.etiqueta} (cap. ${m.capacidad})'))),
                ],
                onChanged: (v) => setState(() => _mesa = v),
              ),
              const SizedBox(height: 12),
              Selector<String>(
                etiqueta: 'Tipo de evento',
                valor: _evento,
                items: _eventos.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _evento = v ?? 'Normal'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notas,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Alergias / notas', border: OutlineInputBorder()),
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

// Widgets auxiliares
class _DiaHeader extends StatelessWidget {
  final String texto;
  const _DiaHeader(this.texto);
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(texto,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
    );
  }
}

class _LeyendaDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LeyendaDot(this.color, this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}
