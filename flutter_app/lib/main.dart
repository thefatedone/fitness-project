import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/config/api_environment_provider.dart';
import 'core/locale/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'l10n/gen/app_localizations.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/providers/password_reset_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/tracker/providers/beverage_provider.dart';
import 'features/tracker/providers/food_recognition_provider.dart';
import 'features/tracker/providers/tracker_provider.dart';
import 'features/tracker/screens/tracker_home_screen.dart';
import 'utils/accessibility_utils.dart';

/// App entry point.
///
/// Builds the [NutriMindApp] root widget. The [AuthProvider] is created
/// here in `main()` (rather than inside the MultiProvider's `create`
/// lambda) so we can capture a reference to it BEFORE the provider
/// tree is built — we then pass that same instance to
/// [ChangeNotifierProvider.value] and use it to wire the centralized
/// 401 hook on [apiClient]. That wiring has to happen before any HTTP
/// call can fire, so doing it post-build (in a post-frame callback)
/// would leave a tiny race window where a 401 would be silently dropped.
void main() {
  // Initialize the Flutter binding BEFORE any plugin-touching code
  // runs. `flutter_secure_storage` (used by `tokenStorage.readToken()`
  // inside `tryAutoLogin` below) talks to a native MethodChannel,
  // which throws "Binding has not yet been initialized" if the
  // binding isn't up yet. `runApp()` would normally do this as its
  // first step, but we need the binding initialized HERE because
  // we're about to create an AuthProvider (and call its
  // `tryAutoLogin`) before `runApp` is invoked. The call is
  // idempotent — Flutter's runtime skips the second invocation.
  WidgetsFlutterBinding.ensureInitialized();

  // Single instance — used both for the provider tree below AND for
  // the apiClient 401 hook. The hook has to be set before runApp so a
  // 401 from any request triggered during the very first frame
  // (e.g. a stale-token GET /users/me via tryAutoLogin) doesn't fall
  // through the unhandled branch.
  final authProvider = AuthProvider()..tryAutoLogin();
  apiClient.onUnauthorized = authProvider.forceLogout;

  // Kick off the platform-channel round-trip for Reduce Transparency
  // before the first frame so the very first `ReduceTransparencyScope`
  // build can read a settled value rather than the in-flight default.
  ReduceTransparencyNotifier.instance.ensureAttached();

  runApp(
    ReduceTransparencyScope(
      notifier: ReduceTransparencyNotifier.instance,
      child: MultiProvider(
        providers: [
        // ThemeProvider must be available BEFORE the MaterialApp's
        // build runs so it can read the user's current theme
        // preference via `context.watch<ThemeProvider>()`. We also kick
        // off `loadSavedMode()` on creation so the persisted choice
        // is drained from SharedPreferences before the first frame
        // paints — same pattern as AuthProvider's `..tryAutoLogin()`.
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider()..loadSavedMode(),
        ),
        // Locale provider — mirrors [ThemeProvider]'s shape
        // (in-memory default + `loadSavedLocale` called on
        // creation so the persisted choice is drained from
        // SharedPreferences before the first frame paints).
        // Registered BEFORE [ThemeProvider]'s siblings only so
        // the comment ordering reads top-to-bottom.
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider()..loadSavedLocale(),
        ),
        // Debug-only API-environment switcher. Reads any persisted
        // override from SharedPreferences on creation
        // (`loadSaved()`), pushes it into `AppConfig`, and re-points
        // `apiClient.dio.options.baseUrl` so the very first frame's
        // (potential) HTTP request lands on the user-picked host.
        // The Settings screen surfaces this in its debug-only
        // "API-окружение" card; in release builds (`kDebugMode ==
        // false`) the UI section is simply absent — the provider
        // itself stays registered but never has a consumer.
        ChangeNotifierProvider<ApiEnvironmentProvider>(
          create: (_) => ApiEnvironmentProvider()..loadSaved(),
        ),
        // .value() reuses the same instance we created above so the
        // 401 hook and the provider tree point at the same AuthProvider.
        // .create(...) would also work but would create a SECOND
        // instance — the hook would call forceLogout on one, while
        // the UI watched the other. That would break the silent-logout
        // UX (a rebuild from the hook wouldn't trigger AuthGate's
        // exhaustive switch because the *watched* instance's status
        // would never change).
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<TrackerProvider>(
          create: (_) => TrackerProvider(),
        ),
        ChangeNotifierProvider<FoodRecognitionProvider>(
          create: (_) => FoodRecognitionProvider(),
        ),
        // Beverage photo recognition flow — parallels
        // `FoodRecognitionProvider`. Used by the
        // `PhotoBeverageScreen` reachable via the Dock's
        // camera icon → "Сфотографировать напиток" choice.
        ChangeNotifierProvider<BeverageProvider>(
          create: (_) => BeverageProvider(),
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (_) => ChatProvider(),
        ),
        ChangeNotifierProvider<ProfileProvider>(
          create: (_) => ProfileProvider(),
        ),
        // The password-reset flow runs while the user is unauthenticated,
        // so this provider is created up-front (alongside the others)
        // and read directly by the three reset screens via
        // `context.read<PasswordResetProvider>()`. The flow calls
        // `provider.reset()` on success so a subsequent attempt starts
        // from a clean state.
        ChangeNotifierProvider<PasswordResetProvider>(
          create: (_) => PasswordResetProvider(),
        ),
      ],
      child: const _NutriMindAppShell(),
      ),
    ),
  );
}

