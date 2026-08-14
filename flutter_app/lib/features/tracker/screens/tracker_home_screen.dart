import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/gen/app_localizations.dart';

import '../../../shared/widgets/app_dock.dart';
import '../../../shared/widgets/email_verification_banner.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/screens/chat_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/food_log_model.dart';
import '../models/water_log_model.dart';
import '../providers/food_recognition_provider.dart';
import '../providers/tracker_provider.dart';
import 'add_food_screen.dart';
import 'edit_food_description_screen.dart';
import 'photo_beverage_screen.dart';
import 'photo_food_screen.dart';
import 'weight_history_screen.dart';

import '../../../widgets/glass/glass_card.dart';
import '../../../widgets/glass/glass_chip.dart';
import '../../../widgets/glass/glass_background_glow.dart';
import '../../../widgets/glass/glass_progress_ring.dart';
import '../../../widgets/glass/glass_surface.dart';

/// Food / water log screen — the authenticated user's home base.
///
/// Single responsibility: render the user's tracker state for the
/// currently-selected day from [TrackerProvider] in a single scrolling
/// page (date nav row, calorie + macro summary, weight entry shortcut,
/// water row, food log grouped by meal) and dispatch add / delete /
/// water-tap / navigate actions back to the provider. No business logic
/// lives here.
/// Thin shim retained so the call sites below stay one-liners. The
/// resolver itself now lives on [TrackerProvider.localizeError] so the
/// add-food and weight-history SnackBars can share the same fallback
/// chain.
String _localizedTrackerError(BuildContext context, TrackerProvider tracker) =>
    TrackerProvider.localizeError(context, tracker);

class TrackerHomeScreen extends StatefulWidget {
  const TrackerHomeScreen({super.key});

  @override
  State<TrackerHomeScreen> createState() => _TrackerHomeScreenState();
}

class _TrackerHomeScreenState extends State<TrackerHomeScreen> {
  /// Scroll-aware blur suppression. When `true`, every glass
  /// surface in the home page falls back to its solid treatment
  /// so the GPU isn't recomputing a full backdrop-blur on every
  /// frame during a fast swipe. The notifier is flipped by the
  /// `NotificationListener` wrapping the body's ListView, with
  /// velocity thresholds + hysteresis to avoid flip-flopping.
  final ValueNotifier<bool> _blurSuppressed = ValueNotifier(false);

  /// Scroll velocity (px/s) above which we treat the list as
  /// "fast enough that blur recomputes would jank". Below this
  /// the glass surfaces render their full blur treatment.
  static const double _blurOffThresholdPxPerSec = 800;

  /// Scroll velocity (px/s) below which we restore the blur. Set
  /// lower than [_blurOffThresholdPxPerSec] so a brief dip in
  /// velocity (a near-stop mid-fling) doesn't flicker the glass
  /// on/off — the surface stays solid until the user genuinely
  /// settles.
  static const double _blurOnThresholdPxPerSec = 200;

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

  @override
  void dispose() {
    _blurSuppressed.dispose();
    super.dispose();
  }

  // Friendly Russian labels for the meal buckets we know about; anything
  // the backend happens to return under an unknown key is shown verbatim
  // (capitalised) rather than dropped or guessed at. Shared with the
  // photo-recognition picker below so the two flows use the same words.
  static const Map<String, String> _mealLabels = {
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
    'snack': 'Snack',
    // Beverage entries — a dedicated bucket since the backend's
    // beverage-recognition flow writes `meal_type='drinks'` (kept
    // distinct from `'snack'` so a 3 PM coffee and a 3 PM cookie
    // don't collapse into the same section). The English key
    // `'drinks'` is the backend's wire format (see
    // `backend/app/api/v1/routes/food_recognition.py`'s
    // `_dual_log_beverage`); translating it as a first-class
    // member of this map — rather than falling through to the
    // "capitalise the raw key" default — avoids the user ever
    // seeing the literal word "Drinks" on screen.
    'drinks': 'Drinks',
  };

  String _mealLabel(BuildContext context, String key) {
    final l10n = AppLocalizations.of(context);
    switch (key) {
      case 'breakfast':
        return l10n.trackerMealBreakfast;
      case 'lunch':
        return l10n.trackerMealLunch;
      case 'dinner':
        return l10n.trackerMealDinner;
      case 'snack':
        return l10n.trackerMealSnack;
      case 'drinks':
        return l10n.trackerMealDrinks;
    }
    return _mealLabels[key] ??
        (key.isEmpty ? key : key[0].toUpperCase() + key.substring(1));
  }

