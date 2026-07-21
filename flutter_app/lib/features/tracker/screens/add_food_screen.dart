import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  final _unitCtrl = TextEditingController(text: 'г');
  final _caloriesCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _fiberCtrl = TextEditingController();

  String _mealType = 'breakfast';

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
    if (v == null || v.trim().isEmpty) return 'Заполни «$label»';
    return null;
  }

  String? _requiredNumber(String? v, String label, {bool allowZero = false}) {
    if (v == null || v.trim().isEmpty) return 'Заполни «$label»';
    final n = num.tryParse(v.trim().replaceAll(',', '.'));
    if (n == null) return 'Введи число';
    if (!allowZero && n < 0) return 'Должно быть ≥ 0';
    return null;
  }

  String? _optionalNumber(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = num.tryParse(v.trim().replaceAll(',', '.'));
    if (n == null) return 'Введи число';
    if (n < 0) return 'Должно быть ≥ 0';
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
      unit: _unitCtrl.text.trim().isEmpty ? 'г' : _unitCtrl.text.trim(),
      photoUrl: null,
      aiGenerated: false,
      createdAt: now,
    );

    final tracker = context.read<TrackerProvider>();
    final ok = await tracker.addFoodEntry(food);
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop<FoodLogModel>(food);
    } else if (tracker.errorMessage != null) {
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

  // ---- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = context.watch<TrackerProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавить еду'),
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
                  decoration: const InputDecoration(
                    labelText: 'Приём пищи',
                    prefixIcon: Icon(Icons.restaurant),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'breakfast', child: Text('Завтрак')),
                    DropdownMenuItem(value: 'lunch', child: Text('Обед')),
                    DropdownMenuItem(value: 'dinner', child: Text('Ужин')),
                    DropdownMenuItem(value: 'snack', child: Text('Перекус')),
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
                  decoration: const InputDecoration(
                    labelText: 'Название',
                    prefixIcon: Icon(Icons.fastfood_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => _requiredText(v, 'название'),
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
                        decoration: const InputDecoration(
                          labelText: 'Количество',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => _requiredNumber(v, 'количество'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _unitCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Ед.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    children: [
                      _chip('г'),
                      _chip('мл'),
                      _chip('шт'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                _NumField(
                  controller: _caloriesCtrl,
                  label: 'Калории, ккал',
                  allowDecimal: true,
                  validator: (v) => _requiredNumber(v, 'калории', allowZero: true),
                ),
                const SizedBox(height: 12),
                _NumField(
                  controller: _proteinCtrl,
                  label: 'Белки, г',
                  validator: (v) => _requiredNumber(v, 'белки', allowZero: true),
                ),
                const SizedBox(height: 12),
                _NumField(
                  controller: _carbsCtrl,
                  label: 'Углеводы, г',
                  validator: (v) => _requiredNumber(v, 'углеводы', allowZero: true),
                ),
                const SizedBox(height: 12),
                _NumField(
                  controller: _fatCtrl,
                  label: 'Жиры, г',
                  validator: (v) => _requiredNumber(v, 'жиры', allowZero: true),
                ),
                const SizedBox(height: 12),
                _NumField(
                  controller: _fiberCtrl,
                  label: 'Клетчатка, г (необязательно)',
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
                  label: const Text('Добавить'),
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
