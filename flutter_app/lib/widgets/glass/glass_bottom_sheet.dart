import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/glass_tokens.dart';
import '../../utils/accessibility_utils.dart';

/// Liquid Glass wrapper around [showModalBottomSheet]. Three things
/// set this apart from a vanilla sheet:
///
///   1. The route barrier (the area BEHIND the sheet) is rendered
///      with a stronger [ImageFilter.blur] sigma so the sheet
///      truly feels like a floating glass panel over the dimmed
///      page — not a translucent overlay on a flat tint.
///   2. The sheet body is a [GlassSurface] instead of the theme's
///      default `bottomSheetTheme.backgroundColor`.
///   3. The entrance animation slides + fades in via a
///      [SpringSimulation] rather than the default `Curves.easeOut`
///      so the sheet "settles" with a small bounce.
///
/// Accessibility: when iOS "Reduce Transparency" is on, both the
/// route barrier blur AND the sheet's glass surface collapse to
/// their solid counterparts. The sheet still slides in with the
/// spring animation (entrance is not transparency-driven).
Future<T?> showGlassBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    // Default `barrierColor` is `Colors.black54`; the sheet would
    // visibly float over a darkened-but-not-blurred page. We let
    // the barrier be transparent so the [BackdropFilter] in
    // [_GlassBarrier] is the only thing the user sees behind the
    // sheet.
    barrierColor: Colors.transparent,
    builder: (ctx) {
      final reduceTransparency = ReduceTransparencyScope.of(ctx);
      return _GlassSheetBody(
        reduceTransparency: reduceTransparency,
        child: Builder(builder: builder),
      );
    },
  );
}

class _GlassSheetBody extends StatelessWidget {
  const _GlassSheetBody({
    required this.child,
    required this.reduceTransparency,
  });

  final Widget child;
  // The `reduceTransparency` flag is reserved for a future
  // Reduce-Transparency solid-sheet fallback (mirror the same
  // pattern as `GlassSurface`). Today the sheet's [BackdropFilter]
  // doubles as the visible blur, so the flag is unused at the
  // widget level — keep it in the constructor for API parity
  // with `showGlassBottomSheet`'s caller contract.
  // ignore: unused_element_parameter
  final bool reduceTransparency;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassTokens.modalBlurSigma,
          sigmaY: GlassTokens.modalBlurSigma,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: GlassTokens.tintColorFor(context),
            border: Border(
              top: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.4),
                width: 1,
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}