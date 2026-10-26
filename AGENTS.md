# AGENTS.md

Flutter app for "Vía Justa" (Android-first). The product is built incrementally from `doc/Via_Justa_Plan_de_trabajo.pdf`; implement only the numbered step being requested. Do not add screens, features, or dependencies beyond that step.

## Commands

```powershell
flutter pub get
flutter analyze
flutter test
flutter test test/municipality_search_test.dart   # single file
flutter run -d <device-id> --no-pub
```

- Jump straight to a screen while iterating: `flutter run -d <device-id> --route=/department/20 --no-pub`. `initialLocation` is `/splash`, which auto-navigates to `/login` after 1.8 s.
- `adb` is not on PATH; use `C:\Android\Sdk\platform-tools\adb.exe`. List devices with `flutter devices` or `flutter emulators --launch Pixel_8`.
- `flutter analyze` and `flutter test` must both pass. There is no CI config in the repo.

## Architecture

- Entrypoint: `lib/main.dart` (`EasyLocalization` > `ProviderScope`) -> `lib/app/app.dart` (`MaterialApp.router`) -> `routerProvider` in `lib/core/router/app_router.dart`.
- `lib/core/` is shared infrastructure: `router/`, `theme/`, `widgets/` (`VjButton`, `VjCard`, `VjBadge`, `VjSearchField`), `utils/`, `demo/`.
- Features live in `lib/features/<feature>/{domain,data,presentation/{pages,state}}/`. Current features: `onboarding`, `splash`, `map_colombia`, `municipality`.
- Routes and `AppRoutes` path helpers are centralized in `app_router.dart`. Add routes there, not inline. Splash uses `context.go` (no back to splash); drill-down uses `context.push`.
- State is Riverpod 3: `ConsumerWidget`/`ConsumerStatefulWidget`, `Provider`, `FutureProvider.family`, `NotifierProvider`. The concrete municipality repository is only referenced by `municipalityRepositoryProvider` so it can be swapped for Supabase later.

## Conventions

- Imports must be `package:via_justa/...`; relative imports are not used.
- All user-visible text goes through `'clave'.tr()`. Every key must exist in both `assets/translations/es.json` and `en.json`; `test/translations_test.dart` fails otherwise. Spanish is the fallback locale.
- Use `AppColors` (`core/theme/app_colors.dart`), `AppSpacing`, and `AppRadius` instead of raw colors/spacing/radii. **`AppRadius` is defined in `core/theme/app_spacing.dart`** — there is no `app_radius.dart`.
- Text styles come from the `Theme` text theme (`headlineMedium`, `bodyLarge`, etc.) rather than ad-hoc `TextStyle`s where possible.
- Assets are registered by directory in `pubspec.yaml` (`assets/translations/`, `assets/images/`, `assets/data/`). A new top-level asset directory needs a pubspec entry.
- Do not change `applicationId`, the theme setup, or platform folders (`android/`, `ios/`, `web/`, etc.) unless the task explicitly says so.
- Do not add dependencies on your own; versions are resolved with `flutter pub add`.

## Implementation caveats

- Municipality data is local sample data in `assets/data/municipalities_cesar.json`; `LocalMunicipalityRepository` only serves department code `20` (Cesar) and returns an empty list for others. DIVIPOLA codes have not been verified against DANE.
- Department shapes on the map are provisional `Path` ovals, not real geography; the map is labeled as a sample.
- `municipality_placeholder_page.dart` is a temporary screen 6 target and is expected to be replaced.
- Layout screens are tested at narrow widths and large system font scales; prefer content-sized/scrollable layouts over fixed header heights.

## Verification

Report only commands actually run. For UI fixes, verify on an Android device/emulator when available (screenshots via `adb shell screencap` + `adb pull`), including overflow/logcat checks (`adb logcat -d | Select-String "overflowed|RenderFlex"`) and a large `font_scale` pass. If no device is available, say so explicitly instead of claiming visual verification.
