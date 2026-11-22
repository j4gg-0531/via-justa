import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/features/auth/domain/consent_document.dart';
import 'package:via_justa/features/auth/presentation/widgets/legal_document_dialog.dart';

/// Texto legal con enlaces interactivos a Términos de Servicio y Política de Privacidad.
class LegalText extends StatefulWidget {
  const LegalText({super.key, required this.prefix});

  final String prefix;

  @override
  State<LegalText> createState() => _LegalTextState();
}

class _LegalTextState extends State<LegalText> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () =>
          showLegalDocumentDialog(context, ConsentDocType.termsAndConditions);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () =>
          showLegalDocumentDialog(context, ConsentDocType.privacyPolicy);
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

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
          TextSpan(text: widget.prefix),
          TextSpan(
            text: 'login.legal_terms'.tr(),
            style: link,
            recognizer: _termsRecognizer,
          ),
          TextSpan(text: 'login.legal_and'.tr()),
          TextSpan(
            text: 'login.legal_privacy'.tr(),
            style: link,
            recognizer: _privacyRecognizer,
          ),
          TextSpan(text: 'login.legal_suffix'.tr()),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
