import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/core/widgets/vj_badge.dart';
import 'package:via_justa/core/widgets/vj_button.dart';
import 'package:via_justa/core/widgets/vj_card.dart';
import 'package:via_justa/core/widgets/vj_confirm_dialog.dart';
import 'package:via_justa/core/widgets/vj_modal_sheet.dart';
import 'package:via_justa/core/widgets/vj_skeleton_box.dart';
import 'package:via_justa/features/businesses/domain/business_draft.dart';
import 'package:via_justa/features/businesses/domain/business_price_notice.dart';
import 'package:via_justa/features/businesses/presentation/state/register_business_provider.dart';
import 'package:via_justa/features/businesses/presentation/widgets/business_withdraw_dialog.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';
import 'package:via_justa/features/prices/presentation/widgets/map_point_picker_sheet.dart';

class RegisterBusinessPage extends ConsumerStatefulWidget {
  const RegisterBusinessPage({super.key, this.businessId});
  final String? businessId;
  @override
  ConsumerState<RegisterBusinessPage> createState() =>
      _RegisterBusinessPageState();
}

class _RegisterBusinessPageState extends ConsumerState<RegisterBusinessPage> {
  final _allowExit = ValueNotifier(false);
  final _scrollController = ScrollController();
  bool _askingToExit = false;
  bool _didRequestEditLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = widget.businessId;
    if (id != null && id.isNotEmpty && !_didRequestEditLoad) {
      _didRequestEditLoad = true;
      final languageCode =
          EasyLocalization.of(context)?.locale.languageCode ?? 'es';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(registerBusinessProvider.notifier)
              .loadEdit(id, languageCode);
        }
      });
    }
  }

  @override
  void dispose() {
    _allowExit.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _confirmWithdraw() async {
    final state = ref.read(registerBusinessProvider);
    if (state.busy || !state.isEditing) return;
    final confirmed = await showWithdrawBusinessDialog(context);
    if (mounted && confirmed == true) {
      await ref.read(registerBusinessProvider.notifier).withdraw();
    }
  }

  Future<void> _exit() async {
    final state = ref.read(registerBusinessProvider);
    if (state.busy || _askingToExit) return;
    if (state.publishedId == null && !state.withdrawn && state.available) {
      _askingToExit = true;
      final confirmed = await showVjConfirmDialog(
        context: context,
        icon: Icons.exit_to_app_rounded,
        tone: VjModalTone.neutral,
        title: 'businessRegistration.leaveTitle'.tr(),
        body: 'businessRegistration.leaveBody'.tr(),
        cancelLabel: 'businessRegistration.stay'.tr(),
        confirmLabel: 'businessRegistration.leave'.tr(),
      );
      _askingToExit = false;
      if (!mounted || confirmed != true) return;
      if (state.locked) {
        await ref.read(registerBusinessProvider.notifier).discard();
        if (!mounted || ref.read(registerBusinessProvider).locked) return;
      }
    }
    _allowExit.value = true;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.businesses);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(registerBusinessProvider.select((value) => value.step), (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    });
    final state = ref.watch(registerBusinessProvider);
    final notifier = ref.read(registerBusinessProvider.notifier);
    final theme = Theme.of(context).textTheme;
    return ValueListenableBuilder<bool>(
      valueListenable: _allowExit,
      builder: (context, allowExit, child) => PopScope(
        canPop: allowExit,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _exit();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              (state.isEditing
                      ? 'businessRegistration.editTitle'
                      : 'businessRegistration.title')
                  .tr(),
            ),
            leading: IconButton(
              onPressed: state.busy ? null : _exit,
              tooltip: 'businessRegistration.back'.tr(),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!state.available) ...[
                    VjCard(
                      borderRadius: AppRadius.xl,
                      elevated: true,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'businessRegistration.unavailable'.tr(),
                            style: theme.bodyLarge,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          VjButton(
                            label: 'businessRegistration.back'.tr(),
                            onPressed: _exit,
                          ),
                        ],
                      ),
                    ),
                  ] else if (state.withdrawn) ...[
                    VjCard(
                      borderRadius: AppRadius.xl,
                      elevated: true,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                size: 30,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'businessRegistration.withdrawnTitle'.tr(),
                            style: theme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'businessRegistration.withdrawnBody'.tr(),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          VjButton(
                            label: 'businessRegistration.done'.tr(),
                            onPressed: _exit,
                          ),
                        ],
                      ),
                    ),
                  ] else if (state.publishedId != null) ...[
                    VjCard(
                      borderRadius: AppRadius.xl,
                      elevated: true,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                color: AppColors.primarySoft,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                size: 30,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'businessRegistration.publishedTitle'.tr(),
                            style: theme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'businessRegistration.publishedBody'.tr(),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          VjButton(
                            label: 'businessRegistration.done'.tr(),
                            onPressed: _exit,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        VjBadge(
                          label: '${state.step + 1} / 4',
                          variant: VjBadgeVariant.navy,
                        ),
                        if (state.municipalityName.isNotEmpty)
                          VjBadge(
                            label: state.municipalityName,
                            icon: Icons.location_on_outlined,
                            variant: VjBadgeVariant.tonal,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'businessRegistration.step${state.step}'.tr(),
                      style: theme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: List.generate(4, (index) {
                        final isDone = index <= state.step;
                        return Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            height: 6,
                            margin: EdgeInsets.only(
                              right: index < 3 ? AppSpacing.xs : 0,
                            ),
                            decoration: BoxDecoration(
                              color: isDone
                                  ? AppColors.primary
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: VjCard(
                        key: ValueKey<int>(state.step),
                        borderRadius: AppRadius.xl,
                        elevated: true,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: AbsorbPointer(
                          absorbing: state.busy || state.locked,
                          child: _StepContent(state: state),
                        ),
                      ),
                    ),
                    if (state.error != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Semantics(
                        liveRegion: true,
                        child: VjCard(
                          borderRadius: AppRadius.md,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .error
                              .withValues(alpha: 0.08),
                          borderColor: Theme.of(context)
                              .colorScheme
                              .error
                              .withValues(alpha: 0.4),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(
                            'businessRegistration.errors.${state.error}'.tr(),
                            style: theme.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (state.locked) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text('businessRegistration.retryHint'.tr()),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    if (state.busy) ...[
                      const VjSkeletonBox(height: 8, borderRadius: AppRadius.pill),
                      const SizedBox(height: AppSpacing.sm),
                      Text('businessRegistration.working'.tr()),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    VjButton(
                      label: state.step == 3
                          ? (state.locked
                                    ? 'businessRegistration.retry'
                                    : state.isEditing
                                    ? 'businessRegistration.saveChanges'
                                    : 'businessRegistration.publish')
                                .tr()
                          : 'businessRegistration.next'.tr(),
                      onPressed: state.busy
                          ? null
                          : state.step == 3
                          ? notifier.submit
                          : notifier.next,
                    ),
                    if (state.step > 0 && !state.locked) ...[
                      const SizedBox(height: AppSpacing.sm),
                      VjButton(
                        label: 'businessRegistration.previous'.tr(),
                        variant: VjButtonVariant.outlined,
                        onPressed: state.busy ? null : notifier.back,
                      ),
                    ],
                    if (state.locked) ...[
                      const SizedBox(height: AppSpacing.sm),
                      VjButton(
                        label: 'businessRegistration.cancelAttempt'.tr(),
                        variant: VjButtonVariant.outlined,
                        onPressed: state.busy ? null : notifier.discard,
                      ),
                    ],
                    if (state.isEditing) ...[
                      const SizedBox(height: AppSpacing.sm),
                      VjButton(
                        label: 'businessRegistration.withdraw'.tr(),
                        variant: VjButtonVariant.outlined,
                        onPressed: state.busy ? null : _confirmWithdraw,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepContent extends ConsumerWidget {
  const _StepContent({required this.state});
  final RegisterBusinessState state;

  Widget _field(
    WidgetRef ref,
    BusinessField field, {
    int lines = 1,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: TextFormField(
      key: ValueKey('${field.name}-${state.editingId}-${state.busy}'),
      initialValue: state.draft.text(field),
      maxLines: lines,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: 'businessRegistration.fields.${field.name}'.tr(),
      ),
      onChanged: (value) =>
          ref.read(registerBusinessProvider.notifier).setField(field, value),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(registerBusinessProvider.notifier);
    final languageCode =
        EasyLocalization.of(context)?.locale.languageCode ?? 'es';
    final draft = state.draft;
    switch (state.step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<BusinessType>(
              key: ValueKey('type-${state.editingId}-${draft.type.name}'),
              initialValue: draft.type,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'businessRegistration.type'.tr(),
              ),
              items: [
                for (final type in BusinessType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text('businessRegistration.types.${type.name}'.tr()),
                  ),
              ],
              onChanged: state.isEditing
                  ? null
                  : (type) {
                      if (type != null) notifier.setType(type);
                    },
            ),
            const SizedBox(height: AppSpacing.lg),
            _field(ref, BusinessField.name),
            _field(ref, BusinessField.descriptionEs, lines: 4),
            _field(ref, BusinessField.descriptionEn, lines: 4),
            Text('businessRegistration.englishHint'.tr()),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            state.zones.when(
              loading: () =>
                  const VjSkeletonBox(height: 52, borderRadius: AppRadius.md),
              error: (_, _) => VjButton(
                label: 'businessRegistration.reloadZones'.tr(),
                onPressed: notifier.reloadZones,
              ),
              data: (zones) => VjButton(
                label: 'businessRegistration.pickLocation'.tr(),
                leadingIcon: Icons.place_outlined,
                onPressed: zones.isEmpty
                    ? null
                    : () async {
                        final point = await showMapPointPickerSheet(
                          context: context,
                          title: 'businessRegistration.pickLocation'.tr(),
                          subtitle: 'businessRegistration.locationHint'.tr(),
                          zones: zones,
                          initialZoneId: state.initialZoneId,
                          initialLatitude: draft.latitude,
                          initialLongitude: draft.longitude,
                          languageCode: context.locale.languageCode,
                        );
                        if (point != null && context.mounted) {
                          notifier.selectPoint(
                            point,
                            context.locale.languageCode,
                          );
                        }
                      },
              ),
            ),
            if (draft.latitude != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.place_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.zoneName,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: AppColors.brandNavy),
                          ),
                          Text(
                            '${draft.latitude}, ${draft.longitude}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _field(ref, BusinessField.address),
            _field(ref, BusinessField.phone, keyboard: TextInputType.phone),
            _field(ref, BusinessField.whatsapp, keyboard: TextInputType.phone),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: draft.whatsappConsent,
              title: Text('businessRegistration.whatsappConsent'.tr()),
              onChanged: (value) => notifier.setWhatsappConsent(value ?? false),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(ref, BusinessField.orderUrl, keyboard: TextInputType.url),
            Text('businessRegistration.linkHint'.tr()),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'businessRegistration.hours'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final day in BusinessDraft.days)
              _DayEditor(
                day: day,
                hours: draft.hours[day] ?? const BusinessDayHours(),
              ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'businessRegistration.photos'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('businessRegistration.photosHint'.tr()),
            for (var index = 0; index < draft.photos.length; index++)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Image.memory(
                        draft.photos[index].bytes,
                        height: 140,
                        fit: BoxFit.cover,
                        semanticLabel: 'businessRegistration.photo'.tr(),
                      ),
                    ),
                    IconButton(
                      onPressed: () => notifier.removePhoto(index),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'businessRegistration.removePhoto'.tr(),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            VjButton(
              label: 'businessRegistration.addPhoto'.tr(),
              variant: VjButtonVariant.outlined,
              onPressed: state.canAddPhoto ? notifier.addPhoto : null,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'businessRegistration.dishes'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (var index = 0; index < draft.dishes.length; index++)
              _DishEditor(
                key: ValueKey(
                  'dish-${draft.dishes[index].id}-${state.editingId}-${state.busy}',
                ),
                index: index,
                dish: draft.dishes[index],
              ),
            const SizedBox(height: AppSpacing.md),
            VjButton(
              label: 'businessRegistration.addDish'.tr(),
              variant: VjButtonVariant.outlined,
              onPressed: state.canAddDish ? notifier.addDish : null,
            ),
          ],
        );
      default:
        final textTheme = Theme.of(context).textTheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: VjBadge(
                label: 'businessRegistration.types.${draft.type.name}'.tr(),
                variant: VjBadgeVariant.tonal,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < BusinessField.values.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'businessRegistration.fields.${BusinessField.values[i].name}'
                          .tr(),
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      draft.text(BusinessField.values[i]).isEmpty
                          ? 'businessRegistration.notProvided'.tr()
                          : draft.text(BusinessField.values[i]),
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < BusinessField.values.length - 1)
                const Divider(height: AppSpacing.sm),
            ],
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.zoneName,
                        style: textTheme.titleSmall,
                      ),
                      Text(
                        '${draft.latitude}, ${draft.longitude}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            for (final day in BusinessDraft.days)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  'businessRegistration.daySummary'.tr(
                    args: [
                      'businessRegistration.days.$day'.tr(),
                      draft.hours[day]?.enabled == true
                          ? '${draft.hours[day]!.open} – ${draft.hours[day]!.close}'
                          : 'businessRegistration.closed'.tr(),
                    ],
                  ),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            const Divider(height: AppSpacing.lg),
            Text(
              'businessRegistration.photoCount'.tr(
                args: [draft.photos.length.toString()],
              ),
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (draft.dishes.isNotEmpty) const SizedBox(height: AppSpacing.sm),
            for (final dish in draft.dishes) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  'businessRegistration.dishSummary'.tr(
                    args: [dish.name, dish.price],
                  ),
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (state.dishPriceNoticeFor(dish) case final noticeAsync?) ...[
                const SizedBox(height: AppSpacing.sm),
                _DishComparisonFeedback(
                  noticeAsync: noticeAsync,
                  languageCode: languageCode,
                  showCheckingLabel: true,
                  onRetry: () => notifier.retryDishComparison(dish.id),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
            const SizedBox(height: AppSpacing.md),
            Material(
              color: AppColors.surfaceSubtle,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                side: const BorderSide(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: draft.publicationConsent,
                  title: Text(
                    'businessRegistration.publicationConsent'.tr(),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  onChanged: (value) =>
                      notifier.setPublicationConsent(value ?? false),
                ),
              ),
            ),
          ],
        );
    }
  }
}

class _DayEditor extends ConsumerWidget {
  const _DayEditor({required this.day, required this.hours});
  final String day;
  final BusinessDayHours hours;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(registerBusinessProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Material(
        color: AppColors.surfaceSubtle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: hours.enabled ? AppColors.primaryBorder : AppColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'businessRegistration.days.$day'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                value: hours.enabled,
                onChanged: (value) => notifier.setHours(
                  day,
                  BusinessDayHours(
                    enabled: value,
                    open: hours.open,
                    close: hours.close,
                  ),
                ),
              ),
              if (hours.enabled)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      SizedBox(
                        width: 120,
                        child: TextFormField(
                          key: ValueKey('open-$day-${hours.open}'),
                          initialValue: hours.open,
                          decoration: InputDecoration(
                            labelText: 'businessRegistration.open'.tr(),
                            hintText: '08:00',
                          ),
                          keyboardType: TextInputType.datetime,
                          onChanged: (value) => notifier.setHours(
                            day,
                            BusinessDayHours(
                              enabled: true,
                              open: value,
                              close: hours.close,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: TextFormField(
                          key: ValueKey('close-$day-${hours.close}'),
                          initialValue: hours.close,
                          decoration: InputDecoration(
                            labelText: 'businessRegistration.close'.tr(),
                            hintText: '18:00',
                          ),
                          keyboardType: TextInputType.datetime,
                          onChanged: (value) => notifier.setHours(
                            day,
                            BusinessDayHours(
                              enabled: true,
                              open: hours.open,
                              close: value,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DishEditor extends ConsumerWidget {
  const _DishEditor({super.key, required this.index, required this.dish});
  final int index;
  final BusinessDishDraft dish;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(registerBusinessProvider);
    final notifier = ref.read(registerBusinessProvider.notifier);
    final languageCode =
        EasyLocalization.of(context)?.locale.languageCode ?? 'es';
    final categories = state.comparableCategories;
    final selectedCategoryId = state.dishCategoryId(index);
    final noticeAsync = state.dishPriceNoticeFor(dish);

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            initialValue: dish.name,
            decoration: InputDecoration(
              labelText: 'businessRegistration.dishName'.tr(),
            ),
            onChanged: (value) => notifier.setDish(index, name: value),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            initialValue: dish.price,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'businessRegistration.dishPrice'.tr(),
            ),
            onChanged: (value) => notifier.setDish(index, price: value),
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              key: ValueKey('dish-cat-${dish.id}-$selectedCategoryId'),
              initialValue: selectedCategoryId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'businessRegistration.dishComparableCategory'.tr(),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'businessRegistration.dishNoCategory'.tr(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (final category in categories)
                  DropdownMenuItem<String?>(
                    value: category.id,
                    child: Text(
                      '${category.localizedName(languageCode)} · ${category.localizedUnit(languageCode)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => notifier.setDish(
                index,
                priceCategoryId: value,
                clearCategory: value == null,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            VjButton(
              label: 'businessRegistration.compareZonePrice'.tr(),
              variant: VjButtonVariant.outlined,
              onPressed: state.canCompareDish(index)
                  ? () => notifier.compareDishPriceById(dish.id)
                  : null,
            ),
          ],
          if (noticeAsync != null) ...[
            const SizedBox(height: AppSpacing.md),
            _DishComparisonFeedback(
              noticeAsync: noticeAsync,
              languageCode: languageCode,
              showCheckingLabel: false,
              onRetry: () => notifier.retryDishComparison(dish.id),
            ),
          ],
          TextButton.icon(
            onPressed: () => notifier.removeDish(index),
            icon: const Icon(Icons.delete_outline),
            label: Text('businessRegistration.removeDish'.tr()),
          ),
        ],
      ),
    );
  }
}

class _DishPriceNoticeCard extends StatelessWidget {
  const _DishPriceNoticeCard({
    required this.notice,
    required this.languageCode,
  });

  final BusinessPriceNotice notice;
  final String languageCode;

  Color _accentColor() {
    switch (notice.level) {
      case PriceVerdictLevel.green:
        return AppColors.semaphoreGreen;
      case PriceVerdictLevel.yellow:
        return AppColors.semaphoreAmber;
      case PriceVerdictLevel.red:
        return AppColors.semaphoreRed;
      case PriceVerdictLevel.insufficient:
        return AppColors.textSecondary;
    }
  }

  IconData _icon() {
    switch (notice.level) {
      case PriceVerdictLevel.green:
        return Icons.check_circle_outline;
      case PriceVerdictLevel.yellow:
        return Icons.info_outline;
      case PriceVerdictLevel.red:
        return Icons.warning_amber_rounded;
      case PriceVerdictLevel.insufficient:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = _accentColor();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon(), color: accent, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'businessRegistration.priceNoticeTitle'.tr(),
                  style: textTheme.labelLarge?.copyWith(color: accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${notice.localizedCategoryName(languageCode)} · ${notice.localizedUnitDescription(languageCode)}',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (notice.isInsufficient)
            Text(
              'businessRegistration.priceNoticeInsufficient'.tr(
                args: [notice.sampleCount.toString()],
              ),
              style: textTheme.bodyMedium,
            )
          else ...[
            Text(
              'businessRegistration.priceNoticeLevels.${notice.level.name}'.tr(),
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'businessRegistration.priceNoticeMedian'.tr(
                args: [notice.formattedMedianCop],
              ),
            ),
            Text(
              'businessRegistration.priceNoticeDifference'.tr(
                args: [
                  notice.formattedDifferenceCop,
                  notice.formattedDeviationPct,
                ],
              ),
            ),
            Text(
              'businessRegistration.priceNoticeSamples'.tr(
                args: [notice.sampleCount.toString()],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'businessRegistration.priceNoticePrivateHint'.tr(),
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DishComparisonFeedback extends StatelessWidget {
  const _DishComparisonFeedback({
    required this.noticeAsync,
    required this.languageCode,
    required this.showCheckingLabel,
    required this.onRetry,
  });

  final AsyncValue<BusinessPriceNotice> noticeAsync;
  final String languageCode;
  final bool showCheckingLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return noticeAsync.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const VjSkeletonBox(height: 10, borderRadius: AppRadius.pill),
          if (showCheckingLabel) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'businessRegistration.priceNoticeChecking'.tr(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      error: (_, _) => _DishPriceErrorCard(onRetry: onRetry),
      data: (notice) => _DishPriceNoticeCard(
        notice: notice,
        languageCode: languageCode,
      ),
    );
  }
}

class _DishPriceErrorCard extends StatelessWidget {
  const _DishPriceErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.textSecondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'businessRegistration.priceNoticeErrorTitle'.tr(),
                  style: textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'businessRegistration.priceNoticeError'.tr(),
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          VjButton(
            label: 'common.retry'.tr(),
            variant: VjButtonVariant.outlined,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
