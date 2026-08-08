import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/food_log_model.dart';
import '../models/food_recognition_result.dart';
import '../providers/food_recognition_provider.dart';
import '../providers/tracker_provider.dart';

/// Screen for correcting an already-logged AI food entry by editing
/// its free-text description and asking Gemini to re-estimate the
/// macros from the EDITED TEXT ONLY (no image).
///
/// Single responsibility: present a multi-line editor that pre-fills
/// with the most recent description Gemini produced for this entry,
/// hand the user's edit off to [FoodRecognitionProvider] (which
/// POSTs to the reanalyze endpoint), and render one of four mutually
/// exclusive states — edit form / analyzing / result / error — based
/// on the provider's observable state.
///
/// Tapping "Готово" pops with `true` so the caller can react (e.g.
/// show a confirmation toast), but the [TrackerProvider] has *already*
/// been updated in-place by [FoodRecognitionProvider] via
/// `updateLocalFoodEntry`, so no refetch is required.
///
/// Why the constructor accepts `initialDescription` separately
/// from [foodLog]: `FoodLogModel` does NOT carry the AI description
/// field — only the recognition-flow response (`FoodRecognitionResult`)
/// does. The home screen looks up the cached description in
/// `FoodRecognitionProvider.descriptionsByFoodLogId` and passes it
/// here, so a fresh edit session within the same app session
/// continues from the text the user last saw. When the cache has
/// expired (app killed/restarted, row was logged in a previous
/// session), the field starts empty and the user types their
/// correction from scratch — a perfectly reasonable fallback.
class EditFoodDescriptionScreen extends StatefulWidget {
  /// The food entry being corrected. Used for the form's contextual
  /// header (a "Уточняем: `foodName`" pill at the top of the edit
  /// screen) and for [reanalyzeDescription]'s `foodId`.
  final FoodLogModel foodLog;

  /// Pre-fill for the editor. May be `''` — see the class-level
  /// docstring for why.
  final String initialDescription;

  const EditFoodDescriptionScreen({
    super.key,
    required this.foodLog,
    required this.initialDescription,
  });

  @override
  State<EditFoodDescriptionScreen> createState() =>
      _EditFoodDescriptionScreenState();
}

class _EditFoodDescriptionScreenState
    extends State<EditFoodDescriptionScreen> {
  /// Drives the whole form so the "Пересчитать" button can call
  /// `currentState!.validate()` without re-walking the tree.
  final _formKey = GlobalKey<FormState>();

  /// Owns the multi-line description the user is editing.
  late final TextEditingController _descriptionCtrl;

  /// Guard flag for the post-frame `reset()` call. Avoids a double-
  /// reset in the common case where both `initState` (post-frame)
  /// and `dispose` would otherwise call it. We DO want `reset()`
  /// on both — entering clean and exiting clean — so this is a
  /// pure read-only-future, not a behaviour switch.
  // (kept as a future reference so the structure is obvious;
  // intentionally not used to mutate state)
  // ignore: unused_field
  Future<void>? _pendingResetOnEnter;

  @override
  void initState() {
    super.initState();
    _descriptionCtrl =
        TextEditingController(text: widget.initialDescription);

    // Reset any stale result/error from a previous attempt — typical
    // case is the user opens this screen after backing out of a
    // half-finished attempt and we don't want the *previous* spinner /
    // error to be rendered when the post-frame body rebuilds.
    //
    // `addPostFrameCallback` is required because `context.read` /
    // `Provider.of(...)` can throw if called too early in the
    // initState → build → settle sequence. We capture the future
    // so the dispose-time reset is a no-op even if the post-frame
    // callback hadn't fired yet at dispose.
    _pendingResetOnEnter = _resetRecognitionLater();
  }

  Future<void> _resetRecognitionLater() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        context.read<FoodRecognitionProvider>().reset();
      } catch (_) {
        // Provider may already be torn down; swallow.
      }
    });
  }

  @override
  void dispose() {
    // Defensive: clear any pending result/error so a stale
    // "✅ Reanalysed" confirmation from this attempt doesn't bleed
    // into a future invocation (e.g. if the home screen reuses the
    // provider for a different action).
    try {
      context.read<FoodRecognitionProvider>().reset();
    } catch (_) {
      // Provider may already be torn down; swallow.
    }
    _descriptionCtrl.dispose();
    super.dispose();
  }

  // ---- actions ------------------------------------------------------------

  Future<void> _reanalyze() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final recognition = context.read<FoodRecognitionProvider>();
    final tracker = context.read<TrackerProvider>();

    // We don't await the provider here — `context.watch` will
    // rebuild this screen on every notify, so the spinner / result
    // state transitions happen automatically. If we awaited, we'd
    // block the UI on the network round-trip and the spinner would
    // never animate.
    unawaited(recognition.reanalyzeDescription(
      foodId: widget.foodLog.id,
      description: _descriptionCtrl.text.trim(),
      trackerProvider: tracker,
    ));
  }

  void _retry() {
    context.read<FoodRecognitionProvider>().reset();
  }

  void _done() {
    context.read<FoodRecognitionProvider>().reset();
    Navigator.of(context).pop(true);
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final recognition = context.watch<FoodRecognitionProvider>();
    final theme = Theme.of(context);

    // State precedence: result > analyzing > error > edit. The order
    // matters — once we have a successful result we render *that*,
    // even if a stale error message were ever left behind.
    //
    // The picker screen isn't a state here: this flow opens straight
    // into the edit form.
    final Widget body;
    if (recognition.lastResult != null && !recognition.isAnalyzing) {
      body = _ResultView(result: recognition.lastResult!, onDone: _done);
    } else if (recognition.isAnalyzing) {
      body = const _AnalyzingView();
    } else if (recognition.errorMessage != null && !recognition.isAnalyzing) {
      body = _ErrorView(
        message: recognition.errorMessage!,
        onRetry: _retry,
      );
    } else {
      body = _EditForm(
        formKey: _formKey,
        controller: _descriptionCtrl,
        onSubmit: _reanalyze,
        foodName: widget.foodLog.foodName,
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Уточнить описание'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SafeArea(child: body),
    );
  }
}