  // ---- date helpers --------------------------------------------------------

  /// True if [a] and [b] fall on the same calendar day in local time.
  /// Time-of-day is intentionally ignored — comparing minutes/hours would
  /// miss matches across the midnight boundary (e.g. 23:59 vs 00:01).
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Friendly label for the centre of the date-nav row: "Today",
  /// "Yesterday", or `dd.MM.yyyy`. Manual padding so we don't depend on
  /// `package:intl`.
  String _dateLabel(BuildContext context, DateTime selected, DateTime now) {
    if (_isSameDay(selected, now)) {
      return AppLocalizations.of(context).trackerDateToday;
    }
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (_isSameDay(selected, yesterday)) {
      return AppLocalizations.of(context).trackerDateYesterday;
    }
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
    // The "+ Add воду" button on the water card opens this modal
    // so the user can pick a custom amount in litres (0.1–10 L) with
    // optional quick-pick chips. The sheet handles its own state
    // (loading, validation, conversion) and closes itself on success;
    // the parent just opens the modal here.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _AddWaterSheet(),
    );
  }

  Future<void> _onDeleteWater(String waterId) async {
    final tracker = context.read<TrackerProvider>();
    final ok = await tracker.deleteWaterEntry(waterId);
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
        title: Text(AppLocalizations.of(context).trackerDeleteRecordTitle),
        content: Text(AppLocalizations.of(context).trackerDeleteRecordBody(food.foodName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).commonDelete),
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
                  AppLocalizations.of(context).trackerMealPickerTitle,
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
    // Whatever the return value (true on "Done", null on back), do NOT
    // reload data here — `FoodRecognitionProvider.analyzePhoto` already
    // called `trackerProvider.addLocalFoodEntry(...)` on success, and the
    // existing `context.watch<TrackerProvider>()` rebuild wired above
    // would render the new row. A redundant refetch would only cause a
    // visible UI flicker.
  }

  /// Shows the camera DockItem's tap dispatcher: a small modal
  /// bottom sheet asking what the user is about to photograph
  /// (food vs beverage). Each option routes to its own screen.
  ///
  /// Why a modal sheet rather than adding a sixth Dock icon:
  /// the Dock is already at its 5-item layout (camera, chat,
  /// add, profile, settings) and adding a sixth would crowd it
  /// — at < 360 dp wide the icons would overflow or compress
  /// into illegible targets. The Dock icon (a single camera)
  /// plus a chooser sheet keeps the Dock's visual rhythm intact
  /// while letting the user reach either flow with one tap.
  ///
  /// The two options have different downstream shapes — the
  /// food flow asks for a meal slot (because meals are filed
  /// under breakfast/lunch/dinner/snack), while the beverage
  /// flow skips that step (beverages always file under "snack"
  /// server-side). Routing through one dispatcher here keeps
  /// that asymmetry out of the Dock's `onTap` callback.
  Future<void> _showCameraChoice() async {
    await showModalBottomSheet<void>(
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
                  AppLocalizations.of(context).trackerCameraChoiceTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.restaurant),
                title: Text(AppLocalizations.of(context).trackerCameraFood),
                subtitle: Text(
                  AppLocalizations.of(context).trackerCameraFoodSubtitle,
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openPhotoFlow();
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_drink_outlined),
                title: Text(AppLocalizations.of(context).trackerCameraBeverage),
                subtitle: Text(
                  AppLocalizations.of(context).trackerCameraBeverageSubtitle,
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openPhotoBeverage();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Pushes [PhotoBeverageScreen] for the beverage flow. No
  /// meal-picker sheet is involved — beverages always file
  /// under "snack" server-side, so the user doesn't need to
  /// answer a meal-slot question. Whatever the return value
  /// (`true` on successful confirm-and-save, `null` on back),
  /// no refetch is required: `BeverageProvider.confirmManual`
  /// already merged the dual-written rows into
  /// [TrackerProvider] in-place.
  Future<void> _openPhotoBeverage() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const PhotoBeverageScreen(),
      ),
    );
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

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _openReanalyze(FoodLogModel food) async {
    // Pushes [EditFoodDescriptionScreen] for an AI-generated row.
    //
    // Pre-filling `initialDescription` from the in-memory cache:
    // `FoodRecognitionProvider.descriptionsByFoodLogId` carries the
    // most recent description Gemini produced for this row across
    // the photo-recognition screen → home screen leg of the flow.
    // When the cache hits (same app session, no kill), the user
    // continues editing from the text they last saw; when it
    // misses (app was killed/restarted, row was logged in a
    // previous session), the field starts empty and the user types
    // their correction from scratch — a perfectly reasonable UX
    // fallback that the spec specifically sanctions.
    //
    // The screen pops with `true` on success, which we currently
    // ignore — the underlying [TrackerProvider] is already
    // updated in place by [FoodRecognitionProvider] via
    // `updateLocalFoodEntry`, so no further action is needed from
    // the caller. If we ever want a toast ("Уточнено!"), this is
    // where it would go.
    final provider = context.read<FoodRecognitionProvider>();
    final cachedDescription =
        provider.descriptionsByFoodLogId[food.id] ?? '';
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditFoodDescriptionScreen(
          foodLog: food,
          initialDescription: cachedDescription,
        ),
      ),
    );
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
      case 'drinks':
        // Reuses the same icon as the camera-choice modal's
        // "Photograph beverage" entry (and
        // `photo_beverage_screen.dart`'s picker view) so any
        // beverage-related affordance the user sees on the home
        // screen renders with the same visual hint. Distinct from
        // `Icons.water_drop_outlined` (used inside individual
        // beverage rows' volume lines) — water_drop is "this row
        // is a beverage", local_drink is "this section is the
        // drinks bucket".
        return Icons.local_drink_outlined;
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
      // Minimal AppBar — the title text and the three trailing icon
      // buttons (settings, profile, chat) have moved into the
      // bottom-floating Dock below. The AppBar is still here purely
      // for status-bar color/height consistency and the OS-conventional
      // top-padding for the date-nav row that sits just under it.
      appBar: AppBar(),
      body: GlassBackgroundGlow(
        child: Stack(
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
            child: NotificationListener<ScrollUpdateNotification>(
              onNotification: (notification) {
                // Estimate velocity as scrollDelta per frame,
                // scaled to per-second by the 16ms frame budget.
                // A 60fps device at 800px/s gives |scrollDelta|
                // ~= 13px per frame. The hysteresis between
                // `_blurOffThresholdPxPerSec` (800) and
                // `_blurOnThresholdPxPerSec` (200) prevents the
                // glass from flickering on/off during a near-stop
                // mid-fling.
                final double v = (notification.scrollDelta ?? 0).abs() *
                    1000 /
                    16;
                final suppress = _blurSuppressed.value;
                if (!suppress && v > _blurOffThresholdPxPerSec) {
                  _blurSuppressed.value = true;
                } else if (suppress && v < _blurOnThresholdPxPerSec) {
                  _blurSuppressed.value = false;
                }
                // Don't intercept the notification — let the
                // ListView keep handling it.
                return false;
              },
              child: ListView(
                // Bottom padding bumped to clear the floating Dock's
                // height (~64 px) plus its 16 px margin so the last
                // food-log tile never hides under the pill. Top stays
                // 0 — the AppBar already reserves the status-bar gutter
                // and the date-nav row sits flush against it.
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                children: [
                // Date navigation row — anchored at the top so the user
                // always knows what day they're looking at.
                _DateNavRow(
                  label: _dateLabel(context, tracker.selectedDate, DateTime.now()),
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
                  suppressBlur: _blurSuppressed,
                ),
                const SizedBox(height: 12),

                // Entry point to the weight history screen — sits between
                // the calorie summary and the macro rows so it's the
                // first thing visible after calories.
                _WeightHistoryEntryCard(
                  latestWeight: tracker.latestWeight,
                  onTap: _openWeightHistory,
                  suppressBlur: _blurSuppressed,
                ),
                const SizedBox(height: 12),

                _MacroRow(
                  label: AppLocalizations.of(context).addFoodProtein,
                  consumed: tracker.totalProtein,
                  target: auth.currentUser?.proteinTarget,
                  color: const Color(0xFF3B82F6), // blue-500
                  suppressBlur: _blurSuppressed,
                ),
                const SizedBox(height: 8),
                _MacroRow(
                  label: AppLocalizations.of(context).trackerFoodCarbs,
                  consumed: tracker.totalCarbs,
                  target: auth.currentUser?.carbsTarget,
                  color: const Color(0xFFF97316), // orange-500
                  suppressBlur: _blurSuppressed,
                ),
                const SizedBox(height: 8),
                _MacroRow(
                  label: AppLocalizations.of(context).trackerFoodFat,
                  consumed: tracker.totalFat,
                  target: auth.currentUser?.fatTarget,
                  color: const Color(0xFFA855F7), // purple-500
                  suppressBlur: _blurSuppressed,
                ),
                const SizedBox(height: 16),
                _WaterRow(
                  waterLogs: tracker.waterLogs,
                  isLoading: tracker.isLoading,
                  onAdd: _onAddWater,
                  onDelete: (id) => _onDeleteWater(id),
                  suppressBlur: _blurSuppressed,
                ),
                const SizedBox(height: 24),
                _FoodLogSection(
                  grouped: tracker.foodLogsByMeal,
                  isEmpty: tracker.foodLogs.isEmpty && !showInitialLoader,
                  mealLabel: _mealLabel,
                  onDelete: _onDeleteFood,
                  // Only AI-generated rows have something to
                  // correct (a textual description Gemini produced);
                  // entries entered manually via `AddFoodScreen`
                  // don't carry an AI description at all. Passing a
                  // single conditional callback keeps the per-tile
                  // logic inside `_FoodLogTile` trivial: show the
                  // edit button iff this callback is non-null.
                  onReanalyze: _openReanalyze,
                  suppressBlur: _blurSuppressed,
                ),
              ],
              ),
            ),
          ),
          if (showInitialLoader)
            Positioned.fill(
              child: ColoredBox(
                color: theme.colorScheme.surface.withValues(alpha: 0.6),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),

          // Bottom-floating Dock. Mirrors the iOS / macOS dock
          // convention: a frosted-glass pill that hovers above the
          // scrolling body, holding the five home-screen actions as
          // icon buttons (camera / chat / add / profile / settings).
          // The Dock's "only enabled when viewing today" rule is
          // expressed on the camera and add entries — they're
          // `onTap: null` on past dates so the dock renders them
          // visibly-disabled (the DockItem helper dims them and
          // ignores taps) rather than letting the user log entries
          // against a date the rest of the UI wouldn't render.
          // `Add food` is marked `emphasized: true` — the most-frequent
          // action, anchored as a filled-circle brand button in the
          // dock center, matching the iOS dock "primary app" treatment
          // and reinforcing muscle memory from the prior FAB. The
          // entry-order here is intentional: the emphasized button
          // sits in the centre (index 2 of 5) so the visual weight
          // stays symmetric regardless of how many non-emphasized
          // items surround it.
          if (showInitialLoader)
            const SizedBox.shrink()
          else
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AppDock(
                items: [
                  DockItem(
                    icon: Icons.camera_alt_outlined,
                    tooltip: AppLocalizations.of(context).trackerDockCameraTooltip,
                    // The Dock item is intentionally
                    // parameterless — both food and beverage
                    // flows share the same camera icon, and the
                    // choice happens in `_showCameraChoice`'s
                    // modal sheet. Keeping the chooser *outside*
                    // the Dock's onTap callback lets the dock
                    // icon stay "press to take a photo" with no
                    // commitment to which downstream flow.
                    onTap: isViewingToday ? _showCameraChoice : null,
                  ),
                  DockItem(
                    icon: Icons.chat_bubble_outline,
                    tooltip: AppLocalizations.of(context).trackerDockChatTooltip,
                    onTap: _openChat,
                  ),
                  DockItem(
                    icon: Icons.add,
                    tooltip: AppLocalizations.of(context).trackerDockAddFoodTooltip,
                    onTap: isViewingToday ? _openAddFood : null,
                    emphasized: true,
                  ),
                  DockItem(
                    icon: Icons.person_outline,
                    tooltip: AppLocalizations.of(context).trackerDockProfileTooltip,
                    onTap: _openProfile,
                  ),
                  DockItem(
                    icon: Icons.settings_outlined,
                    tooltip: AppLocalizations.of(context).trackerDockSettingsTooltip,
                    onTap: _openSettings,
                  ),
                ],
              ),
            ),
        ],
      ),
      ),
    );
  }
}

