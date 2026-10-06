import 'conv.dart';

class Reserva {
  final int id;
  final int? idMesa;
  final String mesa;
  final String area;
  final String cliente;
  final String telefono;
  final DateTime fecha; // solo la fecha (00:00)
  final String hora; // HH:mm
  final int personas;
  final String tipoEvento;
  final String notas;
  final String estado; // programada | pendiente | confirmada | cancelada | completada

  Reserva({
    required this.id,
    this.idMesa,
    this.mesa = '',
    this.area = '',
    required this.cliente,
    this.telefono = '',
    required this.fecha,
    required this.hora,
    required this.personas,
    this.tipoEvento = 'Normal',
    this.notas = '',
    this.estado = 'programada',
  });

  factory Reserva.fromMap(Map<String, dynamic> m) {
    final f = DateTime.tryParse(toStr(m['fecha'])) ?? DateTime.now();
    return Reserva(
      id: toInt(m['id']),
      idMesa: toIntN(m['id_mesa']),
      mesa: toStr(m['mesa']),
      area: toStr(m['area']),
      cliente: toStr(m['nombre_cliente']),
      telefono: toStr(m['telefono']),
      fecha: DateTime(f.year, f.month, f.day),
      hora: toStr(m['hora'], '00:00'),
      personas: toInt(m['num_personas'], 1),
      tipoEvento: toStr(m['tipo_evento'], 'Normal'),
      notas: toStr(m['alergias_notas']),
      estado: toStr(m['estado'], 'programada').toLowerCase(),
    );
  }

  String get fechaIso =>
      '${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

  String get estadoEtiqueta {
    switch (estado) {
      case 'confirmada':
        return 'Confirmada';
      case 'pendiente':
        return 'Pendiente';
      case 'cancelada':
        return 'Cancelada';
      case 'completada':
        return 'Completada';
      default:
        return 'Reservada';
    }
  }
}
