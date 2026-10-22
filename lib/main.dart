import 'package:flutter/material.dart';
import 'core/api/api.dart';
import 'core/security/biometric_service.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/biometric_lock_screen.dart';
import 'features/dashboard/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.instance.restore();
  bool faceLockEnabled = false;
  try { faceLockEnabled = await BiometricService.instance.isEnabled(); }
  catch (_) { /* Unsupported or migrated secure storage: ordinary login remains possible. */ }
  runApp(SmartGuardApp(faceLockEnabled: faceLockEnabled));
}

class SmartGuardApp extends StatefulWidget {
  const SmartGuardApp({super.key, required this.faceLockEnabled});
  final bool faceLockEnabled;

  @override
  State<SmartGuardApp> createState() => _SmartGuardAppState();
}

class _SmartGuardAppState extends State<SmartGuardApp> {
  int sessionVersion = 0;
  bool unlocked = false;

  void _onSignedIn() => setState(() { unlocked = true; sessionVersion++; });
  void _onSignedOut() => setState(() { unlocked = false; sessionVersion++; });

  Future<void> _clearAndSignIn() async {
    await Api.instance.logout();
    _onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF10233F);
    const teal = Color(0xFF0A9189);
    final Widget start;
    if (Api.instance.token == null) {
      start = AuthScreen(key: ValueKey('auth_$sessionVersion'), onSignedIn: _onSignedIn);
    } else if (widget.faceLockEnabled && !unlocked) {
      start = BiometricLockScreen(
        key: ValueKey('lock_$sessionVersion'),
        onUnlocked: _onSignedIn,
        onSignOut: _clearAndSignIn,
      );
    } else {
      start = HomeScreen(key: ValueKey('home_$sessionVersion'), onSignedOut: _onSignedOut);
    }

    return MaterialApp(
      title: 'SmartGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: teal, primary: teal, secondary: navy,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F8FC),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF5F8FC)),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          filled: true,
          fillColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      home: start,
    );
  }
}