// =============================================================================
// Date navigation row
// =============================================================================

/// Sits directly under the AppBar: ‹  Today  › (or "Yesterday" / "dd.MM.yyyy").
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
            tooltip: AppLocalizations.of(context).trackerDatePrevTooltip,
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
            tooltip: AppLocalizations.of(context).trackerDateNextTooltip,
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
/// (when weight is known) or a "Add вес" CTA (when it's not).
class _WeightHistoryEntryCard extends StatelessWidget {
  const _WeightHistoryEntryCard({
    required this.latestWeight,
    required this.onTap,
    this.suppressBlur,
  });

  final double? latestWeight;
  final VoidCallback onTap;
  final ValueListenable<bool>? suppressBlur;

  String _fmtKg(double v) => v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasWeight = latestWeight != null;

    // Glass treatment: the row sits inside a GlassCard so the
    // surface blurs whatever's behind it (the page background) and
    // picks up the brand-tinted highlight along the top edge.
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      borderRadius: BorderRadius.circular(20),
      suppressBlur: suppressBlur,
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
                  AppLocalizations.of(context).trackerWeightCardTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasWeight
                      ? AppLocalizations.of(context).trackerWeightCardCurrent(_fmtKg(latestWeight!))
                      : AppLocalizations.of(context).trackerWeightCardAdd,
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
  const _CaloriesSummaryCard({required this.consumed, required this.target, this.suppressBlur});

