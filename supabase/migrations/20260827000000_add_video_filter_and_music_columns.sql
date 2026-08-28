-- Adds the editing-mode metadata columns chosen in the Create flow's
-- Filter and Music steps:
--
--   filter_preset : stable VideoFilterPreset id ('none' = untouched);
--                   the client re-applies the matching ColorFilter.matrix
--                   when the video plays back.
--   music_title / music_artist / music_url : library-track metadata for
--                   background music. The audio is NOT mixed into the
--                   uploaded file here — that re-encoding job is deferred
--                   to server-side processing, same as trimStart/trimEnd.
--
-- All nullable with no defaults so existing rows/uploads are unaffected.

alter table public.videos add column if not exists filter_preset text;
alter table public.videos add column if not exists music_title text;
alter table public.videos add column if not exists music_artist text;
alter table public.videos add column if not exists music_url text;

create index if not exists idx_videos_filter_preset
  on public.videos(filter_preset)
  where filter_preset is not null;

-- ---------------------------------------------------------------------------
-- Realtime delivery fix: `notifications` was never added to the
-- supabase_realtime publication, so no insert ever reached subscribed
-- clients (the client-side channel was healthy but the server side had
-- nothing to emit). Guarded so re-running an already-applied line is a
-- no-op instead of a duplicate_object failure.
do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception
  when duplicate_object then null;
end $$;

