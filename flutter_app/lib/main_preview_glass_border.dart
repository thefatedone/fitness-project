import 'package:flutter/material.dart';

import 'l10n/gen/app_localizations.dart';
import 'utils/accessibility_utils.dart';
import 'widgets/glass/glass_bottom_sheet.dart';
import 'widgets/glass/glass_card.dart';
import 'widgets/glass/glass_chip.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ReduceTransparencyNotifier.instance.ensureAttached();
  runApp(const _PreviewApp());
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return ReduceTransparencyScope(
      notifier: ReduceTransparencyNotifier.instance,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const _PreviewHost(),
      ),
    );
  }
}

class _PreviewHost extends StatelessWidget {
  const _PreviewHost();
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF050505),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              SizedBox(height: 80),
              _CardPreview(label: 'Hero (top-tier border)'),
              SizedBox(height: 16),
              _CardPreview(label: 'Surface (most common)'),
              SizedBox(height: 16),
              _CardPreview(label: 'Inline (chips / small)'),
            ],
          ),
        ),
      );
}

class _CardPreview extends StatelessWidget {
  const _CardPreview({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: const SizedBox(
              height: 100,
              child: Center(child: Text('Border should be barely visible')),
            ),
          ),
        ],
      );
}