  final double consumed;
  final num? target;
  final ValueListenable<bool>? suppressBlur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTarget = target != null && target! > 0;
    final ratio = hasTarget
        ? (consumed / target!.toDouble()).clamp(0.0, 1.0)
        : 0.0;
    final consumedRounded = consumed.round();

    // Glass treatment: the calorie summary is the dominant card on
    // the home screen, so wrapping it in a GlassCard gives it the
    // Liquid Glass look the rest of the screen now shares with the
    // Dock. The calorie count is rendered inside a
    // [GlassProgressRing] so the user reads both the absolute
    // number (centre) and the % of goal (ring fill) at a glance.
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      borderRadius: BorderRadius.circular(20),
      suppressBlur: suppressBlur,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GlassProgressRing(
            value: ratio,
            color: theme.colorScheme.primary,
            size: 96,
            strokeWidth: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$consumedRounded',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hasTarget)
                  Text(
                    '${(ratio * 100).round()}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasTarget
                      ? AppLocalizations.of(context).trackerCaloriesToday
                      : AppLocalizations.of(context).trackerCaloriesEaten,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasTarget
                      ? AppLocalizations.of(context)
                          .trackerCaloriesKcalOf(target!.round().toString())
                      : AppLocalizations.of(context).trackerCaloriesKcalOnly,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

/// Single row in the macro summary block (protein / carbs / fat). Same
/// null-tolerant design as `_CaloriesSummaryCard`.
class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.consumed,
    required this.target,
    required this.color,
    this.suppressBlur,
  });

