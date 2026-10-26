import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';

/// Campo de búsqueda con ícono de lupa y botón para limpiar.
class VjSearchField extends StatefulWidget {
  const VjSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.initialText,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final String? initialText;

  @override
  State<VjSearchField> createState() => _VjSearchFieldState();
}

class _VjSearchFieldState extends State<VjSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      widget.onChanged(widget.initialText!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      color: AppColors.surface,
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textMuted,
          ),
          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  tooltip: 'common.clear'.tr(),
                  onPressed: _clear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
        onChanged: widget.onChanged,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}