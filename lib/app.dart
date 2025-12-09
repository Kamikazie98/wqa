import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart' hide Consumer;
import 'package:package_info_plus/package_info_plus.dart';

import 'constants/brand.dart';
import 'controllers/auth_controller.dart';
import 'services/api_client.dart';
import 'services/url_launcher_service.dart';
import 'services/user_profile_service.dart';
import 'features/auth/otp_page.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/profile_setup_screen.dart';
import 'screens/permissions_screen.dart';

class WaiqApp extends StatelessWidget {
  const WaiqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(
          title: Brand.name,
          debugShowCheckedModeBanner: false,
          locale: const Locale('fa'),
          supportedLocales: const [
            Locale('fa'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          theme: _buildTheme(Brightness.dark),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: ThemeMode.dark,
          builder: (context, child) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF05060A),
                    Color(0xFF0A0F1E),
                    Color(0xFF11172A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(color: Colors.white.withOpacity(0.02)),
                      ),
                    ),
                  ),
                  Positioned.fill(child: child ?? const SizedBox.shrink()),
                ],
              ),
            );
          },
          initialRoute: '/',
          routes: {
            '/': (context) => const _AppEntryPoint(),
            '/permissions': (context) => const PermissionsScreen(),
          },
        ),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    const neon = Color(0xFF64D2FF);
    final baseTheme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: neon,
        brightness: Brightness.dark,
        primary: neon,
        onPrimary: Colors.black,
        secondary: const Color(0xFF7C5BFF),
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF070A13),
      fontFamily: GoogleFonts.vazirmatn().fontFamily,
    );

    return baseTheme.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withOpacity(0.08),
        shadowColor: neon.withOpacity(0.25),
        surfaceTintColor: Colors.white.withOpacity(0.04),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 10,
        margin: const EdgeInsets.all(8),
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: neon, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neon,
          foregroundColor: Colors.black,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shadowColor: neon.withOpacity(0.4),
          elevation: 6,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: neon.withOpacity(0.9),
          foregroundColor: Colors.black,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: neon,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withOpacity(0.05),
        surfaceTintColor: Colors.transparent,
        indicatorColor: neon.withOpacity(0.2),
        iconTheme:
            WidgetStateProperty.all(const IconThemeData(color: Colors.white)),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.black.withOpacity(0.8),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _AppEntryPoint extends StatefulWidget {
  const _AppEntryPoint();

  @override
  State<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<_AppEntryPoint> {
  bool _checkedVersion = false;
  bool _updateRequired = false;
  String? _downloadUrl;
  String? _latestVersion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVersion();
      _checkAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_updateRequired) {
      return _UpdateRequiredView(
        latestVersion: _latestVersion,
        downloadUrl: _downloadUrl,
      );
    }

    // Consumer for AuthController and UserProfileService
    return Consumer2<AuthController, UserProfileService>(
      builder: (context, auth, profileService, _) {
        if (!auth.isSessionChecked) {
          // Show a loading screen while the session is being checked.
          return const _LoadingView();
        }

        if (auth.isAuthenticated) {
          if (profileService.isLoading) {
            // If authenticated and profile is still loading, show loading screen.
            return const _LoadingView();
          } else if (profileService.hasProfile) {
            // If profile is loaded and exists, go to home.
            return const HomeShell();
          } else {
            // If profile is loaded but doesn't exist, go to setup.
            return const ProfileSetupScreen();
          }
        }

        // If not authenticated, go to login page.
        return const OtpPage();
      },
    );
  }

  Future<void> _checkAuth() async {
    final auth = context.read<AuthController>();
    final profileService = context.read<UserProfileService>();
    try {
      await auth.checkSession();
      if (auth.isAuthenticated && mounted) {
        // No need to await, the consumer will react to the state change
        profileService.getProfile();
      }
    } catch (e) {
      print('[_checkAuth] Error: $e');
    }
  }

  Future<void> _checkVersion() async {
    try {
      final api = context.read<ApiClient>();
      final info = await PackageInfo.fromPlatform();
      final response = await api.postJson(
        '/app/check-version',
        body: {'version': info.version},
        authRequired: false,
      );
      final updateRequired = response['update_required'] as bool? ?? false;
      if (!mounted) return;
      if (updateRequired) {
        setState(() {
          _updateRequired = true;
          _latestVersion =
              response['latest_version']?.toString() ?? info.version;
          _downloadUrl = response['download_url']?.toString();
        });
      }
    } catch (_) {
      // اگر چک نسخه خطا داد، اپ را بلاک نکن.
    }
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF05060A),
              Color(0xFF0A0F1E),
              Color(0xFF11172A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'در حال بارگذاری...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdateRequiredView extends StatelessWidget {
  const _UpdateRequiredView({this.downloadUrl, this.latestVersion});

  final String? downloadUrl;
  final String? latestVersion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.system_update, size: 56),
                const SizedBox(height: 12),
                const Text(
                  'به‌روزرسانی لازم است',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  latestVersion == null
                      ? 'برای ادامه لطفاً اپلیکیشن را به آخرین نسخه به‌روز کنید.'
                      : 'نسخه $latestVersion منتشر شده است. برای ادامه لطفاً اپلیکیشن را به‌روز کنید.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (downloadUrl != null && downloadUrl!.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => UrlLauncherService.openUrl(downloadUrl!),
                    icon: const Icon(Icons.download),
                    label: const Text('دانلود به‌روزرسانی'),
                  )
                else
                  const Text('لینک دانلود در دسترس نیست.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
