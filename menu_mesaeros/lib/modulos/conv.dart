// Conversión segura de valores que llegan de PHP/PostgreSQL
// (los numeric llegan como String, los booleanos pueden ser bool, 't' o 1...).
int toInt(dynamic v, [int defecto = 0]) {
  if (v == null) return defecto;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is bool) return v ? 1 : 0;
  return int.tryParse(v.toString()) ?? double.tryParse(v.toString())?.toInt() ?? defecto;
}

int? toIntN(dynamic v) {
  if (v == null || v.toString().isEmpty) return null;
  return toInt(v);
}

double toDouble(dynamic v, [double defecto = 0.0]) {
  if (v == null) return defecto;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? defecto;
}

bool toBool(dynamic v, [bool defecto = false]) {
  if (v == null) return defecto;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase();
  return s == 't' || s == 'true' || s == '1';
}

String toStr(dynamic v, [String defecto = '']) => v == null ? defecto : v.toString();

String dinero(double v) => '\$${v.toStringAsFixed(2)}';