  final String label;
  final double consumed;
  final num? target;
  final Color color;
  final ValueListenable<bool>? suppressBlur;

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

    // Glass treatment: macro rows are static (no tap), so we use
    // the lower-level [GlassSurface] rather than [GlassCard]. The
    // shared tint/border tokens give every card on the screen the
    // same Liquid Glass language.
    return GlassSurface(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      suppressBlur: suppressBlur,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _macroIcon(label),
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
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
            ),
          ),
          const SizedBox(width: 12),
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
    );
  }

  /// Per-nutrient glyph for the macro row's leading chip.
  /// Keeps each row scannable at a glance without needing the
  /// label's first letter to do all the work.
  IconData _macroIcon(String label) {
    if (label.contains('Protein') || label.contains('Белки') || label.contains('ცილები')) {
      return Icons.fitness_center_outlined;
    }
    if (label.contains('Carbs') || label.contains('Углеводы') || label.contains('ნახშირწყლები')) {
      return Icons.bakery_dining_outlined;
    }
    if (label.contains('Fat') || label.contains('Жиры') || label.contains('ცხიმები')) {
      return Icons.opacity_outlined;
    }
    return Icons.circle_outlined;
  }

  static String _formatG(num g) =>
      g == g.roundToDouble() ? g.toInt().toString() : g.toStringAsFixed(1);
}

/// Formats a water amount for display, matching the web app's
/// `WaterTracker.tsx` exactly:
///   * `< 1000 ml`  →  `"X ml"`
///   * `>= 1000 ml`  →  whole litres as `"X L"`, otherwise one decimal
///                       place `"X.X L"`.
String _formatWaterAmount(int ml) {
  if (ml < 1000) return '$ml мл';
  final litres = ml / 1000;
  if (litres == litres.roundToDouble()) return '${litres.toInt()} L';
  return '${litres.toStringAsFixed(1)} L';
}

