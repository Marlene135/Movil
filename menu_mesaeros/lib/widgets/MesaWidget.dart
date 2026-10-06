import 'package:flutter/material.dart';

// Widget principal que dibuja la mesa cuadrada/redondeada junto con sus sillas
class MesaWidget extends StatefulWidget {
  final String numero;
  final bool isSelected;
  // Estado en la base de datos: disponible | ocupada | por_limpiar | reservada
  final String estado;

  const MesaWidget({
    Key? key,
    required this.numero,
    required this.isSelected,
    this.estado = 'disponible',
  }) : super(key: key);

  @override
  State<MesaWidget> createState() => _MesaWidgetState();
}

class _MesaWidgetState extends State<MesaWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = widget.isSelected;

    // Color de acento según el estado de la mesa
    Color acento;
    switch (widget.estado) {
      case 'ocupada':
        acento = const Color(0xFFE65100);
        break;
      case 'por_limpiar':
        acento = const Color(0xFF6B645C);
        break;
      case 'reservada':
        acento = const Color(0xFF3F6FD8);
        break;
      default:
        acento = const Color(0xFF0F8A50);
    }
    final bool conEstado = widget.estado != 'disponible';

    final Color mainColor = isSelected
        ? const Color(0xFFCBEAD7)
        : (conEstado ? acento.withOpacity(0.12) : Colors.white);
    final Color borderColor = isSelected
        ? const Color(0xFF0F8A50)
        : (conEstado ? acento : Colors.grey.shade300);
    final Color sillaColor = isSelected
        ? const Color(0xFFAFDBC0)
        : (conEstado ? acento.withOpacity(0.35) : Colors.grey.shade300);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Silla superior
          Positioned(
            top: -8,
            child: SillaWidget(color: sillaColor),
          ),
          // Silla inferior
          Positioned(
            bottom: -8,
            child: SillaWidget(color: sillaColor),
          ),
          // Silla izquierda
          Positioned(
            left: -8,
            child: SillaWidget(vertical: true, color: sillaColor),
          ),
          // Silla derecha
          Positioned(
            right: -8,
            child: SillaWidget(vertical: true, color: sillaColor),
          ),

          // Superficie principal de la mesa con animación de hover
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 60,
            height: 60,
            transform: _isHovered
                ? (Matrix4.identity()..translate(0, -4, 0))
                : Matrix4.identity(),
            decoration: BoxDecoration(
              color: mainColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isHovered && !isSelected
                    ? const Color(0xFF0F8A50).withOpacity(0.5)
                    : borderColor,
                width: 2,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: const Color(0xFF0F8A50).withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                if (_isHovered)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: Center(
              child: Text(
                widget.numero,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isSelected ? const Color(0xFF0F8A50) : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget secundario para renderizar los respaldos de las sillas alrededor de la mesa
class SillaWidget extends StatelessWidget {
  final bool vertical;
  final Color color;

  const SillaWidget({
    Key? key,
    this.vertical = false,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: vertical ? 10 : 30,
      height: vertical ? 30 : 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}