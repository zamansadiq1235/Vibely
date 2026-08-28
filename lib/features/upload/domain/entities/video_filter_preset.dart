import 'package:flutter/material.dart';

/// Curated color-grade presets for the upload editor's Filter step.
/// Each preset carries its own [ColorFilter.matrix], applied live over
/// the video preview while choosing, persisted as a stable string id on
/// the draft/videos row (`filter_preset`), and re-applied at playback in
/// the feed by looking the id back up through [byId].
///
/// Matrices are standard 4x5 row-major color matrices (r,g,b,a rows ×
/// offset column), the format ColorFilter.matrix expects.
class VideoFilterPreset {
  const VideoFilterPreset({
    required this.id,
    required this.label,
    required this.icon,
    required this.matrix,
  });

  /// Stable identifier persisted in the database — never rename an id,
  /// only adjust how it renders.
  final String id;
  final String label;
  final IconData icon;
  final List<double> matrix;

  /// Plain-string form of [none]'s id so const defaults elsewhere
  /// (`UploadDraft`) can reference it without a const-eval property
  /// access.
  static const String noneId = 'none';

  static const none = VideoFilterPreset(
    id: noneId,
    label: 'Original',
    icon: Icons.filter_none_rounded,
    matrix: <double>[
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0, //
      0, 0, 1, 0, 0, //
      0, 0, 0, 1, 0,
    ],
  );

  /// All selectable presets, in picker order.
  static const all = [
    none,
    vivid,
    warmSunset,
    coolOcean,
    monoNoir,
    vintage,
    fadeSoft,
    dramatic,
    mintAqua,
  ];

  static const vivid = VideoFilterPreset(
    id: 'vivid',
    label: 'Vivid',
    icon: Icons.auto_awesome_rounded,
    matrix: <double>[
      1.25, 0, 0, 0, -24, //
      0, 1.25, 0, 0, -18, //
      0, 0, 1.25, 0, -12, //
      0, 0, 0, 1, 0,
    ],
  );

  static const warmSunset = VideoFilterPreset(
    id: 'warm_sunset',
    label: 'Warm',
    icon: Icons.wb_sunny_rounded,
    matrix: <double>[
      1.15, 0.08, 0, 0, 10, //
      0.02, 1.05, 0, 0, 2, //
      0, 0, 0.92, 0, -6, //
      0, 0, 0, 1, 0,
    ],
  );

  static const coolOcean = VideoFilterPreset(
    id: 'cool_ocean',
    label: 'Cool',
    icon: Icons.ac_unit_rounded,
    matrix: <double>[
      0.92, 0, 0.05, 0, 0, //
      0, 1.0, 0.03, 0, 4, //
      0.04, 0.02, 1.12, 0, 14, //
      0, 0, 0, 1, 0,
    ],
  );

  static const monoNoir = VideoFilterPreset(
    id: 'mono_noir',
    label: 'Noir',
    icon: Icons.blur_on_rounded,
    matrix: <double>[
      0.33, 0.59, 0.11, 0, 6, //
      0.33, 0.59, 0.11, 0, 6, //
      0.33, 0.59, 0.11, 0, 6, //
      0, 0, 0, 1, 0,
    ],
  );

  static const vintage = VideoFilterPreset(
    id: 'vintage',
    label: 'Vintage',
    icon: Icons.camera_roll_rounded,
    matrix: <double>[
      0.9, 0.25, 0, 0, 16, //
      0.15, 0.85, 0, 0, 8, //
      0.05, 0.1, 0.75, 0, 22, //
      0, 0, 0, 1, 0,
    ],
  );

  static const fadeSoft = VideoFilterPreset(
    id: 'fade_soft',
    label: 'Fade',
    icon: Icons.opacity_rounded,
    matrix: <double>[
      0.82, 0, 0, 0, 26, //
      0, 0.86, 0, 0, 24, //
      0, 0, 0.88, 0, 20, //
      0, 0, 0, 1, 0,
    ],
  );

  static const dramatic = VideoFilterPreset(
    id: 'dramatic',
    label: 'Dramatic',
    icon: Icons.contrast_rounded,
    matrix: <double>[
      1.45, -0.18, -0.18, 0, 12, //
      -0.18, 1.38, -0.18, 0, 12, //
      -0.18, -0.18, 1.45, 0, 10, //
      0, 0, 0, 1, 0,
    ],
  );

  static const mintAqua = VideoFilterPreset(
    id: 'mint_aqua',
    label: 'Mint',
    icon: Icons.water_drop_rounded,
    matrix: <double>[
      0.88, 0.06, 0, 0, 8, //
      0.03, 1.12, 0.05, 0, 8, //
      0, 0.06, 1.02, 0, 16, //
      0, 0, 0, 1, 0,
    ],
  );

  /// Looks up a persisted id — falls back to no filtering if an unknown
  /// value ever comes back (e.g., removed preset from older uploads).
  static VideoFilterPreset? byId(String? id) {
    if (id == null) return null;
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}