// Note on the "Сессия истекла" toast:
// `AuthProvider.sessionExpiredNotice` is set to `true` by the
// `apiClient` 401 hook. A future integration in [LoginScreen] should
// read this flag in `initState`, show a SnackBar
// "Сессия истекла, войди снова.", and call
// `authProvider.sessionExpiredNotice = false` (and a matching
// `notifyListeners` via a small helper) to clear it. LoginScreen
// wasn't part of this three-file task scope, so the data is captured
// here but the toast UI is a follow-up.

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
    return ReduceTransparencyScope(
      notifier: ReduceTransparencyNotifier.instance,
      child: MultiProvider(
        providers: [
          // ThemeProvider must be available BEFORE NutriMindApp's own
          // build runs so the MaterialApp below can read the user's
          // current theme preference via `context.watch<ThemeProvider>()`.
          // We also kick off `loadSavedMode()` on creation so the
          // persisted choice is drained from SharedPreferences before
          // the first frame paints — same pattern as AuthProvider's
          // `..tryAutoLogin()`.
          ChangeNotifierProvider<ThemeProvider>(
            create: (_) => ThemeProvider()..loadSavedMode(),
          ),
        // See the matching registration in `main()` for
        // rationale — second copy so widget tests that mount
        // `NutriMindApp` directly see the provider too.
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider()..loadSavedLocale(),
        ),
        // See the matching registration in `main()` for rationale
        // — this second copy exists so that mounting `NutriMindApp`
        // directly (e.g. from a widget test) gives the Settings
        // screen a valid `ApiEnvironmentProvider` to read. The
        // provider is safe to register in release builds because
        // the only UI section that uses it is wrapped in
        // `kDebugMode`.
        ChangeNotifierProvider<ApiEnvironmentProvider>(
          create: (_) => ApiEnvironmentProvider()..loadSaved(),
        ),
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
        // Beverage photo recognition flow — parallels
        // `FoodRecognitionProvider`. Used by the
        // `PhotoBeverageScreen` reachable via the Dock's
        // camera icon → "Сфотографировать напиток" choice.
        ChangeNotifierProvider<BeverageProvider>(
          create: (_) => BeverageProvider(),
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (_) => ChatProvider(),
        ),
        ChangeNotifierProvider<ProfileProvider>(
          create: (_) => ProfileProvider(),
        ),
        // The password-reset flow runs while the user is unauthenticated,
        // so this provider is created up-front (alongside the others)
        // and read directly by the three reset screens via
        // `context.read<PasswordResetProvider>()`. The flow calls
        // `provider.reset()` on success so a subsequent attempt starts
        // from a clean state.
        ChangeNotifierProvider<PasswordResetProvider>(
          create: (_) => PasswordResetProvider(),
        ),
      ],
        child: const _NutriMindAppShell(),
      ),
    );
  }
}

