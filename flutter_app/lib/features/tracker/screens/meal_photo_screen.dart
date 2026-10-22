import '../../../shared/widgets/photo_preview.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../l10n/gen/app_localizations.dart';

import '../widgets/meal_scan_overlay.dart';
import '../models/saved_meal_model.dart';
import '../widgets/meal_ingredient_dialog.dart';
import '../models/meal_analysis_result.dart';
import '../providers/food_recognition_provider.dart';
import '../providers/tracker_api.dart';
import '../providers/tracker_provider.dart';

import '../../../widgets/glass/glass_card.dart';
import '../../../widgets/glass/glass_chip.dart';
import '../../../widgets/glass/glass_progress_ring.dart';
import '../../../widgets/glass/glass_scale_pulse_badge.dart';
import '../../../theme/glass_tokens.dart';

/// Screen for logging a multi-item meal from a single photo.
///
/// Single responsibility: drive the camera/gallery picker, hand the
/// chosen image off to [FoodRecognitionProvider.analyzeMealPhoto] for
/// the no-save multi-item estimate, then on success let the user
/// review/edit ingredients, then save the entire dish with one request.
///
/// State precedence (driven by the provider's observable state, not
/// local flags):
///
///   * picker (no picked image, no result)        — show CTA buttons.
///   * scanning (picked image + isAnalyzing)      — stable photo card
///     with a soft scan-sweep animation.
///   * focus (result just landed)                — animate the photo
///     pan+zoom toward the detected plate box.
///   * reveal (focus done, totals + items animating in) —
///     count-up totals, staggered item list, edit affordances.
///   * saved (after the user taps "Save meal")   — pop(true).
///   * error (any non-success terminal state)    — friendly retry.
///
/// The 3-phase sequence (scanning → focus → reveal) drives the
/// animation timing. All animations respect
/// `MediaQuery.disableAnimations` — the screen snaps to its end
/// state instead of tweening.
class MealPhotoScreen extends StatefulWidget {
  /// Which meal slot the accepted items will be filed under.
  final String mealType;

  final SavedMealModel? initialMeal;
  final SavedMealModel? pendingMeal;

  const MealPhotoScreen({
    super.key,
    required this.mealType,
    this.initialMeal,
    this.pendingMeal,
  });

  @override
  State<MealPhotoScreen> createState() => _MealPhotoScreenState();
}

