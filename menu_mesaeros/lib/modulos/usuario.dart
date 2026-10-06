// Permisos según el rol del usuario (el servidor aplica las mismas reglas).
String _rol(Map<String, dynamic>? usuario) =>
    (usuario?['rol'] ?? '').toString().trim().toLowerCase();

/// Administrador: puede editar catálogo, áreas y estructura de mesas.
bool esAdmin(Map<String, dynamic>? usuario) {
  final r = _rol(usuario);
  return r == 'administrador' || r == 'admin';
}

/// Caja o administrador: puede cancelar cuentas con consumo.
bool esCajaOAdmin(Map<String, dynamic>? usuario) => esAdmin(usuario) || _rol(usuario) == 'cajero';
