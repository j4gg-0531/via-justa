import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:via_justa/core/widgets/vj_confirm_dialog.dart';
import 'package:via_justa/core/widgets/vj_modal_sheet.dart';

/// Muestra el diálogo unificado para confirmar el retiro de un comercio publicado.
Future<bool?> showWithdrawBusinessDialog(BuildContext context) {
  return showVjConfirmDialog(
    context: context,
    icon: Icons.storefront_outlined,
    tone: VjModalTone.destructive,
    title: 'businessRegistration.withdrawTitle'.tr(),
    body: 'businessRegistration.withdrawBody'.tr(),
    cancelLabel: 'businessRegistration.stay'.tr(),
    confirmLabel: 'businessRegistration.withdrawConfirm'.tr(),
  );
}
