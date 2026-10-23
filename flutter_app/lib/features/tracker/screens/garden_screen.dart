import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../models/garden_model.dart';
import '../providers/tracker_provider.dart';
import '../widgets/avocado_tree.dart';
import '../widgets/garden_card.dart';

class GardenScreen extends StatefulWidget {
  const GardenScreen({super.key, required this.onAddFood});
  final VoidCallback onAddFood;

  @override
  State<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends State<GardenScreen> {
  int? _previewStage;
  final ScrollController _scroll = ScrollController();
  final ScrollController _stagesScroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    _stagesScroll.dispose();
    super.dispose();
  }

  void _showStage(int stage) {
    final current = context.read<TrackerProvider>().garden?.stage;
    setState(() => _previewStage = stage == current ? null : stage);
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<TrackerProvider>();
    final model = tracker.garden;
    final baseTheme = Theme.of(context);
    final dark = baseTheme.brightness == Brightness.dark;
    final theme = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: dark ? const Color(0xFFA4C29B) : const Color(0xFF527D52),
        onPrimary: dark ? const Color(0xFF15251A) : Colors.white,
        onSurfaceVariant: dark
            ? const Color(0xFFB1C0B3)
            : const Color(0xFF5C6B5E),
      ),
    );
    final l10n = AppLocalizations.of(context);
    final surface = theme.brightness == Brightness.dark
        ? const Color(0xFF111A15)
        : const Color(0xFFF6F4ED);
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: surface,
        appBar: AppBar(
          backgroundColor: surface,
          title: Text(l10n.gardenTitle),
          actions: [
            IconButton(
              onPressed: tracker.gardenLoading ? null : tracker.loadGarden,
              icon: const Icon(Icons.refresh),
              tooltip: l10n.gardenRetry,
            ),
          ],
        ),
        body: model == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tracker.gardenFailed
                            ? l10n.gardenLoadFailed
                            : l10n.gardenLoading,
                      ),
                      if (tracker.gardenFailed)
                        TextButton(
                          onPressed: tracker.loadGarden,
                          child: Text(l10n.gardenRetry),
                        ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: tracker.loadGarden,
                child: ListView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [
                    Padding(
                      key: const ValueKey('garden-current-progress'),
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.gardenCurrentStage(
                              gardenStageLabel(l10n, model.stage),
                              model.stage + 1,
                            ),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.gardenGrowthCount(model.growthDays),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.gardenStagesTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StageGallery(
                      key: const PageStorageKey('garden-stages-gallery'),
                      controller: _stagesScroll,
                      current: model.stage,
                      selected: _previewStage ?? model.stage,
                      onSelect: _showStage,
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: SizedBox(
                        height: 310,
                        child: GardenScene(
                          stage: _previewStage ?? model.stage,
                          decorated: model.potUnlocked,
                        ),
                      ),
                    ),
                    if (_previewStage != null && _previewStage != model.stage)
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 4),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(
                              l10n.gardenPreview,
                              style: theme.textTheme.labelMedium,
                            ),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _previewStage = null),
                              child: Text(l10n.gardenReturnToPlant),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      l10n.gardenAvocado,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.gardenIntro,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _GardenPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            gardenStageLabel(l10n, model.stage),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            model.stage == 4
                                ? l10n.gardenMatureHint
                                : l10n.gardenNextDays(model.daysToNextStage),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          _Stages(model: model),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _GardenPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_outlined,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.gardenWeeklyTitle,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '${model.weekCount.clamp(0, 4)} / 4',
                                style: theme.textTheme.labelLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.gardenWeeklyBody,
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          _Week(model: model),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Opacity(
                                opacity: model.potUnlocked ? 1 : .45,
                                child: Image.asset(
                                  'assets/garden/pot.webp',
                                  width: 52,
                                  height: 52,
                                  cacheWidth: 160,
                                  excludeFromSemantics: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  model.weeklyComplete
                                      ? l10n.gardenWeekDone
                                      : model.potUnlocked
                                      ? l10n.gardenPotOwned
                                      : l10n.gardenPotReward,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _GardenPanel(
                      child: Row(
                        children: [
                          Icon(
                            Icons.park_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.gardenCollection(model.grownTrees),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.gardenRules,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                    if (tracker.gardenFailed)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          l10n.gardenStale,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onAddFood();
                      },
                      icon: Icon(
                        model.loggedToday ? Icons.restaurant_menu : Icons.add,
                      ),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          model.loggedToday
                              ? l10n.gardenAddMeal
                              : l10n.gardenEarnStep,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Stages extends StatelessWidget {
  const _Stages({required this.model});
  final GardenModel model;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: List.generate(
        5,
        (index) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Semantics(
              label: gardenStageLabel(AppLocalizations.of(context), index),
              selected: index == model.stage,
              child: Column(
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: index <= model.stage
                          ? primary
                          : primary.withValues(alpha: .12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${GardenModel.thresholds[index]}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Week extends StatelessWidget {
  const _Week({required this.model});
  final GardenModel model;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = MaterialLocalizations.of(context);
    return Row(
      children: model.weekDays.map((day) {
        final today = DateUtils.isSameDay(day.date, model.today);
        return Expanded(
          child: Semantics(
            label: local.formatMediumDate(day.date),
            checked: day.earned,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                children: [
                  Text(
                    local.narrowWeekdays[day.date.weekday % 7],
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      color: theme.colorScheme.primary.withValues(
                        alpha: day.earned ? .12 : .04,
                      ),
                      border: today
                          ? Border.all(color: theme.colorScheme.primary)
                          : null,
                    ),
                    child: Icon(
                      day.earned ? Icons.check_rounded : Icons.remove_rounded,
                      size: 15,
                      color: day.earned
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StageGallery extends StatelessWidget {
  const _StageGallery({
    super.key,
    required this.selected,
    required this.current,
    required this.controller,
    required this.onSelect,
  });
  final ScrollController controller;
  final int current;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dark = theme.brightness == Brightness.dark;
    final large = MediaQuery.textScalerOf(context).scale(14) > 17;
    return SingleChildScrollView(
      controller: controller,
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 9),
              child: Semantics(
                button: true,
                selected: selected == i,
                label: i == current
                    ? '${gardenStageLabel(l10n, i)}, ${l10n.gardenCurrentStageTag}'
                    : gardenStageLabel(l10n, i),
                child: SizedBox(
                  width: large ? 132 : 94,
                  height: large ? null : 190,
                  child: Material(
                    color: selected == i
                        ? (dark
                              ? const Color(0xFF243D2B)
                              : const Color(0xFFE7EDE0))
                        : (dark
                              ? const Color(0xFF18251D)
                              : const Color(0xFFF0EEE7)),
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey('garden-stage-$i'),
                      onTap: () => onSelect(i),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 9, 6, 12),
                        child: Column(
                          children: [
                            SizedBox(
                              height: large ? 100 : 82,
                              child: Image.asset(
                                AvocadoTree.assetFor(i),
                                fit: BoxFit.contain,
                                cacheWidth: 260,
                                excludeFromSemantics: true,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              gardenStageLabel(l10n, i),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              l10n.gardenStageDays(GardenModel.thresholds[i]),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (i == current)
                              Text(
                                l10n.gardenCurrentStageTag,
                                key: const ValueKey(
                                  'garden-current-stage-marker',
                                ),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GardenPanel extends StatelessWidget {
  const _GardenPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1A281F) : const Color(0xFFFFFEF9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: dark ? const Color(0xFF293B2D) : const Color(0xFFE8E7DC),
        ),
      ),
      child: child,
    );
  }
}
