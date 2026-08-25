# Vibely

Short videos. Real connections.

A short-video social app built with Flutter + Riverpod + Supabase, following
the TikTok/Reels interaction model with an original visual identity.

> **Status: Phase 12 of 15 — Notifications (Realtime).**
> This repo is being built incrementally, phase by phase, per the project
> plan below.

## Authentication (Phase 3)

Implemented:

- Email/password sign up (collects email, password, username, full name,
  profile picture) and login
- Google and Facebook sign-in via Supabase's built-in OAuth flow
  (`signInWithOAuth`) — no extra native SDK packages required
- Forgot password / reset password email flow
- Email verification (Supabase sends this automatically on sign up;
  `resendEmailVerification` is available if the user needs a new link)
- Persistent sessions (handled by `supabase_flutter`'s local storage —
  no extra code needed)
- A single `authNotifierProvider` (`AsyncNotifier<AuthState>`) that is the
  one source of truth for: unauthenticated / needs-profile-completion /
  authenticated, with Loading and Error states built in via `AsyncValue`
- `go_router`'s `redirect` callback reads that state to enforce exactly
  the flow from the spec: **Splash → Login (if signed out) → Complete
  Profile (if profile incomplete) → Home**

### OAuth setup (Google & Facebook)

This app uses Supabase's hosted OAuth flow rather than the native Google/
Facebook SDKs, which keeps the Flutter side to zero extra dependencies.
To make it work:

1. In the **Supabase Dashboard → Authentication → Providers**, enable
   Google and Facebook, and paste in the Client ID/Secret from each
   provider's developer console.
2. In each provider's console (Google Cloud Console / Meta for
   Developers), add this as an authorized redirect URI — Supabase shows
   you the exact value on the Providers page, it looks like:
   `https://your-project-ref.supabase.co/auth/v1/callback`
3. Register a custom URL scheme for the app so Supabase can redirect
   back into it after the browser-based OAuth step:
   - **Android**: add an intent filter for `io.vibely.app://login-callback/`
     in `android/app/src/main/AndroidManifest.xml`.
   - **iOS**: add `io.vibely.app` as a URL scheme in `ios/Runner/Info.plist`.
   - This scheme must match `_oauthRedirect` in
     `lib/features/auth/data/datasources/auth_remote_data_source.dart`.

No `GOOGLE_WEB_CLIENT_ID` / `FACEBOOK_APP_ID` env values are needed with
this approach — those keys in `.env.example` are left in case you later
swap to the native SDK flow for a more integrated (non-browser) sign-in
experience.

### Complete Profile

A profile counts as "complete" once `full_name` is set and an avatar has
been uploaded (see `AppProfile.isComplete`). The signup form *collects* a
profile picture too, but it's actually uploaded on the Complete Profile
screen — signup doesn't guarantee an active session yet if email
confirmation is required, and Storage uploads need an authenticated
client.

## Notifications (Phase 12)

New folder: `lib/features/notifications/`, now the real Notifications
tab, with a live unread badge on the bottom nav.

- **All 8 notification types** from spec §26 render with their own
  icon, color, and message ("liked your video," "sent you a friend
  request," etc.) — every one of them was already being *generated*
  server-side by the trigger functions in migration 0004; this phase is
  what finally reads and displays them.
- **Realtime** (spec §26: "Use Supabase Realtime where appropriate") —
  a channel subscribed to `INSERT`s on `notifications` filtered to the
  signed-in user fires as soon as any of those 8 triggers creates a row
  for them, live-updating the badge and list without polling. The row
  itself isn't passed through the callback (it lacks the joined actor
  profile the UI needs), so a new-row signal triggers a light re-fetch
  of page 0 instead of hand-assembling a partial entity — simple and
  correct, at the cost of one extra query per burst of new
  notifications rather than zero.
- **Read state**: tapping a notification marks it read optimistically;
  "Mark all read" does the same for the whole list. Both are treated as
  low-stakes enough to skip rollback-on-failure — worst case a read
  marker lags the server by one fetch, which self-corrects.
