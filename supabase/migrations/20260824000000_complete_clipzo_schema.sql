-- ==============================================================================
-- CLIPZO COMPLETE DATABASE SCHEMA, TRIGGERS, STORAGE & RLS POLICIES
-- ==============================================================================
-- Run this script in the Supabase SQL Editor to set up the entire backend.

-- 1. EXTENSIONS
create extension if not exists "uuid-ossp";
create extension if not exists "pg_trgm";

-- ==============================================================================
-- 2. TABLES & CONSTRAINTS
-- ==============================================================================

-- PROFILES TABLE
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[A-Za-z0-9_]{3,20}$'),
  full_name text not null default '',
  bio text not null default '',
  avatar_path text,
  followers_count integer not null default 0,
  following_count integer not null default 0,
  friends_count integer not null default 0,
  likes_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Search index on username and full_name using trigrams
create index if not exists idx_profiles_username_trgm on public.profiles using gin (username gin_trgm_ops);
create index if not exists idx_profiles_full_name_trgm on public.profiles using gin (full_name gin_trgm_ops);

-- VIDEOS TABLE
create table if not exists public.videos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null constraint videos_user_id_fkey references public.profiles(id) on delete cascade,
  video_path text not null,
  thumbnail_path text,
  caption text not null default '',
  visibility text not null default 'public' check (visibility in ('public', 'friends', 'private')),
  views_count integer not null default 0,
  likes_count integer not null default 0,
  comments_count integer not null default 0,
  shares_count integer not null default 0,
  saves_count integer not null default 0,
  reposts_count integer not null default 0,
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_videos_user_id on public.videos(user_id);
create index if not exists idx_videos_created_at on public.videos(created_at desc);
create index if not exists idx_videos_caption_trgm on public.videos using gin (caption gin_trgm_ops);

-- VIDEO LIKES TABLE
create table if not exists public.video_likes (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint video_likes_video_id_user_id_key unique (video_id, user_id)
);

create index if not exists idx_video_likes_video_id on public.video_likes(video_id);
create index if not exists idx_video_likes_user_id on public.video_likes(user_id);

-- COMMENTS TABLE
create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null constraint comments_user_id_fkey references public.profiles(id) on delete cascade,
  parent_id uuid references public.comments(id) on delete cascade,
  content text not null,
  likes_count integer not null default 0,
  replies_count integer not null default 0,
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_comments_video_id on public.comments(video_id, created_at desc);
create index if not exists idx_comments_parent_id on public.comments(parent_id);
create index if not exists idx_comments_user_id on public.comments(user_id);

-- COMMENT LIKES TABLE
create table if not exists public.comment_likes (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.comments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint comment_likes_comment_id_user_id_key unique (comment_id, user_id)
);

create index if not exists idx_comment_likes_comment_id on public.comment_likes(comment_id);
create index if not exists idx_comment_likes_user_id on public.comment_likes(user_id);

-- SAVED VIDEOS TABLE
create table if not exists public.saved_videos (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint saved_videos_video_id_user_id_key unique (video_id, user_id)
);

create index if not exists idx_saved_videos_user_id on public.saved_videos(user_id, created_at desc);
create index if not exists idx_saved_videos_video_id on public.saved_videos(video_id);

-- REPOSTS TABLE
create table if not exists public.reposts (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint reposts_video_id_user_id_key unique (video_id, user_id)
);

create index if not exists idx_reposts_user_id on public.reposts(user_id, created_at desc);
create index if not exists idx_reposts_video_id on public.reposts(video_id);

-- VIDEO SHARES TABLE
create table if not exists public.video_shares (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  share_type text not null default 'native',
  created_at timestamptz not null default now()
);

create index if not exists idx_video_shares_video_id on public.video_shares(video_id);