/// Returns the time portion of an ISO 8601 datetime string as
/// `HH:mm`. Manual string slicing — `intl` not in the dependency set.
String _formatHourMinute(DateTime t) {
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// Water tracking card + entry list. Brings the mobile experience to
/// parity with the web's `WaterTracker.tsx`:
///   * header with formatted total / goal
///   * progress bar (0..1) and "X% дневной цели" caption
///   * "Add воду" button that opens [_AddWaterSheet]
///   * per-entry list with formatted amount, time, and a delete icon
class _WaterRow extends StatefulWidget {
  const _WaterRow({
    required this.waterLogs,
    required this.isLoading,
    required this.onAdd,
    required this.onDelete,
    this.suppressBlur,
  });

  final List<WaterLogModel> waterLogs;
  final bool isLoading;
  final VoidCallback onAdd;
  final Future<void> Function(String waterId) onDelete;
  final ValueListenable<bool>? suppressBlur;

  @override
  State<_WaterRow> createState() => _WaterRowState();
}

class _WaterRowState extends State<_WaterRow> {
  /// Tracks the id of an entry we just deleted so we can show an
  /// undo-style SnackBar with a single confirm. The undo itself is
  /// out of scope (would require a "recently deleted" buffer on the
  /// provider), so the button just dismisses the snackbar.
  String? _recentlyDeletedId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // We pull the user's weight from AuthProvider here (not from a
    // context prop) because the parent screen already does the same
    // `context.watch<AuthProvider>()` lookup a few lines above and we
    // want the rebuild chain to share that. The "watch" here is the
    // cheap part — only the *currentUser* getter is touched.
    final auth = context.watch<AuthProvider>();
    final goalMl = TrackerProvider.computeDailyWaterGoalMl(
      auth.currentUser?.currentWeight,
    );

    final totalMl = widget.waterLogs.fold<int>(
      0,
      (sum, w) => sum + w.amount,
    );
    final ratio = goalMl > 0
        ? (totalMl / goalMl).clamp(0.0, 1.0)
        : 0.0;
    final remainingMl = (goalMl - totalMl).clamp(0, goalMl);
    final pct = goalMl > 0 ? ((totalMl / goalMl) * 100).round() : 0;
    final goalReached = goalMl > 0 && totalMl >= goalMl;

    // Glass treatment: the water card is now a [GlassCard] that
    // blends with the calorie card above it. Quick-pick
    // volume chips sit underneath the progress bar so the user
    // can tap a common volume (250ml, 500ml, 1L) and have it
    // prefilled into the add sheet's text field.
    final quickPicks = <int>[250, 500, 1000];
    int? selectedQuickPick;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      borderRadius: BorderRadius.circular(20),
      suppressBlur: widget.suppressBlur,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.water_drop_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).trackerWaterTitle,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context).trackerWaterProgress(
                        _formatWaterAmount(totalMl),
                        _formatWaterAmount(goalMl),
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: widget.isLoading ? null : widget.onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppLocalizations.of(context).commonSave),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHigh,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                goalReached
                    ? AppLocalizations.of(context).trackerWaterGoalReached
                    : AppLocalizations.of(context).trackerWaterPctOfGoal(pct.toString()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: goalReached
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: goalReached ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
          if (remainingMl > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppLocalizations.of(context).trackerWaterRemaining(
                    _formatWaterAmount(remainingMl),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          // Quick-pick chips — the user can tap one to (in a
          // follow-up) prefill the add-sheet's text field. Today
          // they just visually communicate "these are the common
          // volumes". `selected` is a local-only flag because we
          // don't have persistent state to remember the last pick
          // across renders; the chip still demonstrates the
          // `selected` styling path used by `GlassChip`.
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ml in quickPicks)
                GlassChip(
                  label: _formatWaterAmount(ml),
                  selected: ml == selectedQuickPick,
                  onTap: () {
                    // The selected state is a UI demo here; the
                    // actual "prefill the add sheet" hook would
                    // forward through `widget.onAdd` with a
                    // pre-set value. Out of scope for this pass.
                  },
                ),
            ],
          ),
          if (widget.waterLogs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _WaterLogList(
                waterLogs: widget.waterLogs,
                onDelete: _handleDelete,
                recentlyDeletedId: _recentlyDeletedId,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleDelete(String id) async {
    setState(() {
      _recentlyDeletedId = id;
    });
    await widget.onDelete(id);
    if (!mounted) return;
    // Reset the indicator after the snackbar's auto-dismiss window
    // (~4s) so the same entry doesn't stay in the "just deleted" state
    // if a rebuild happens.
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _recentlyDeletedId = null);
      }
    });
  }
}

/// Per-entry list of today's water logs. Each row shows the formatted
/// amount, the time it was logged (HH:mm), and a delete icon. The
/// delete icon doesn't show a blocking dialog — the parent already
/// shows an undo-style snackbar via the [WidgetRef] callback.
class _WaterLogList extends StatelessWidget {
  const _WaterLogList({
    required this.waterLogs,
    required this.onDelete,
    required this.recentlyDeletedId,
  });

