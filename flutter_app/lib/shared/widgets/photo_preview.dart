import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Decode a display-sized preview; retain the original file for recognition.
/// A square bounding box preserves aspect ratio and caps decoded pixel memory.
class PhotoPreview extends StatelessWidget {
  const PhotoPreview({
    super.key,
    required this.file,
    this.fit = BoxFit.contain,
  });
  final File file;
  final BoxFit fit;

  static int decodeEdge(Size viewport, double pixelRatio) =>
      (viewport.longestSide * pixelRatio).ceil().clamp(64, 2048);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final screen = MediaQuery.sizeOf(context);
      final size = Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : screen.width,
        constraints.hasBoundedHeight ? constraints.maxHeight : screen.height,
      );
      // Round to stable cache buckets so small layout changes reuse a decoder.
      final edge = math.min(
        2048,
        ((decodeEdge(size, MediaQuery.devicePixelRatioOf(context)) + 127) ~/
                128) *
            128,
      );
      return RepaintBoundary(
        child: Image(
          image: ResizeImage(
            FileImage(file),
            width: edge,
            height: edge,
            policy: ResizeImagePolicy.fit,
          ),
          fit: fit,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        ),
      );
    },
  );
}