-- VIDEO VIEWS TABLE
create table if not exists public.video_views (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_video_views_video_id on public.video_views(video_id);

-- FOLLOWS TABLE
create table if not exists public.follows (
  id uuid primary key default gen_random_uuid(),
  follower_id uuid not null constraint follows_follower_id_fkey references public.profiles(id) on delete cascade,
  following_id uuid not null constraint follows_following_id_fkey references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint follows_follower_id_following_id_key unique (follower_id, following_id),
  constraint follows_no_self_follow check (follower_id <> following_id)
);

create index if not exists idx_follows_follower_id on public.follows(follower_id);
create index if not exists idx_follows_following_id on public.follows(following_id);

-- FRIEND REQUESTS TABLE
create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null constraint friend_requests_sender_id_fkey references public.profiles(id) on delete cascade,
  receiver_id uuid not null constraint friend_requests_receiver_id_fkey references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint friend_requests_sender_id_receiver_id_key unique (sender_id, receiver_id),
  constraint friend_requests_no_self_request check (sender_id <> receiver_id)
);

create index if not exists idx_friend_requests_sender on public.friend_requests(sender_id, status);
create index if not exists idx_friend_requests_receiver on public.friend_requests(receiver_id, status);

-- NOTIFICATIONS TABLE
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid not null constraint notifications_actor_id_fkey references public.profiles(id) on delete cascade,
  type text not null,
  entity_id uuid,
  edentity_id uuid,
  video_id uuid references public.videos(id) on delete cascade,
  comment_id uuid references public.comments(id) on delete cascade,
  friend_request_id uuid references public.friend_requests(id) on delete cascade,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

-- Ensure all columns exist even if the notifications table was already created in earlier setups
alter table public.notifications add column if not exists entity_id uuid;
alter table public.notifications add column if not exists edentity_id uuid;
alter table public.notifications add column if not exists video_id uuid;
alter table public.notifications add column if not exists comment_id uuid;
alter table public.notifications add column if not exists friend_request_id uuid;
alter table public.notifications drop constraint if exists notifications_type_check;

create index if not exists idx_notifications_recipient on public.notifications(recipient_id, created_at desc);

-- HASHTAGS TABLE
create table if not exists public.hashtags (
  id uuid primary key default gen_random_uuid(),
  tag text not null unique,
  usage_count integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_hashtags_tag_trgm on public.hashtags using gin (tag gin_trgm_ops);

-- VIDEO HASHTAGS TABLE
create table if not exists public.video_hashtags (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  hashtag_id uuid not null references public.hashtags(id) on delete cascade,
  constraint video_hashtags_video_id_hashtag_id_key unique (video_id, hashtag_id)
);

-- ==============================================================================
-- 3. TRIGGERS & FUNCTIONS FOR AUTOMATIC COUNTS & NOTIFICATIONS
-- ==============================================================================

-- 3.1 Handle new user signup trigger
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'username', 'user_' || substr(new.id::text, 1, 8)),
    coalesce(new.raw_user_meta_data ->> 'full_name', '')
  )
  on conflict (id) do update set
    username = excluded.username,
    full_name = excluded.full_name;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 3.2 Follow counts trigger & notification
create or replace function public.handle_follow_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if (TG_OP = 'INSERT') then
    update public.profiles set following_count = following_count + 1 where id = new.follower_id;
    update public.profiles set followers_count = followers_count + 1 where id = new.following_id;
    -- Insert notification
    insert into public.notifications (recipient_id, actor_id, type, entity_id)
    values (new.following_id, new.follower_id, 'new_follower', new.id);
    return new;
  elsif (TG_OP = 'DELETE') then
    update public.profiles set following_count = greatest(0, following_count - 1) where id = old.follower_id;
    update public.profiles set followers_count = greatest(0, followers_count - 1) where id = old.following_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists on_follow_changed on public.follows;
create trigger on_follow_changed
  after insert or delete on public.follows
  for each row execute procedure public.handle_follow_change();

