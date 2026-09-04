import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../models/food_log_model.dart';
import '../providers/tracker_provider.dart';

/// Manual food-entry form.
///
/// Single responsibility: collect a single food entry's metadata
/// (meal-type, name, quantity, unit, calories + macros) and hand it off to
/// [TrackerProvider.addFoodEntry]. The provider is the source of truth for
/// state + server merge; this screen just paints the form and routes the
/// result.
class AddFoodScreen extends StatefulWidget {
  const AddFoodScreen({super.key});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers — kept here so we don't fight Flutter over managed state.
  final _nameCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '100');
  // The unit field defaults to the *localised* "g" (RU: "г", KA: "გ"),
  // matching the chip-label text rendered by `_unitChips` below. This
  // The unit field is also the wire-protocol default sent to
  // the backend in `_onSubmit` if the user leaves the field
  // empty — so the value that ships on the wire matches the
  // active UI locale (EN: "g", RU: "г", KA: "გ"). The default
  // text is seeded in `didChangeDependencies()` below (NOT in
  // the field initializer or in `initState()`) because
  // `AppLocalizations.of(context)` does an
  // `InheritedWidget` lookup, which throws if called before the
  // widget's `BuildContext` is attached to the tree — that's
  // exactly the case during field initialization and during
  // `initState()`.
  final TextEditingController _unitCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _fiberCtrl = TextEditingController();

  String _mealType = 'breakfast';

  /// Latches `true` the first time we seed `_unitCtrl.text` from
  /// `AppLocalizations.of(context).addFoodUnitG`. `didChangeDependencies`
  /// can run more than once over the lifetime of this State
  /// (locale changes, theme changes, MediaQuery changes), and the
  /// `_unitCtrl.text.isEmpty` guard plus this latch together make
  /// sure we only overwrite the field with the locale default
  /// while the user hasn't typed anything — a locale change while
  /// the user has selected a non-default unit (e.g. "ml") must
  /// not silently revert the field to "g".
  bool _unitDefaultApplied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_unitDefaultApplied && _unitCtrl.text.isEmpty) {
      // Safe to call here — `didChangeDependencies` is the
      // first lifecycle hook where the State.context is
      // attached to the inherited-widget tree, so
      // `AppLocalizations.of(context)` works without throwing.
      _unitCtrl.text = AppLocalizations.of(context).addFoodUnitG;
      _unitDefaultApplied = true;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _quantityCtrl, _unitCtrl,
      _caloriesCtrl, _proteinCtrl, _carbsCtrl, _fatCtrl, _fiberCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- validators ------------------------------------------------------------

  String? _requiredText(String? v, String label) {
    if (v == null || v.trim().isEmpty) return label;
    return null;
  }

  String? _requiredNumber(String? v, String label, {bool allowZero = false}) {
    if (v == null || v.trim().isEmpty) return label;
    final n = num.tryParse(v.trim().replaceAll(',', '.'));
    if (n == null) return null;
    if (!allowZero && n < 0) return null;
    return null;
  }

  String? _optionalNumber(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = num.tryParse(v.trim().replaceAll(',', '.'));
    if (n == null) return null;
    if (n < 0) return null;
    return null;
  }

  double? _parseDouble(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return num.tryParse(t.replaceAll(',', '.'))?.toDouble();
  }

  void _setUnit(String u) {
    _unitCtrl.text = u;
    _unitCtrl.selection =
        TextSelection.collapsed(offset: _unitCtrl.text.length);
    // The unit field is unmasked — no validation — so no setState is
    // strictly required, but rebuilding keeps any wrapping label up to date.
    setState(() {});
  }

  // ---- submit ----------------------------------------------------------------

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Build a FoodLogModel. Server-managed fields (id, user_id,
    // ai_generated, created_at) are placeholder values — toCreateJson()
    // strips them off before POSTing, and the provider replaces the local
    // entry with the server's response on success.
    final now = DateTime.now();
    final food = FoodLogModel(
      id: '',
      userId: '',
      date: now,
      mealType: _mealType,
      foodName: _nameCtrl.text.trim(),
      calories: _parseDouble(_caloriesCtrl) ?? 0,
      protein: _parseDouble(_proteinCtrl) ?? 0,
      carbs: _parseDouble(_carbsCtrl) ?? 0,
      fat: _parseDouble(_fatCtrl) ?? 0,
      fiber: _parseDouble(_fiberCtrl),
      quantity: _parseDouble(_quantityCtrl) ?? 100,
      unit: _unitCtrl.text.trim().isEmpty
          ? AppLocalizations.of(context).addFoodUnitG
          : _unitCtrl.text.trim(),
      photoUrl: null,
      aiGenerated: false,
      createdAt: now,
    );

    final tracker = context.read<TrackerProvider>();
    final ok = await tracker.addFoodEntry(food);
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop<FoodLogModel>(food);
    } else {
      ScaffoldMessenger.of(context)
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

  // ---- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isLoading = context.watch<TrackerProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addFoodTitle),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Meal-type dropdown
                DropdownButtonFormField<String>(
                  initialValue: _mealType,
                  decoration: InputDecoration(
                    labelText: l10n.addFoodMealLabel,
                    prefixIcon: const Icon(Icons.restaurant),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                        value: 'breakfast', child: Text(l10n.addFoodMealBreakfast)),
                    DropdownMenuItem(
                        value: 'lunch', child: Text(l10n.addFoodMealLunch)),
                    DropdownMenuItem(
                        value: 'dinner', child: Text(l10n.addFoodMealDinner)),
                    DropdownMenuItem(
                        value: 'snack', child: Text(l10n.addFoodMealSnack)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _mealType = v);
                  },
                ),
                const SizedBox(height: 16),

                // Food name
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.addFoodName,
                    prefixIcon: const Icon(Icons.fastfood_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      _requiredText(v, l10n.addFoodFieldRequired(l10n.addFoodName)),
                ),
                const SizedBox(height: 16),

                // Quantity + unit (side by side), with quick-pick chips below.
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _quantityCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.addFoodQuantity,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => _requiredNumber(
                            v, l10n.addFoodFieldRequired(l10n.addFoodQuantity)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _unitCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.addFoodUnit,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    children: [
                      _chip(l10n.addFoodUnitG),
                      _chip(l10n.addFoodUnitMl),
                      _chip(l10n.addFoodUnitPcs),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                _NumField(
                  controller: _caloriesCtrl,
                  label: l10n.addFoodCalories,
                  allowDecimal: true,
                  validator: (v) => _requiredNumber(
                      v, l10n.addFoodFieldRequired(l10n.addFoodCalories)),
                ),
                const SizedBox(height: 12),
                _NumField(
                  controller: _proteinCtrl,
                  label: l10n.addFoodProtein,
                  validator: (v) => _requiredNumber(
                      v, l10n.addFoodFieldRequired(l10n.addFoodProtein)),
                ),
                const SizedBox(height: 12),
                _NumField(
                  controller: _carbsCtrl,
                  label: l10n.addFoodCarbs,
                  validator: (v) => _requiredNumber(
                      v, l10n.addFoodFieldRequired(l10n.addFoodCarbs)),
                ),
                const SizedBox(height: 12),
                _NumField(
                  controller: _fatCtrl,
                  label: l10n.addFoodFat,
                  validator: (v) => _requiredNumber(
                      v, l10n.addFoodFieldRequired(l10n.addFoodFat)),
                ),
                const SizedBox(height: 12),
                _NumField(
                  controller: _fiberCtrl,
                  label: l10n.addFoodFiber,
                  validator: _optionalNumber,
                ),
                const SizedBox(height: 24),

                FilledButton.icon(
                  onPressed: isLoading ? null : _onSubmit,
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(l10n.addFoodButtonAdd),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(
          label: Text(label),
          onPressed: () => _setUnit(label),
        ),
      );
}

/// Single numeric text field with consistent styling.
class _NumField extends StatelessWidget {
  const _NumField({
    required this.controller,
    required this.label,
    required this.validator,
    this.allowDecimal = false,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(
        decimal: allowDecimal,
        signed: false,
      ),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }
}
