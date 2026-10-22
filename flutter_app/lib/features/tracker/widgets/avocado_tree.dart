import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Bundled botanical artwork. Transparent images keep the plant independent
/// from the landscape, typography, theme and accessible interface controls.
class AvocadoTree extends StatefulWidget {
  const AvocadoTree({super.key, required this.stage, this.decorated = false});
  final int stage;
  final bool decorated;
  static const assets = ['seed', 'root', 'sprout', 'leaves', 'tree'];
  static String assetFor(int stage) =>
      'assets/garden/${assets[stage.clamp(0, 4)]}.webp';

  @override
  State<AvocadoTree> createState() => _AvocadoTreeState();
}

class _AvocadoTreeState extends State<AvocadoTree>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  void _updateMotion() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _float.stop();
      _float.value = 0;
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMotion();
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pixels =
              (constraints.biggest.shortestSide *
                      MediaQuery.devicePixelRatioOf(context))
                  .ceil()
                  .clamp(1, 1254);
          return AnimatedBuilder(
            animation: _float,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  AvocadoTree.assetFor(widget.stage),
                  fit: BoxFit.contain,
                  cacheWidth: pixels,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                ),
              ],
            ),
            builder: (context, child) => Transform.translate(
              offset: Offset(0, math.sin(_float.value * math.pi * 2) * 2),
              child: child,
            ),
          );
        },
      ),
    ),
  );
}

/// Background stays static so the composition floats subtly without making
/// typography or the whole screen drift. The surface fade works in both themes.
class GardenScene extends StatelessWidget {
  const GardenScene({
    super.key,
    required this.stage,
    this.decorated = false,
    this.topInset = 0,
  });
  final int stage;
  final bool decorated;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF111A15) : const Color(0xFFF6F4ED);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/garden/landscape.webp',
          fit: BoxFit.cover,
          cacheWidth: 1100,
          excludeFromSemantics: true,
        ),
        ColoredBox(
          color: dark
              ? const Color(0xFF081810).withValues(alpha: .48)
              : const Color(0xFFF8F4E9).withValues(alpha: .12),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, .32, .77, 1],
              colors: [
                surface.withValues(alpha: .76),
                surface.withValues(alpha: .05),
                surface.withValues(alpha: .10),
                surface,
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, topInset, 20, 8),
          child: AvocadoTree(stage: stage, decorated: decorated),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 2,
          child: ColoredBox(color: surface),
        ),
      ],
    );
  }
}
