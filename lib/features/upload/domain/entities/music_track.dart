/// A library track offered by the upload editor's Music step.
///
/// The composer previews the track in-app ([previewUrl]) while choosing;
/// only the *metadata* (title/artist/preview url) is persisted on the
/// videos row (`music_title`, `music_artist`, `music_url`). Actually
/// baking audio into the uploaded file is a re-encoding job deferred to
/// server-side processing — same rationale as trimStart/trimEnd on
/// [UploadDraft], which this mirrors deliberately.
class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.genre,
    this.previewUrl,
    this.thumbnailUrl,
  });

  final String id;
  final String title;
  final String artist;

  /// Simple bucket label used to group chips in the picker.
  final String genre;

  /// Directly streamable audio URL used for in-editor preview. Null
  /// renders the track as metadata-only (no preview available).
  final String? previewUrl;

  /// Optional cover artwork. Curated library tracks ride on their gradient
  /// artwork instead; the real-time MusicAPI search results carry one.
final String? thumbnailUrl;

  static const all = [
    lobelia,
    emberLights,
    midnightDrive,
    paperCrane,
    softFocus,
    rooftopBloom,
    gravityHush,
    neonTide,
  ];

  static const lobelia = MusicTrack(
    id: 'lobelia',
    title: 'Lobelia',
    artist: 'Clipzo Studio',
    genre: 'Chill',
    // Royalty-free, license-free sample streams for editor previews.
    previewUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
  );

  static const emberLights = MusicTrack(
    id: 'ember_lights',
    title: 'Ember Lights',
    artist: 'Aurea Rae',
    genre: 'Lo-fi',
    previewUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
  );

  static const midnightDrive = MusicTrack(
    id: 'midnight_drive',
    title: 'Midnight Drive',
    artist: 'Kite & Ivory',
    genre: 'Electronic',
    previewUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
  );

  static const paperCrane = MusicTrack(
    id: 'paper_crane',
    title: 'Paper Crane',
    artist: 'Yuna Mori',
    genre: 'Ambient',
    previewUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
  );

  static const softFocus = MusicTrack(
    id: 'soft_focus',
    title: 'Soft Focus',
    artist: 'Halcyon Pool',
    genre: 'Chill',
    previewUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
  );

  static const rooftopBloom = MusicTrack(
    id: 'rooftop_bloom',
    title: 'Rooftop Bloom',
    artist: 'Marisol Vane',
    genre: 'Pop',
    previewUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
  );

  static const gravityHush = MusicTrack(
    id: 'gravity_hush',
    title: 'Gravity Hush',
    artist: 'Orbit Lane',
    genre: 'Electronic',
    previewUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
  );

  static const neonTide = MusicTrack(
    id: 'neon_tide',
    title: 'Neon Tide',
    artist: 'Cassette Ghosts',
    genre: 'Synthwave',
    previewUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
  );

  static MusicTrack? byId(String? id) {
    if (id == null) return null;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }
}