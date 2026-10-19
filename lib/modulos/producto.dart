import 'conv.dart';

class Categoria {
  final int id;
  final String nombre;
  final String estacion; // 'cocina' | 'barra'
  final bool activa;

  Categoria({required this.id, required this.nombre, this.estacion = 'cocina', this.activa = true});

  factory Categoria.fromMap(Map<String, dynamic> m) => Categoria(
        id: toInt(m['id']),
        nombre: toStr(m['nombre']),
        estacion: toStr(m['estacion'], 'cocina'),
        activa: toBool(m['activa'], true),
      );
}

class Producto {
  final int id;
  final String nombre;
  final String descripcion;
  final double precio;
  final int? idCategoria;
  final String categoria;
  final String estacion;
  final bool activo;
  final bool disponible;
  final int tiempoPreparacion;
  final double costo;

  Producto({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    required this.precio,
    this.idCategoria,
    this.categoria = '',
    this.estacion = 'cocina',
    this.activo = true,
    this.disponible = true,
    this.tiempoPreparacion = 15,
    this.costo = 0,
  });

  factory Producto.fromMap(Map<String, dynamic> m) => Producto(
        id: toInt(m['id']),
        nombre: toStr(m['nombre']),
        descripcion: toStr(m['descripcion']),
        precio: toDouble(m['precio']),
        idCategoria: toIntN(m['id_categoria']),
        categoria: toStr(m['categoria']),
        estacion: toStr(m['estacion'], 'cocina'),
        activo: toBool(m['activo'], true),
        disponible: toBool(m['disponible'], true),
        tiempoPreparacion: toInt(m['tiempo_preparacion_min'], 15),
        costo: toDouble(m['costo']),
      );

  /// La base de datos no guarda emoji; se elige uno según el nombre/categoría.
  String get emoji {
    final t = '${nombre.toLowerCase()} ${categoria.toLowerCase()}';
    const reglas = <String, String>{
      'taco': '🌮', 'burrito': '🌯', 'hamburguesa': '🍔', 'pizza': '🍕', 'alita': '🍗', 'pollo': '🍗',
      'nacho': '🧀', 'queso': '🧀', 'guacamole': '🥑', 'ensalada': '🥗', 'sopa': '🍲', 'pasta': '🍝',
      'carne': '🥩', 'pescado': '🐟', 'camar': '🍤', 'postre': '🍰', 'pastel': '🍰', 'helado': '🍨',
      'margarita': '🍹', 'cocktel': '🍸', 'coctel': '🍸', 'cerveza': '🍺', 'vino': '🍷', 'café': '☕',
      'cafe': '☕', 'refresco': '🥤', 'agua': '💧', 'jugo': '🧃', 'bebida': '🥤', 'entrada': '🥑',
    };
    for (final e in reglas.entries) {
      if (t.contains(e.key)) return e.value;
    }
    return estacion == 'barra' ? '🥤' : '🍽️';
  }
}
