import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/food_recognition_result.dart';
import '../providers/food_recognition_provider.dart';
import '../providers/tracker_provider.dart';

/// Screen for logging a food entry from a photo via Gemini.
///
/// Single responsibility: drive the camera/gallery picker, hand the chosen
/// image off to [FoodRecognitionProvider], and render one of four mutually
/// exclusive states — picker / analyzing / result / error — based on the
/// provider's observable state. Tapping "Готово" pops with `true` so the
/// caller can react (e.g. show a confirmation toast), but the
/// [TrackerProvider] has *already* been updated in-place by
/// [FoodRecognitionProvider] via `addLocalFoodEntry`, so no refetch is
/// required.
class PhotoFoodScreen extends StatefulWidget {
  /// Which meal slot the recognised food will be filed under.
  final String mealType;

  const PhotoFoodScreen({super.key, required this.mealType});

  @override
  State<PhotoFoodScreen> createState() => _PhotoFoodScreenState();
}

class _PhotoFoodScreenState extends State<PhotoFoodScreen> {
  /// Local handle to the most recently picked image, so the analyzing
  /// overlay can show it beneath its spinner. Reset to `null` when the
  /// user retries or leaves the screen.
  File? _pickedFile;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    // Defensive: clear any pending result/error so a stale "✅ Logged"
    // message doesn't bleed into a future invocation. We don't care
    // about the notify outcome — dispose is best-effort.
    try {
      context.read<FoodRecognitionProvider>().reset();
    } catch (_) {
      // Provider may already be torn down; swallow.
    }
    super.dispose();
  }

  // ---- picker actions -------------------------------------------------------

  Future<void> _pick(ImageSource source) async {
    // System pickers (camera / photo library) can throw in a handful of
    // ways — no camera hardware, revoked permissions, intent cancelled
    // mid-flow, etc. We always want the picker screen to survive this and
    // tell the user *in their language* what went wrong, instead of
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

    // Cancellation — the picker returned null. This is normal user
    // behaviour, not an error: stay quietly on the picker screen.
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    setState(() => _pickedFile = file);

    // Kick the analysis off immediately — the watcher above will switch
    // the body to the analyzing overlay on the next frame.
    context.read<FoodRecognitionProvider>().analyzePhoto(
      imageFile: file,
      mealType: widget.mealType,
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
    context.read<FoodRecognitionProvider>().reset();
    setState(() => _pickedFile = null);
  }

  void _done() {
    context.read<FoodRecognitionProvider>().reset();
    Navigator.of(context).pop(true);
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final recognition = context.watch<FoodRecognitionProvider>();
    final theme = Theme.of(context);

    // State precedence: result > analyzing > error > picker. The order
    // matters — once we have a successful result we render *that*, even
    // if a stale error message were ever left behind.
    final Widget body;
    if (recognition.lastResult != null && !recognition.isAnalyzing) {
      body = _ResultView(result: recognition.lastResult!, onDone: _done);
    } else if (recognition.isAnalyzing && _pickedFile != null) {
      body = _AnalyzingView(image: _pickedFile!);
    } else if (recognition.errorMessage != null && !recognition.isAnalyzing) {
      body = _ErrorView(
        message: recognition.errorMessage!,
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
        title: const Text('Фото еды'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SafeArea(child: body),
    );
  }
}

// =============================================================================
// State views
// =============================================================================

/// Initial state: two large buttons. One launches the camera, one opens
/// the gallery picker.
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
            Icons.image_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Сфотографируй еду или выбери снимок из галереи',
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

/// While Gemini is thinking: show the picked image with a spinner and a
/// label so the user knows we *are* doing something.
class _AnalyzingView extends StatelessWidget {
  const _AnalyzingView({required this.image});

  final File image;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: Image.file(
            image,
            fit: BoxFit.contain,
          ),
        ),
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.55),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Colors.white,
                ),
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

/// Result of a successful analysis. Renders the food name, confidence
/// badge, compact macros, optional description, ingredients (as chips),
/// and an unmissable allergy warning block when relevant.
class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.onDone});

  final FoodRecognitionResult result;
  final VoidCallback onDone;

  // Confidence → (label, color) — used for the badge.
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
          // Allergy warning — ABOVE the nutrition card, per spec.
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

                  // Compact macro row — mirrors `_MacroRow` visually so
                  // the two screens feel of a piece.
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

/// Error path: friendly message + retry button (resets provider state so
/// the picker returns).
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
