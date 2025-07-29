import 'package:flutter/material.dart';

class AIAssistantButton extends StatelessWidget {
  final VoidCallback onTap;

  const AIAssistantButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome, // ✨ AI assistant icon
            color: Colors.black87,
            size: 28,
          ),
        ),
      ),
    );
  }
}