-- 3.3 Friend requests count trigger & notification
create or replace function public.handle_friend_request_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if (TG_OP = 'INSERT') then
    if (new.status = 'pending') then
      insert into public.notifications (recipient_id, actor_id, type, entity_id, friend_request_id)
      values (new.receiver_id, new.sender_id, 'friend_request', new.id, new.id);
    elsif (new.status = 'accepted') then
      update public.profiles set friends_count = friends_count + 1 where id in (new.sender_id, new.receiver_id);
    end if;
    return new;
  elsif (TG_OP = 'UPDATE') then
    if (old.status <> 'accepted' and new.status = 'accepted') then
      update public.profiles set friends_count = friends_count + 1 where id in (new.sender_id, new.receiver_id);
      insert into public.notifications (recipient_id, actor_id, type, entity_id, friend_request_id)
      values (new.sender_id, new.receiver_id, 'friend_request_accepted', new.id, new.id);
    elsif (old.status = 'accepted' and new.status <> 'accepted') then
      update public.profiles set friends_count = greatest(0, friends_count - 1) where id in (new.sender_id, new.receiver_id);
    end if;
    return new;
  elsif (TG_OP = 'DELETE') then
    if (old.status = 'accepted') then
      update public.profiles set friends_count = greatest(0, friends_count - 1) where id in (old.sender_id, old.receiver_id);
    end if;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists on_friend_request_changed on public.friend_requests;
create trigger on_friend_request_changed
  after insert or update or delete on public.friend_requests
  for each row execute procedure public.handle_friend_request_change();

-- 3.4 Video Likes count trigger & notification
create or replace function public.handle_video_like_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_author_id uuid;
begin
  if (TG_OP = 'INSERT') then
    update public.videos set likes_count = likes_count + 1 where id = new.video_id returning user_id into v_author_id;
    if (v_author_id is not null) then
      update public.profiles set likes_count = likes_count + 1 where id = v_author_id;
      if (v_author_id <> new.user_id) then
        insert into public.notifications (recipient_id, actor_id, type, entity_id, video_id)
        values (v_author_id, new.user_id, 'video_like', new.video_id, new.video_id);
      end if;
    end if;
    return new;
  elsif (TG_OP = 'DELETE') then
    update public.videos set likes_count = greatest(0, likes_count - 1) where id = old.video_id returning user_id into v_author_id;
    if (v_author_id is not null) then
      update public.profiles set likes_count = greatest(0, likes_count - 1) where id = v_author_id;
    end if;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists on_video_like_changed on public.video_likes;
create trigger on_video_like_changed
  after insert or delete on public.video_likes
  for each row execute procedure public.handle_video_like_change();

-- 3.5 Comments count trigger & notification
create or replace function public.handle_comment_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_video_author_id uuid;
  v_parent_author_id uuid;
begin
  if (TG_OP = 'INSERT') then
    update public.videos set comments_count = comments_count + 1 where id = new.video_id returning user_id into v_video_author_id;
    if (new.parent_id is not null) then
      update public.comments set replies_count = replies_count + 1 where id = new.parent_id returning user_id into v_parent_author_id;
      if (v_parent_author_id is not null and v_parent_author_id <> new.user_id) then
        insert into public.notifications (recipient_id, actor_id, type, entity_id, video_id, comment_id)
        values (v_parent_author_id, new.user_id, 'comment_reply', new.id, new.video_id, new.id);
      end if;
    else
      if (v_video_author_id is not null and v_video_author_id <> new.user_id) then
        insert into public.notifications (recipient_id, actor_id, type, entity_id, video_id, comment_id)
        values (v_video_author_id, new.user_id, 'comment', new.id, new.video_id, new.id);
      end if;
    end if;
    return new;
  elsif (TG_OP = 'DELETE') then
    update public.videos set comments_count = greatest(0, comments_count - 1) where id = old.video_id;
    if (old.parent_id is not null) then
      update public.comments set replies_count = greatest(0, replies_count - 1) where id = old.parent_id;
    end if;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists on_comment_changed on public.comments;
