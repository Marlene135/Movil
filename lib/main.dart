import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'servicios/api_service.dart';
import 'vistas/pinlogin.dart';

/// Permite navegar desde fuera de un widget (p. ej. al expirar la sesión).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  // Si el servidor responde 401 con una sesión activa, regresa al login.
  ApiService.onSesionExpirada = () {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.pushNamedAndRemoveUntil('/login', (_) => false);
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Tu sesión expiró. Ingresa tu PIN de nuevo.')),
      );
    }
  };
  runApp(const SazonTrackApp());
}

class SazonTrackApp extends StatelessWidget {
  const SazonTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SazónTrack',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        // Fuente base por defecto para toda la app (textos, botones, labels)
        fontFamily: GoogleFonts.montserrat().fontFamily,

        // Configuración de temas de texto globales
        textTheme: TextTheme(
          // Estilo para títulos elegantes (como el logo SazónTrack)
          displayLarge: GoogleFonts.greatVibes(
            fontSize: 36,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF26201B),
          ),
          // Estilo para subtítulos/headers limpios
          labelSmall: GoogleFonts.montserrat(
            fontSize: 10,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF8C847B),
          ),
        ),
      ),
      routes: {
        '/login': (_) => const PinLoginScreen(),
      },
      home: const PinLoginScreen(),
    );
  }
}
