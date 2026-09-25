// vista del teclado de pin para el login de usuario
import 'package:flutter/material.dart';
import '../widgets/keypadbutton.dart';
import '../servicios/db_service.dart';
import 'mesas.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  String _pin = '';
  final int _maxPinLength = 4;
  bool _obscurePin = true;
  bool _isLoading = false;
  int _selectedTab = 0; // 0: PIN, 1: Acceso, 2: Registro

  void _onNumberPress(String digit) {
    if (_pin.length < _maxPinLength) {
      setState(() {
        _pin += digit;
      });
    }
  }

  void _onDeleteSingle() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _onClearAll() {
    setState(() {
      _pin = '';
    });
  }

  Future<Map<String, dynamic>?> _validarPinEnBaseDeDatos(String pin) async {
    return await DbService.validarPin(pin);
  }

  Future<void> _handleLogin() async {
    if (_pin.length < _maxPinLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa los 4 dígitos del PIN'),
          backgroundColor: Colors.black87,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final usuario = await _validarPinEnBaseDeDatos(_pin);

      if (!mounted) return;

      if (usuario != null) {
        final String nombreMesero = usuario['nombre'] ?? 'Mesero';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Bienvenido, $nombreMesero!'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );

        if (!mounted) return;

        // Redirección a la vista de mesas
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MesasScreen(usuario: usuario),
          ),
        );
   

        // Aquí navegas a la siguiente pantalla (mesas o menú):
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(builder: (_) => MesasScreen(usuario: usuario)),
        // );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN incorrecto o usuario inactivo.'),
            backgroundColor: Color(0xFFC62828),
          ),
        );
        _onClearAll();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión con la base de datos: $e'),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF8F5),
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1EDE6),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE5DFD4), width: 1),
                    ),
                    child: const Icon(
                      Icons.room_service_rounded,
                      size: 32,
                      color: Color(0xFF26201B),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'SazónTrack',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 32,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF26201B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'CONTROL & PUNTO DE VENTA',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8C847B),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTabs(),
                  const SizedBox(height: 16),
                  _buildPinDisplay(),
                  const SizedBox(height: 20),
                  _buildKeypad(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF26201B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Entrar',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFECE7DF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _tabItem(0, 'PIN', null),
          _tabItem(1, 'Acceso', Icons.person_outline_rounded),
          _tabItem(2, 'Registro', Icons.person_add_alt_rounded),
        ],
      ),
    );
  }

  Widget _tabItem(int index, String label, IconData? icon) {
    final bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF26201B) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? Colors.white : const Color(0xFF6B645C),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF6B645C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinDisplay() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFECE7DF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 28),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_maxPinLength, (index) {
              final bool hasValue = index < _pin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasValue ? const Color(0xFF26201B) : const Color(0xFFCCC5B9),
                ),
                child: hasValue && !_obscurePin
                    ? Center(
                        child: Text(
                          _pin[index],
                          style: const TextStyle(fontSize: 8, color: Colors.white),
                        ),
                      )
                    : null,
              );
            }),
          ),
          IconButton(
            icon: Icon(
              _obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 20,
              color: const Color(0xFF6B645C),
            ),
            onPressed: () => setState(() => _obscurePin = !_obscurePin),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3']),
        const SizedBox(height: 10),
        _buildKeypadRow(['4', '5', '6']),
        const SizedBox(height: 10),
        _buildKeypadRow(['7', '8', '9']),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: KeypadButton(
                onTap: _onClearAll,
                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFC62828), size: 22),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KeypadButton(
                onTap: () => _onNumberPress('0'),
                child: const Text(
                  '0',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF26201B)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KeypadButton(
                onTap: _onDeleteSingle,
                child: const Icon(Icons.backspace_outlined, color: Color(0xFF6B645C), size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> numbers) {
    return Row(
      children: numbers.map((digit) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: KeypadButton(
              onTap: () => _onNumberPress(digit),
              child: Text(
                digit,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF26201B),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}