create trigger on_comment_changed
  after insert or delete on public.comments
  for each row execute procedure public.handle_comment_change();

-- 3.6 Comment Likes count trigger & notification
create or replace function public.handle_comment_like_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_comment_author_id uuid;
begin
  if (TG_OP = 'INSERT') then
    update public.comments set likes_count = likes_count + 1 where id = new.comment_id returning user_id into v_comment_author_id;
    if (v_comment_author_id is not null and v_comment_author_id <> new.user_id) then
      insert into public.notifications (recipient_id, actor_id, type, entity_id, comment_id)
      values (v_comment_author_id, new.user_id, 'comment_like', new.comment_id, new.comment_id);
    end if;
    return new;
  elsif (TG_OP = 'DELETE') then
    update public.comments set likes_count = greatest(0, likes_count - 1) where id = old.comment_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists on_comment_like_changed on public.comment_likes;
create trigger on_comment_like_changed
  after insert or delete on public.comment_likes
  for each row execute procedure public.handle_comment_like_change();

-- 3.7 Saved Videos count trigger
create or replace function public.handle_saved_video_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if (TG_OP = 'INSERT') then
    update public.videos set saves_count = saves_count + 1 where id = new.video_id;
    return new;
  elsif (TG_OP = 'DELETE') then
    update public.videos set saves_count = greatest(0, saves_count - 1) where id = old.video_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists on_saved_video_changed on public.saved_videos;
create trigger on_saved_video_changed
  after insert or delete on public.saved_videos
  for each row execute procedure public.handle_saved_video_change();

-- 3.8 Reposts count trigger & notification
create or replace function public.handle_repost_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_video_author_id uuid;
begin
  if (TG_OP = 'INSERT') then
    update public.videos set reposts_count = reposts_count + 1 where id = new.video_id returning user_id into v_video_author_id;
    if (v_video_author_id is not null and v_video_author_id <> new.user_id) then
      insert into public.notifications (recipient_id, actor_id, type, entity_id, video_id)
      values (v_video_author_id, new.user_id, 'repost', new.video_id, new.video_id);
    end if;
    return new;
  elsif (TG_OP = 'DELETE') then
    update public.videos set reposts_count = greatest(0, reposts_count - 1) where id = old.video_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists on_repost_changed on public.reposts;
create trigger on_repost_changed
  after insert or delete on public.reposts
  for each row execute procedure public.handle_repost_change();

-- 3.9 Video Shares count trigger
create or replace function public.handle_video_share_insert()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update public.videos set shares_count = shares_count + 1 where id = new.video_id;
  return new;
end;
$$;

drop trigger if exists on_video_share_inserted on public.video_shares;
create trigger on_video_share_inserted
  after insert on public.video_shares
  for each row execute procedure public.handle_video_share_insert();

-- 3.10 Video Views count trigger
create or replace function public.handle_video_view_insert()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update public.videos set views_count = views_count + 1 where id = new.video_id;
  return new;
end;
$$;

drop trigger if exists on_video_view_inserted on public.video_views;
create trigger on_video_view_inserted
  after insert on public.video_views
  for each row execute procedure public.handle_video_view_insert();

-- 3.11 Hashtag usage trigger
create or replace function public.handle_video_hashtag_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if (TG_OP = 'INSERT') then
    update public.hashtags set usage_count = usage_count + 1 where id = new.hashtag_id;
    return new;
  elsif (TG_OP = 'DELETE') then
    update public.hashtags set usage_count = greatest(0, usage_count - 1) where id = old.hashtag_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists on_video_hashtag_changed on public.video_hashtags;
create trigger on_video_hashtag_changed
  after insert or delete on public.video_hashtags
  for each row execute procedure public.handle_video_hashtag_change();

-- ==============================================================================
-- 4. RPC FUNCTIONS
-- ==============================================================================

