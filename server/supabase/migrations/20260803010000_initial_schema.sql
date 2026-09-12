create type public.content_status as enum (
  'draft',
  'pending',
  'published',
  'archived'
);

create type public.universal_part_of_speech as enum (
  'ADJ',
  'ADP',
  'ADV',
  'AUX',
  'CCONJ',
  'DET',
  'INTJ',
  'NOUN',
  'NUM',
  'PART',
  'PRON',
  'PROPN',
  'PUNCT',
  'SCONJ',
  'SYM',
  'VERB',
  'X'
);

create type public.sentence_type as enum (
  'phrase',
  'sentence',
  'question'
);

create type public.media_owner_type as enum (
  'word',
  'sentence'
);

create type public.media_audio_type as enum (
  'original',
  'translation'
);

create table public.words (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  status public.content_status not null default 'published',

  lang text not null,
  title text not null,
  base_form text null,
  definition text not null,

  writing_phonetic text null,
  writing_transliterated text not null,

  part_of_speech public.universal_part_of_speech not null,

  frequency_rank integer null,
  difficulty_level smallint null,

  tags text[] not null default '{}'::text[],
  translations jsonb not null default '{}'::jsonb,
  sentence_ids uuid[] not null default '{}'::uuid[],
  metadata jsonb not null default '{}'::jsonb,

  constraint words_metadata_is_object
    check (jsonb_typeof(metadata) = 'object')
);

alter table public.words enable row level security;

revoke all on table public.words from anon, authenticated;
grant select on table public.words to anon, authenticated;
grant all on table public.words to service_role;

create policy "Published words are publicly readable"
on public.words
for select
to anon, authenticated
using (status = 'published');

comment on table public.words is
  'Vocabulary entries where each row represents one word sense.';

comment on column public.words.definition is
  'English definition of the word sense.';

create table public.sentences (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  status public.content_status not null default 'published',

  lang text not null,
  title text not null,
  sentence_type public.sentence_type not null,
  source text null,

  writing_phonetic text null,
  writing_transliterated text not null,

  difficulty_level smallint null,
  tags text[] not null default '{}'::text[],

  translations jsonb not null default '{}'::jsonb,
  breakdown jsonb not null
    default '{"schemaVersion":1,"items":[]}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,

  constraint sentences_metadata_is_object
    check (jsonb_typeof(metadata) = 'object')
);

alter table public.sentences enable row level security;

revoke all on table public.sentences from anon, authenticated;
grant select on table public.sentences to anon, authenticated;
grant all on table public.sentences to service_role;

create policy "Published sentences are publicly readable"
on public.sentences
for select
to anon, authenticated
using (status = 'published');

comment on table public.sentences is
  'Phrases, complete sentences, and questions used as learning content.';

comment on column public.sentences.sentence_type is
  'Classified as question when interrogative, sentence when complete, otherwise phrase.';

create table public.media_photos (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  status public.content_status not null default 'published',

  owner_type public.media_owner_type not null,
  owner_id uuid not null,

  object_path text not null unique,
  is_primary boolean not null default false,

  source text null,
  photo_type text not null,
  style text null,
  width integer null,
  height integer null,

  tags text[] not null default '{}'::text[],
  metadata jsonb not null default '{}'::jsonb,

  constraint media_photos_photo_type_is_not_blank
    check (length(btrim(photo_type)) > 0),
  constraint media_photos_width_is_positive
    check (width is null or width > 0),
  constraint media_photos_height_is_positive
    check (height is null or height > 0),
  constraint media_photos_metadata_is_object
    check (jsonb_typeof(metadata) = 'object')
);

create index media_photos_owner_idx
  on public.media_photos (owner_type, owner_id);

create unique index media_photos_one_primary_per_owner_idx
  on public.media_photos (owner_type, owner_id)
  where is_primary;

alter table public.media_photos enable row level security;

revoke all on table public.media_photos from anon, authenticated;
grant select on table public.media_photos to anon, authenticated;
grant all on table public.media_photos to service_role;

create policy "Published media photos are publicly readable"
on public.media_photos
for select
to anon, authenticated
using (status = 'published');

comment on table public.media_photos is
  'Photo assets owned by words or sentences and stored through Supabase Storage.';

comment on column public.media_photos.metadata is
  'Extensible photo metadata such as alt text and generation details.';

create table public.media_audio (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  status public.content_status not null default 'published',

  owner_type public.media_owner_type not null,
  owner_id uuid not null,

  object_path text not null unique,
  is_primary boolean not null default false,

  source text null,
  audio_type public.media_audio_type not null,
  lang text not null,
  locale text null,
  voice text null,
  duration_ms integer null,

  subtitle_tracks jsonb not null default '[]'::jsonb,
  tags text[] not null default '{}'::text[],
  metadata jsonb not null default '{}'::jsonb,

  constraint media_audio_lang_is_not_blank
    check (length(btrim(lang)) > 0),
  constraint media_audio_duration_is_not_negative
    check (duration_ms is null or duration_ms >= 0),
  constraint media_audio_subtitle_tracks_is_array
    check (jsonb_typeof(subtitle_tracks) = 'array'),
  constraint media_audio_metadata_is_object
    check (jsonb_typeof(metadata) = 'object')
);

create index media_audio_owner_idx
  on public.media_audio (owner_type, owner_id);

create unique index media_audio_one_primary_per_variant_idx
  on public.media_audio (owner_type, owner_id, audio_type, lang, locale)
  nulls not distinct
  where is_primary;

alter table public.media_audio enable row level security;

revoke all on table public.media_audio from anon, authenticated;
grant select on table public.media_audio to anon, authenticated;
grant all on table public.media_audio to service_role;

create policy "Published media audio is publicly readable"
on public.media_audio
for select
to anon, authenticated
using (status = 'published');

comment on table public.media_audio is
  'Original and translated audio assets owned by words or sentences.';

comment on column public.media_audio.subtitle_tracks is
  'Versioned subtitle or karaoke track descriptors associated with this recording.';

comment on column public.media_audio.metadata is
  'Extensible audio metadata such as codec and generation details.';

create table public.media_videos (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  status public.content_status not null default 'published',

  owner_type public.media_owner_type not null,
  owner_id uuid not null,

  object_path text not null unique,
  is_primary boolean not null default false,

  source text null,
  video_type text not null,
  lang text null,
  locale text null,
  duration_ms integer null,
  width integer null,
  height integer null,

  subtitle_tracks jsonb not null default '[]'::jsonb,
  tags text[] not null default '{}'::text[],
  metadata jsonb not null default '{}'::jsonb,

  constraint media_videos_video_type_is_not_blank
    check (length(btrim(video_type)) > 0),
  constraint media_videos_duration_is_not_negative
    check (duration_ms is null or duration_ms >= 0),
  constraint media_videos_width_is_positive
    check (width is null or width > 0),
  constraint media_videos_height_is_positive
    check (height is null or height > 0),
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

comment on column public.media_videos.subtitle_tracks is
  'Versioned subtitle track descriptors associated with this video.';

comment on column public.media_videos.metadata is
  'Extensible video metadata such as codec and generation details.';
