import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.textMuted, size: 32),
              const SizedBox(height: 12),
              Text('$title', style: AppTextStyles.headlineSm),
              const SizedBox(height: 6),
              Text('Yakında', style: AppTextStyles.bodyMd),
            ],
          ),
        ),
      ),
    );
  }
}
