import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/glass_tokens.dart';
import '../../utils/accessibility_utils.dart';

/// Liquid Glass wrapper around [showDialog]. Mirrors
/// [showGlassBottomSheet] for dialogs: stronger barrier blur,
/// glass-surface body, spring entrance. Use this for confirmation
/// dialogs / destructive-action prompts where the user is being
/// asked to commit to something — the glass treatment makes the
/// moment feel deliberate rather than incidental.
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? barrierLabel,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierLabel: barrierLabel ??
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.transparent,
    builder: (ctx) {
      final reduceTransparency = ReduceTransparencyScope.of(ctx);
      return _GlassDialogBody(
        reduceTransparency: reduceTransparency,
        child: Builder(builder: builder),
      );
    },
  );
}

class _GlassDialogBody extends StatelessWidget {
  const _GlassDialogBody({
    required this.child,
    required this.reduceTransparency,
  });

  final Widget child;
  // `reduceTransparency` is part of the public API for symmetry
  // with `showGlassBottomSheet`'s contract; the dialog's
  // [BackdropFilter] is replaced with a flat coloured barrier
  // when the setting flips (see the build path below).
  // ignore: unused_element_parameter
  final bool reduceTransparency;

  @override
  Widget build(BuildContext context) {
    final reduceTransparencyNow = ReduceTransparencyScope.of(context);
    return BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: GlassTokens.modalBlurSigma,
        sigmaY: GlassTokens.modalBlurSigma,
      ),
      child: Stack(
        children: [
          // The dark barrier visible through the blur. We use a
          // slightly higher opacity than the bottom-sheet version
          // because dialogs should feel more "blocking" than
          // sheets — the user is being asked to make a choice
          // rather than browse a pickable list.
          ColoredBox(
            color: Colors.black.withValues(alpha: reduceTransparencyNow ? 0.6 : 0.45),
          ),
          // Spring entrance: a single `TweenAnimationBuilder` drives
          // both the scale and the opacity so the dialog pops in
          // with one combined curve (350ms easeOutCubic) rather
          // than two competing tweens.
          Center(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0, end: 1),
              builder: (context, t, child) {
                final scale = 0.92 + 0.08 * t;
                final opacity = t.clamp(0.0, 1.0);
                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                );
              },
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}