class Mesa {
  final int id;
  final int numero;
  final int capacidad;
  final String estado; // 'libre', 'ocupada', 'cuenta'
  final String? mesero;
  final double totalActual;

  Mesa({
    required this.id,
    required this.numero,
    required this.capacidad,
    required this.estado,
    this.mesero,
    this.totalActual = 0.0,
  });

  factory Mesa.fromMap(Map<String, dynamic> map) {
    return Mesa(
      id: map['id'],
      numero: map['numero'],
      capacidad: map['capacidad'] ?? 4,
      estado: map['estado'] ?? 'libre',
      mesero: map['mesero'],
      totalActual: (map['total_actual'] != null)
          ? double.tryParse(map['total_actual'].toString()) ?? 0.0
          : 0.0,
    );
  }
}