# Clipzo

## Authentication setup

Email sign-up and sign-in use Supabase Auth. Before running the app:

1. Copy `.env.example` to `.env` and set `SUPABASE_URL` and
   `SUPABASE_ANON_KEY`.
2. Apply `supabase/migrations/20260824000000_complete_clipzo_schema.sql`
   in the Supabase SQL Editor or run `supabase db push`. This provisions all
   database tables (`profiles`, `videos`, `video_likes`, `comments`, `comment_likes`,
   `saved_videos`, `reposts`, `video_shares`, `video_views`, `follows`,
   `friend_requests`, `notifications`, `hashtags`, `video_hashtags`), automatic
   counter triggers, notification triggers, RPC functions, storage buckets, and RLS policies.
3. In Supabase Authentication settings, enable Email authentication. If
   email confirmation is enabled, users must confirm their email before
   their first sign-in.

Then run:

```bash
flutter pub get
flutter run
```
# Vibely
