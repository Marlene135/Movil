import 'conv.dart';

class Area {
  final int id;
  final String nombre;
  Area({required this.id, required this.nombre});

  factory Area.fromMap(Map<String, dynamic> m) =>
      Area(id: toInt(m['id']), nombre: toStr(m['nombre']));
}

class Mesa {
  final int id;
  String numero;
  int capacidad;
  String estado; // disponible | ocupada | por_limpiar | reservada
  int? idArea;
  String area;
  double x;
  double y;
  int? grupo; // mesas unidas comparten el mismo valor
  final int? idOrden;
  final double totalActual;
  final int comensales;
  final String? mesero;

  Mesa({
    required this.id,
    required this.numero,
    this.capacidad = 4,
    this.estado = 'disponible',
    this.idArea,
    this.area = '',
    this.x = 0,
    this.y = 0,
    this.grupo,
    this.idOrden,
    this.totalActual = 0.0,
    this.comensales = 0,
    this.mesero,
  });

  factory Mesa.fromMap(Map<String, dynamic> m) => Mesa(
        id: toInt(m['id']),
        numero: toStr(m['numero']),
        capacidad: toInt(m['capacidad'], 4),
        estado: toStr(m['estado'], 'disponible'),
        idArea: toIntN(m['id_area']),
        area: toStr(m['area']),
        x: toDouble(m['pos_x']),
        y: toDouble(m['pos_y']),
        grupo: toIntN(m['grupo_union']),
        idOrden: toIntN(m['id_orden']),
        totalActual: toDouble(m['total_actual']),
        comensales: toInt(m['comensales']),
        mesero: m['mesero']?.toString(),
      );

  bool get ocupada => estado == 'ocupada';

  /// Etiqueta para listas desplegables: "T1 · Terraza"
  String get etiqueta => area.isEmpty ? numero : '$numero · $area';
}

class OrdenItem {
  final int idDetalle;
  final int? idProducto;
  final String nombre;
  final int cantidad;
  final double precio;
  final String notas;
  final String estado; // PENDIENTE | EN_PREPARACION | LISTO | ENTREGADO
  final String estacion;

  OrdenItem({
    required this.idDetalle,
    this.idProducto,
    required this.nombre,
    required this.cantidad,
    required this.precio,
    this.notas = '',
    this.estado = 'PENDIENTE',
    this.estacion = 'cocina',
  });

  factory OrdenItem.fromMap(Map<String, dynamic> m) => OrdenItem(
        idDetalle: toInt(m['id_detalle']),
        idProducto: toIntN(m['id_producto']),
        nombre: toStr(m['nombre']),
        cantidad: toInt(m['cantidad'], 1),
        precio: toDouble(m['precio']),
        notas: toStr(m['notas']),
        estado: toStr(m['estado'], 'PENDIENTE'),
        estacion: toStr(m['estacion'], 'cocina'),
      );

  double get subtotal => cantidad * precio;
}

class Orden {
  final int id;
  final String folio;
  final int? idMesa;
  final double subtotal;
  final double total;
  final int comensales;
  final List<OrdenItem> items;

  Orden({
    required this.id,
    required this.folio,
    this.idMesa,
    this.subtotal = 0,
    this.total = 0,
    this.comensales = 1,
    this.items = const [],
  });

  factory Orden.fromMap(Map<String, dynamic> m) => Orden(
        id: toInt(m['id_orden']),
        folio: toStr(m['folio']),
        idMesa: toIntN(m['id_mesa']),
        subtotal: toDouble(m['subtotal']),
        total: toDouble(m['total']),
        comensales: toInt(m['comensales'], 1),
        items: ((m['items'] as List?) ?? const [])
            .map((e) => OrdenItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Platillo en la pantalla de cocina (KDS), con datos de su cuenta y mesa.
class KdsItem {
  final int idDetalle;
  final int idOrden;
  final String folio;
  final String mesa;
  final String nombre;
  final int cantidad;
  final String notas;
  final String estado;
  final String estacion;
  final int minutos;

  KdsItem({
    required this.idDetalle,
    required this.idOrden,
    required this.folio,
    required this.mesa,
    required this.nombre,
    required this.cantidad,
    this.notas = '',
    required this.estado,
    required this.estacion,
    this.minutos = 0,
  });

  factory KdsItem.fromMap(Map<String, dynamic> m) => KdsItem(
        idDetalle: toInt(m['id_detalle']),
        idOrden: toInt(m['id_orden']),
        folio: toStr(m['folio']),
        mesa: toStr(m['mesa']),
        nombre: toStr(m['nombre']),
        cantidad: toInt(m['cantidad'], 1),
        notas: toStr(m['notas']),
        estado: toStr(m['estado'], 'PENDIENTE'),
        estacion: toStr(m['estacion'], 'cocina'),
        minutos: toInt(m['minutos']),
      );
}

String etiquetaEstadoItem(String estado) {
  switch (estado) {
    case 'EN_PREPARACION':
      return 'En preparación';
    case 'LISTO':
      return 'Listo';
    case 'ENTREGADO':
      return 'Entregado';
    case 'CANCELADO':
      return 'Cancelado';
    default:
      return 'Pendiente';
  }
}