// =============================================================================
// State views
// =============================================================================

/// Initial state: a contextual "we're editing X" line + multi-line
/// description editor + "Пересчитать" submit button.
class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.formKey,
    required this.controller,
    required this.onSubmit,
    required this.foodName,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final String foodName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // "Уточняем: <food name>" — gives the user a clear
            // anchor for *which* row they're editing, especially
            // when several AI-generated rows are visible above the
            // bottom dock.
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Уточняем',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      foodName.isEmpty ? 'Без названия' : foodName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Описание',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: controller,
              minLines: 5,
              maxLines: 10,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText:
                    'Например: это бурый рис, а не белый, и масла было меньше',
                isDense: false,
              ),
              validator: (v) {
                final raw = (v ?? '').trim();
                if (raw.isEmpty) {
                  return 'Введи описание — его отправим в ИИ для пересчёта.';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Опиши, что на самом деле в блюде — это поможет '
                'точнее пересчитать калории и макросы. Изображение '
                'не используется.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.refresh),
              label: const Text('Пересчитать'),
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

/// While Gemini is thinking: a centered spinner + label so the user
/// knows we *are* doing something. No image to lay underneath (text-
/// only path), unlike [_AnalyzingView] in `photo_food_screen.dart`.
class _AnalyzingView extends StatelessWidget {
  const _AnalyzingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Анализируем описание...',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Result of a successful reanalysis.
///
/// Duplicates the styling from `photo_food_screen.dart`'s
/// `_ResultView` (~200 lines) rather than extracting a shared
/// widget, on purpose: keeping that file untouched minimises the
/// blast radius of this change. The two views will diverge as the
/// photo and edit flows evolve; sharing them via a true shared
/// widget is a follow-up.
class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.onDone});

  final FoodRecognitionResult result;
  final VoidCallback onDone;

  // Confidence → (label, color) — used for the badge. Same map as
  // `photo_food_screen.dart`'s identical widget; kept inline so
  // this file doesn't depend on anything photo-screen-internal.
  static const Map<String, ({String label, Color color})> _confidenceStyle = {
    'high': (label: 'Высокая точность', color: Color(0xFF22C55E)), // green
    'medium': (label: 'Средняя точность', color: Color(0xFFEAB308)), // amber
    'low': (label: 'Низкая точность', color: Color(0xFFEF4444)), // red
  };

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Widget _macroChip(BuildContext context, String label, String value) {
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
    final confidence = _confidenceStyle[result.confidence] ??
        _confidenceStyle['medium']!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Allergy warning — ABOVE the nutrition card, matching
          // the established convention from `photo_food_screen.dart`.
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
                          result.foodName.isEmpty
                              ? 'Без названия'
                              : result.foodName,
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
                  if (result.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      result.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Compact macro row — mirrors `_MacroRow` visually
                  // so the two screens feel of a piece.
                  Row(
                    children: [
                      _macroChip(context, 'ккал',
                          result.calories.round().toString()),
                      _macroChip(context, 'Б',
                          '${_fmt(result.protein)} г'),
                      _macroChip(context, 'У',
                          '${_fmt(result.carbs)} г'),
                      _macroChip(context, 'Ж',
                          '${_fmt(result.fat)} г'),
                    ],
                  ),

                  if (result.ingredients.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Что распознано',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: result.ingredients
                          .map(
                            (ing) => Chip(
                              label: Text(
                                ing,
                                style: theme.textTheme.bodySmall,
                              ),
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHigh,
                              side: BorderSide(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
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

/// Error path: friendly message + retry button (resets provider
/// state so the edit form returns). Identical visual treatment to
/// `photo_food_screen.dart`'s `_ErrorView` — duplicated here for
/// the same isolation rationale as `_ResultView`.
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
