// Utilidades de interfaz compartidas por las pantallas.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------
// Paleta SazónTrack
// ---------------------------------------------------------------------
const Color kCafe = Color(0xFF26201B);
const Color kVerde = Color(0xFF0F8A50);
const Color kRojo = Color(0xFFC62828);

const Color kFondo = Color(0xFFF3F1EC); // fondo general (crema)
const Color kPanel = Color(0xFFFDFBF8); // paneles / barras laterales
const Color kBorde = Color(0xFFE5DFD4); // bordes suaves
const Color kBordePill = Color(0xFFCFC8BC); // borde de chips
const Color kTexto = Color(0xFF26201B);
const Color kTextoSuave = Color(0xFF8C847B);

// Colores de estado (mesas, KDS, reservas)
const Color kEstadoLibre = Color(0xFF1B9A63);
const Color kEstadoOcupada = Color(0xFFE03A3A);
const Color kEstadoReservada = Color(0xFFF5B800);
const Color kEstadoLimpiar = Color(0xFF2F6FE4);
const Color kCian = Color(0xFF18BFE8);
const Color kAmbar = Color(0xFFF5B800);
const Color kPrecio = Color(0xFF10B981);

const ShapeBorder kFormaDialogo =
    RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24)));

// ---------------------------------------------------------------------
// Tema local de las pantallas (botones, progreso, snackbars)
// ---------------------------------------------------------------------
class TemaSazon extends StatelessWidget {
  final Widget child;
  const TemaSazon({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    final esquema = base.colorScheme.copyWith(
      primary: kTexto,
      onPrimary: Colors.white,
      secondary: kVerde,
      surface: kPanel,
      onSurface: kTexto,
    );
    return Theme(
      data: base.copyWith(
        colorScheme: esquema,
        scaffoldBackgroundColor: kFondo,
        dividerColor: kBorde,
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: kTexto),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: kTexto,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kTexto,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: forma,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kTexto,
            side: const BorderSide(color: kTexto),
            shape: forma,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: kTexto,
          contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------
// Campos de texto con el estilo de la app
// ---------------------------------------------------------------------
OutlineInputBorder _borde(Color color, [double ancho = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: ancho),
    );

InputDecoration campo(String? etiqueta, {String? prefixText, String? hint, IconData? icono}) {
  return InputDecoration(
    labelText: etiqueta,
    hintText: hint,
    prefixText: prefixText,
    prefixIcon: icono == null ? null : Icon(icono, size: 20, color: kTextoSuave),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    labelStyle: const TextStyle(color: kTextoSuave),
    border: _borde(kBorde),
    enabledBorder: _borde(kBorde),
    focusedBorder: _borde(kTexto, 1.5),
  );
}

// ---------------------------------------------------------------------
// Componentes visuales reutilizables
// ---------------------------------------------------------------------

/// Título de página con subtítulo (se usa dentro del AppBar).
class TituloPagina extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final IconData? icono;
  final Color? colorIcono;

  const TituloPagina(this.titulo, {super.key, this.subtitulo, this.icono, this.colorIcono});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icono != null) ...[
          Icon(icono, size: 26, color: colorIcono ?? kTexto),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTexto, height: 1.1),
              ),
              if (subtitulo != null)
                Text(
                  subtitulo!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kTextoSuave, fontWeight: FontWeight.w400),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Botón redondo blanco para el AppBar (atrás, actualizar...).
class BotonRedondo extends StatelessWidget {
  final IconData icono;
  final String? tooltip;
  final VoidCallback? onPressed;

  const BotonRedondo({super.key, required this.icono, this.tooltip, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Center(
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(side: BorderSide(color: kBorde)),
          child: SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: tooltip,
              icon: Icon(icono, size: 20, color: kTexto),
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta blanca con esquinas redondeadas y sombra suave.
/// Si se indica [colorSuperior] dibuja una franja de color arriba (como las mesas).
class TarjetaSazon extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radio;
  final Color? colorSuperior;
  final Color? fondo;

  const TarjetaSazon({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radio = 22,
    this.colorSuperior,
    this.fondo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: fondo ?? kPanel,
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(color: kBorde),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (colorSuperior != null) Container(height: 5, color: colorSuperior),
          // Flexible: si la tarjeta tiene altura limitada, el contenido (p. ej. una
          // Column con Expanded) aprovecha el espacio disponible.
          Flexible(child: Padding(padding: padding, child: child)),
        ],
      ),
    );
  }
}

/// Chip en forma de píldora: seleccionado = fondo oscuro.
class PillChip extends StatelessWidget {
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;
  final VoidCallback? onLong;
  final Widget? leading;

  const PillChip({
    super.key,
    required this.texto,
    required this.seleccionado,
    required this.onTap,
    this.onLong,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLong,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: seleccionado ? kTexto : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: seleccionado ? kTexto : kBordePill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 6)],
              Text(
                texto,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: seleccionado ? Colors.white : kTexto,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Leyenda: punto de color dentro de una píldora blanca.
class LeyendaPill extends StatelessWidget {
  final Color color;
  final String texto;
  const LeyendaPill(this.color, this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: kBorde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(texto, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kTexto)),
        ],
      ),
    );
  }
}

/// Etiqueta de estado con fondo de color sólido (Disponible, Ocupada...).
class EtiquetaEstado extends StatelessWidget {
  final String texto;
  final Color color;
  final bool suave; // true = fondo translúcido y texto de color
  const EtiquetaEstado(this.texto, this.color, {super.key, this.suave = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: suave ? color.withValues(alpha: 0.14) : color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: suave ? color : Colors.white,
        ),
      ),
    );
  }
}

