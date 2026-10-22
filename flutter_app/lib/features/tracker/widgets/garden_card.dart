import 'package:flutter/material.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../widgets/glass/glass_card.dart';
import '../models/garden_model.dart';
import 'avocado_tree.dart';

String gardenStageLabel(AppLocalizations l10n, int stage) => [
  l10n.gardenSeed,
  l10n.gardenRoot,
  l10n.gardenSprout,
  l10n.gardenLeaves,
  l10n.gardenTree,
][stage.clamp(0, 4)];

class GardenCard extends StatelessWidget {
  const GardenCard({
    super.key,
    required this.garden,
    required this.loading,
    required this.failed,
    required this.onOpen,
    required this.onRetry,
  });
  final GardenModel? garden;
  final bool loading;
  final bool failed;
  final VoidCallback onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final model = garden;
    if (model == null) {
      return GlassCard(
        child: Row(
          children: [
            Icon(Icons.spa_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(failed ? l10n.gardenLoadFailed : l10n.gardenLoading),
            ),
            if (failed || !loading)
              IconButton(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                tooltip: l10n.gardenRetry,
              ),
          ],
        ),
      );
    }
    final dark = theme.brightness == Brightness.dark;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    final surface = dark ? const Color(0xFF111A15) : const Color(0xFFF6F4ED);
    final foreground = dark ? const Color(0xFFF3F5EC) : const Color(0xFF223B2B);
    final muted = dark ? const Color(0xFFB8C6B9) : const Color(0xFF536753);
    return Semantics(
      button: true,
      label: l10n.gardenOpen,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .12 : .05),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: surface,
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: largeText ? 340 : 284,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GardenScene(
                        stage: model.stage,
                        decorated: model.potUnlocked,
                        topInset: largeText ? 116 : 66,
                      ),
                      Positioned(
                        top: 19,
                        left: 20,
                        right: 18,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.gardenTitle,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: foreground,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    gardenStageLabel(l10n, model.stage),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: surface.withValues(alpha: .72),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: foreground,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        model.stage == 4
                            ? l10n.gardenMatureHint
                            : l10n.gardenNextDays(model.daysToNextStage),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: foreground,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: model.growthDays / 21,
                          minHeight: 4,
                          color: const Color(0xFF6A9368),
                          backgroundColor: muted.withValues(alpha: .12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            model.loggedToday
                                ? Icons.check_circle_outline
                                : Icons.add_circle_outline,
                            size: 15,
                            color: dark
                                ? const Color(0xFFA8CBA2)
                                : const Color(0xFF3E6D43),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              model.loggedToday
                                  ? l10n.gardenTodayDone
                                  : l10n.gardenTodayPrompt,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (failed)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            l10n.gardenStale,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
