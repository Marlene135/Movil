// widgets/modificadores_dialog.dart - Formulario de extras / exclusiones / nota
// que se abre desde el botón "+ Nota" de cada platillo de la comanda.
import 'package:flutter/material.dart';
import '../modulos/conv.dart';
import 'ui.dart';

/// Extras disponibles (nombre, precio). Edita esta lista para cambiar las opciones.
const List<({String nombre, double precio})> kExtrasDisponibles = [
  (nombre: 'Extra Tocino', precio: 15),
  (nombre: 'Doble Queso', precio: 20),
  (nombre: 'Papas a la francesa', precio: 35),
];

/// Exclusiones disponibles ("Sin ..."). Edita esta lista para cambiar las opciones.
const List<String> kExclusionesDisponibles = [
  'Sin Cebolla',
  'Sin Jitomate',
];

/// Selección hecha en el formulario.
class ModificadoresSeleccion {
  final Set<String> extras;
  final Set<String> sin;
  final String nota;

  const ModificadoresSeleccion({this.extras = const {}, this.sin = const {}, this.nota = ''});

  bool get vacia => extras.isEmpty && sin.isEmpty && nota.trim().isEmpty;

  /// Texto único que se guarda en `notas` y se envía a cocina.
  String get texto {
    final partes = <String>[
      if (extras.isNotEmpty) extras.join(', '),
      if (sin.isNotEmpty) sin.join(', '),
      if (nota.trim().isNotEmpty) nota.trim(),
    ];
    return partes.join(' · ');
  }
}

/// Abre el formulario. Devuelve la selección, o `null` si se cierra sin guardar.
Future<ModificadoresSeleccion?> pedirModificadores(
  BuildContext context, {
  required String producto,
  required double precio,
  ModificadoresSeleccion inicial = const ModificadoresSeleccion(),
}) {
  return showDialog<ModificadoresSeleccion>(
    context: context,
    builder: (_) => _ModificadoresDialog(producto: producto, precio: precio, inicial: inicial),
  );
}

class _ModificadoresDialog extends StatefulWidget {
  final String producto;
  final double precio;
  final ModificadoresSeleccion inicial;
  const _ModificadoresDialog({required this.producto, required this.precio, required this.inicial});

  @override
  State<_ModificadoresDialog> createState() => _ModificadoresDialogState();
}

class _ModificadoresDialogState extends State<_ModificadoresDialog> {
  late final Set<String> _extras = {...widget.inicial.extras};
  late final Set<String> _sin = {...widget.inicial.sin};
  late final TextEditingController _nota = TextEditingController(text: widget.inicial.nota);

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  double get _total => widget.precio +
      kExtrasDisponibles.where((e) => _extras.contains(e.nombre)).fold(0.0, (s, e) => s + e.precio);

  void _alternar(Set<String> set, String valor) =>
      setState(() => set.contains(valor) ? set.remove(valor) : set.add(valor));

  void _guardar() => Navigator.pop(
        context,
        ModificadoresSeleccion(extras: _extras, sin: _sin, nota: _nota.text),
      );

  @override
  Widget build(BuildContext context) {
    return TemaSazon(
      child: Dialog(
        backgroundColor: Colors.white,
        shape: kFormaDialogo,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _encabezado(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _seccion('AGREGAR EXTRAS'),
                      for (final e in kExtrasDisponibles)
                        _opcion(
                          e.nombre,
                          precio: '+${dinero(e.precio)}',
                          activa: _extras.contains(e.nombre),
                          onTap: () => _alternar(_extras, e.nombre),
                        ),
                      const SizedBox(height: 14),
                      _seccion('EXCLUSIONES (SIN)'),
                      for (final s in kExclusionesDisponibles)
                        _opcion(s, activa: _sin.contains(s), onTap: () => _alternar(_sin, s)),
                      const SizedBox(height: 14),
                      _seccion('NOTA ADICIONAL'),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextField(
                          controller: _nota,
                          maxLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Ej. término medio',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: kBorde),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: kBorde),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _guardar,
                    style: FilledButton.styleFrom(
                      backgroundColor: kTexto,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Guardar nota', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                          child: Text(dinero(_total),
                              style: const TextStyle(color: kTexto, fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _encabezado() => Container(
        color: kTexto,
        padding: const EdgeInsets.fromLTRB(20, 18, 8, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.producto,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(dinero(widget.precio), style: const TextStyle(color: Color(0xFFD6D0C6), fontSize: 13)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ),
      );

  Widget _seccion(String titulo) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: kFondo, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Expanded(
              child: Text(titulo,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: kTexto)),
            ),
            const Text('OPCIONAL',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6))),
          ],
        ),
      );

  Widget _opcion(String nombre, {String? precio, required bool activa, required VoidCallback onTap}) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: activa ? kTexto : kBorde, width: activa ? 1.5 : 1),
            ),
            child: Row(
              children: [
                if (activa) ...[
                  const Icon(Icons.check_circle, size: 18, color: kTexto),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(nombre,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTexto)),
                ),
                if (precio != null)
                  Text(precio, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextoSuave)),
              ],
            ),
          ),
        ),
      );
}