import 'package:flutter/material.dart';
import '../theme/colors.dart';

class PaperBackground extends StatelessWidget {
  final Widget child;
  const PaperBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.paperBackground,
      ),
      child: child,
    );
  }
}