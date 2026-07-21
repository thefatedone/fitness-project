import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

    String latestText = latest == null ? 'Нет данных' : '${_fmt(latest)} кг';
    String? targetText =
        target == null ? null : 'Цель: ${_fmt(target)} кг';
    String? remainingText;
    if (latest != null && target != null) {
      final diff = (latest - target).abs();
      remainingText = 'Осталось: ${_fmt(diff)} кг';
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
        title: const Text('История веса'),
        backgroundColor: theme.colorScheme.surface,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        tooltip: 'Добавить замер',
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
                  'Текущий вес',
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

class _ChartCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Reverse so X-axis reads chronologically left-to-right (oldest on the
    // left). The history endpoint serves newest-first.
    final reversed = entries.reversed.toList(growable: false);

    final weights = reversed.map((e) => e.weight).toList(growable: false);
    var minW = weights.reduce((a, b) => a < b ? a : b);
    var maxW = weights.reduce((a, b) => a > b ? a : b);

    // If the user has set a target weight, fold it into the min/max
    // calculation BEFORE padding. Without this, a target that's still
    // well above (or below) the current data range would land outside
    // [minY, maxY] and the dashed reference line would silently fail to
    // render — exactly when the user most wants to see "how far to go".
    if (targetWeight != null) {
      if (targetWeight! < minW) minW = targetWeight!;
      if (targetWeight! > maxW) maxW = targetWeight!;
    }

    // Add a couple of kilograms of headroom so the line isn't flush with
    // the chart edges. The padding is applied AFTER folding the target in,
    // so the target line is guaranteed to sit inside the visible band.
    final headroom = ((maxW - minW).abs() < 0.5) ? 2.0 : 2.0;
    final minY = (minW - headroom).floorToDouble();
    final maxY = (maxW + headroom).ceilToDouble();

    final spots = <FlSpot>[
      for (var i = 0; i < reversed.length; i++)
        FlSpot(i.toDouble(), reversed[i].weight),
    ];

    // Overlay the target line whenever one is set. With the range fix
    // above, the target is always inside [minY, maxY], so no extra
    // "is it in range?" check is needed.
    final extras = <HorizontalLine>[];
    if (targetWeight != null) {
      extras.add(
        HorizontalLine(
          y: targetWeight!,
          color: theme.colorScheme.secondary,
          strokeWidth: 1.5,
          dashArray: const [6, 6],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(right: 6, bottom: 2),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
            labelResolver: (_) => 'Цель',
          ),
        ),
      );
    }

    // Subsample X-axis labels: at most 5-6 across the whole range.
    final labelInterval =
        reversed.length <= 6 ? 1.0 : (reversed.length / 5).ceilToDouble();

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text(
                'Динамика',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(
              height: 250,
              child: LineChart(
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
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, p, bar, idx) =>
                            FlDotCirclePainter(
                          radius: 3.5,
                          color: theme.colorScheme.primary,
                          strokeWidth: 2,
                          strokeColor: theme.colorScheme.surface,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                      ),
                    ),
                  ],
                  extraLinesData:
                      extras.isEmpty ? null : ExtraLinesData(horizontalLines: extras),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: ((maxW - minW) / 4).clamp(0.5, 5.0),
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
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
                        interval: ((maxW - minW) / 4).clamp(0.5, 5.0),
                        getTitlesWidget: (value, meta) {
                          // Hide the very top / very bottom labels so
                          // the unit text doesn't fight the chart frame.
                          if (value == meta.max || value == meta.min) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              formatKg(value.toDouble()),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
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
                          final idx = value.round();
                          if (idx < 0 || idx >= reversed.length) {
                            return const SizedBox.shrink();
                          }
                          // Only render labels at integer positions that
                          // fall on our subsampled interval.
                          if ((value - idx.toDouble()).abs() > 0.01) {
                            return const SizedBox.shrink();
                          }
                          if ((idx % labelInterval.round()) != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              formatForChart(reversed[idx].date),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) =>
                          theme.colorScheme.inverseSurface.withValues(alpha: 0.9),
                      getTooltipItems: (spots) => spots.map((s) {
                        final entry = reversed[s.x.toInt()];
                        return LineTooltipItem(
                          '${formatKg(s.y)} кг\n'
                          '${formatForChart(entry.date)}',
                          TextStyle(
                            color: theme.colorScheme.onInverseSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
            'Добавь ещё одну запись веса, чтобы увидеть график',
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
              'Все записи',
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
                  '${formatKg(entry.weight)} кг',
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
              'Пока нет записей о весе',
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
    if (v == null || v.trim().isEmpty) return 'Введи вес';
    final n = num.tryParse(v.trim().replaceAll(',', '.'));
    if (n == null) return 'Введи число';
    if (n <= 0) return 'Должен быть > 0';
    if (n > 500) return 'Слишком большое значение';
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
    } else if (tracker.errorMessage != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(tracker.errorMessage!),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<TrackerProvider>().isLoading;

    return AlertDialog(
      title: const Text('Добавить вес'),
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
              decoration: const InputDecoration(
                labelText: 'Вес, кг',
                border: OutlineInputBorder(),
              ),
              validator: _weightValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              textInputAction: TextInputAction.done,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Заметка (необязательно)',
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
          child: const Text('Отмена'),
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
          label: const Text('Добавить'),
        ),
      ],
    );
  }
}
