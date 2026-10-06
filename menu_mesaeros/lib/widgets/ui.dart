// Utilidades de interfaz compartidas por las pantallas.
import 'package:flutter/material.dart';

const Color kCafe = Color(0xFF26201B);
const Color kVerde = Color(0xFF0F8A50);
const Color kRojo = Color(0xFFC62828);

/// SnackBar rápido (verde = ok, rojo = error).
void mensaje(BuildContext context, String texto, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: error ? kRojo : null,
      duration: Duration(seconds: error ? 4 : 2),
    ));
}

/// Diálogo de confirmación. Devuelve true si el usuario acepta.
Future<bool> confirmar(BuildContext context, String titulo, String detalle,
    {String aceptar = 'Aceptar', bool peligro = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(detalle),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(aceptar, style: TextStyle(color: peligro ? kRojo : kVerde, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Campo de lista desplegable con borde (sin usar DropdownButtonFormField).
class Selector<T> extends StatelessWidget {
  final String? etiqueta;
  final T? valor;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const Selector({
    super.key,
    this.etiqueta,
    required this.valor,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: etiqueta,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: valor,
          isExpanded: true,
          isDense: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Diálogo con un solo campo de texto (p. ej. nombre de un área o categoría).
Future<String?> pedirTexto(BuildContext context, String titulo,
    {String inicial = '', String etiqueta = 'Nombre'}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextoDialog(titulo: titulo, inicial: inicial, etiqueta: etiqueta),
  );
}

class _TextoDialog extends StatefulWidget {
  final String titulo;
  final String inicial;
  final String etiqueta;
  const _TextoDialog({required this.titulo, required this.inicial, required this.etiqueta});

  @override
  State<_TextoDialog> createState() => _TextoDialogState();
}

class _TextoDialogState extends State<_TextoDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _aceptar() {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        controller: _c,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.etiqueta, border: const OutlineInputBorder()),
        onSubmitted: (_) => _aceptar(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: _aceptar, child: const Text('Guardar')),
      ],
    );
  }
}

/// Convierte "12,5" o "12.5" en double (null si no es número).
double? leerNumero(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));
