import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../widgets/glass/glass_card.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/weight_log_model.dart';
import '../providers/tracker_provider.dart';

/// Weight history screen — full list + trend chart.
///
/// Single responsibility: render [TrackerProvider.weightHistory] as a
/// Material-list of past entries plus a small `fl_chart` line-chart that
/// also overlays the user's target weight as a dashed reference line.
/// No business logic: all mutations route back through
/// [TrackerProvider.addWeightEntry].
class WeightHistoryScreen extends StatefulWidget {
  const WeightHistoryScreen({super.key});

  @override
  State<WeightHistoryScreen> createState() => _WeightHistoryScreenState();
}

class _WeightHistoryScreenState extends State<WeightHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Defer the load until after the first frame so we don't trigger a
    // setState during build, and the initial-load spinner below has a
    // chance to render briefly before the data arrives.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TrackerProvider>().loadWeightHistory();
    });
  }

  // ---- manual date formatting (intl-free) -----------------------------------

  /// The history endpoint returns `date` as `"yyyy-MM-dd"`. This parser
  /// accepts that exact shape and returns the same string with
  /// `yyyy-MM-dd` re-arranged to `dd.MM.yyyy` for the list rows, and to
  /// `dd.MM` for chart X-axis labels. Keeping the helper local means we
  /// don't need `package:intl`.
  static String _formatForList(String ymd) {
    if (ymd.length < 10) return ymd;
    return '${ymd.substring(8, 10)}.${ymd.substring(5, 7)}.${ymd.substring(0, 4)}';
  }

  static String _formatForChart(String ymd) {
    if (ymd.length < 10) return ymd;
    return '${ymd.substring(8, 10)}.${ymd.substring(5, 7)}';
  }

  String _fmt(double v) => v.toStringAsFixed(1);

  // ---- add-weight dialog ----------------------------------------------------

  Future<void> _showAddDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => _AddWeightDialog(parentContext: context),
    );
  }

  // ---- summary card data ----------------------------------------------------

  /// Pulled out so we can also feed it to the FAB tooltip / header.
  ({String latest, String? target, String? remaining}) _summary() {
    final tracker = context.read<TrackerProvider>();
    final auth = context.read<AuthProvider>();
    final latest = tracker.latestWeight;
    final target = auth.currentUser?.targetWeight;
    final l10n = AppLocalizations.of(context);

    String latestText = latest == null
        ? l10n.weightHistoryLatestMissing
        : '${_fmt(latest)} кг';
    String? targetText = target == null
        ? null
        : l10n.weightHistoryTarget(_fmt(target));
    String? remainingText;
    if (latest != null && target != null) {
      final diff = (latest - target).abs();
      remainingText = l10n.weightHistoryRemaining(_fmt(diff));
    }

    return (latest: latestText, target: targetText, remaining: remainingText);
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<TrackerProvider>();
    final theme = Theme.of(context);

    final isEmpty = tracker.weightHistory.isEmpty;
    final initialLoading = tracker.isLoading && isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).weightHistoryTitle),
        backgroundColor: theme.colorScheme.surface,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        tooltip: AppLocalizations.of(context).weightHistoryAddTitle,
        child: const Icon(Icons.add),
      ),
      body: Stack(
        children: [
          if (initialLoading)
            const Center(child: CircularProgressIndicator())
          else if (isEmpty)
            _EmptyView()
          else
            _buildLoaded(theme, tracker),
        ],
      ),
    );
  }

  Widget _buildLoaded(ThemeData theme, TrackerProvider tracker) {
    final summary = _summary();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // 1. Summary row --------------------------------------------------
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).weightHistoryWeight,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.latest,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (summary.target != null || summary.remaining != null)
                  const SizedBox(height: 8),
                if (summary.target != null)
                  Text(
                    summary.target!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (summary.remaining != null)
                  Text(
                    summary.remaining!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Chart -------------------------------------------------------
        if (tracker.weightHistory.length >= 2)
          _ChartCard(
            theme: theme,
            entries: tracker.weightHistory,
            targetWeight: context.read<AuthProvider>().currentUser?.targetWeight,
            formatForChart: _formatForChart,
            formatKg: _fmt,
          )
        else
          _OnePointHint(theme: theme),

        const SizedBox(height: 24),

        // 3. Plain list --------------------------------------------------
        _HistoryList(
          entries: tracker.weightHistory,
          formatForList: _formatForList,
          formatKg: _fmt,
        ),
      ],
    );
  }
}

// =============================================================================
// Chart
// =============================================================================

class _ChartCard extends StatefulWidget {
  const _ChartCard({
    required this.theme,
    required this.entries,
    required this.targetWeight,
    required this.formatForChart,
    required this.formatKg,
  });

