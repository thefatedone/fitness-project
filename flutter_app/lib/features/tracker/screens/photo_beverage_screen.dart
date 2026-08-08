import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/beverage_result.dart';
import '../../auth/providers/auth_api.dart';
import '../providers/beverage_api.dart';
import '../providers/beverage_provider.dart';
import '../providers/tracker_provider.dart';

/// Screen for logging a beverage from a photo via Gemini, with
/// confidence-gated auto-logging.
///
/// Single responsibility: drive the camera/gallery picker, hand
/// the chosen image off to [BeverageProvider], and render one of
/// four mutually exclusive states based on the provider's
/// observable state — picker / analyzing / result (auto-logged or
/// suggest-only) / error. Mirrors the structure of
/// `photo_food_screen.dart` but with an extra UI state for the
/// medium/low-confidence manual-confirmation form.
///
/// The big difference from the food flow: beverages don't take a
/// meal_type parameter — the server always files them under
/// "snack" (beverages happen at all hours and don't fit
/// breakfast/lunch/dinner cleanly). So this screen is
/// parameterless, and the DockItem dispatch from
/// `tracker_home_screen.dart` goes straight here without showing
/// a meal-picker bottom sheet.
class PhotoBeverageScreen extends StatefulWidget {
  const PhotoBeverageScreen({super.key});

  @override
  State<PhotoBeverageScreen> createState() => _PhotoBeverageScreenState();
}