-- 4.1 Batch check interaction flags (liked, saved, reposted)
create or replace function public.get_video_interaction_flags(p_video_ids uuid[])
returns table (
  video_id uuid,
  is_liked boolean,
  is_saved boolean,
  is_reposted boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  return query
  select
    v.id as video_id,
    coalesce(bool_or(vl.user_id = v_user_id), false) as is_liked,
    coalesce(bool_or(sv.user_id = v_user_id), false) as is_saved,
    coalesce(bool_or(r.user_id = v_user_id), false) as is_reposted
  from unnest(p_video_ids) as v(id)
  left join public.video_likes vl on vl.video_id = v.id and vl.user_id = v_user_id
  left join public.saved_videos sv on sv.video_id = v.id and sv.user_id = v_user_id
  left join public.reposts r on r.video_id = v.id and r.user_id = v_user_id
  group by v.id;
end;
$$;

-- ==============================================================================
-- 5. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

alter table public.profiles enable row level security;
alter table public.videos enable row level security;
alter table public.video_likes enable row level security;
alter table public.comments enable row level security;
alter table public.comment_likes enable row level security;
alter table public.saved_videos enable row level security;
alter table public.reposts enable row level security;
alter table public.video_shares enable row level security;
alter table public.video_views enable row level security;
alter table public.follows enable row level security;
alter table public.friend_requests enable row level security;
alter table public.notifications enable row level security;
alter table public.hashtags enable row level security;
alter table public.video_hashtags enable row level security;

-- PROFILES POLICIES
drop policy if exists "Profiles are publicly readable" on public.profiles;
create policy "Profiles are publicly readable"
  on public.profiles for select
  using (true);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "Users can insert their own profile" on public.profiles;
create policy "Users can insert their own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

-- VIDEOS POLICIES
drop policy if exists "Videos are readable based on visibility" on public.videos;
create policy "Videos are readable based on visibility"
  on public.videos for select
  using (
    not is_deleted and (
      visibility = 'public'
      or user_id = auth.uid()
      or (
        visibility = 'friends' and exists (
          select 1 from public.friend_requests fr
          where fr.status = 'accepted'
            and (
              (fr.sender_id = auth.uid() and fr.receiver_id = videos.user_id)
              or (fr.receiver_id = auth.uid() and fr.sender_id = videos.user_id)
            )
        )
      )
    )
  );

drop policy if exists "Users can insert own videos" on public.videos;
create policy "Users can insert own videos"
  on public.videos for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own videos" on public.videos;
create policy "Users can update own videos"
  on public.videos for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own videos" on public.videos;
create policy "Users can delete own videos"
  on public.videos for delete
  using (auth.uid() = user_id);

-- VIDEO LIKES POLICIES
drop policy if exists "Video likes are publicly readable" on public.video_likes;
create policy "Video likes are publicly readable"
  on public.video_likes for select
  using (true);

drop policy if exists "Users can like videos" on public.video_likes;
create policy "Users can like videos"
  on public.video_likes for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can unlike videos" on public.video_likes;
create policy "Users can unlike videos"
  on public.video_likes for delete
  using (auth.uid() = user_id);

-- COMMENTS POLICIES
drop policy if exists "Comments are publicly readable" on public.comments;
create policy "Comments are publicly readable"
  on public.comments for select
  using (not is_deleted);

drop policy if exists "Users can create comments" on public.comments;
create policy "Users can create comments"
  on public.comments for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own comments" on public.comments;
create policy "Users can update own comments"
  on public.comments for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own comments" on public.comments;
create policy "Users can delete own comments"
  on public.comments for delete
  using (auth.uid() = user_id);

-- COMMENT LIKES POLICIES
drop policy if exists "Comment likes are publicly readable" on public.comment_likes;
create policy "Comment likes are publicly readable"
  on public.comment_likes for select
  using (true);

drop policy if exists "Users can like comments" on public.comment_likes;
create policy "Users can like comments"
  on public.comment_likes for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can unlike comments" on public.comment_likes;
create policy "Users can unlike comments"
  on public.comment_likes for delete
  using (auth.uid() = user_id);

-- SAVED VIDEOS POLICIES
drop policy if exists "Users can view own saved videos" on public.saved_videos;
create policy "Users can view own saved videos"
  on public.saved_videos for select
  using (auth.uid() = user_id);

drop policy if exists "Users can save videos" on public.saved_videos;
create policy "Users can save videos"
  on public.saved_videos for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can unsave videos" on public.saved_videos;
create policy "Users can unsave videos"
  on public.saved_videos for delete
  using (auth.uid() = user_id);

-- REPOSTS POLICIES
drop policy if exists "Reposts are publicly readable" on public.reposts;
create policy "Reposts are publicly readable"
  on public.reposts for select
  using (true);

drop policy if exists "Users can repost videos" on public.reposts;
create policy "Users can repost videos"
  on public.reposts for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can remove reposts" on public.reposts;
create policy "Users can remove reposts"
  on public.reposts for delete
  using (auth.uid() = user_id);

-- VIDEO SHARES POLICIES
drop policy if exists "Video shares are publicly readable" on public.video_shares;
create policy "Video shares are publicly readable"
  on public.video_shares for select
  using (true);

drop policy if exists "Anyone can record video shares" on public.video_shares;
create policy "Anyone can record video shares"
  on public.video_shares for insert
  with check (true);

-- VIDEO VIEWS POLICIES
drop policy if exists "Video views are publicly readable" on public.video_views;
create policy "Video views are publicly readable"
  on public.video_views for select
  using (true);

drop policy if exists "Anyone can record video views" on public.video_views;
create policy "Anyone can record video views"
  on public.video_views for insert
  with check (true);

-- FOLLOWS POLICIES
drop policy if exists "Follows are publicly readable" on public.follows;
create policy "Follows are publicly readable"
  on public.follows for select
  using (true);

drop policy if exists "Users can follow others" on public.follows;
create policy "Users can follow others"
  on public.follows for insert
  with check (auth.uid() = follower_id);

drop policy if exists "Users can unfollow others" on public.follows;
create policy "Users can unfollow others"
  on public.follows for delete
  using (auth.uid() = follower_id);

-- FRIEND REQUESTS POLICIES
drop policy if exists "Users can view involved friend requests" on public.friend_requests;
create policy "Users can view involved friend requests"
  on public.friend_requests for select
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

drop policy if exists "Users can send friend requests" on public.friend_requests;
create policy "Users can send friend requests"
  on public.friend_requests for insert
  with check (auth.uid() = sender_id);

drop policy if exists "Users can update involved friend requests" on public.friend_requests;
create policy "Users can update involved friend requests"
  on public.friend_requests for update
  using (auth.uid() = sender_id or auth.uid() = receiver_id)
  with check (auth.uid() = sender_id or auth.uid() = receiver_id);

drop policy if exists "Users can delete involved friend requests" on public.friend_requests;
create policy "Users can delete involved friend requests"
  on public.friend_requests for delete
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- NOTIFICATIONS POLICIES
drop policy if exists "Users can view own notifications" on public.notifications;
create policy "Users can view own notifications"
  on public.notifications for select
  using (auth.uid() = recipient_id);

drop policy if exists "Users can insert notifications" on public.notifications;
create policy "Users can insert notifications"
  on public.notifications for insert
  with check (true);

drop policy if exists "Users can update own notifications" on public.notifications;
create policy "Users can update own notifications"
  on public.notifications for update
  using (auth.uid() = recipient_id)
  with check (auth.uid() = recipient_id);

drop policy if exists "Users can delete own notifications" on public.notifications;
create policy "Users can delete own notifications"
  on public.notifications for delete
  using (auth.uid() = recipient_id);

-- HASHTAGS POLICIES
drop policy if exists "Hashtags are publicly readable" on public.hashtags;
create policy "Hashtags are publicly readable"
  on public.hashtags for select
  using (true);

drop policy if exists "Authenticated users can insert hashtags" on public.hashtags;
create policy "Authenticated users can insert hashtags"
  on public.hashtags for insert
  with check (auth.role() = 'authenticated');

drop policy if exists "Authenticated users can update hashtags" on public.hashtags;
create policy "Authenticated users can update hashtags"
  on public.hashtags for update
  using (auth.role() = 'authenticated');

-- VIDEO HASHTAGS POLICIES
drop policy if exists "Video hashtags are publicly readable" on public.video_hashtags;
create policy "Video hashtags are publicly readable"
  on public.video_hashtags for select
  using (true);

drop policy if exists "Authenticated users can insert video hashtags" on public.video_hashtags;
create policy "Authenticated users can insert video hashtags"
  on public.video_hashtags for insert
  with check (auth.role() = 'authenticated');

-- ==============================================================================
-- 6. STORAGE BUCKETS & POLICIES
-- ==============================================================================

-- Create buckets if not exist
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values 
  ('avatars', 'avatars', true, 5242880, array['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
  ('thumbnails', 'thumbnails', true, 10485760, array['image/jpeg', 'image/png', 'image/webp']),
  ('videos', 'videos', true, 524288000, array['video/mp4', 'video/quicktime', 'video/webm', 'video/3gpp', 'video/x-matroska'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Storage policies for avatars
drop policy if exists "Avatar images are publicly accessible" on storage.objects;
create policy "Avatar images are publicly accessible"
  on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists "Users can upload their own avatar" on storage.objects;
create policy "Users can upload their own avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and (auth.uid()::text = (storage.foldername(name))[1] or auth.role() = 'authenticated')
  );

drop policy if exists "Users can update their own avatar" on storage.objects;
create policy "Users can update their own avatar"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and (auth.uid()::text = (storage.foldername(name))[1] or auth.role() = 'authenticated')
  );

drop policy if exists "Users can delete their own avatar" on storage.objects;
create policy "Users can delete their own avatar"
  on storage.objects for delete
  using (
    bucket_id = 'avatars'
    and (auth.uid()::text = (storage.foldername(name))[1] or auth.role() = 'authenticated')
  );

-- Storage policies for thumbnails
drop policy if exists "Thumbnails are publicly accessible" on storage.objects;
create policy "Thumbnails are publicly accessible"
  on storage.objects for select
  using (bucket_id = 'thumbnails');

drop policy if exists "Users can upload thumbnails" on storage.objects;
create policy "Users can upload thumbnails"
  on storage.objects for insert
  with check (
    bucket_id = 'thumbnails'
    and (auth.uid()::text = (storage.foldername(name))[1] or auth.role() = 'authenticated')
  );

drop policy if exists "Users can delete own thumbnails" on storage.objects;
create policy "Users can delete own thumbnails"
  on storage.objects for delete
  using (
    bucket_id = 'thumbnails'
    and (auth.uid()::text = (storage.foldername(name))[1] or auth.role() = 'authenticated')
  );

-- Storage policies for videos
drop policy if exists "Videos are publicly accessible" on storage.objects;
create policy "Videos are publicly accessible"
  on storage.objects for select
  using (bucket_id = 'videos');

drop policy if exists "Users can upload videos" on storage.objects;
create policy "Users can upload videos"
  on storage.objects for insert
  with check (
    bucket_id = 'videos'
    and (auth.uid()::text = (storage.foldername(name))[1] or auth.role() = 'authenticated')
  );

drop policy if exists "Users can delete own videos" on storage.objects;
create policy "Users can delete own videos"
  on storage.objects for delete
  using (
    bucket_id = 'videos'
    and (auth.uid()::text = (storage.foldername(name))[1] or auth.role() = 'authenticated')
  );
