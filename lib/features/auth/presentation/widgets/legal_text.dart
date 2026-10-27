import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';

/// Texto legal con enlaces subrayados a términos y privacidad.
class LegalText extends StatelessWidget {
  const LegalText({super.key, required this.prefix});

  final String prefix;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall!;
    final link = small.copyWith(
      color: AppColors.primary,
      decoration: TextDecoration.underline,
    );

    return Text.rich(
      TextSpan(
        style: small,
        children: [
          TextSpan(text: prefix),
          TextSpan(text: 'login.legal_terms'.tr(), style: link),
          TextSpan(text: 'login.legal_and'.tr()),
          TextSpan(text: 'login.legal_privacy'.tr(), style: link),
          TextSpan(text: 'login.legal_suffix'.tr()),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