class _PhotoBeverageScreenState extends State<PhotoBeverageScreen> {
  /// Local handle to the most recently picked image, so the
  /// analyzing overlay can show it beneath its spinner. Reset to
  /// `null` when the user retries or leaves the screen.
  File? _pickedFile;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    // Defensive: clear any pending result/error so a stale
    // confirmation from this attempt doesn't bleed into a future
    // invocation (e.g. if the home screen reuses the provider
    // for a different action). Best-effort — dispose may run
    // while the provider is being torn down.
    try {
      context.read<BeverageProvider>().reset();
    } catch (_) {
      // Provider may already be torn down; swallow.
    }
    super.dispose();
  }

  // ---- picker actions -------------------------------------------------------

  Future<void> _pick(ImageSource source) async {
    // System pickers (camera / photo library) can throw in a
    // handful of ways — no camera hardware, revoked
    // permissions, intent cancelled mid-flow, etc. We always
    // want the picker screen to survive this and tell the user
    // *in their language* what went wrong, instead of letting
    // the exception bubble up and crash the screen.
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

    // Cancellation — the picker returned null. This is normal
    // user behaviour, not an error: stay quietly on the picker
    // screen.
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    setState(() => _pickedFile = file);

    // Kick the analysis off immediately — the watcher above will
    // switch the body to the analyzing overlay on the next
    // frame.
    context.read<BeverageProvider>().analyzePhoto(
      imageFile: file,
      trackerProvider: context.read<TrackerProvider>(),
    );
  }

  void _showPickerError(ImageSource source) {
    final hint = source == ImageSource.camera
        ? 'Не удалось открыть камеру. Попробуй выбрать фото из галереи.'
        : 'Не удалось открыть галерею.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(hint),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _retry() {
    context.read<BeverageProvider>().reset();
    setState(() => _pickedFile = null);
  }

  void _done() {
    context.read<BeverageProvider>().reset();
    Navigator.of(context).pop(true);
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final beverage = context.watch<BeverageProvider>();
    final theme = Theme.of(context);

    // State precedence: result > analyzing > error > picker. The
    // order matters — once we have a successful result we render
    // *that*, even if a stale error message were ever left
    // behind. Within "result", the auto-logged card wins over
    // the manual-confirm form (which only renders when
    // `autoLogged == false`).
    final Widget body;
    if (beverage.lastResult != null && !beverage.isAnalyzing) {
      if (beverage.lastResult!.autoLogged) {
        body = _AutoLoggedView(
          result: beverage.lastResult!,
          onDone: _done,
        );
      } else {
        body = _ManualConfirmView(
          suggestion: beverage.lastResult!.suggestion!,
          imageFile: _pickedFile!,
          onSubmitted: _done,
        );
      }
    } else if (beverage.isAnalyzing && _pickedFile != null) {
      body = _AnalyzingView(image: _pickedFile!);
    } else if (beverage.errorMessage != null && !beverage.isAnalyzing) {
      body = _ErrorView(
        message: beverage.errorMessage!,
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
        title: const Text('Фото напитка'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SafeArea(child: body),
    );
  }
}

// =============================================================================
// State views
// =============================================================================

/// Initial state: two large buttons. One launches the camera,
/// one opens the gallery picker. Mirrors the food flow's picker
/// with copy adjusted for the beverage context.
class _PickerView extends StatelessWidget {
  const _PickerView({required this.onCamera, required this.onGallery});

  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Icon(
            Icons.local_drink_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Сфотографируй напиток или выбери снимок из галереи',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Сделать фото'),
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
              label: const Text('Выбрать из галереи'),
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

/// While Gemini is thinking: show the picked image with a
/// spinner and a label. Same visual treatment as the food
/// flow's analyzing view — kept identical so users get a
/// consistent "AI is working" signal across both screens.
class _AnalyzingView extends StatelessWidget {
  const _AnalyzingView({required this.image});

  final File image;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: Image.file(image, fit: BoxFit.contain),
        ),
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.55),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  'Анализируем фото...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Auto-logged branch: server already dual-wrote the
/// FoodLog + WaterLog pair. Show the committed values + a
/// "Готово" button. Mirrors the food result view's structure
/// but with five macro chips (calories / Б / У / Ж / Сахар)
/// instead of four — sugar is beverage-specific.
class _AutoLoggedView extends StatelessWidget {
  const _AutoLoggedView({required this.result, required this.onDone});

  final BeverageRecognitionResult result;
  final VoidCallback onDone;

  static const Map<String, ({String label, Color color})> _confidenceStyle = {
    'high': (label: 'Высокая точность', color: Color(0xFF22C55E)), // green
    'medium': (label: 'Средняя точность', color: Color(0xFFEAB308)), // amber
    'low': (label: 'Низкая точность', color: Color(0xFFEF4444)), // red
  };

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Widget _macroChip(
    BuildContext context,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nutrition = result.nutrition!;
    final confidence = _confidenceStyle[result.confidence ?? 'high'] ??
        _confidenceStyle['high']!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Allergy warning — ABOVE the nutrition card, matching
          // the established convention from the food flow.
          if (result.hasAllergyWarning)
            Card(
              color: const Color(0xFFFFEDD5), // amber-100
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFEA580C)), // amber-600
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          color: Color(0xFFB45309), // amber-700
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '⚠️ Возможен конфликт с аллергией',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: const Color(0xFFB45309),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...result.allergyWarnings.map(
                      (w) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  '),
                            Expanded(
                              child: Text(
                                w,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF7C2D12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (result.hasAllergyWarning) const SizedBox(height: 16),

          // Main result card.
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          nutrition.beverageName.isEmpty
                              ? 'Без названия'
                              : nutrition.beverageName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _ConfidenceChip(
                        label: confidence.label,
                        color: confidence.color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Volume line — beverages always carry a volume
                  // display so the user knows how much of what
                  // was logged.
                  Row(
                    children: [
                      Icon(
                        Icons.water_drop_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${nutrition.volumeMl.round()} мл',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Compact macro row — five chips instead of
                  // the food flow's four: Сахар is
                  // beverage-specific. The order matches the
                  // user's mental model of "calories first, then
                  // macros, then sugar last".
                  Row(
                    children: [
                      _macroChip(context, 'ккал',
                          nutrition.calories.round().toString()),
                      _macroChip(context, 'Б',
                          '${_fmt(nutrition.protein)} г'),
                      _macroChip(context, 'У',
                          '${_fmt(nutrition.carbs)} г'),
                      _macroChip(context, 'Ж',
                          '${_fmt(nutrition.fat)} г'),
                      _macroChip(context, 'Сахар',
                          '${_fmt(nutrition.sugarG)} г'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onDone,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Suggest-only branch: server returned medium/low confidence.
/// Show a manual-confirmation form PRE-FILLED with the AI's
/// suggested values. The user can edit any field, then tap
/// "Подтвердить и сохранить" to fire `confirmManual` and pop the
/// screen on success (with a brief SnackBar).
///
/// Numeric validators use the comma/dot-tolerant pattern from
/// `_AddWaterSheet` in `tracker_home_screen.dart` — accepts
/// "0,5" / "0.5" / "0,5 г" etc. The `volumeMl` validator requires
/// `> 0` (matches the backend's `gt: 0` constraint); the macro
/// validators require `>= 0` (matches `ge: 0`).
class _ManualConfirmView extends StatefulWidget {
  const _ManualConfirmView({
    required this.suggestion,
    required this.imageFile,
    required this.onSubmitted,
  });

  final BeverageNutrition suggestion;

  /// The image file under examination. Carried through from
  /// `_PhotoBeverageScreenState._pickedFile` so the manual-confirm
  /// flow can re-check the user's edited name against the
  /// still-held photo via `verifyBeverageName` without having to
  /// ask the user to re-pick. The file is only read (not
  /// mutated) by this view.
  final File imageFile;

  /// Fires once the user successfully confirms + saves. The
  /// screen pops on this signal so the caller (the dock) can
  /// react however it wants — typically just returning to the
  /// tracker home with the new rows already merged.
  final VoidCallback onSubmitted;

  @override
  State<_ManualConfirmView> createState() => _ManualConfirmViewState();
}

class _ManualConfirmViewState extends State<_ManualConfirmView> {
  /// Drives the form so the submit button can
  /// `currentState!.validate()` without re-walking the tree.
  final _formKey = GlobalKey<FormState>();

  // Owned controllers — initialised with the AI's suggested
  // values via `_populateFromSuggestion` once the form actually
  // renders for the first time. Keeping them as `late final`
  // fields (not `final` initialised in initState) lets the form
  // render in picker / analyzing state with empty controllers
  // — they're only populated after the suggest-only result
  // arrives.
  late final TextEditingController _nameCtrl = TextEditingController();
  late final TextEditingController _volumeCtrl = TextEditingController();
  late final TextEditingController _caloriesCtrl = TextEditingController();
  late final TextEditingController _proteinCtrl = TextEditingController();
  late final TextEditingController _carbsCtrl = TextEditingController();
  late final TextEditingController _fatCtrl = TextEditingController();
  late final TextEditingController _sugarCtrl = TextEditingController();

  // ---------------------------------------------------------------------------
  // Base-rate caches (volume-driven proportional recalc)
  // ---------------------------------------------------------------------------
  //
  // Captured from the suggestion on first render; used by
  // `_onVolumeChanged` to recompute each macro as
  // `baseValue * (newVolume / baseVolume)`. Anchoring on the
  // *server-returned* values (not the controllers' current
  // text) prevents float-rounding errors from compounding as
  // the user types — once the controller text deviates from the
  // previous integer-rounded display value, every subsequent
  // recompute would be slightly off the server's view of the
  // truth.
  //
  // Initialised to 0 so the listener's `_baseVolume <= 0` guard
  // short-circuits cleanly before [_populateFromSuggestion]
  // runs on the first build.
  double _baseVolume = 0;
  double _baseCalories = 0;
  double _baseProtein = 0;
  double _baseCarbs = 0;
  double _baseFat = 0;
  double _baseSugar = 0;

  // ---------------------------------------------------------------------------
  // Recalc-badge pulse state
  // ---------------------------------------------------------------------------
  //
  // `_recalcBadgeVisible` drives the badge's opacity (1.0 when
  // visible, 0.0 when not). The badge autofades via the
  // TweenAnimationBuilder in [_RecalcBadge]. `_recalcToken`
  // increments on each recompute so the badge's tween re-keys
  // and the fade-in re-plays from 0 → 1 on every volume edit.
  bool _recalcBadgeVisible = false;
  int _recalcToken = 0;
  Timer? _recalcTimer;

  /// One-shot guard so we only populate the controllers on the
  /// first render of this view (the suggestion can't change
  /// mid-confirm — if it does, the whole view would re-mount).
  bool _populated = false;

  /// `true` while a `confirmManual` round-trip is in flight.
  /// Used to swap the submit button's label to a spinner.
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Recompute macros proportionally when the user edits the
    // volume. Listening on the VOLUME controller (not the
    // macro controllers) keeps the recompute direction one-way:
    // volume → macros. Listening on the macros and emitting
    // back to volume would create a cycle when the user edits
    // any macro directly.
    _volumeCtrl.addListener(_onVolumeChanged);
  }

  void _populateFromSuggestion() {
    if (_populated) return;
    final s = widget.suggestion;
    // Capture the server's view of the values (anchor for the
    // volume-driven recompute — see the base-rate field
    // commentary above).
    _baseVolume = s.volumeMl;
    _baseCalories = s.calories;
    _baseProtein = s.protein;
    _baseCarbs = s.carbs;
    _baseFat = s.fat;
    _baseSugar = s.sugarG;

    _nameCtrl.text = s.beverageName;
    _volumeCtrl.text = _fmt(s.volumeMl);
    _caloriesCtrl.text = _fmt(s.calories);
    _proteinCtrl.text = _fmt(s.protein);
    _carbsCtrl.text = _fmt(s.carbs);
    _fatCtrl.text = _fmt(s.fat);
    _sugarCtrl.text = _fmt(s.sugarG);
    _populated = true;
  }

  @override
  void dispose() {
    _volumeCtrl.removeListener(_onVolumeChanged);
    _recalcTimer?.cancel();
    _nameCtrl.dispose();
    _volumeCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _sugarCtrl.dispose();
    super.dispose();
  }

  // ---- form validation -----------------------------------------------------

  /// Comma/dot-tolerant numeric parser shared by every macro
  /// field. Accepts "0,5" / "0.5" — the comma form is common in
  /// Russian-keyboard input where the period requires a layout
  /// switch.
  static double? _parseNumber(String raw) {
    final cleaned = raw.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return num.tryParse(cleaned)?.toDouble();
  }

  static String? _validatePositiveMl(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return 'Введи объём';
    final n = _parseNumber(raw);
    if (n == null) return 'Введи число';
    if (n <= 0) return 'Объём должен быть больше 0';
    return null;
  }

  static String? _validateNonNegative(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return null; // empty defaults to 0 on submit
    final n = _parseNumber(raw);
    if (n == null) return 'Введи число';
    if (n < 0) return 'Не может быть отрицательным';
    return null;
  }

  // ---- submit --------------------------------------------------------------

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);

    final provider = context.read<BeverageProvider>();
    final tracker = context.read<TrackerProvider>();

    // Capture the user's final values up front, since the
    // anti-mismatch step may take a while (verification round-
    // trip) and we want to commit exactly these values once we
    // clear the dialog hurdle.
    final claimedName = _nameCtrl.text.trim();
    final volumeMl = _parseNumber(_volumeCtrl.text) ?? 0;
    final calories = _parseNumber(_caloriesCtrl.text) ?? 0;
    final protein = _parseNumber(_proteinCtrl.text) ?? 0;
    final carbs = _parseNumber(_carbsCtrl.text) ?? 0;
    final fat = _parseNumber(_fatCtrl.text) ?? 0;
    final sugarG = _parseNumber(_sugarCtrl.text) ?? 0;

    // Anti-mismatch check: if the user has edited the beverage
    // name meaningfully relative to the AI's original
    // suggestion, re-ask Gemini whether the image plausibly
    // shows the claimed name. If the model says it's
    // implausible, show a dialog so the user can correct or
    // override. ApiException (any failure on the verification
    // call) is treated as inconclusive — the verification call
    // is best-effort, and a network blip should not block the
    // user's save.
    final originalName = widget.suggestion.beverageName;
    if (_namesDifferMeaningfully(claimedName, originalName)) {
      try {
        final api = BeverageApi();
        final result = await api.verifyBeverageName(
          imageFile: widget.imageFile,
          claimedName: claimedName,
        );
        final plausible = result['plausible'] == true;
        final detectedInstead = result['detected_instead'] as String?;
        if (!plausible) {
          if (!mounted) return;
          final shouldProceed = await _showMismatchDialog(
            claimedName: claimedName,
            detectedInstead: detectedInstead,
          );
          if (!shouldProceed) {
            // User chose to edit — bail out cleanly. The form is
            // preserved so they can correct the name without
            // re-entering the macros.
            if (mounted) setState(() => _submitting = false);
            return;
          }
        }
      } on ApiException {
        // Inconclusive — fall through and let the save proceed.
      } catch (_) {
        // Any other error — also inconclusive.
      }
    }

    final result = await provider.confirmManual(
      beverageName: claimedName,
      volumeMl: volumeMl,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      sugarG: sugarG,
      trackerProvider: tracker,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Напиток сохранён'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      widget.onSubmitted();
    } else {
      // On failure, the provider's `errorMessage` is set. Push
      // it as a SnackBar AND keep the form populated so the user
      // can retry — the screen itself doesn't switch to the
      // `_ErrorView` here because we're mid-confirm rather than
      // mid-initial-analysis.
      final msg = provider.errorMessage ??
          'Не удалось сохранить напиток. Попробуй снова.';
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  // ---- volume-driven recompute ---------------------------------------------

  /// Recomputes each macro proportional to the volume change.
  /// Pure client-side ratio math — no network call, no fake
  /// delay: the math is `baseValue * (newVolume / baseVolume)`,
  /// where `baseValue` and `baseVolume` were captured from the
  /// server-returned suggestion on first render. The badge
  /// visibility is toggled on so the visual cue ("Пересчитано")
  /// pulses for ~400ms before fading back out.
  ///
  /// Skipped (silently) when the parsed volume is empty, ≤ 0,
  /// or unparseable — typing partial input ("33" while building
  /// up to "330") shouldn't perturb the macros with a ratio
  /// against 33. Listening on the volume controller means the
  /// recompute fires on every keystroke; the badge pulse
  /// handles the "this was just recomputed" visual signal so
  /// each keystroke doesn't feel noisy.
  void _onVolumeChanged() {
    final raw = _volumeCtrl.text.trim().replaceAll(',', '.');
    final newVolume = double.tryParse(raw);
    if (newVolume == null || newVolume <= 0) return;
    if (_baseVolume <= 0) return;
    final ratio = newVolume / _baseVolume;
    setState(() {
      _caloriesCtrl.text = _fmt(_baseCalories * ratio);
      _proteinCtrl.text = _fmt(_baseProtein * ratio);
      _carbsCtrl.text = _fmt(_baseCarbs * ratio);
      _fatCtrl.text = _fmt(_baseFat * ratio);
      _sugarCtrl.text = _fmt(_baseSugar * ratio);
      _recalcToken++;
      _recalcBadgeVisible = true;
    });
    _recalcTimer?.cancel();
    _recalcTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _recalcBadgeVisible = false);
      }
    });
  }

  // ---- name-difference check + verify-on-save ------------------------------

  /// Whitespace-normalised, case-insensitive containment check.
  /// Two names are considered "the same" if either contains the
  /// other after normalisation — that swallows the common case
  /// where the user made a cosmetic edit (e.g. "Кока-Кола" →
  /// "Кока Кола", or "Cola" → "Cola Light") without changing
  /// the actual beverage. The verification round-trip is wasted
  /// on those.
  bool _namesDifferMeaningfully(String a, String b) {
    final normA = a.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    final normB = b.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normA == normB) return false;
    if (normA.contains(normB) || normB.contains(normA)) return false;
    return true;
  }

  /// Shows the "this looks like X, not Y" mismatch dialog and
  /// returns whether the user chose to proceed anyway.
  ///
  /// `true` → user tapped "Всё равно сохранить" (proceed).
  /// `false` → user tapped "Исправить" (return to the form) or
  /// dismissed the dialog some other way.
  Future<bool> _showMismatchDialog({
    required String claimedName,
    required String? detectedInstead,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('Внимание'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Судя по фото, это не похоже на «$claimedName».',
                style: theme.textTheme.bodyMedium,
              ),
              if (detectedInstead != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Больше похоже на: $detectedInstead',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Исправить'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Всё равно сохранить'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  // ---- helpers -------------------------------------------------------------

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  static const Map<String, ({String label, Color color})> _confidenceStyle = {
    'medium': (label: 'Средняя точность', color: Color(0xFFEAB308)), // amber
    'low': (label: 'Низкая точность', color: Color(0xFFEF4444)), // red
  };

  // ---- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Populate the controllers exactly once on the first build
    // of this view. Side-effecting during build is normally
    // frowned upon, but here it's safe (and clean): we only
    // write to controllers we own, the guards above prevent
    // re-runs, and there's no rebuild triggered by the writes
    // themselves (TextEditingController doesn't notify).
    _populateFromSuggestion();

    final theme = Theme.of(context);
    final suggestion = widget.suggestion;
    final confidenceLevel = suggestion.confidence ?? 'low';
    final confidence =
        _confidenceStyle[confidenceLevel] ?? _confidenceStyle['low']!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Explanatory caption above the form. The
            // explanation is deliberately honest about why
            // we're asking the user to verify — "не уверен(а)
            // в определении" — so the user doesn't think the
            // extra confirmation step is a bug.
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Не уверен(а) в определении — проверь и подтверди данные.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Top row: confidence badge + (if present) the
            // model's prose description of the visual cues it
            // used. The description is what the user is being
            // asked to verify, so it's placed prominently.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ConfidenceChip(
                  label: confidence.label,
                  color: confidence.color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (suggestion.description ?? '').isEmpty
                        ? '— описание отсутствует'
                        : suggestion.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Beverage name field.
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Название напитка',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) {
                final raw = (v ?? '').trim();
                if (raw.isEmpty) return 'Введи название';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Volume field — required, > 0.
            TextFormField(
              controller: _volumeCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Объём, мл',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: _validatePositiveMl,
            ),
            const SizedBox(height: 12),

            // Calories field — >= 0.
            TextFormField(
              controller: _caloriesCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Калории, ккал',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _RecalcBadge(
                  visible: _recalcBadgeVisible,
                  token: _recalcToken,
                ),
              ),
              validator: _validateNonNegative,
            ),

            // Collapsible "Подробнее" section for the rest of
            // the macros. Defaults to collapsed — most beverage
            // entries (water, plain coffee, simple sodas) don't
            // need protein/carb/fat/sugar broken out, so we hide
            // them by default and let the curious / precise user
            // expand.
            const SizedBox(height: 8),
            Theme(
              // Removes the ExpansionTile's default heavy top/bottom
              // borders for a flatter, settings-list look.
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: const Text('Подробнее (белки, жиры, углеводы, сахар)'),
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  TextFormField(
                    controller: _proteinCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Белки, г',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _RecalcBadge(
                        visible: _recalcBadgeVisible,
                        token: _recalcToken,
                      ),
                    ),
                    validator: _validateNonNegative,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _carbsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Углеводы, г',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _RecalcBadge(
                        visible: _recalcBadgeVisible,
                        token: _recalcToken,
                      ),
                    ),
                    validator: _validateNonNegative,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fatCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Жиры, г',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _RecalcBadge(
                        visible: _recalcBadgeVisible,
                        token: _recalcToken,
                      ),
                    ),
                    validator: _validateNonNegative,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sugarCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Сахар, г',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _RecalcBadge(
                        visible: _recalcBadgeVisible,
                        token: _recalcToken,
                      ),
                    ),
                    validator: _validateNonNegative,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: const Text('Подтвердить и сохранить'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error path: friendly message + retry button (resets provider
/// state so the picker returns). Mirrors `photo_food_screen.dart`'s
/// error view exactly.
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
            Icon(
              Icons.cloud_off,
              size: 56,
              color: theme.colorScheme.error,
            ),
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
              label: const Text('Попробовать снова'),
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

/// Small "✨ Пересчитано" badge that appears briefly next to a
/// macro field after a volume-driven recompute. Uses a
/// `TweenAnimationBuilder<double>` to drive the opacity pulse —
/// the builder's `key` is keyed on `token` so each recompute
/// re-keys the tween, restarting the fade-in from 0.0 → 1.0 and
/// giving a fresh pulse on every volume edit.
///
/// The slot is a fixed-width `SizedBox` so the field's layout
/// doesn't shift as the badge fades in/out — the badge is
/// always present in the suffixIcon slot, just invisible most
/// of the time. Without the fixed width, the input cursor would
/// jump left/right on every recompute, which is the most jarring
/// UX failure mode for an "auto-update" affordance.
class _RecalcBadge extends StatelessWidget {
  const _RecalcBadge({required this.visible, required this.token});

  /// `true` flips the tween's target to 1.0 (fade-in); `false`
  /// flips it to 0.0 (fade-out).
  final bool visible;

  /// Increments on every volume-driven recompute. Drives the
  /// `ValueKey` on the `TweenAnimationBuilder` so the tween
  /// re-instantiates and the fade-in re-plays from 0.0.
  final int token;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 110,
      child: Center(
        child: TweenAnimationBuilder<double>(
          // Re-key on each token change so the tween restarts
          // from 0 → 1 every time, giving a fresh pulse.
          key: ValueKey('recalc-$token'),
          tween: Tween(begin: 0, end: visible ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 200),
          builder: (context, opacity, _) => Opacity(
            opacity: opacity,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Пересчитано',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
