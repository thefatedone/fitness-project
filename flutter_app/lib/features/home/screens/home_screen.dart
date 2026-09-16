import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/gen/app_localizations.dart';

import '../../auth/providers/auth_provider.dart';

/// Authenticated landing screen.
///
/// Single responsibility: confirm to the user that they are signed in, give
/// them a logout affordance, and reserve a slot for the upcoming food
/// tracker UI. The actual tracker / dashboard / water / AI screens will be
/// wired in by a later step — this widget is intentionally a stub so the
/// auth flow can be smoke-tested end-to-end first.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    // Pop the route stack back to the root (AuthGate). The provider
    // has already flipped to `unauthenticated`, so AuthGate rebuilds
    // into the LoginScreen on the same frame — without this pop the
    // user would still be looking at HomeScreen until they manually
    // navigated back.
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final name = auth.currentUser?.fullName;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).appName),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context).homeLogout,
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            name == null
                ? AppLocalizations.of(context).homeLoading
                : '${AppLocalizations.of(context).homeGreeting(name)} 👋\n\n'
                    '${AppLocalizations.of(context).homeTrackerPreview}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