/// The actual [MaterialApp]. Separated from [NutriMindApp] so the
/// latter can stand as a thin shell that just sets up the provider
/// tree, while this widget does the
/// `context.watch<ThemeProvider>().flutterThemeMode` read needed to
/// plumb the user's theme preference into `MaterialApp.themeMode`.
///
/// The split keeps the provider scope obvious: [NutriMindApp] is
/// "what the app shell looks like"; [_NutriMindAppShell] is "what
/// the app renders, given the current theme".
class _NutriMindAppShell extends StatelessWidget {
  const _NutriMindAppShell();

  @override
  Widget build(BuildContext context) {
    // Single source of truth for the user's theme choice. Watching
    // here (not in `NutriMindApp`) is intentional: this widget is a
    // child of the MultiProvider, so the watch resolves cleanly,
    // and we rebuild whenever the user flips the mode.
    final themeMode = context.watch<ThemeProvider>().flutterThemeMode;
    // Mirror the theme watch for locale — a change here rebuilds
    // MaterialApp with a new `locale`, which propagates to every
    // descendant (DatePicker labels, AlertDialog buttons, scroll
    // physics tooltips, the language section label itself, etc.)
    // without any explicit per-screen wiring. The Settings screen
    // is the single user-facing entry point that mutates this.
    final flutterLocale = context.watch<LocaleProvider>().flutterLocale;

    return MaterialApp(
      // `title` is a `String` consumed by the OS task switcher (Android
      // Recent / iOS app switcher) — not displayed inside the app's
      // widget tree. The ARB defines `appName: "NutriMind"` for all three
      // locales (en, ru, ka); the brand is locale-invariant, so the
      // const literal matches the ARB value. Resolving this through
      // `AppLocalizations.of(context)` here would throw because
      // `_NutriMindAppShell.build` runs BEFORE the `MaterialApp` builds
      // (the `Localizations` widget that provides `AppLocalizations` is
      // created BY the `MaterialApp`), so the lookup returns null and
      // the `!` asserts. The two-step Builder pattern below handles all
      // in-app `AppLocalizations.of(context)` lookups safely.
      title: 'NutriMind',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: flutterLocale,
      // `AppLocalizations.localizationsDelegates` bundles the
      // generated ARB-driven `AppLocalizations.delegate` together
      // with `GlobalMaterialLocalizations.delegates` (which itself
      // includes the matching `GlobalCupertinoLocalizations.delegate`
      // for each supported locale — see the comment on the prior
      // `.delegates`-form rationale further down). The generated
      // class is what powers the per-screen `AppLocalizations.of(context)`
      // lookups that replace the previously-hardcoded Russian strings.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // The three locales the app supports today. Adding a new
      // language is a two-line change: extend [AppLocale], add a
      // case to [LocaleProvider.flutterLocale], append the
      // matching `Locale(...)` here. Anything else (the Settings
      // screen's `SegmentedButton`, the native-name labels) picks
      // up the new entry automatically because it iterates over
      // [AppLocale.values].
      //
      // Derived from `AppLocale.values` so the two lists can't
      // drift; the per-locale `AppLocale` enum's name is the
      // canonical language code.
      supportedLocales: const [
        Locale('en'),
        Locale('ka'),
        Locale('ru'),
      ],
      home: const AuthGate(),
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
