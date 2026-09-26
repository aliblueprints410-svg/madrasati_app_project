import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/providers/core_providers.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/confetti_celebration.dart';
import 'features/auth/views/splash_screen.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    print("WidgetsFlutterBinding initialized");

    // Load environment variables
    await dotenv.load(fileName: ".env");
    print("dotenv loaded");

    // Initialize Supabase
    await Supabase.initialize(
      url: dotenv.env[AppConstants.supabaseUrlEnvKey] ?? '',
      anonKey: dotenv.env[AppConstants.supabaseAnonKeyEnvKey] ?? '',
    );
    print("Supabase initialized");

    // Initialize SharedPreferences
    final sharedPreferences = await SharedPreferences.getInstance();
    print("SharedPreferences initialized");

    // Initialize Notification Service (OneSignal)
    await NotificationService().initialize();

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const SchoolApp(),
      ),
    );
  } catch (e, stackTrace) {
    print("Error during initialization: $e");
    print(stackTrace);
  }
}

class SchoolApp extends ConsumerWidget {
  const SchoolApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: ConfettiCelebrationOverlay(
            child: child!,
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}
