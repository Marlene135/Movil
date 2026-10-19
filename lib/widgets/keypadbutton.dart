import 'package:flutter/material.dart';

class KeypadButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const KeypadButton({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1EDE6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5DFD4), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}