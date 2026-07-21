import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final name = auth.currentUser?.fullName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NutriMind'),
        actions: [
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            name == null
                ? 'Загрузка...'
                : 'Привет, $name! 👋\n\nЗдесь будет трекер питания.',
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
