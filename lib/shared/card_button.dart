import 'package:flutter/material.dart';

/// Small outlined button used on cards (mockups 6 and 7).
class CardButton extends StatelessWidget {
  const CardButton({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
