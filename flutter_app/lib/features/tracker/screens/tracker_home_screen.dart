import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/email_verification_banner.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/screens/chat_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../models/food_log_model.dart';
import '../providers/tracker_provider.dart';
import 'add_food_screen.dart';
import 'photo_food_screen.dart';
import 'weight_history_screen.dart';

/// Food / water log screen — the authenticated user's home base.
///
/// Single responsibility: render the user's tracker state for the
/// currently-selected day from [TrackerProvider] in a single scrolling
/// page (date nav row, calorie + macro summary, weight entry shortcut,
/// water row, food log grouped by meal) and dispatch add / delete /
/// water-tap / navigate actions back to the provider. No business logic
/// lives here.
class TrackerHomeScreen extends StatefulWidget {
  const TrackerHomeScreen({super.key});

  @override
  State<TrackerHomeScreen> createState() => _TrackerHomeScreenState();
}

class _TrackerHomeScreenState extends State<TrackerHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Defer the first load until after the first frame so `context.read`
    // is safe to call and we don't trigger a setState during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Fire both loads in parallel — weight history is independent of
      // the day's food/water log. Awaiting sequentially would just
      // double the perceived latency.
      final tracker = context.read<TrackerProvider>();
      tracker.loadDailyData(DateTime.now());
      tracker.loadWeightHistory();
    });
  }

  // Friendly Russian labels for the meal buckets we know about; anything
  // the backend happens to return under an unknown key is shown verbatim
  // (capitalised) rather than dropped or guessed at. Shared with the
  // photo-recognition picker below so the two flows use the same words.
  static const Map<String, String> _mealLabels = {
    'breakfast': 'Завтрак',
    'lunch': 'Обед',
    'dinner': 'Ужин',
    'snack': 'Перекус',
  };

  String _mealLabel(String key) {
    return _mealLabels[key] ??
        (key.isEmpty ? key : key[0].toUpperCase() + key.substring(1));
  }

  // ---- date helpers --------------------------------------------------------

  /// True if [a] and [b] fall on the same calendar day in local time.
  /// Time-of-day is intentionally ignored — comparing minutes/hours would
  /// miss matches across the midnight boundary (e.g. 23:59 vs 00:01).
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Friendly label for the centre of the date-nav row: "Сегодня",
  /// "Вчера", or `dd.MM.yyyy`. Manual padding so we don't depend on
  /// `package:intl`.
  String _dateLabel(DateTime selected, DateTime now) {
    if (_isSameDay(selected, now)) return 'Сегодня';
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (_isSameDay(selected, yesterday)) return 'Вчера';
    final dd = selected.day.toString().padLeft(2, '0');
    final mm = selected.month.toString().padLeft(2, '0');
    return '$dd.$mm.${selected.year}';
  }

  Future<void> _openDatePicker() async {
    final tracker = context.read<TrackerProvider>();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: tracker.selectedDate,
      // One year back is plenty for daily tracking; clamp the upper
      // bound at now so users can't accidentally navigate into the
      // future via the picker either.
      firstDate: DateTime(now.year - 1, now.month, now.day),
      lastDate: now,
    );
    if (picked == null) return;
    await tracker.loadDailyData(picked);
  }

  // ---- existing actions ----------------------------------------------------

  Future<void> _onAddWater() async {
    final tracker = context.read<TrackerProvider>();
    final ok = await tracker.addWaterEntry(250);
    if (!mounted) return;
    if (!ok && tracker.errorMessage != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(tracker.errorMessage!),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _onDeleteFood(FoodLogModel food) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: Text('«${food.foodName}» будет удалена из сегодняшнего дневника.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final tracker = context.read<TrackerProvider>();
    final ok = await tracker.deleteFoodEntry(food.id);
    if (!mounted) return;
    if (!ok && tracker.errorMessage != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(tracker.errorMessage!),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _openAddFood() async {
    // The TrackerProvider already merges the response into its own state,
    // so we ignore the returned FoodLogModel — there's nothing extra to do.
    await Navigator.of(context).push<FoodLogModel>(
      MaterialPageRoute(builder: (_) => const AddFoodScreen()),
    );
  }

  /// Shows a modal bottom sheet asking which meal slot the photo will be
  /// filed under. Once the user picks, push [PhotoFoodScreen] with that
  /// meal type — the screen is otherwise self-contained.
  Future<void> _openPhotoFlow() async {
    final mealType = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'К какому приёму пищи отнести?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final entry in _mealLabels.entries)
                ListTile(
                  leading: Icon(_iconForMeal(entry.key)),
                  title: Text(entry.value),
                  onTap: () => Navigator.of(ctx).pop(entry.key),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (mealType == null || !mounted) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PhotoFoodScreen(mealType: mealType),
      ),
    );
    // Whatever the return value (true on "Готово", null on back), do NOT
    // reload data here — `FoodRecognitionProvider.analyzePhoto` already
    // called `trackerProvider.addLocalFoodEntry(...)` on success, and the
    // existing `context.watch<TrackerProvider>()` rebuild wired above
    // would render the new row. A redundant refetch would only cause a
    // visible UI flicker.
  }

  Future<void> _openWeightHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WeightHistoryScreen()),
    );
    // No reload — the weight history screen calls loadWeightHistory()
    // itself on mount, and any new entry the user added there shows up
    // in this screen via the existing context.watch on the next frame.
  }

  Future<void> _openChat() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
    // No reload — the chat screen is independent of the tracker; on
    // return the user lands back here with whatever state they left.
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    // No reload — `ProfileProvider.saveProfile` pushes the new
    // `UserModel` into `AuthProvider` directly, so any change the
    // user just made (name, targets, photo) is already visible via
    // the existing context.watch on this screen.
  }

  IconData _iconForMeal(String key) {
    switch (key) {
      case 'breakfast':
        return Icons.wb_sunny_outlined;
      case 'lunch':
        return Icons.lunch_dining_outlined;
      case 'dinner':
        return Icons.dinner_dining_outlined;
      case 'snack':
        return Icons.cookie_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<TrackerProvider>();
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    // First-load spinner only — once the user has data on screen, subsequent
    // loads (after adding an entry) don't blank the UI.
    final showInitialLoader = tracker.isLoading && tracker.foodLogs.isEmpty;

    // The two FABs (manual add / photo) only make sense for today — the
    // underlying provider methods stamp their entries with DateTime.now()
    // or selectedDate inconsistently. Rather than expose a flow that
    // would silently mislead the user, hide the FABs entirely when
    // viewing a past day.
    final isViewingToday = _isSameDay(tracker.selectedDate, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('NutriMind'),
        actions: [
          IconButton(
            tooltip: 'Профиль',
            icon: const Icon(Icons.person_outline),
            onPressed: _openProfile,
          ),
          IconButton(
            tooltip: 'Чат с NutriBot',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: _openChat,
          ),
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      floatingActionButton: isViewingToday
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'fab-camera',
                  onPressed: _openPhotoFlow,
                  tooltip: 'Фото еды',
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  foregroundColor: theme.colorScheme.onSecondaryContainer,
                  child: const Icon(Icons.camera_alt),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'fab-add',
                  onPressed: _openAddFood,
                  tooltip: 'Добавить еду',
                  child: const Icon(Icons.add),
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              // Reload whichever day the user is currently looking at —
              // pulling to refresh on a past date should refresh *that*
              // day, not silently jump back to today.
              await Future.wait([
                tracker.loadDailyData(tracker.selectedDate),
                tracker.loadWeightHistory(),
              ]);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                // Date navigation row — anchored at the top so the user
                // always knows what day they're looking at.
                _DateNavRow(
                  label: _dateLabel(tracker.selectedDate, DateTime.now()),
                  canGoForward: !isViewingToday,
                  onPrev: () => tracker.loadDailyData(
                    tracker.selectedDate.subtract(const Duration(days: 1)),
                  ),
                  onNext: () => tracker.loadDailyData(
                    tracker.selectedDate.add(const Duration(days: 1)),
                  ),
                  onPickDate: _openDatePicker,
                ),
                const SizedBox(height: 12),
                // Soft "verify your email" reminder. Renders SizedBox.shrink()
                // when there's no user, the user has no email, the user
                // already verified, or they dismissed the banner this
                // session — so the line below is effectively a no-op for
                // the vast majority of the time and the user never has
                // to think about it.
                const EmailVerificationBanner(),
                const SizedBox(height: 12),
                _CaloriesSummaryCard(
                  consumed: tracker.totalCalories,
                  target: auth.currentUser?.dailyCalTarget,
                ),
                const SizedBox(height: 12),

                // Entry point to the weight history screen — sits between
                // the calorie summary and the macro rows so it's the
                // first thing visible after calories.
                _WeightHistoryEntryCard(
                  latestWeight: tracker.latestWeight,
                  onTap: _openWeightHistory,
                ),
                const SizedBox(height: 12),

                _MacroRow(
                  label: 'Белки',
                  consumed: tracker.totalProtein,
                  target: auth.currentUser?.proteinTarget,
                  color: const Color(0xFF3B82F6), // blue-500
                ),
                const SizedBox(height: 8),
                _MacroRow(
                  label: 'Углеводы',
                  consumed: tracker.totalCarbs,
                  target: auth.currentUser?.carbsTarget,
                  color: const Color(0xFFF97316), // orange-500
                ),
                const SizedBox(height: 8),
                _MacroRow(
                  label: 'Жиры',
                  consumed: tracker.totalFat,
                  target: auth.currentUser?.fatTarget,
                  color: const Color(0xFFA855F7), // purple-500
                ),
                const SizedBox(height: 16),
                _WaterRow(
                  totalMl: tracker.totalWaterMl,
                  isLoading: tracker.isLoading,
                  onAdd: _onAddWater,
                ),
                const SizedBox(height: 24),
                _FoodLogSection(
                  grouped: tracker.foodLogsByMeal,
                  isEmpty: tracker.foodLogs.isEmpty && !showInitialLoader,
                  mealLabel: _mealLabel,
                  onDelete: _onDeleteFood,
                ),
              ],
            ),
          ),
          if (showInitialLoader)
            Positioned.fill(
              child: ColoredBox(
                color: theme.colorScheme.surface.withValues(alpha: 0.6),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Date navigation row
// =============================================================================

/// Sits directly under the AppBar: ‹  Сегодня  › (or "Вчера" / "dd.MM.yyyy").
/// Tapping the label opens the system date picker. The forward chevron
/// disables itself at today or later so the user can't navigate into the
/// future.
class _DateNavRow extends StatelessWidget {
  const _DateNavRow({
    required this.label,
    required this.canGoForward,
    required this.onPrev,
    required this.onNext,
    required this.onPickDate,
  });

  final String label;
  final bool canGoForward;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Предыдущий день',
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
          ),
          Expanded(
            child: Center(
              child: InkWell(
                onTap: onPickDate,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Следующий день',
            icon: const Icon(Icons.chevron_right),
            // Disable at today-or-later so the user can never navigate
            // into a day with no data (or, worse, future-tense dates the
            // tracker isn't designed to handle).
            onPressed: canGoForward ? onNext : null,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Entry-point card for the weight-history screen
// =============================================================================

/// Compact card that summarises the user's latest logged weight and
/// launches [WeightHistoryScreen] on tap. Renders either a value + chevron
/// (when weight is known) or a "Добавить вес" CTA (when it's not).
class _WeightHistoryEntryCard extends StatelessWidget {
  const _WeightHistoryEntryCard({
    required this.latestWeight,
    required this.onTap,
  });

  final double? latestWeight;
  final VoidCallback onTap;

  String _fmtKg(double v) => v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasWeight = latestWeight != null;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
          child: Row(
            children: [
              Icon(
                hasWeight
                    ? Icons.monitor_weight_outlined
                    : Icons.add_circle_outline,
                color: hasWeight
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Вес',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasWeight
                          ? 'Текущий вес: ${_fmtKg(latestWeight!)} кг'
                          : 'Добавить вес',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: hasWeight
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

/// Rounded card showing calories consumed vs the user's daily target with
/// a single progress bar. Gracefully degrades when the user hasn't filled
/// in their profile yet (target is null) — we show only the consumed value.
class _CaloriesSummaryCard extends StatelessWidget {
  const _CaloriesSummaryCard({required this.consumed, required this.target});

  final double consumed;
  final num? target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTarget = target != null && target! > 0;
    final ratio = hasTarget
        ? (consumed / target!.toDouble()).clamp(0.0, 1.0)
        : 0.0;
    final consumedRounded = consumed.round();

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasTarget ? 'Калории сегодня' : 'Калорий съедено',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$consumedRounded',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  hasTarget
                      ? ' / ${target!.round()} ккал'
                      : ' ккал',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (hasTarget) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 10,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Single row in the macro summary block (protein / carbs / fat). Same
/// null-tolerant design as `_CaloriesSummaryCard`.
class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.consumed,
    required this.target,
    required this.color,
  });

  final String label;
  final double consumed;
  final num? target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTarget = target != null && target! > 0;
    final ratio = hasTarget
        ? (consumed / target!.toDouble()).clamp(0.0, 1.0)
        : 0.0;
    final consumedRounded = consumed.toStringAsFixed(
      consumed == consumed.roundToDouble() ? 0 : 1,
    );

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  hasTarget
                      ? '$consumedRounded / ${_formatG(target!)} г'
                      : '$consumedRounded г',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (hasTarget) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatG(num g) =>
      g == g.roundToDouble() ? g.toInt().toString() : g.toStringAsFixed(1);
}

/// Water tracking row: total consumed + a "+250 мл" button.
class _WaterRow extends StatelessWidget {
  const _WaterRow({
    required this.totalMl,
    required this.isLoading,
    required this.onAdd,
  });

  final int totalMl;
  final bool isLoading;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Icon(Icons.water_drop_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Вода',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '$totalMl мл',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: isLoading ? null : onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('250 мл'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Food-log section: a header per meal bucket + ListTiles for each entry,
/// or a single empty-state line if nothing's been logged yet.
class _FoodLogSection extends StatelessWidget {
  const _FoodLogSection({
    required this.grouped,
    required this.isEmpty,
    required this.mealLabel,
    required this.onDelete,
  });

  final Map<String, List<FoodLogModel>> grouped;
  final bool isEmpty;
  final String Function(String) mealLabel;
  final void Function(FoodLogModel food) onDelete;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            'Пока нет записей',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    final children = <Widget>[];
    // Preserve a friendly order: known meals first in the canonical order,
    // then any unknown buckets alphabetically.
    const knownOrder = ['breakfast', 'lunch', 'dinner', 'snack'];
    final known = knownOrder
        .where(grouped.containsKey)
        .map((k) => MapEntry(k, grouped[k]!));
    final unknown = grouped.entries
        .where((e) => !knownOrder.contains(e.key))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    void addSection(String key, List<FoodLogModel> entries) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            mealLabel(key),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
      for (final food in entries) {
        children.add(_FoodLogTile(food: food, onDelete: () => onDelete(food)));
      }
    }

    for (final entry in known) {
      addSection(entry.key, entry.value);
    }
    for (final entry in unknown) {
      addSection(entry.key, entry.value);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// Single food-log entry. Subtitle is "Б/У/Ж" (белки/углеводы/жиры) per
/// the spec — compact single-line format that fits a single-line ListTile.
class _FoodLogTile extends StatelessWidget {
  const _FoodLogTile({required this.food, required this.onDelete});

  final FoodLogModel food;
  final VoidCallback onDelete;

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle =
        '${food.calories.round()} ккал • Б/У/Ж ${_fmt(food.protein)}/${_fmt(food.carbs)}/${_fmt(food.fat)} г';

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        title: Text(
          food.foodName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: IconButton(
          tooltip: 'Удалить',
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