  final ThemeData theme;
  final List<WeightHistoryEntry> entries;
  final double? targetWeight;
  final String Function(String ymd) formatForChart;
  final String Function(double v) formatKg;

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> {
  /// Index of the currently-selected chart point, or `null` if the
  /// user isn't hovering/tapping any point. Drives the [GlassCard]
  /// tooltip rendered on top of the chart.
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    // Reverse so X-axis reads chronologically left-to-right (oldest on
    // the left). The history endpoint serves newest-first.
    final reversed = widget.entries.reversed.toList(growable: false);

    final weights = reversed.map((e) => e.weight).toList(growable: false);
    var minW = weights.reduce((a, b) => a < b ? a : b);
    var maxW = weights.reduce((a, b) => a > b ? a : b);

    if (widget.targetWeight != null) {
      if (widget.targetWeight! < minW) minW = widget.targetWeight!;
      if (widget.targetWeight! > maxW) maxW = widget.targetWeight!;
    }

    final headroom = ((maxW - minW).abs() < 0.5) ? 2.0 : 2.0;
    final minY = (minW - headroom).floorToDouble();
    final maxY = (maxW + headroom).ceilToDouble();

    final spots = <FlSpot>[
      for (var i = 0; i < reversed.length; i++)
        FlSpot(i.toDouble(), reversed[i].weight),
    ];

    final extras = <HorizontalLine>[];
    if (widget.targetWeight != null) {
      extras.add(
        HorizontalLine(
          y: widget.targetWeight!,
          color: widget.theme.colorScheme.secondary,
          strokeWidth: 1.5,
          dashArray: const [6, 6],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(right: 6, bottom: 2),
            style: widget.theme.textTheme.labelSmall?.copyWith(
              color: widget.theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
            labelResolver: (_) =>
                AppLocalizations.of(context).weightHistoryChartGoalLabel,
          ),
        ),
      );
    }

    // Subsample X-axis labels: at most 5-6 across the whole range.
    final labelInterval = reversed.length <= 6
        ? 1.0
        : (reversed.length / 5).ceilToDouble();

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              AppLocalizations.of(context).weightHistoryTitle,
              style: widget.theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: widget.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(
            height: 250,
            child: Stack(
              children: [
                LineChart(
                  LineChartData(
                    minY: minY,
                    maxY: maxY,
                    minX: 0,
                    maxX: (reversed.length - 1).toDouble(),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.25,
                        preventCurveOverShooting: true,
                        color: widget.theme.colorScheme.primary,
                        barWidth: 3,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, p, bar, idx) =>
                              FlDotCirclePainter(
                            radius: 3.5,
                            color: widget.theme.colorScheme.primary,
                            strokeWidth: 2,
                            strokeColor: widget.theme.colorScheme.surface,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: widget.theme.colorScheme.primary
                              .withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                    extraLinesData: extras.isEmpty
                        ? null
                        : ExtraLinesData(horizontalLines: extras),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval:
                          ((maxW - minW) / 4).clamp(0.5, 5.0),
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: widget.theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.5),
                        strokeWidth: 1,
                        dashArray: const [4, 4],
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          interval:
                              ((maxW - minW) / 4).clamp(0.5, 5.0),
                          getTitlesWidget: (value, meta) {
                            if (value == meta.max ||
                                value == meta.min) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding:
                                  const EdgeInsets.only(right: 4),
                              child: Text(
                                widget.formatKg(value.toDouble()),
                                style: widget.theme.textTheme.labelSmall
                                    ?.copyWith(
                                  color: widget
                                      .theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: labelInterval,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= reversed.length) {
                              return const SizedBox.shrink();
                            }
                            if ((value - idx.toDouble()).abs() > 0.01) {
                              return const SizedBox.shrink();
                            }
                            if ((idx % labelInterval.round()) != 0) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                widget.formatForChart(
                                    reversed[idx].date),
                                style: widget.theme.textTheme.labelSmall
                                    ?.copyWith(
                                  color: widget
                                      .theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      // Suppress fl_chart's built-in tooltip; we
                      // render our own [GlassCard] tooltip overlay
                      // (see _ChartTooltip below). Built-in tooltip
                      // was just a flat `inverseSurface` pill; the
                      // [GlassCard] picks up the brand tint and
                      // reads as part of the Liquid Glass language.
                      handleBuiltInTouches: false,
                      touchCallback: (event, response) {
                        if (response == null ||
                            response.lineBarSpots == null ||
                            response.lineBarSpots!.isEmpty) {
                          setState(() => _selectedIndex = null);
                          return;
                        }
                        final barSpot = response.lineBarSpots!.first;
                        // `TouchLineBarSpot` extends `LineBarSpot`
                        // which extends `FlSpot` — its x/y are the
                        // chart coordinates we want.
                        setState(
                            () => _selectedIndex = barSpot.x.toInt());
                      },
                    ),
                  ),
                ),
                // Glass tooltip overlay — sits on top of the chart
                // and shows the date + weight of the currently-
                // selected point.
                if (_selectedIndex != null &&
                    _selectedIndex! >= 0 &&
                    _selectedIndex! < reversed.length)
                  Positioned(
                    top: 8,
                    right: 16,
                    child: _ChartTooltip(
                      entry: reversed[_selectedIndex!],
                      formatKg: widget.formatKg,
                      formatForChart: widget.formatForChart,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact glass tooltip that hovers over the chart when the user
/// has selected a point. Reads as a small floating [GlassCard] —
/// same surface treatment as the rest of the app, just at a
/// smaller size.
class _ChartTooltip extends StatelessWidget {
  const _ChartTooltip({
    required this.entry,
    required this.formatKg,
    required this.formatForChart,
  });

  final WeightHistoryEntry entry;
  final String Function(double v) formatKg;
  final String Function(String ymd) formatForChart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${formatKg(entry.weight)} кг',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatForChart(entry.date),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when there's exactly one entry — we want a hint, but a line
/// chart with a single point isn't meaningful.
class _OnePointHint extends StatelessWidget {
  const _OnePointHint({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Center(
          child: Text(
            AppLocalizations.of(context).weightHistoryEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// List
// =============================================================================

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.entries,
    required this.formatForList,
    required this.formatKg,
  });

  final List<WeightHistoryEntry> entries;
  final String Function(String ymd) formatForList;
  final String Function(double v) formatKg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              AppLocalizations.of(context).weightHistoryWeightHint,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final entry in entries)
            ListTile(
              leading: SizedBox(
                width: 72,
                child: Text(
                  AppLocalizations.of(context).weightHistoryWeightHint,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(
                formatForList(entry.date),
                style: theme.textTheme.bodyMedium,
              ),
              subtitle: (entry.note == null || entry.note!.isEmpty)
                  ? null
                  : Text(
                      entry.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
              dense: true,
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Empty / loading states
// =============================================================================

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.monitor_weight_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).weightHistoryEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Add-weight dialog
// =============================================================================

/// Modal dialog for logging a new weight. Lives in its own StatefulWidget
/// so its `isLoading` / `errorMessage` rebuild stays scoped to the dialog —
/// `Provider.of(context.watch)` outside the dialog's build would touch the
/// parent screen unnecessarily.
class _AddWeightDialog extends StatefulWidget {
  const _AddWeightDialog({required this.parentContext});

  /// The screen's [BuildContext], used only to look up the *tracker* —
  /// NOT for SnackBar / Navigator (we'd escape the dialog's overlay).
  final BuildContext parentContext;

  @override
  State<_AddWeightDialog> createState() => _AddWeightDialogState();
}

class _AddWeightDialogState extends State<_AddWeightDialog> {
  final _formKey = GlobalKey<FormState>();
  final _weightCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _weightCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// Accept both `,` and `.` as the decimal separator. Parse with both
  /// chars normalised to `.` so a Russian-locale user typing "12,5"
  /// doesn't get rejected.
  String? _weightValidator(String? v) {
    final l10n = AppLocalizations.of(context);
    if (v == null || v.trim().isEmpty) return l10n.weightHistoryWeightRequired;
    final n = num.tryParse(v.trim().replaceAll(',', '.'));
    if (n == null) return l10n.onboardingEnterNumber;
    if (n <= 0) return l10n.weightHistoryMustBePositive;
    if (n > 500) return l10n.weightHistoryTooLarge;
    return null;
  }

  double? _parseWeight() {
    return num.tryParse(_weightCtrl.text.trim().replaceAll(',', '.'))
        ?.toDouble();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final tracker = context.read<TrackerProvider>();
    // Render a snackbar using the dialog's OWN BuildContext so it stays
    // attached to the dialog's overlay if the dialog ever animates out.
    final messenger = ScaffoldMessenger.of(context);

    final w = _parseWeight();
    if (w == null) return;

    final ok = await tracker.addWeightEntry(
      w,
      _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              TrackerProvider.localizeError(context, tracker),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<TrackerProvider>().isLoading;

    return AlertDialog(
      title: Text(AppLocalizations.of(context).weightHistoryAddTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              autofocus: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).weightHistoryWeight,
                border: OutlineInputBorder(),
              ),
              validator: _weightValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              textInputAction: TextInputAction.done,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).weightHistoryNote,
                border: OutlineInputBorder(),
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
        FilledButton.icon(
          onPressed: isLoading ? null : _submit,
          icon: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check, size: 18),
          label: Text(AppLocalizations.of(context).commonSave),
        ),
      ],
    );
  }
}
