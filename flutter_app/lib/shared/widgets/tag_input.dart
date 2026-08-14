import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../widgets/glass/glass_chip.dart';

/// Free-text tag input that mirrors the behaviour of
/// `nutrimind/src/components/ui/tag-input.tsx` on the web — the user
/// can type any custom string, press Enter (or Drop a comma) to commit
/// it as a removable chip, paste comma/newline-separated text to add
/// many at once, and hit Backspace on an empty field to peel off the
/// last chip.
///
/// Single responsibility: hold the controller / focus / keyboard state
/// for a single composition, surface the canonicalised tag list to the
/// caller via [onChanged]. Insertion order is preserved (NOT sorted
/// alphabetically), and case-insensitive duplicates collapse to the
/// first-seen casing.
///
/// This widget is *purely* controlled: it never owns the tag list
/// itself. Pass in the current list via [value]; pass in a setter via
/// [onChanged]. State-management in the parent is whatever the parent
/// prefers (setState, Provider, Riverpod, ...).
class TagInputField extends StatefulWidget {
  /// The current tags. The widget never mutates this; it calls
  /// [onChanged] with a new list whenever the user adds or removes a
  /// tag.
  final List<String> value;

  /// Called with the new full tag list after every add / remove /
  /// backspace / blur action.
  final ValueChanged<List<String>> onChanged;

  /// Hint text shown inside the trailing text field when it's empty.
  final String? hintText;

  /// When `true`, the × remove handles disappear and the text field
  /// becomes non-editable. Used during save/upload to lock the form
  /// against in-flight edits.
  final bool disabled;

  const TagInputField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hintText,
    this.disabled = false,
  });

  @override
  State<TagInputField> createState() => _TagInputFieldState();
}

class _TagInputFieldState extends State<TagInputField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---- input handlers --------------------------------------------------------

  /// Detects a trailing comma or newline in the field and commits
  /// whatever came before it. Listening on the controller (rather than
  /// intercepting at TextInputFormatter level) is intentional: a
  /// formatter would have to textually transform the field mid-typing
  /// and re-emit a selection, which complicates the cursor jump. This
  /// code path stays simple — strip-and-commit — and only fires on the
  /// exact character the user typed.
  void _onTextChanged() {
    final text = _controller.text;
    if (text.isEmpty) return;
    final last = text[text.length - 1];
    if (last != ',' && last != '\n') return;

    final stripped = text.substring(0, text.length - 1);
    _controller.value = TextEditingValue(
      text: stripped,
      selection: TextSelection.collapsed(offset: stripped.length),
    );
    _commitInput(stripped);
  }

  /// Field lost focus — mirror the web component's `onBlur` and commit
  /// anything the user typed but didn't Enter. Better than silently
  /// discarding on focus loss.
  void _onFocusChange() {
    if (_focusNode.hasFocus) return;
    _commitInput(_controller.text);
  }

  /// The IME's submit button (Done / Enter on mobile keyboard).
  void _onSubmitted(String value) {
    _commitInput(value);
  }

  /// Backspace on an empty input → peel off the last chip. Implemented
  /// via a `Focus.onKeyEvent` wrapper because TextField itself doesn't
  /// expose a "backspace on empty" callback the way JS `onKeyDown`
  /// does — we have to listen at the focus level and filter.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (widget.disabled) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    if (_controller.text.isEmpty && widget.value.isNotEmpty) {
      _removeAt(widget.value.length - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---- mutations -------------------------------------------------------------

  /// Commit whatever raw text is in the field. Splits on comma or
  /// newline (the latter catches both "paste with newline separators"
  /// and stray Enter keystrokes), trims, drops empties, dedupes
  /// case-insensitively against [widget.value], appends the survivors
  /// in their original order, clears the field, fires onChanged.
  void _commitInput(String raw) {
    if (raw.trim().isEmpty) {
      // Empty trim → nothing to add, but we may still need to clear.
      // _controller.clear() does NOT re-trigger our listener with
      // empty text (the listener early-returns on empty), so it's
      // safe to call unconditionally.
      _controller.clear();
      return;
    }

    final pieces = raw
        .split(RegExp(r'[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);

    // Case-insensitive dedup. We keep the casing the user *first*
    // typed for any given tag — re-typing "Milk" after "milk" already
    // exists is a no-op, but typing "milk" first and "MILK" later
    // would dedup to the original "milk" (case preserved).
    final existingLower = widget.value
        .map((t) => t.toLowerCase())
        .toSet();
    final additions = <String>[];
    for (final piece in pieces) {
      final lower = piece.toLowerCase();
      if (existingLower.contains(lower)) continue;
      existingLower.add(lower);
      additions.add(piece);
    }

    if (additions.isEmpty) {
      _controller.clear();
      return;
    }

    widget.onChanged([...widget.value, ...additions]);
    _controller.clear();
  }

  /// Remove the chip at [index]. We pass the index in from the chip's
  /// tap callback (rather than the value) so a hypothetical list with
  /// duplicates would still be unambiguous. Duplicates are prevented
  /// upstream by the case-insensitive dedup above; this is just being
  /// explicit.
  void _removeAt(int index) {
    if (index < 0 || index >= widget.value.length) return;
    final newList = [...widget.value]..removeAt(index);
    widget.onChanged(newList);
  }

  // ---- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final chipBg = primary.withValues(alpha: 0.10);
    final chipBorder = primary.withValues(alpha: 0.30);

    return Focus(
      onKeyEvent: _onKey,
      child: Container(
        // Outlined-container look matching the other form fields in the
        // app — same border + radius family as `OutlinedInputBorder`.
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < widget.value.length; i++)
              _TagChip(
                label: widget.value[i],
                color: primary,
                backgroundColor: chipBg,
                borderColor: chipBorder,
                onRemove: widget.disabled ? null : () => _removeAt(i),
              ),
            // The trailing text field — sized to its content via
            // IntrinsicWidth with a min-width hint so it never
            // collapses to zero. Inside a Wrap, plain TextField would
            // shrink to the cursor width and be hard to tap;
            // IntrinsicWidth grows it with the typed text.
            IntrinsicWidth(
              stepHeight: 0.6,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 120),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !widget.disabled,
                  readOnly: widget.disabled,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _onSubmitted,
                  decoration: InputDecoration(
                    hintText: widget.hintText ??
                        AppLocalizations.of(context).tagInputDefaultHint,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill-shaped tag chip with an inline × remove handle. The handle is
/// absent in the disabled state. The visual is delegated to the
/// shared [GlassChip] so tag rendering stays consistent with every
/// other glass surface in the app (and so the Reduce Transparency
/// fallback is handled in one place, not two).
class _TagChip extends StatelessWidget {
  final String label;
  final VoidCallback? onRemove;
  final Color color;
  // ignore: unused_element_parameter
  final Color backgroundColor;
  // ignore: unused_element_parameter
  final Color borderColor;

  const _TagChip({
    required this.label,
    required this.onRemove,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassChip(
      label: label,
      onRemove: onRemove,
      color: color,
    );
  }
}