class _MealPhotoScreenState extends State<MealPhotoScreen>
    with TickerProviderStateMixin {
  /// Local handle to the most recently picked image. Drives the
  /// full-bleed photo behind the scanning/focus overlays. Reset
  /// when the user retries or leaves the screen.
  File? _pickedFile;

  final ImagePicker _picker = ImagePicker();
  final _mealName = TextEditingController();
  late final String _mealId;
  late String _mealType;
  DateTime? _mealDate;
  MealAnalysisResult? _initialResult;
  SavedMealModel? _pendingSave;

  // Independent scan, focus and result-reveal timelines.
  late final AnimationController _scanController;
  late final AnimationController _focusController;
  late final AnimationController _revealController;

  /// Working copy of the result, one per accepted item. The user
  /// can edit grams (sliding stepper) and remove items (× on each
  /// chip). Edits are kept locally — the provider is not re-poked
  /// until "Save meal" is tapped.
  ///
  /// `null` until the first result arrives; afterwards, edits are
  /// made by mutating entries in this list and calling setState.
  List<_EditableItem>? _editableItems;

  /// Tracks which item (if any) is in the expanded "edit portion"
  /// view. Exactly one item can be expanded at a time so the
  /// expanded glass card doesn't compete for vertical space with
  /// its siblings. `null` means "everything is in chip form".
  String? _expandedItemId;

  /// `true` while the atomic meal save is in flight. Used to swap
  /// the save button to a spinner while the day's log is being
  /// updated.
  bool _isSaving = false;

  /// Token incremented on every grams-edit so the chip's
  /// [GlassScalePulseBadge] re-keys and the badge pulses.
  int _recalcToken = 0;

  @override
  void initState() {
    super.initState();
    _mealId = widget.pendingMeal?.id ?? newMealId();
    _pendingSave = widget.pendingMeal;
    final initial = widget.pendingMeal ?? widget.initialMeal;
    _mealDate = widget.pendingMeal?.date;
    _mealType = initial?.mealType ?? widget.mealType;
    if (initial != null) {
      _mealName.text = initial.name;
      _initialResult = initial.toAnalysis();
    }
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4400),
    );

    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mealDate ??= context.read<TrackerProvider>().selectedDate;
    if (_mealName.text.isEmpty) {
      _mealName.text = AppLocalizations.of(context).mealDefaultName;
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final analyzing = context.read<FoodRecognitionProvider>().isAnalyzing;
    if (reduceMotion) {
      _scanController.stop();
      if (_editableItems != null) {
        _focusController.value = 1;
        _revealController.value = 1;
      }
    } else if (analyzing && !_scanController.isAnimating) {
      _scanController.repeat();
    }
  }

  @override
  void dispose() {
    // Defensive: clear any pending result/error so a stale result
    // doesn't bleed into a future invocation. Best-effort — the
    // provider may already be torn down by the time we reach this.
    try {
      context.read<FoodRecognitionProvider>().resetMealAnalysis();
    } catch (_) {
      // Provider may already be torn down; swallow.
    }
    _mealName.dispose();
    _scanController.dispose();
    _focusController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  // ---- picker actions -------------------------------------------------------

  Future<void> _pick(ImageSource source) async {
    // System pickers (camera / photo library) can throw in a handful
    // of ways — no camera hardware, revoked permissions, intent
    // cancelled mid-flow. We want the screen to survive this and
    // tell the user *in their language* what went wrong instead of
    // letting the exception bubble up and crash the screen.
    final XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
    } catch (_) {
      if (!mounted) return;
      _showPickerError(source);
      return;
    }

    // Cancellation — the picker returned null. Stay quietly on the
    // picker screen (don't pop).
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    // Each new image starts a fresh sweep; reduced motion stays static.
    _scanController.value = 0;
    if (!MediaQuery.of(context).disableAnimations) {
      _scanController.repeat();
    }
    setState(() {
      _pickedFile = file;
      // Reset the editing state — the new analysis hasn't arrived
      // yet, so the previous result (if any) is now stale.
      _editableItems = null;
      _expandedItemId = null;
    });

    // Kick the analysis off immediately. The watcher above will
    // switch the body to the scanning overlay on the next frame.
    try {
      await context.read<FoodRecognitionProvider>().analyzeMealPhoto(
        imageFile: file,
        mealType: widget.mealType,
        trackerProvider: context.read<TrackerProvider>(),
      );
    } finally {
      if (mounted) _scanController.stop();
    }
  }

  void _showPickerError(ImageSource source) {
    final hint = source == ImageSource.camera
        ? AppLocalizations.of(context).profileCameraError
        : AppLocalizations.of(context).profileGalleryError;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(hint), behavior: SnackBarBehavior.floating),
      );
  }

  // ---- editing --------------------------------------------------------------

  /// Toggles the expanded edit card for [item]. Exactly one card open
  /// at a time (closing any prior card). The chip-to-card
  /// transition uses `AnimatedSize` + `AnimatedSwitcher` so the
  /// surrounding chips reflow without manual geometry juggling.
  void _toggleExpand(String itemId) {
    setState(() {
      _expandedItemId = _expandedItemId == itemId ? null : itemId;
    });
  }

  /// Removes the item whose id is [itemId] from the editable list
  /// (and closes its edit card if open). All in-memory — the
  /// provider is not re-poked; the result's server-side has already
  /// been discarded by the no-save endpoint.
  void _removeItem(String itemId) {
    setState(() {
      _editableItems?.removeWhere((e) => e.id == itemId);
      if (_expandedItemId == itemId) _expandedItemId = null;
    });
  }

  /// Recomputes the per-item totals after a grams edit, using
  /// [MacroTotals.scale] from the data layer (factor = newGrams /
  /// 100 against the per-100g reference). Also bumps
  /// [_recalcToken] so the chip's pulse-badge animation re-fires
  /// on every edit.
  void _updateGrams(String itemId, double newGrams) {
    final items = _editableItems;
    if (items == null) return;
    final idx = items.indexWhere((e) => e.id == itemId);
    if (idx < 0) return;

    final old = items[idx];
    if (old.grams == newGrams) return;

    setState(() {
      items[idx] = old.copyWith(
        grams: newGrams,
        // The per-100g reference doesn't have a `scale` helper
        // (the data layer exposes one on MacroTotals only) — we
        // multiply per macro inline. `factor = newGrams / 100`
        // maps the per-100g reference to the new portion.
        totals: MacroTotals(
          kcal: old.per100g.kcal * newGrams / 100.0,
          protein: old.per100g.protein * newGrams / 100.0,
          carbs: old.per100g.carbs * newGrams / 100.0,
          fat: old.per100g.fat * newGrams / 100.0,
        ),
        // Update `lastBaseline` to the new value so the next edit's
        // range is centred on what the user just committed to,
        // rather than compounding across edits.
        lastBaseline: newGrams,
      );
      _recalcToken++;
    });
  }

  /// Live roll-up of every editable item's totals. Re-derived on
  /// every setState so the totals card stays in sync with the
  /// chip-list edits without a separate cache.
  MacroTotals _rolledUpTotals() {
    final items = _editableItems ?? const <_EditableItem>[];
    double k = 0, p = 0, c = 0, f = 0;
    for (final e in items) {
      k += e.totals.kcal;
      p += e.totals.protein;
      c += e.totals.carbs;
      f += e.totals.fat;
    }
    return MacroTotals(kcal: k, protein: p, carbs: c, fat: f);
  }

  // ---- save -----------------------------------------------------------------

  Future<void> _editIngredient(String? id) async {
    if (_isSaving || _pendingSave != null) return;
    final old = id == null
        ? null
        : _editableItems!.firstWhere((v) => v.id == id);
    final ingredient = await showDialog<MealIngredient>(
      context: context,
      builder: (_) => MealIngredientDialog(
        ingredient: old == null
            ? null
            : MealIngredient(
                name: old.name,
                grams: old.grams,
                calories: old.totals.kcal,
                protein: old.totals.protein,
                carbs: old.totals.carbs,
                fat: old.totals.fat,
              ),
      ),
    );
    if (ingredient == null || !mounted) return;
    setState(() {
      final updated = _EditableItem.fromAnalyzed(
        ingredient.toAnalyzed(id ?? newMealId()),
      );
      if (id == null) {
        _editableItems!.add(updated);
      } else {
        _editableItems![_editableItems!.indexWhere((v) => v.id == id)] =
            updated;
      }
      _recalcToken++;
    });
  }

  Future<void> _saveAll() async {
    final items = _editableItems;
    if (_isSaving || items == null || items.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    if (_mealName.text.trim().isEmpty ||
        items.length > 100 ||
        items.any(
          (item) =>
              item.name.trim().isEmpty ||
              item.grams <= 0 ||
              [
                item.grams,
                item.totals.kcal,
                item.totals.protein,
                item.totals.carbs,
                item.totals.fat,
              ].any((value) => !value.isFinite || value < 0 || value > 100000),
        )) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.mealInvalidValue)));
      return;
    }
    // A retry uses precisely the same snapshot and operation ID, even if the
    // response was lost after the server committed the entire meal.
    _pendingSave ??= SavedMealModel(
      id: _mealId,
      name: _mealName.text.trim(),
      mealType: _mealType,
      date: _mealDate!,
      ingredients: [
        for (final item in items)
          MealIngredient(
            name: item.name,
            grams: item.grams,
            calories: item.totals.kcal,
            protein: item.totals.protein,
            carbs: item.totals.carbs,
            fat: item.totals.fat,
          ),
      ],
    );
    setState(() => _isSaving = true);
    final tracker = context.read<TrackerProvider>();
    final account = tracker.recoveryAccountKey;
    try {
      await tracker.persistMealDraft(_pendingSave!);
      final saved = await TrackerApi().saveMeal(_pendingSave!);
      if (tracker.recoveryAccountKey != account) return;
      await tracker.acceptCommittedMeal(saved);
      await tracker.clearMealDraft(_pendingSave!.id);
      if (tracker.recoveryAccountKey != account) return;
      if (!mounted) return;
      context.read<FoodRecognitionProvider>().resetMealAnalysis();
      Navigator.of(context).pop(true);
    } on UnresolvedMealDraft {
      if (!mounted) return;
      setState(() => _pendingSave = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.diaryFinishPreviousMeal)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.mealSaveRetry),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Resets the provider + picked-file state so the user can
  /// re-shoot or pick a different photo without leaving the
  /// screen. Backs to the picker CTA.
  void _retry() {
    context.read<FoodRecognitionProvider>().resetMealAnalysis();
    _focusController.reset();
    _revealController.reset();
    setState(() {
      _pickedFile = null;
      _editableItems = null;
      _expandedItemId = null;
    });
  }

  // ---- phase transitions ----------------------------------------------------

  /// Fires when a result lands in the provider. Seeds
  /// [_editableItems] from the result's `items`, runs the focus
  /// animation, then the reveal animation in sequence.
  void _onResultArrived(MealAnalysisResult result) {
    if (_editableItems != null) return; // Already populated; ignore re-runs.
    // `setState` here is essential: this method is called from a
    // post-frame callback, and without the explicit dirty-marking
    // the framework won't schedule another rebuild — so the user
    // would be stuck on the picker view that the previous build
    // fell through to while `_editableItems` was still null.
    setState(() {
      _editableItems = result.items
          .map((i) => _EditableItem.fromAnalyzed(i))
          .toList(growable: true);
    });

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      // Skip directly to the reveal final state — no focus pan
      // (the photo stays where it was), no count-up (totals show
      // at their final value).
      _scanController.stop();
      _focusController.value = 1.0;
      _revealController.value = 1.0;
      return;
    }

    _scanController.stop();
    _focusController.forward(from: 0).then((_) {
      if (!mounted) return;
      // Phase 3: reveal (count-up + staggered items).
      _revealController.forward(from: 0);
    });
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final recognition = context.watch<FoodRecognitionProvider>();
    final theme = Theme.of(context);

    // Seed editable items on result land (sibling of the
    // post-frame initState hook so re-builds during navigation
    // don't miss the transition).
    final result = _initialResult ?? recognition.lastMealAnalysis;
    if (result != null && _editableItems == null && !recognition.isAnalyzing) {
      // Mark seed as needed; the actual assignment happens in
      // `_onResultArrived` to keep build pure.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _onResultArrived(result);
      });
    }

    // State precedence: scanning > no-food > result >
    // error > picker.
    final Widget body;
    final hasResult = result != null && !recognition.isAnalyzing;
    final hasError =
        !recognition.isAnalyzing && recognition.errorMessage != null;
    final noFoodDetected =
        hasResult && result.noFoodDetected && result.items.isEmpty;

    // Retain the photo while the result is seeded after this frame.
    if (_pickedFile != null &&
        (recognition.isAnalyzing || (hasResult && _editableItems == null))) {
      body = _ScanningView(
        image: _pickedFile!,
        scanController: _scanController,
      );
    } else if (noFoodDetected) {
      body = _NoFoodView(onRetry: _retry);
    } else if (hasResult && _editableItems != null) {
      body = _ResultsView(
        image: _pickedFile,
        result: result,
        editableItems: _editableItems!,
        showConfidence:
            widget.initialMeal == null && widget.pendingMeal == null,
        expandedItemId: _expandedItemId,
        recalcToken: _recalcToken,
        revealController: _revealController,
        focusController: _focusController,
        // Frozen scan-controller value at handoff — the focusing
        // image's light overlay paints against this static wave
        // position while the light fades out.
        waveT: _scanController.value,
        rolledUpTotals: _rolledUpTotals(),
        onToggleExpand: _toggleExpand,
        onRemoveItem: _removeItem,
        onUpdateGrams: _updateGrams,
        onEditItem: (id) => _editIngredient(id),
        onAddItem: () => _editIngredient(null),
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _mealName,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).mealNameLabel,
              ),
            ),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _mealType,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).trackerMealPickerTitle,
              ),
              items: [
                DropdownMenuItem(
                  value: 'breakfast',
                  child: Text(
                    AppLocalizations.of(context).trackerMealBreakfast,
                  ),
                ),
                DropdownMenuItem(
                  value: 'lunch',
                  child: Text(AppLocalizations.of(context).trackerMealLunch),
                ),
                DropdownMenuItem(
                  value: 'dinner',
                  child: Text(AppLocalizations.of(context).trackerMealDinner),
                ),
                DropdownMenuItem(
                  value: 'snack',
                  child: Text(AppLocalizations.of(context).trackerMealSnack),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _mealType = v);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    } else if (hasError) {
      body = _ErrorView(
        message: FoodRecognitionProvider.localizeError(context, recognition),
        onRetry: _retry,
      );
    } else {
      body = _PickerView(
        onCamera: () => _pick(ImageSource.camera),
        onGallery: () => _pick(ImageSource.gallery),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.initialMeal == null
              ? AppLocalizations.of(context).mealPhotoScan
              : AppLocalizations.of(context).mealRepeat,
        ),
        backgroundColor: theme.colorScheme.surface,
      ),
      // The save button lives in a persistent bottom bar so the
      // user can scroll the item list without losing access to
      // it. The picker view hides the bar (nothing to save yet).
      bottomNavigationBar: (hasResult && _editableItems != null)
          ? _SaveBar(
              isSaving: _isSaving,
              itemCount: _editableItems!.length,
              onSave: _saveAll,
              enabled: _editableItems!.isNotEmpty,
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            if (_pendingSave != null && !_isSaving)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(AppLocalizations.of(context).mealSaveRetry),
              ),
            Expanded(
              child: AbsorbPointer(
                absorbing: _isSaving || _pendingSave != null,
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// View: Picker (initial CTA state)
// =============================================================================

/// Initial state: two large buttons. Mirrors `photo_food_screen.dart`'s
/// picker view so the two photo flows feel like the same exit.
class _PickerView extends StatelessWidget {
  const _PickerView({required this.onCamera, required this.onGallery});

  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Icon(
            Icons.restaurant_menu_outlined,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.mealPhotoPickerInstructions,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.camera_alt),
              label: Text(l10n.photoFoodTakePhoto),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library),
              label: Text(l10n.photoFoodPickGallery),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// =============================================================================
// View: Scanning — stable photo, quiet light sweep, status below.
// =============================================================================

class _ScanningView extends StatelessWidget {
  const _ScanningView({required this.image, required this.scanController});

  final File image;
  final AnimationController scanController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: PhotoPreview(file: image, fit: BoxFit.cover),
                  ),
                  if (!reduceMotion) MealScanOverlay(phase: scanController),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Semantics(
            liveRegion: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    AppLocalizations.of(context).mealPhotoAnalyzing,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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

// =============================================================================
// View: Results (phase 2 + 3 — focus pan + reveal stagger)
// =============================================================================

/// Results phase: photo header (with the focus pan), totals card
/// (with count-up), item list (with staggered reveal), and the
/// expanded edit card for the currently-expanded item.
///
/// The photo keeps the scan layout, then gently settles toward the plate
/// while the scanning light fades away.
class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.image,
    required this.showConfidence,
    required this.result,
    required this.editableItems,
    required this.expandedItemId,
    required this.recalcToken,
    required this.revealController,
    required this.focusController,
    required this.waveT,
    required this.rolledUpTotals,
    required this.onToggleExpand,
    required this.onRemoveItem,
    required this.onUpdateGrams,
    required this.onEditItem,
    required this.onAddItem,
    required this.header,
  });

  final bool showConfidence;
  final Widget header;
  final ValueChanged<String> onEditItem;
  final VoidCallback onAddItem;
  final File? image;
  final MealAnalysisResult result;
  final List<_EditableItem> editableItems;
  final String? expandedItemId;

  /// Bumped on every grams edit so the chip's pulse-badge fires.
  final int recalcToken;

  final AnimationController revealController;
  final AnimationController focusController;

  /// Frozen scan-controller value captured at handoff. The focusing
  /// image's light overlay paints against this static wave position
  /// while the light fades out across the focus window.
  final double waveT;

  /// Pre-computed roll-up so the screen doesn't re-derive it on
  /// every build (the parent recomputes when grams change).
  final MacroTotals rolledUpTotals;

  final ValueChanged<String> onToggleExpand;
  final ValueChanged<String> onRemoveItem;
  final void Function(String itemId, double newGrams) onUpdateGrams;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Photo header — focus animation lives here. Rendered
          // even when image is null (unlikely in practice — the
          // scanning phase wouldn't have run).
          if (image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: _FocusingImage(
                  image: image!,
                  plateBox: result.plateBox,
                  controller: focusController,
                  waveT: waveT,
                  reduceMotion: reduceMotion,
                ),
              ),
            ),
          if (image != null) const SizedBox(height: 16),

          header,
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.mealPhotoItems(editableItems.length),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (showConfidence)
                  GlassChip(
                    label: l10n.mealPhotoEstimates,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
          ),

          // Totals card — count-up animation per macro.
          _TotalsCard(
            totals: rolledUpTotals,
            revealController: revealController,
            reduceMotion: reduceMotion,
            recalcToken: recalcToken,
          ),
          const SizedBox(height: 8),

          // Disclaimer.
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.mealPhotoDisclaimer,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Item list — staggered reveal.
          for (var i = 0; i < editableItems.length; i++)
            _AnimatedItemRow(
              index: i,
              total: editableItems.length,
              revealController: revealController,
              reduceMotion: reduceMotion,
              child: _ItemRow(
                item: editableItems[i],
                showConfidence: showConfidence,
                onEdit: () => onEditItem(editableItems[i].id),
                expanded: expandedItemId == editableItems[i].id,
                onToggleExpand: () => onToggleExpand(editableItems[i].id),
                onRemove: () => onRemoveItem(editableItems[i].id),
                onUpdateGrams: (g) => onUpdateGrams(editableItems[i].id, g),
              ),
            ),
          OutlinedButton.icon(
            onPressed: onAddItem,
            icon: const Icon(Icons.add),
            label: Text(l10n.mealAddIngredient),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Sub-view: photo header with focus pan + zoom
// =============================================================================

/// Small eased zoom with a bounded pan toward the detected plate.
class _FocusingImage extends StatelessWidget {
  const _FocusingImage({
    required this.image,
    required this.plateBox,
    required this.controller,
    required this.waveT,
    required this.reduceMotion,
  });

  final File image;
  final PlateBox? plateBox;
  final AnimationController controller;

  /// Frozen scan-controller value captured at handoff. The fading
  /// light overlay paints against this static wave position so the
  /// light fades without animating the wave itself.
  final double waveT;

  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: PhotoPreview(file: image, fit: BoxFit.cover),
      builder: (context, preview) {
        final t = reduceMotion ? 1.0 : controller.value;
        final eased = Curves.easeOutCubic.transform(t);
        final scale = reduceMotion ? 1.0 : 1.0 + 0.035 * eased;
        final plate = plateBox;
        // Pan toward the plate using local image bounds, within the
        // overscan supplied by the small zoom. No exposed image edges.
        final pan = plate == null || reduceMotion
            ? Offset.zero
            : Offset(
                    (0.5 - plate.x - plate.w / 2).clamp(-0.5, 0.5),
                    (0.5 - plate.y - plate.h / 2).clamp(-0.5, 0.5),
                  ) *
                  (scale - 1) *
                  eased;
        final overlayFade = reduceMotion ? 0.0 : 1.0 - eased;

        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) => Transform.translate(
                    offset: Offset(
                      pan.dx * constraints.maxWidth,
                      pan.dy * constraints.maxHeight,
                    ),
                    child: Transform.scale(scale: scale, child: preview),
                  ),
                ),
              ),
              if (overlayFade > 0)
                Positioned.fill(
                  child: MealScanOverlay(
                    phase: AlwaysStoppedAnimation(waveT),
                    opacity: overlayFade,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// Sub-view: totals card with count-up bars
// =============================================================================

/// Renders the meal's roll-up kcal inside a [GlassProgressRing]
/// (mirrors the home-screen calorie card's look) + three animated
/// macro bars (protein / carbs / fat) that count up from 0 to
/// their final values over [revealController]'s window.
///
/// Each macro bar uses a `TweenAnimationBuilder<double>` so the
/// fill animates independently of the reveal controller's end
/// state — that way a re-reveal (which the spec doesn't actually
/// trigger) would still count up rather than snap.
class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.totals,
    required this.revealController,
    required this.reduceMotion,
    required this.recalcToken,
  });

  final MacroTotals totals;
  final AnimationController revealController;
  final bool reduceMotion;
  final int recalcToken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final kcal = totals.kcal.round();

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      borderRadius: BorderRadius.circular(20),
      elevation: GlassElevation.hero,
      child: AnimatedBuilder(
        animation: revealController,
        builder: (context, _) {
          final t = reduceMotion ? 1.0 : revealController.value;
          // Curve the reveal so the kcal number lands first
          // (smoother settle than a straight linear ramp).
          final eased = Curves.easeOutCubic.transform(t);
          // Animated kcal display (count-up). When reduceMotion
          // is on, show the final value directly.
          final displayedKcal = reduceMotion ? kcal : (kcal * eased).round();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // No ratio to display against the daily target
                  // here — this screen doesn't know the user's
                  // daily calorie budget. Use a "ring for visual
                  // weight" with the ring value pinned at the
                  // partial fill (kcal modulo 500 / 500), so the
                  // ring isn't fully blank.
                  GlassProgressRing(
                    value: (kcal % 500) / 500.0,
                    color: scheme.primary,
                    size: 80,
                    strokeWidth: 8,
                    tipHighlightColor: scheme.onSurface,
                    child: Text(
                      '$displayedKcal',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.trackerCaloriesEaten,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$displayedKcal ${l10n.unitKcalShort}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Three count-up bars: protein / carbs / fat.
              _AnimatedBar(
                key: ValueKey('protein-$recalcToken'),
                label: l10n.addFoodProtein,
                color: const Color(0xFF3B82F6),
                target: totals.protein,
                reveal: t,
                reduceMotion: reduceMotion,
              ),
              const SizedBox(height: 6),
              _AnimatedBar(
                key: ValueKey('carbs-$recalcToken'),
                label: l10n.trackerFoodCarbs,
                color: const Color(0xFFF97316),
                target: totals.carbs,
                reveal: t,
                reduceMotion: reduceMotion,
              ),
              const SizedBox(height: 6),
              _AnimatedBar(
                key: ValueKey('fat-$recalcToken'),
                label: l10n.trackerFoodFat,
                color: const Color(0xFFA855F7),
                target: totals.fat,
                reveal: t,
                reduceMotion: reduceMotion,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Single count-up macro bar. Re-keyed by the parent via
/// `ValueKey('protein-$recalcToken')` so the tween re-keys and
/// the count-up replays on every grams edit.
class _AnimatedBar extends StatelessWidget {
  const _AnimatedBar({
    super.key,
    required this.label,
    required this.color,
    required this.target,
    required this.reveal,
    required this.reduceMotion,
  });

  final String label;
  final Color color;
  final double target;
  final double reveal;
  final bool reduceMotion;

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eased = Curves.easeOutCubic.transform(reveal);
    final displayed = reduceMotion ? target : target * eased;
    final displayedStr = _fmt(displayed);

    return TweenAnimationBuilder<double>(
      // 600 ms — fast enough that a fresh mount reads as
      // "filling up", slow enough that the fill is visible.
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: target),
      builder: (context, animated, _) {
        final ratio = target == 0 ? 0.0 : (displayed / target).clamp(0.0, 1.0);
        return Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 64,
              child: Text(
                '$displayedStr ${AppLocalizations.of(context).unitGramsShort}',
                textAlign: TextAlign.end,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Sub-view: item row (chip form + expanded edit card)
// =============================================================================

/// Single detected item — defaults to "chip" form (compact pill
/// showing name + grams + kcal), expands into a glass edit card
/// with a grams slider/stepper + remove button on tap. The
/// chip-to-card transition uses `AnimatedCrossFade` so the
/// geometry shift reads as a deliberate transition rather than
/// a glitchy swap.
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.showConfidence,
    required this.onEdit,
    required this.expanded,
    required this.onToggleExpand,
    required this.onRemove,
    required this.onUpdateGrams,
  });

  final bool showConfidence;
  final VoidCallback onEdit;
  final _EditableItem item;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onRemove;
  final void Function(double newGrams) onUpdateGrams;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final pct = (item.confidence * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 220),
        firstCurve: Curves.easeInCubic,
        secondCurve: Curves.easeOutCubic,
        crossFadeState: expanded
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        // First: chip form (compact pill, tappable).
        firstChild: _ItemChipRow(
          item: item,
          showConfidence: showConfidence,
          confidencePct: pct,
          onTap: onToggleExpand,
          onRemove: onRemove,
        ),
        // Second: expanded glass card with grams slider.
        secondChild: GlassCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          borderRadius: BorderRadius.circular(20),
          borderColorOverride: theme.colorScheme.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (showConfidence &&
                      MediaQuery.textScalerOf(context).scale(14) < 21)
                    GlassChip(
                      label: l10n.mealPhotoConfidence('$pct'),
                      color: theme.colorScheme.primary,
                    ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: l10n.mealPhotoCancel,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onToggleExpand,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${l10n.mealPhotoGramsLabel(_fmtGrams(item.grams))} • ${item.totals.kcal.round()} ${l10n.unitKcalShort}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              // Grams slider — range picked from the original
              // grams × 0.3..2.0 (a 3x window either side of the
              // estimate is generous enough for user override
              // without straying into "obviously wrong" land).
              _GramsStepper(
                grams: item.grams,
                baseline: item.lastBaseline,
                onChanged: onUpdateGrams,
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.mealEditIngredient),
                  ),
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                    ),
                    label: Text(
                      l10n.commonDelete,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtGrams(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// Slider + +/- stepper for grams editing. The slider's bounds
/// are anchored on the editable item's `lastBaseline` (not the
/// server's original estimate) so consecutive edits stay
/// relative to the user's last value, not compounding across
/// edits.
class _GramsStepper extends StatelessWidget {
  const _GramsStepper({
    required this.grams,
    required this.baseline,
    required this.onChanged,
  });

  final double grams;
  final double baseline;
  final void Function(double newGrams) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final lower = (baseline * 0.3).clamp(1.0, double.infinity);
    final upper = (baseline * 2.0).clamp(lower + 1, double.infinity);

    return Row(
      children: [
        IconButton(
          tooltip: '-',
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => onChanged((grams - 5).clamp(lower, upper)),
        ),
        Expanded(
          child: Slider(
            value: grams.clamp(lower, upper),
            min: lower,
            max: upper,
            divisions: ((upper - lower) / 5).round().clamp(1, 200),
            label: l10n.mealPhotoGramsLabel(grams.round().toString()),
            onChanged: onChanged,
          ),
        ),
        IconButton(
          tooltip: '+',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => onChanged((grams + 5).clamp(lower, upper)),
        ),
      ],
    );
  }
}

/// Compact (collapsed) chip form for an item. Shows the name +
/// grams + confidence badge. The grams label pulses via
/// [GlassScalePulseBadge] on edit (keyed off the parent's
/// `recalcToken` via a `ValueKey`).
class _ItemChipRow extends StatelessWidget {
  const _ItemChipRow({
    required this.item,
    required this.showConfidence,
    required this.confidencePct,
    required this.onTap,
    required this.onRemove,
  });

  final bool showConfidence;
  final _EditableItem item;
  final int confidencePct;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name.isEmpty
                        ? AppLocalizations.of(context).photoFoodNoName
                        : item.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.mealPhotoGramsLabel(_fmtGrams(item.grams))} • ${item.totals.kcal.round()} ${l10n.unitKcalShort}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (showConfidence &&
                MediaQuery.textScalerOf(context).scale(14) < 21)
              GlassScalePulseBadge(
                label: l10n.mealPhotoConfidence('$confidencePct'),
                color: theme.colorScheme.primary,
              ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: l10n.commonDelete,
              icon: const Icon(Icons.close, size: 18),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtGrams(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

// =============================================================================
// Sub-view: staggered item reveal
// =============================================================================

/// Wraps a single item row in a fade+scale "stagger reveal". The
/// reveal delay is `index / total * 0.4` of the controller's
/// window — so the first item lands early, the last item lands
/// ~400 ms later.
class _AnimatedItemRow extends StatelessWidget {
  const _AnimatedItemRow({
    required this.index,
    required this.total,
    required this.revealController,
    required this.reduceMotion,
    required this.child,
  });

  final int index;
  final int total;
  final AnimationController revealController;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: revealController,
      builder: (context, _) {
        if (reduceMotion) return child;
        // Stagger window: 0..1 of the controller value mapped
        // through `delay..1` where delay = index / total × 0.4.
        final delay = total > 1 ? (index / (total - 1)) * 0.4 : 0.0;
        final t = ((revealController.value - delay) / (1.0 - delay)).clamp(
          0.0,
          1.0,
        );
        final eased = Curves.easeOutCubic.transform(t);
        final scale = 0.94 + 0.06 * eased;
        final opacity = eased;
        return Opacity(
          opacity: opacity,
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}

// =============================================================================
// View: No-food empty state
// =============================================================================

/// Friendly "no food detected" state with a retry button. Same
/// visual treatment as the analyze-error state for consistency.
class _NoFoodView extends StatelessWidget {
  const _NoFoodView({required this.onRetry});

  final VoidCallback onRetry;

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
              Icons.no_food_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).mealPhotoNoFood,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context).commonTryAgain),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// View: Error state
// =============================================================================

/// Standard retry-friendly error state. Mirrors the single-item
/// photo flow's `_ErrorView` for visual consistency.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context).commonTryAgain),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Sub-view: persistent save bar
// =============================================================================

/// Sticky-bottom "Save meal" button. Shown only when the result
/// is ready and there's at least one item to save. Disables
/// itself while a save round-trip is in flight.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.isSaving,
    required this.itemCount,
    required this.onSave,
    required this.enabled,
  });

  final bool isSaving;
  final int itemCount;
  final VoidCallback onSave;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (!enabled || isSaving) ? null : onSave,
            icon: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(
              isSaving
                  ? AppLocalizations.of(context).mealSaving
                  : AppLocalizations.of(context).mealPhotoSave,
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Helper: editable item (working copy with grams/totals overrides)
// =============================================================================

/// Local working copy of an [AnalyzedItem]. The screen edits the
/// grams (and rebuilds per-100g totals from `MacroTotals.scale`),
/// but the original `per100g` / `point` / `confidence` / `name`
/// values stay frozen.
class _EditableItem {
  final String id;
  final String name;
  final double grams;
  final MacroMacros per100g;
  final MacroTotals totals;
  final double confidence;
  final AnalyzedPoint point;

  /// Most recent grams the user committed to. Used as the slider
  /// range anchor (so consecutive edits stay relative to the
  /// user's last value, not the server's original). Defaults to
  /// the server's grams.
  final double lastBaseline;

  const _EditableItem({
    required this.id,
    required this.name,
    required this.grams,
    required this.per100g,
    required this.totals,
    required this.confidence,
    required this.point,
    required this.lastBaseline,
  });

  factory _EditableItem.fromAnalyzed(AnalyzedItem src) {
    return _EditableItem(
      id: src.id,
      name: src.name,
      grams: src.grams,
      per100g: src.per100g,
      totals: src.totals,
      confidence: src.confidence,
      point: src.point,
      lastBaseline: src.grams,
    );
  }

  _EditableItem copyWith({
    String? id,
    String? name,
    double? grams,
    MacroMacros? per100g,
    MacroTotals? totals,
    double? confidence,
    AnalyzedPoint? point,
    double? lastBaseline,
  }) {
    return _EditableItem(
      id: id ?? this.id,
      name: name ?? this.name,
      grams: grams ?? this.grams,
      per100g: per100g ?? this.per100g,
      totals: totals ?? this.totals,
      confidence: confidence ?? this.confidence,
      point: point ?? this.point,
      lastBaseline: lastBaseline ?? this.lastBaseline,
    );
  }
}
