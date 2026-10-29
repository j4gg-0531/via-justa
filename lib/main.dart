import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/app/app.dart';
import 'package:via_justa/core/supabase/supabase_bootstrap.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Sin SUPABASE_URL/SUPABASE_ANON_KEY el cliente es null y la app funciona en
  // modo DEMO. Con ellos, la sesión se conserva entre reinicios.
  final SupabaseClient? client = await initializeSupabase();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('es'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('es'),
      child: ProviderScope(
        overrides: [
          if (client != null) supabaseClientProvider.overrideWithValue(client),
        ],
        child: const ViaJustaApp(),
      ),
    ),
  );
}
