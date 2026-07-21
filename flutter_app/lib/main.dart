import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/tracker/providers/food_recognition_provider.dart';
import 'features/tracker/providers/tracker_provider.dart';
import 'features/tracker/screens/tracker_home_screen.dart';

/// App entry point.
///
/// Builds the [NutriMindApp] root widget. Providers live INSIDE that
/// widget (see below) so the root is self-contained — that's what makes
/// `pumpWidget(const NutriMindApp())` a useful thing to do in a smoke
/// test. `runApp` itself does only this one thing.
void main() {
  runApp(const NutriMindApp());
}

/// Top-level [MaterialApp] wrapper.
///
/// Owns the [MultiProvider] for cross-feature state and the Material 3
/// theme, and points [MaterialApp.home] at [AuthGate] — the only piece of
/// UI that actually knows whether to show a splash, the login screen, or
/// the tracker home screen.
///
/// Keeping the providers *inside* this widget (rather than wrapping it
/// from `main()`) is deliberate: it makes `NutriMindApp` self-mountable in
/// widget tests without having to rebuild the provider tree by hand.
class NutriMindApp extends StatelessWidget {
  const NutriMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          // `..tryAutoLogin()` runs once on creation. We don't await it
          // here — AuthGate will render a spinner while it resolves.
          create: (_) => AuthProvider()..tryAutoLogin(),
        ),
        ChangeNotifierProvider<TrackerProvider>(
          create: (_) => TrackerProvider(),
        ),
        ChangeNotifierProvider<FoodRecognitionProvider>(
          create: (_) => FoodRecognitionProvider(),
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (_) => ChatProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'NutriMind',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.green,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

/// Single source of truth for "what screen is the user looking at?".
///
/// `context.watch<AuthProvider>()` rebuilds this widget whenever the
/// provider notifies; we then dispatch on `AuthStatus` with an exhaustive
/// switch. Switching is exhaustive, so a new status added to the enum
/// without a matching case will be a compile-time error — exactly what we
/// want.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.authenticated:
        return const TrackerHomeScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
