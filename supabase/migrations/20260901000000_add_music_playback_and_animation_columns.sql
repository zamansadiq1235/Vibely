-- Adds the editing-mode extras chosen in the Create flow's Music and Edit
-- steps, beyond the earlier filter/music metadata columns:
--
--   music_volume        : 0.0-1.0 playback volume for the added track
--                        (persisted alongside music_url from the MusicAPI/curated
--                        library pick, applied at feed playback).
--   mute_original_audio : mute the video's own audio at playback when a
--                        track is playing (the video itself isn't re-encoded
--                        client-side — mixing is deferred, same as trim).
--   animation_preset    : stable VideoAnimationPreset id ('none' = untouched);
--                        the client replays the transform (zoom, slide, bounce,
--                        shake, ken-burns) when the video plays back.
--
-- All nullable with no defaults so existing rows/uploads are unaffected.
alter table public.videos add column if not exists music_volume double precision;
alter table public.videos add column if not exists mute_original_audio boolean;
alter table public.videos add column if not exists animation_preset text;

create index if not exists idx_videos_animation_preset
  on public.videos(animation_preset)
  where animation_preset is not null;