import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'presentation/providers/voice_command_provider.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/device_screen.dart';
import 'presentation/screens/routines_screen.dart';
import 'presentation/screens/confirmation_screen.dart';
import 'presentation/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => VoiceCommandProvider()..initAsync(),
      child: const VoiceCommandApp(),
    ),
  );
}

class VoiceCommandApp extends StatelessWidget {
  const VoiceCommandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Home',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AppRouter(),
    );
  }
}

class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VoiceCommandProvider>();

    if (!provider.isInitialized) {
      return const _SplashScreen();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: switch (provider.currentScreen) {
        AppScreen.dashboard    => const DashboardScreen(key: ValueKey('dash')),
        AppScreen.device       => const DeviceScreen(key: ValueKey('device')),
        AppScreen.routines     => const RoutinesScreen(key: ValueKey('routines')),
        AppScreen.confirmation => const ConfirmationScreen(key: ValueKey('confirm')),
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VoiceCommandProvider>();
    return Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 48, height: 48,
              child: CircularProgressIndicator(color: kCyan, strokeWidth: 2),
            ),
            const SizedBox(height: 24),
            Text('VOICE HOME', style: kDisplay(28)),
            const SizedBox(height: 8),
            Text('Iniciando...', style: kLabel(14, color: kTextDim)),
            if (provider.initError != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  provider.initError!,
                  style: kLabel(12, color: kCoral),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