/// Insignia gris con un conteo ("3 mesas").
class InsigniaGris extends StatelessWidget {
  final String texto;
  const InsigniaGris(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFF6B645C), borderRadius: BorderRadius.circular(8)),
      child: Text(texto, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// Botón oscuro redondeado con icono (acciones principales).
class BotonOscuro extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final VoidCallback? onPressed;
  final Color color;

  const BotonOscuro(this.texto, {super.key, this.icono, this.onPressed, this.color = kTexto});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: icono == null ? const SizedBox.shrink() : Icon(icono, size: 18),
      label: Text(texto, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
    );
  }
}

/// Estado de error de conexión con botón para reintentar.
class ErrorConexion extends StatelessWidget {
  final String mensajeError;
  final VoidCallback onReintentar;
  final bool oscuro;

  const ErrorConexion({super.key, required this.mensajeError, required this.onReintentar, this.oscuro = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: kRojo.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.wifi_off_rounded, size: 34, color: kRojo),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              mensajeError,
              textAlign: TextAlign.center,
              style: TextStyle(color: oscuro ? Colors.white70 : kTextoSuave),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: onReintentar, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

/// Logotipo "SazónTrack" en letra cursiva.
class LogoSazon extends StatelessWidget {
  final double tamano;
  const LogoSazon({super.key, this.tamano = 30});

  @override
  Widget build(BuildContext context) {
    return Text(
      'SazónTrack',
      style: GoogleFonts.greatVibes(fontSize: tamano, fontWeight: FontWeight.w600, color: kTexto),
    );
  }
}

// ---------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------

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
    builder: (ctx) => TemaSazon(
      child: AlertDialog(
        backgroundColor: kPanel,
        shape: kFormaDialogo,
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(detalle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(aceptar, style: TextStyle(color: peligro ? kRojo : kVerde, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
      decoration: campo(etiqueta).copyWith(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: valor,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: kPanel,
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
    return TemaSazon(
      child: AlertDialog(
        backgroundColor: kPanel,
        shape: kFormaDialogo,
        title: Text(widget.titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: _c,
          autofocus: true,
          decoration: campo(widget.etiqueta),
          onSubmitted: (_) => _aceptar(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: _aceptar, child: const Text('Guardar')),
        ],
      ),
    );
  }
}

/// Convierte "12,5" o "12.5" en double (null si no es número).
double? leerNumero(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));
