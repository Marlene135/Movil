import 'package:flutter/material.dart';
import 'ui.dart';

// Widget principal que dibuja la mesa cuadrada/redondeada junto con sus sillas
class MesaWidget extends StatefulWidget {
  final String numero;
  final bool isSelected;
  // Estado en la base de datos: disponible | ocupada | por_limpiar | reservada
  final String estado;

  const MesaWidget({
    super.key,
    required this.numero,
    required this.isSelected,
    this.estado = 'disponible',
  });

  @override
  State<MesaWidget> createState() => _MesaWidgetState();
}

class _MesaWidgetState extends State<MesaWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = widget.isSelected;

    // Color de acento según el estado de la mesa (mismos colores que la leyenda)
    Color acento;
    switch (widget.estado) {
      case 'ocupada':
        acento = kEstadoOcupada;
        break;
      case 'por_limpiar':
        acento = kEstadoLimpiar;
        break;
      case 'reservada':
        acento = kEstadoReservada;
        break;
      default:
        acento = kEstadoLibre;
    }

    final Color borderColor = isSelected
        ? kTexto
        : (_isHovered ? acento.withValues(alpha: 0.6) : kBorde);
    final Color sillaColor = isSelected ? kTexto.withValues(alpha: 0.35) : acento.withValues(alpha: 0.35);

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
                ? Matrix4.translationValues(0.0, -4.0, 0.0)
                : Matrix4.identity(),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _isHovered || isSelected ? 0.12 : 0.05),
                  blurRadius: _isHovered || isSelected ? 12 : 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Franja superior con el color del estado (como en el mapa de mesas)
                Container(height: 6, color: acento),
                Expanded(
                  child: Center(
                    child: Text(
                      widget.numero,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: kTexto,
                      ),
                    ),
                  ),
                ),
              ],
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
    super.key,
    this.vertical = false,
    required this.color,
  });

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
