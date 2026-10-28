import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SignInButton extends StatelessWidget {
  const SignInButton({super.key, required this.icon, required this.text, required this.onPressed});

  final IconData icon;
  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: AppTheme.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 24),
          const SizedBox(width: 10),
          Text(text),
        ]),
      ),
    );
  }
}
