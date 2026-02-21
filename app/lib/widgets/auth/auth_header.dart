import 'package:flutter/material.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_size.dart';

/// A welcome header widget used in auth screens (login, signup, and forgot password in the future).
class AuthHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const AuthHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: AppTextStyles.headlineMedium(
            context,
            fontWeight: AppTextSize.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          AppSpacing.gapXS,
          Text(
            subtitle!,
            style: AppTextStyles.titleMedium(
              context,
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
