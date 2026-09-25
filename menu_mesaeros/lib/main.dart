import 'package:flutter/material.dart';
import 'vistas/pinlogin.dart';

void main() {
  runApp(const SazonTrackApp());
}

class SazonTrackApp extends StatelessWidget {
  const SazonTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SazónTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF6F4EF),
        fontFamily: 'sans-serif',
      ),
      home: const PinLoginScreen(),
    );
  }
}