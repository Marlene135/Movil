/* import 'package:flutter/material.dart';
import '../modulos/producto.dart'; // Importa el modelo de Producto de tu proyecto

class ProductoCard extends StatelessWidget {
  final Producto producto;
  final VoidCallback? onAgregar;

  const ProductoCard({
    Key? key,
    required this.producto,
    this.onAgregar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge de Categoría (Pill oscuro)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E), // Negro / Gris muy oscuro
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  producto.categoria ?? 'General',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Nombre del Producto
              Text(
                producto.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1E1E1E),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Fila inferior: Precio y Botón de sumar (+)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Precio en verde brillante
              Text(
                '\$${producto.precio.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF10B981), // Verde característico de la imagen
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Botón (+) circular
              InkWell(
                onTap: onAgregar,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6), // Gris claro de fondo
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 18,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}




*/