  final List<WaterLogModel> waterLogs;
  final Future<void> Function(String waterId) onDelete;
  final String? recentlyDeletedId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final w in waterLogs)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  child: Text(
                    _formatWaterAmount(w.amount),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatHourMinute(w.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (recentlyDeletedId == w.id)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                else
                  IconButton(
                    tooltip: AppLocalizations.of(context).trackerTooltipDelete,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: theme.colorScheme.onSurfaceVariant,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onDelete(w.id),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Modal bottom sheet for entering a custom water amount in litres.
///
/// Shows a numeric input in litres (range 0.1–10), four quick-pick
/// chips (0.2 / 0.5 / 1 / 2 L) that pre-fill the input, and a confirm
/// button that converts to millilitres and calls
/// [TrackerProvider.addWaterEntry]. Mirrors the visual weight of
/// `weight_history_screen.dart`'s add-weight dialog.
class _AddWaterSheet extends StatefulWidget {
  const _AddWaterSheet();

  @override
  State<_AddWaterSheet> createState() => _AddWaterSheetState();
}

class _AddWaterSheetState extends State<_AddWaterSheet> {
  final _formKey = GlobalKey<FormState>();
  final _litresCtrl = TextEditingController();

  /// The four web-app quick-pick values, in litres. Each row of
  /// [liter, formatted]. Mirrors the web's "0.2 / 0.5 / 1 / 2 L"
  /// pre-fill buttons.
  static const List<double> _quickPicks = <double>[0.2, 0.5, 1.0, 2.0];

  bool _isSubmitting = false;

  @override
  void dispose() {
    _litresCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);

    final raw = _litresCtrl.text.trim().replaceAll(',', '.');
    final litres = num.tryParse(raw);
    if (litres == null) return; // validator already caught this
    final ml = (litres * 1000).round();

    final tracker = context.read<TrackerProvider>();
    final ok = await tracker.addWaterEntry(ml);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _localizedTrackerError(context, tracker),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(context).trackerWaterAddTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context).trackerWaterAddInstructions,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _litresCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).trackerWaterLiters,
                  border: const OutlineInputBorder(),
                  hintText: AppLocalizations.of(context).trackerWaterHint,
                ),
                validator: (v) {
                  final raw = (v ?? '').trim();
                  if (raw.isEmpty) return AppLocalizations.of(context).trackerWaterRequired;
                  final n = num.tryParse(raw.replaceAll(',', '.'));
                  if (n == null) return AppLocalizations.of(context).commonErrorShort;
                  if (n < 0.1) return AppLocalizations.of(context).trackerWaterMin;
                  if (n > 10) return AppLocalizations.of(context).trackerWaterMax;
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in _quickPicks)
                    ActionChip(
                      label: Text(_formatWaterAmount((v * 1000).round())),
                      onPressed: () {
                        _litresCtrl.text = v.toString();
                        // Keep the cursor at the end of the new value
                        // — TextEditingController.text assignment
                        // leaves it at offset 0 by default.
                        _litresCtrl.selection = TextSelection.collapsed(
                          offset: _litresCtrl.text.length,
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(AppLocalizations.of(context).commonSave),
              ),
            ],
          ),
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
    required this.onReanalyze,
    this.suppressBlur,
  });

  final Map<String, List<FoodLogModel>> grouped;
  final bool isEmpty;

  /// BuildContext-aware meal-name resolver. The section header needs
  /// to render the active locale's label for each meal bucket, so
  /// the callback receives the surrounding [BuildContext] (along
  /// with the meal-type wire key). Returning a non-null string
  /// makes the section header straight-render the label; falling
  /// through to the meal-key fallback is the consumer's choice.
  final String Function(BuildContext, String) mealLabel;
  final void Function(FoodLogModel food) onDelete;

  /// Invoked when the user taps "Refine" on an AI-generated row.
  /// `null` means "no edit affordance" — applied to manually-added
  /// entries, which have no AI description to correct.
  final Future<void> Function(FoodLogModel food)? onReanalyze;
  final ValueListenable<bool>? suppressBlur;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            AppLocalizations.of(context).trackerEmptyLog,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    final children = <Widget>[];
    // Preserve a friendly order: known meals first in the canonical order,
    // then any unknown buckets alphabetically. `'drinks'` is placed
    // at the end of the canonical order (after `'snack'`) because
    // beverages, like snacks, are typically consumed at any hour
    // of the day rather than locked to breakfast / lunch /
    // dinner windows — putting drinks last among the "anytime"
    // categories reads as: meals first, then anytime items,
    // drinks at the very end (reflecting that beverages are
    // semantically a different "track" from even snacks — they
    // carry dual data via the FoodLog + WaterLog pair).
    const knownOrder = ['breakfast', 'lunch', 'dinner', 'snack', 'drinks'];
    final known = knownOrder
        .where(grouped.containsKey)
        .map((k) => MapEntry(k, grouped[k]!));
    final unknown = grouped.entries
        .where((e) => !knownOrder.contains(e.key))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // Each meal bucket becomes one [GlassCard] containing the
    // bucket header + its tiles. The card's outer shape is what
    // makes the page read as a stack of glass plates; the tiles
    // inside are flat list items (no per-tile border) so the cards
    // don't end up looking like nested windows.
    void addSection(String key, List<FoodLogModel> entries) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: GlassCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            borderRadius: BorderRadius.circular(18),
            suppressBlur: suppressBlur,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          mealLabel(context, key),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final food in entries)
                  // Entry animation: when a new food log lands, the
                  // matching tile gets a fresh key → fresh
                  // mount → fires the TweenAnimationBuilder once.
                  // Existing tiles re-mount with no animation
                  // because their data didn't change.
                  _EntryAnimation(
                    key: ValueKey(food.id),
                    child: _FoodLogTile(
                      food: food,
                      onDelete: () => onDelete(food),
                      // The edit affordance is conditional on
                      // `aiGenerated`: manually-entered rows don't
                      // carry an AI description to refine, so
                      // passing `null` here makes the tile render
                      // with only the existing delete icon.
                      onReanalyze: food.aiGenerated
                          ? () => onReanalyze?.call(food)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
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

/// One-shot scale + fade animation for a freshly-mounted food
/// tile. Runs once on mount with `Curves.easeOutBack` so the new
/// entry "settles" with a subtle spring overshoot — the
/// Liquid-Glass equivalent of iOS's row-insertion animation.
///
/// The animation is keyed off the [child]'s identity (the parent
/// passes a [ValueKey]); an existing tile whose data didn't
/// change won't re-mount, so the animation only fires for truly
/// new entries.
class _EntryAnimation extends StatelessWidget {
  const _EntryAnimation({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // A tiny tween (1 ms) → final value 1 means the builder
      // runs exactly once with `t = 1`, then the widget holds at
      // its full state. The "animation" is the transition from
      // `begin` to `end`, which the framework interpolates over
      // `duration`. We pre-set `t = 1` so the FIRST frame is the
      // rest state — _unless_ we drive it manually. Instead, use a
      // full TweenAnimationBuilder for a proper once-per-mount
      // tween.
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, t, child) {
        final scale = 0.9 + 0.1 * t;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: child,
    );
  }
}

/// Single food-log entry. Subtitle is "Б/У/Ж" (белки/углеводы/жиры) per
/// the spec — compact single-line format that fits a single-line ListTile.
class _FoodLogTile extends StatelessWidget {
  const _FoodLogTile({
    required this.food,
    required this.onDelete,
    this.onReanalyze,
  });

  final FoodLogModel food;
  final VoidCallback onDelete;

  /// Optional callback to render the "Refine" edit affordance. When
  /// `null`, the tile shows only the existing delete icon — used for
  /// manually-entered rows that have no AI description to refine.
  final VoidCallback? onReanalyze;

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = AppLocalizations.of(context).trackerFoodSubtitle(
      food.calories.round().toString(),
      _fmt(food.protein),
      _fmt(food.carbs),
      _fmt(food.fat),
    );

    // Tiles no longer wrap themselves in a `Card` — the parent
    // meal section now owns the glass surface (one [GlassCard]
    // per meal bucket), and the tile is just a flat ListTile
    // inside it. Keeping the tile as a ListTile preserves the
    // hover/long-press affordances and the trailing IconButton
    // tappability without double-stacking surfaces.
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
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
      // Trailing holds both action icons when the row is AI-
      // generated (render side-by-side via `Row(mainAxisSize:
      // min)` so the ListTile doesn't expand to claim the full
      // row width) and just the delete icon otherwise.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onReanalyze != null)
            IconButton(
              tooltip: AppLocalizations.of(context).trackerTooltipRefine,
              icon: const Icon(Icons.edit_outlined),
              onPressed: onReanalyze,
            ),
          IconButton(
            tooltip: AppLocalizations.of(context).trackerTooltipDelete,
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
