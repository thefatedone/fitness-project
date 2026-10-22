import 'package:flutter/material.dart';

/// Compact wordmark aligned with the garden's botanical identity.
class NutriMindBrand extends StatelessWidget {
  const NutriMindBrand({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'NutriMind',
      header: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/branding/nutrimind-mark.png',
                width: 32,
                height: 32,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'NutriMind',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
