import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/features/municipality/domain/city_landmark.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';

/// Carrusel editorial de fotografías verificadas (CC) de los sitios icónicos de
/// la ciudad piloto (`M14`), con scrim de contraste AA, créditos visibles y chips
/// interactivos para saltar directamente a cada lugar.
class CityLandmarkCarousel extends ConsumerStatefulWidget {
  const CityLandmarkCarousel({
    super.key,
    required this.landmarks,
  });

  final List<CityLandmark> landmarks;

  @override
  ConsumerState<CityLandmarkCarousel> createState() =>
      _CityLandmarkCarouselState();
}

class _CityLandmarkCarouselState extends ConsumerState<CityLandmarkCarousel> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpToSlide(int index) {
    final total = widget.landmarks.length;
    if (total == 0) return;
    ref
        .read(municipalityGalleryIndexProvider.notifier)
        .selectIndex(index, total: total);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final landmarks = widget.landmarks;
    if (landmarks.isEmpty) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;
    final rawIndex = ref.watch(municipalityGalleryIndexProvider);
    final activeIndex = rawIndex < landmarks.length ? rawIndex : 0;
    final activeLandmark = landmarks[activeIndex];
    final hasPrev = activeIndex > 0;
    final hasNext = activeIndex < landmarks.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: landmarks.length,
                  onPageChanged: (index) => ref
                      .read(municipalityGalleryIndexProvider.notifier)
                      .selectIndex(index, total: landmarks.length),
                  itemBuilder: (context, index) {
                    final item = landmarks[index];
                    return Image.asset(
                      item.assetPath,
                      fit: BoxFit.cover,
                      semanticLabel: item.titleKey.tr(),
                      errorBuilder: (context, error, stackTrace) =>
                          const _LandmarkImageFallback(),
                    );
                  },
                ),

                // Scrim inferior oscuro para garantizar contraste >= 4.5:1 (WCAG AA)
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const <double>[0.0, 0.48, 1.0],
                        colors: <Color>[
                          AppColors.textPrimary.withValues(alpha: 0.12),
                          Colors.transparent,
                          AppColors.textPrimary.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                  ),
                ),

                // Indicador de posición (ej. 1 / 4) en esquina superior derecha
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Text(
                      '${activeIndex + 1} / ${landmarks.length}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.surface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                // Controles táctiles accesibles anterior / siguiente (>= 48 dp)
                if (hasPrev)
                  Positioned(
                    left: AppSpacing.xs,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        tooltip: 'municipality.gallery_prev'.tr(),
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _jumpToSlide(activeIndex - 1),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.textPrimary.withValues(
                            alpha: 0.56,
                          ),
                          foregroundColor: AppColors.surface,
                          minimumSize: const Size(48, 48),
                        ),
                      ),
                    ),
                  ),
                if (hasNext)
                  Positioned(
                    right: AppSpacing.xs,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        tooltip: 'municipality.gallery_next'.tr(),
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => _jumpToSlide(activeIndex + 1),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.textPrimary.withValues(
                            alpha: 0.56,
                          ),
                          foregroundColor: AppColors.surface,
                          minimumSize: const Size(48, 48),
                        ),
                      ),
                    ),
                  ),

                // Título del sitio y puntos de página sobre el scrim inferior
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          activeLandmark.titleKey.tr(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            color: AppColors.surface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activeLandmark.subtitleKey.tr(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.surface.withValues(alpha: 0.90),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            for (var i = 0; i < landmarks.length; i++) ...[
                              if (i > 0) const SizedBox(width: 6),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 6,
                                width: i == activeIndex ? 20 : 6,
                                decoration: BoxDecoration(
                                  color: i == activeIndex
                                      ? AppColors.surface
                                      : AppColors.surface.withValues(
                                          alpha: 0.45,
                                        ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'municipality.photo_credit'.tr(
            namedArgs: {'credit': activeLandmark.attributionLabel},
          ),
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (var i = 0; i < landmarks.length; i++)
              ChoiceChip(
                label: Text(landmarks[i].chipKey.tr()),
                selected: i == activeIndex,
                selectedColor: AppColors.primarySoft,
                backgroundColor: AppColors.surface,
                side: BorderSide(
                  color: i == activeIndex
                      ? AppColors.primary
                      : AppColors.border,
                ),
                labelStyle: textTheme.bodySmall?.copyWith(
                  color: i == activeIndex
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => _jumpToSlide(i),
              ),
          ],
        ),
      ],
    );
  }
}

class _LandmarkImageFallback extends StatelessWidget {
  const _LandmarkImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.primarySoft, AppColors.border],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.photo_camera_outlined,
          size: 36,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