- **Tap-to-navigate** is kind-aware: comment/comment-like/reply
  notifications open the comments sheet straight to that video (reusing
  Phase 8's `CommentBottomSheet`); a friend request opens the Friend
  Requests screen (Phase 10); likes, new followers, accepted requests,
  and reposts go to the actor's profile — there's still no standalone
  video player screen (spec §41) to jump straight to *the* video for
  the first and last of those, so the profile is the most useful
  landing spot available today, same reasoning applied to grid taps in
  Phases 9-11.
- The subscription lives inside `notificationsProvider`, watched from
  `MainShell` itself (not just the Notifications screen) so the badge
  stays live while browsing other tabs, and unsubscribes cleanly via
  `ref.onDispose`.

## Search (Phase 11)

New folder: `lib/features/search/`, wired up as the real Search tab.

- **Debounced input** (spec §22) — the text field waits 400ms after
  typing stops before updating `searchQueryProvider`; every results
  provider watches that debounced value, not the raw keystrokes, so
  typing "flutter" doesn't fire 7 queries.
- **Three tabs**: Users, Videos, Hashtags — each backed by its own
  paginated `ILIKE` query (20/page), matching against `username`/
  `full_name`, `videos.caption`, and `hashtags.tag` respectively.
  Queries are sanitized against PostgREST's `%`/`_` wildcard characters
  so a search containing them behaves like literal text, not a pattern.
- **Uses the trigram indexes from migration 0001** — `gin_trgm_ops` on
  `profiles.username`, `profiles.full_name`, and `videos.caption` — so
  these `ILIKE '%...%'` queries stay fast as the tables grow, per spec
  §22's "Use PostgreSQL indexes for efficient searches."
- **User results reuse `ProfileActionButtons`** (Phase 4) directly, so
  Follow/Add Friend from a search result behaves identically to the
  profile screen's — same relationship states, same optimistic +
  rollback handling, no third copy of that logic.
- **Video results** reuse the same `VideoThumbnailGrid` from Phase 9.
- **Hashtag results**, when tapped, plug the tag straight into the
  search box and jump to the Videos tab — there's no separate
  "videos tagged #x" endpoint yet, so this reuses the caption search
  (hashtags are parsed out of captions at upload time, per Phase 5), a
  reasonable stand-in until/unless a dedicated hashtag-videos query is
  worth adding.

## Follows, Friend Requests, Friends (Phase 10)

Two new folders: `lib/features/follows/` and `lib/features/friends/`.
This phase builds the four list screens that have been placeholders
since Phase 4, where the single-profile Follow/Add Friend button was
first built.

- **Followers / Following screens** (spec §23/§24) — paginated (30/page),
  each row shows a Follow/Following button reflecting *the viewer's*
  relationship to that person (not the profile owner's) — so viewing a
  stranger's followers list still lets you follow people straight from
  it. Toggling follow from a row updates that row optimistically, with
  rollback on failure, by reusing `RelationshipActions.toggleFollow`
  from Phase 4 rather than a second copy of that mutation.
- **Friends screen** (spec §21/§25) — accepted `friend_requests`, from
  either side (a friendship works both ways, so the query pulls rows
  where the viewed user is *either* sender or receiver and picks
  whichever profile isn't them). "Remove Friend" only appears on your
  own friends list, with a confirmation dialog first.
- **Friend Requests screen** (spec §20) — two tabs, Received (Accept /
  Reject) and Sent (Cancel), reachable from a new icon on your own
  profile's app bar. Both reuse the accept/reject/cancel mutations Phase
  4 already built on `ProfileRepository` — this phase's job was just
  giving them a list to act on and removing the row locally once
  actioned.
- All four lists are RLS-backed the same way the single-profile view
  already was: `follows` and `reposts`-style public readability for
  Followers/Following/Friends, while Friend Requests' Received/Sent tabs
  only ever query the signed-in user's own rows.

## Share, Save, Repost (Phase 9)

Three new folders: `lib/features/shares/`, `lib/features/saved_videos/`,
`lib/features/reposts/`. All three follow the same optimistic-update
pattern established by Likes (Phase 7): patch the feed's in-memory
`VideoPost` immediately, persist to Supabase, roll back on failure.

- **Share** (spec §14) — tapping the share icon opens a small sheet:
  "Share via..." (native OS share sheet, `share_plus`) or "Copy link."
  Both record a `video_shares` row and bump `sharesCount`. There's no
  web app or custom domain yet, so the "link" shared today is the direct
  Supabase Storage URL for the video file — swapping in a real
  `vibely.app/video/:id` page later is a one-line change once that
  exists, consistent with the CDN/streaming integration the spec's
  architecture section anticipates.
- **Save** (spec §15) — the bookmark icon toggles `saved_videos`
  (optimistic + rollback), and a new **Saved Videos screen**
  (`/saved-videos`, reachable from a bookmark icon on your own profile's
  app bar) shows a paginated grid of everything you've saved, with
  unsaving from the feed instantly removing an item from that grid too
  if both are mounted at once.
- **Repost** (spec §16) — the repeat icon toggles `reposts`
  (optimistic + rollback, unique-violation-safe against double-tapping),
  with a dedicated **Reposted Videos screen**
  (`/reposted-videos/:userId`, viewable for any user since reposts are
  public) and now-real grids in the Profile's **Videos** and **Reposts**
  tabs (previously empty-state placeholders since Phase 4) — both use a
  new shared `VideoThumbnailGrid` widget.
- **What's still a placeholder**: the "↻ Zaman reposted" indicator
  *inline in the main feed* isn't built — the Home feed still queries
  only `videos` (spec §28's simple recency ranking), not reposts
  surfaced as feed entries from people you follow. Making reposts appear
  in the feed itself is a feed-ranking enhancement, not a repost-CRUD
  one, and fits naturally alongside the "smarter algorithm" work the
  spec already earmarks for later. The Profile "Liked" tab is also still
  a placeholder — it needs a "list every video I've liked" query that
  Phase 7 didn't build (Likes only tracks whether one specific video is
  liked, for the feed heart icon).
- Grid thumbnails aren't tappable into a real player yet — there's no
  standalone single-video screen (spec §41 lists one separately from the
  main feed); tapping shows a short explanatory snackbar instead of
  silently doing nothing.

## Comments (Phase 8)

New folder: `lib/features/comments/`. Tapping the comment icon in the
feed opens a `CommentBottomSheet` (spec §11), backed by:

- **Two paginated family notifiers** — `commentsProvider(videoId)` for
  top-level comments (`parent_id IS NULL`, newest first, 20/page) and
  `repliesProvider(parentCommentId)` for that comment's replies (oldest
  first, 10/page), loaded only when the user taps "N Replies" — never
  eagerly, matching §11's "do not load thousands of comments at once."
- **`CommentActions`** — coordinates everything a single add/delete/like
  needs to touch: the right comments-or-replies list, the parent
  comment's `repliesCount` (for a reply), and the video's
  `commentsCount` back in the feed (via the same `feedProvider.
  patchVideo` used by Phase 7's likes). Like/unlike is optimistic with
  rollback on failure, same pattern as video likes; add/delete surface
  their error directly rather than silently reverting a comment the
  user just typed.
- **Comment likes** — `comment_likes`, mirroring `video_likes` exactly
  (idempotent insert/delete, unique-violation treated as already-liked).
- **Delete** — own comments only (enforced by RLS, migration 0005); the
  trigger from migration 0003 handles decrementing counts server-side,
  the optimistic local removal just keeps the UI from lagging behind it.
- **Reply threading** is two levels deep in the UI (top-level comment →
  its replies) even though the `comments` table supports arbitrary
  self-referencing depth — replying to a reply still attaches to the
  original top-level comment, matching how most short-video apps
  present threads.

## Likes (Phase 7)

New folder: `lib/features/likes/`. This phase replaces the feed's
local-only heart toggle from Phase 6 with a real, persisted mutation:

- **`LikeRepository`** — `likeVideo`/`unlikeVideo` against `video_likes`,
  idempotent on duplicate/missing rows (a unique-violation from
  double-tapping fast is treated as "already liked," not an error).
- **`LikeActions`** — the piece that actually makes double-tap feel
  instant: it patches the feed's in-memory `VideoPost` immediately (heart
  fills, count changes with zero latency), *then* writes to Supabase. If
  that write fails, the local change is rolled back and the feed screen
  shows why — so the UI can never end up displaying a like that wasn't
  actually saved.
- `videos.likes_count` is never written directly from the client — the
  optimistic count bump is a display prediction only; the real number
  still comes from the server-side trigger (migration 0003) and
  self-corrects on the next feed refresh.
- The double-tap heart-pop animation from Phase 6 is unchanged visually —
  it's now backed by this real mutation instead of a fake local toggle.

Tapping the heart icon in the action bar and double-tapping the video
both go through the same `LikeActions.setLiked`, so behavior (and
rollback-on-failure) is consistent between the two gestures.

## Video Feed (Phase 6)

The Home tab is now real, in `lib/features/feed/`:

- **`HomeFeedScreen`** — a full-screen vertical `PageView.builder`
  (`scrollDirection: Axis.vertical`), one video per page, matching spec
  §7 exactly.
- **Controller lifecycle** (`FeedVideoControllerCache`) — at most 3
  `VideoPlayerController`s exist at any time: previous, current, next.
  Every page change disposes everything outside that window and
  preloads the next video so playback starts instantly on swipe. This
  directly satisfies §7/§30's repeated "never initialize dozens of
  controllers" requirement.
- **Playback behavior**: auto-play the current video, auto-pause when
  swiped away, loop, tap to play/pause, mute/unmute (persists across the
  preload window), a scrubbable progress bar, a buffering spinner, and a
  thumbnail shown until the real video is ready — with an error state +
  Retry button if a video fails to load.
- **Double-tap to like** shows the heart-pop animation spec §7 asks for,
  now backed by a persisted, rollback-safe mutation — see Phase 7 below
  for how the actual write happens.
- **Pagination**: fetches `AppConstants.feedPageSize` (20) videos at a
  time and loads the next page once the user is within 3 videos of the
  end — never fetches unlimited data (§29).
- **View counting** (§37): a `video_views` row is only inserted after a
  video has been the active page for `AppConstants.minWatchDurationForView`
  (2s) continuously — flicking past several videos quickly doesn't
  inflate anyone's view count.
- **Feed ranking** (§28): this phase's query is a simple `order by
  created_at desc`, exactly as the spec's "initial implementation"
  calls for. The repository/query boundary is deliberately narrow
  (`FeedRepository.fetchFeed(page)`) so a smarter ranking (friends first,
  popularity, etc.) can replace the ordering later without the feed
  screen or controller cache needing to change at all.
- **Bottom navigation is now real** (`lib/core/router/main_shell.dart`):
  a `StatefulShellRoute.indexedStack` wraps Home/Search/Create/
  Notifications/Profile so each tab keeps its own stack and state —
  switching away from Home and back doesn't lose scroll position or
  force video controllers to reinitialize. Create gets the visually
  distinct pill button the spec asks for (§6).

Action-bar icons for comment/share/save/repost are present and tappable
in the feed UI but not yet wired to a mutation — each shows a short
"arrives in Phase N" hint, matching exactly when each is built.

## Video Upload (Phase 5)

Implemented, in `lib/features/upload/`: the full Create → Publish wizard
from spec §17, as a single screen (`CreateVideoScreen`) stepping through:

1. **Select video** — gallery or camera (`image_picker`), capped at the
   spec's 180s and the `videos` bucket's 500 MB limit (migration 0006).
2. **Preview / Trim** — plays the picked file with `video_player`; a
   range slider sets `trimStart`/`trimEnd` metadata on the draft.
   **Note:** actually re-encoding the file to those trim points needs a
   video-processing package or server-side job, which isn't in this
   phase's dependency list — the full file uploads for now, with the
   trim points saved so a future CDN/transcoding integration (spec §1:
   *"architecture must allow future integration with a dedicated video
   streaming/CDN solution"*) can act on them.
3. **Thumbnail** — pick a custom cover image, or skip to fall back to
   the video's own first frame at playback time (no auto-frame-extraction
   package is in the dependency list either, so this phase doesn't
   generate one client-side).
4. **Caption** — free text; hashtags are parsed live from `#tags` typed
   into the caption (shown as chips) rather than a separate field.
5. **Privacy** — Public / Friends / Private, matching the `videos.
   visibility` enum and RLS rules from Phase 2.
6. **Upload** — shows a real byte-level progress bar (not a spinner) via
   `ProgressUploadClient`, a small helper (`lib/shared/services/
   progress_upload_client.dart`) that streams the file straight to
   Supabase Storage's REST endpoint using `http`, since
   `supabase_flutter`'s built-in `.upload()` doesn't expose progress —
   this is the one dependency added beyond the original package list,
   specifically to satisfy §17's "show upload progress" requirement
   properly instead of faking it.

Also handled per spec §17: **cancel** (aborts the in-flight HTTP request),
**retry** (re-runs `publish()` against the same draft, so nothing typed
is lost), and a **no-network check** before starting (via
`connectivity_plus`) plus network-failure handling mid-upload.

On success, the flow inserts the `videos` row and links any parsed
hashtags (upserted into `hashtags` + `video_hashtags`), then clears the
draft. The **Home feed** that will actually display these videos, and the
**profile grid** that shows a user's own uploads, are Phase 6 and later —
right now there's no way to *watch* an uploaded video in-app yet, only
publish one.

## Profile (Phase 4)

Implemented, in `lib/features/profile/`:

- **`ProfileScreen(userId: ...)`** — a single screen used for both "my
  profile" (bottom nav tab, `userId` omitted) and anyone else's profile
  (`/user/:userId`, e.g. reached from search or a video's author). Shows
  avatar, name, username, bio, and the Following/Followers/Likes/Friends
  stat row from spec §27.
- **Own profile** → `Edit Profile` button → `EditProfileScreen` (change
  avatar, full name, bio; username is read-only for now — changing it
  safely needs an availability-check flow, noted as a later addition).
- **Someone else's profile** → `Follow`/`Following` button plus a second
  button that walks the friend-request state machine from spec §20:
  `Add Friend` → `Request Sent` → *(they accept)* → `Friends`, or
  `Accept` if they sent you a request first. All of this reads/writes
  `follows` and `friend_requests` directly — RLS (migration 0005)
  enforces who can do what, and the counters on both profiles update via
  the triggers from migration 0003, so the UI just re-fetches after each
  action rather than incrementing anything client-side.
- **Videos / Reposts / Liked tabs** — the tab structure is in place
  (`ProfileContentTabs`) with an empty state in each; the actual grids of
  video thumbnails plug in once the `videos` feature exists (Phase 6 for
  Videos, Phase 9 for Reposts/Liked).
- Followers / Following / Friends *list* screens (tapping a stat) are
  placeholders until Phase 10, which builds the follow/friend-request
  feature in full, including pagination.

## Database setup (Phase 2)

Migrations live in `supabase/migrations/`, numbered in the order they must
run:

| File | What it does |
|---|---|
| `0001_core_schema.sql` | Extensions, enums, all tables + indexes |
| `0002_new_user_trigger.sql` | Auto-creates a `profiles` row on signup |
| `0003_count_triggers.sql` | Server-side counters (likes, comments, follows, etc.) |
| `0004_notification_triggers.sql` | Creates `notifications` rows for the events in spec §26 |
| `0005_rls_policies.sql` | Row Level Security on every table |
| `0006_storage.sql` | `avatars` / `videos` / `thumbnails` buckets + storage policies |

**Apply them** with the Supabase CLI:

```bash
supabase login
supabase link --project-ref your-project-ref
supabase db push
```

Or paste each file's contents into the Supabase Dashboard → SQL Editor, in
order, if you're not using the CLI.

Design notes:

- **All counters are server-side.** `videos.likes_count`,
  `comments_count`, `friends_count`, etc. are maintained by triggers, never
  by `count++` in Flutter — see §36 of the spec.
- **Friends vs. followers are separate relationships.** `follows` is
  one-directional and instant; `friend_requests` requires
  pending → accepted before either side counts as a "friend."
- **Video visibility** (`public` / `friends` / `private`) is enforced at
  the Postgres row level via `can_view_video()`, used in every RLS
  `select` policy that touches videos or their children (likes, comments,
  shares...). The `videos` storage bucket is currently public at the file
  level for simplicity — see the comment in `0006_storage.sql` for how to
  tighten that with signed URLs later if you need file-level privacy too.
- **`video_views`** exists so the app can insert one row per watched view
  (after your own minimum-watch-duration check) rather than trusting a
  client-side increment; a trigger rolls it into `videos.views_count`.
- **The service-role key is never used by the Flutter app.** Everything
  above is designed to work fully through RLS with the anon key.

## What's implemented so far (Phase 1)

- Flutter project skeleton with feature-first `lib/` structure
- Riverpod (`ProviderScope`, `flutter_riverpod`) wired at the app root
- Material 3 theme, light + dark, original color identity (violet/aqua —
  not TikTok's red/black/white)
- `go_router` route table for every screen in the spec (placeholder
  builders for now)
- Supabase client initialization via `flutter_dotenv` (`.env`, gitignored)
- Shared error types (`AppException`, `Failure`) for consistent
  Loading/Success/Empty/Error handling in later phases
- Form validators for the Phase 3 auth screens

## Setup

1. Install Flutter (stable channel, Dart ≥3.3).
2. `flutter pub get`
3. Copy `.env.example` to `.env` and fill in your Supabase project's URL
   and anon key (Project Settings → API in the Supabase dashboard).
   **Never put the service-role key in `.env` or anywhere in this app.**
4. `flutter run`

Supabase project setup (tables, RLS, storage buckets) lands in **Phase 2**
of this README's roadmap — until then there's no schema to point the app
at beyond auth.

## Project structure

```
lib/
├── core/               # theme, router, network, errors, utils, constants
├── features/           # one folder per feature, data/domain/presentation
│   └── splash/
└── shared/              # cross-feature widgets/models/services
```

## Roadmap

| Phase | Scope |
|---|---|
| 1 | Project setup, Riverpod, theme, routing, Supabase config ✅ |
| 2 | Database schema, RLS, storage policies ✅ |
| 3 | Authentication (email, Google, Facebook) ✅ |
| 4 | Profile + edit profile + stats ✅ |
| 5 | Video upload ✅ |
| 6 | TikTok-style vertical video feed ✅ |
| 7 | Likes ✅ |
| 8 | Comments, comment likes, replies ✅ |
| 9 | Share, save, repost ✅ |
| 10 | Follows, friend requests, friends ✅ |
| 11 | Search ✅ |
| 12 | Notifications (Realtime) *(this phase)* ✅ |
| 13 | Performance optimization |
| 14 | Testing |
| 15 | Docs |

## Tech stack

Flutter · Dart · Riverpod · go_router · Supabase (Auth, Postgres, Storage,
Realtime, RLS) · video_player

## Security notes

- The Supabase **anon key** is safe in the client; it's constrained by RLS.
- The **service-role key** must never appear in this repo or app.
- `.env`, keystores, and OAuth config files are gitignored — see `.gitignore`.
