create table public.media_videos (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  status public.content_status not null default 'published',

  owner_type public.media_owner_type not null,
  owner_id uuid not null,

  object_path text not null unique,
  is_primary boolean not null default false,

  origin public.media_origin not null,
  source text null,
  video_type text not null,
  lang text null,
  locale text null,
  duration_ms integer null,

  subtitle_tracks jsonb not null default '[]'::jsonb,
  tags text[] not null default '{}'::text[],
  metadata jsonb not null default
    '{"schemaVersion":1,"width":null,"height":null,"ai":null}'::jsonb,

  constraint media_videos_video_type_is_not_blank
    check (length(btrim(video_type)) > 0),
  constraint media_videos_duration_is_not_negative
    check (duration_ms is null or duration_ms >= 0),
  constraint media_videos_subtitle_tracks_is_array
    check (jsonb_typeof(subtitle_tracks) = 'array'),
  constraint media_videos_metadata_is_object
    check (jsonb_typeof(metadata) = 'object')
);

create index media_videos_owner_idx
  on public.media_videos (owner_type, owner_id);

create unique index media_videos_one_primary_per_variant_idx
  on public.media_videos (owner_type, owner_id, video_type, lang, locale)
  nulls not distinct
  where is_primary;

alter table public.media_videos enable row level security;

revoke all on table public.media_videos from anon, authenticated;
grant select on table public.media_videos to anon, authenticated;
grant all on table public.media_videos to service_role;

create policy "Published media videos are publicly readable"
on public.media_videos
for select
to anon, authenticated
using (status = 'published');

comment on table public.media_videos is
  'Video assets owned by words or sentences and stored through Supabase Storage.';

comment on column public.media_videos.origin is
  'Creation origin: AI-generated, user-supplied, or curated.';

comment on column public.media_videos.source is
  'Optional provider, source URL, import source, or attribution.';

comment on column public.media_videos.subtitle_tracks is
  'Versioned subtitle track descriptors associated with this video.';

comment on column public.media_videos.metadata is
  'Versioned video metadata including dimensions and AI generation details.';
