import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Curated motion presets for the upload editor Edit step (animations rail).
/// Each preset drives a looping transform (slow zoom, slide, bounce, shake,
/// ken-burns) while choosing, persisted as a stable string id on the
/// draft/videos row (`animation_preset`), and re-applied at playback in the
/// feed by looking the id back up through [byId] - same metadata-only
/// pattern as [VideoFilterPreset]. Transforms are pure functions of t in
/// [0,1] so a single AnimationController value can drive them without
/// rebuilding widget trees.
class VideoAnimationPreset {
  const VideoAnimationPreset({
    required this.id,
    required this.label,
    required this.icon,
    this.duration = const Duration(seconds: 6),
    required this.kind,
  });

  final String id;
  final String label;
  final IconData icon;

  /// Drives the transform math in [wrap]; 'none' renders the child untouched.
  /// Length of one full loop - the feed repeats it continuously; the editor
  /// preview restarts it whenever the selection changes.
  final Duration duration;
  final VideoAnimationKind kind;

  static const String noneId = 'none';

  static const none = VideoAnimationPreset(
    id: noneId,
    label: 'Original',
    icon: Icons.motion_photos_off_rounded,
    kind: VideoAnimationKind.none,
    duration: Duration.zero,
  );

  static const zoomIn = VideoAnimationPreset(
    id: 'zoom_in',
    label: 'Zoom In',
    icon: Icons.zoom_in_rounded,
    kind: VideoAnimationKind.zoomIn,
  );

  static const zoomOut = VideoAnimationPreset(
    id: 'zoom_out',
    label: 'Zoom Out',
    icon: Icons.zoom_out_rounded,
    kind: VideoAnimationKind.zoomOut,
  );

  static const slideUp = VideoAnimationPreset(
    id: 'slide_up',
    label: 'Slide Up',
    icon: Icons.arrow_upward_rounded,
    kind: VideoAnimationKind.slideUp,
  );

  static const bounce = VideoAnimationPreset(
    id: 'bounce',
    label: 'Bounce',
    icon: Icons.animation_rounded,
    kind: VideoAnimationKind.bounce,
  );

  static const shake = VideoAnimationPreset(
    id: 'shake',
    label: 'Shake',
    icon: Icons.vibration_rounded,
    kind: VideoAnimationKind.shake,
  );

  static const kenBurns = VideoAnimationPreset(
    id: 'ken_burns',
    label: 'Ken Burns',
    icon: Icons.pan_tool_rounded,
    kind: VideoAnimationKind.kenBurns,
  );

  /// All selectable presets, in picker order.
  static const all = [
    none,
    zoomIn,
    zoomOut,
    slideUp,
    bounce,
    shake,
    kenBurns,
  ];

  /// Looks up a persisted id - falls back to no animation if an unknown
  /// value ever comes back (e.g., removed preset from older uploads).
  static VideoAnimationPreset? byId(String? id) {
    if (id == null) return null;
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Wraps [child] with the motion transform at loop position [t] (0.0-1.0).
  /// Pure math - no rebuilds, no state - callers drive an AnimationController
  /// and pass its current value in (the feed widget and the editor preview do
  /// exactly this).
  Widget wrap({required Widget child, required double t}) {
    switch (kind) {
      case VideoAnimationKind.none:
        return child;
      case VideoAnimationKind.zoomIn:
        return Transform.scale(scale: 1.0 + 0.20 * t, child: child);
      case VideoAnimationKind.zoomOut:
        return Transform.scale(scale: 1.2 - 0.20 * t, child: child);
      case VideoAnimationKind.slideUp:
        return Transform.translate(offset: Offset(0, (1 - t) * 120), child: child);
      case VideoAnimationKind.bounce: {
        final s = 1.0 + 0.08 * math.sin(t * math.pi * 6);
        return Transform.scale(scale: s, child: child);
      }
      case VideoAnimationKind.shake: {
        final dx = math.sin(t * math.pi * 8) * 10;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      }
      case VideoAnimationKind.kenBurns: {
        return Transform.scale(
          scale: 1.0 + 0.15 * t,
          child: Transform.translate(
            offset: Offset(28 * t, -14 * t),
            child: child,
          ),
        );
      }
    }
  }
}

enum VideoAnimationKind { none, zoomIn, zoomOut, slideUp, bounce, shake, kenBurns }
