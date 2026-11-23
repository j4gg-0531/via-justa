import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_spacing.dart';
import 'package:via_justa/features/municipality/domain/city_landmark.dart';

/// Encabezado fotográfico editorial con atribución Creative Commons para la
/// guía completa de Ciudad y Cultura (`VJ-15`).
class CityEditorialPhotoHero extends StatelessWidget {
  const CityEditorialPhotoHero({
    super.key,
    required this.landmark,
    required this.captionLabel,
  });

  final CityLandmark landmark;
  final String captionLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  landmark.assetPath,
                  fit: BoxFit.cover,
                  semanticLabel: landmark.titleKey.tr(),
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.primarySoft,
                    child: const Center(
                      child: Icon(
                        Icons.location_city_outlined,
                        size: 36,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const <double>[0.45, 1.0],
                        colors: <Color>[
                          Colors.transparent,
                          AppColors.textPrimary.withValues(alpha: 0.78),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.sm,
                  child: Text(
                    captionLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.surface,
                      fontWeight: FontWeight.w600,
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
            namedArgs: {'credit': landmark.attributionLabel},
          ),
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
