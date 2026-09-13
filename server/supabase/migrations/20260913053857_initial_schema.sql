-- Initial application schema and storage configuration.
-- The auth and storage schemas are managed by Supabase.

-- Source: schemas/00_types.sql

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

create type public.media_origin as enum (
  'ai',
  'user',
  'curated'
);

comment on type public.media_origin is
  'Creation origin for a media asset: AI-generated, user-supplied, or curated.';

create type public.media_audio_type as enum (
  'original',
  'translation'
);

create type public.knowledge_level as enum (
  'beginner',
  'intermediate',
  'advanced'
);

create type public.writing_display_mode as enum (
  'standardOnly',
  'standardAndPhonetic',
  'standardAndTransliterated',
  'standardAndPhoneticAndTransliterated'
);

comment on type public.writing_display_mode is
  'Reading aids shown next to the standard writing: phonetic and/or transliterated layers.';

create type public.audio_pace as enum ('slow', 'normal', 'fast');

-- Source: schemas/10_curated_words.sql

create table public.curated_words (
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

  constraint curated_words_metadata_is_object
    check (jsonb_typeof(metadata) = 'object')
);

alter table public.curated_words enable row level security;

revoke all on table public.curated_words from anon, authenticated;
grant select on table public.curated_words to anon, authenticated;
grant all on table public.curated_words to service_role;

create policy "Published curated words are publicly readable"
on public.curated_words
for select
to anon, authenticated
using (status = 'published');

comment on table public.curated_words is
  'Curated vocabulary entries where each row represents one word sense.';

comment on column public.curated_words.definition is
  'English definition of the word sense.';

-- Source: schemas/20_curated_sentences.sql

create table public.curated_sentences (
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

  constraint curated_sentences_metadata_is_object
    check (jsonb_typeof(metadata) = 'object')
);

alter table public.curated_sentences enable row level security;

revoke all on table public.curated_sentences from anon, authenticated;
grant select on table public.curated_sentences to anon, authenticated;
grant all on table public.curated_sentences to service_role;

create policy "Published curated sentences are publicly readable"
on public.curated_sentences
for select
to anon, authenticated
using (status = 'published');

comment on table public.curated_sentences is
  'Curated phrases, complete sentences, and questions used as learning content.';

comment on column public.curated_sentences.sentence_type is
  'Classified as question when interrogative, sentence when complete, otherwise phrase.';

-- Source: schemas/30_media_photos.sql

create table public.media_photos (
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
  photo_type text not null,
  style text null,

  tags text[] not null default '{}'::text[],
  metadata jsonb not null default
    '{"schemaVersion":1,"width":null,"height":null,"lang":null,"ai":null}'::jsonb,

  constraint media_photos_photo_type_is_not_blank
    check (length(btrim(photo_type)) > 0),
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

comment on column public.media_photos.origin is
  'Creation origin: AI-generated, user-supplied, or curated.';

comment on column public.media_photos.source is
  'Optional provider, source URL, import source, or attribution.';

comment on column public.media_photos.metadata is
  'Versioned photo metadata including dimensions and AI generation details.';

-- Source: schemas/31_media_audio.sql

create table public.media_audio (
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
  audio_type public.media_audio_type not null,
  pace public.audio_pace not null default 'normal',
  lang text not null,
  locale text null,
  voice text null,
  duration_ms integer null,

  subtitle_tracks jsonb not null default '[]'::jsonb,
  tags text[] not null default '{}'::text[],
  metadata jsonb not null default
    '{"schemaVersion":1,"speakerGender":null,"ai":null}'::jsonb,

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
  on public.media_audio (owner_type, owner_id, audio_type, lang, locale, pace)
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

comment on column public.media_audio.origin is
  'Creation origin: AI-generated, user-supplied, or curated.';

comment on column public.media_audio.source is
  'Optional provider, source URL, import source, or attribution.';

comment on column public.media_audio.subtitle_tracks is
  'Versioned subtitle or karaoke track descriptors associated with this recording.';

comment on column public.media_audio.metadata is
  'Extensible audio metadata such as codec and generation details.';

comment on column public.media_audio.pace is
  'Recording pace label; independent of playback rate and provider voice settings.';

-- Source: schemas/32_media_videos.sql

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

-- Source: schemas/40_ugc_words.sql

create table public.ugc_words (
  user_id uuid not null references auth.users(id) on delete cascade,
  id uuid not null,
  created_at timestamptz(3) not null,
  updated_at timestamptz(3) not null,
  deleted_at timestamptz(3) null,

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
  translations text not null,
  sentence_ids uuid[] not null default '{}'::uuid[],
  photo jsonb not null default '{}'::jsonb,
  audio jsonb not null default '{}'::jsonb,
  favorited_at timestamptz(3) null,

  primary key (user_id, id),
  constraint ugc_words_photo_is_object
    check (jsonb_typeof(photo) = 'object'),
  constraint ugc_words_audio_is_object
    check (jsonb_typeof(audio) = 'object')
);

create index ugc_words_user_updated_idx
  on public.ugc_words (user_id, updated_at, id);

alter table public.ugc_words enable row level security;

revoke all on table public.ugc_words from anon, authenticated;
grant select, insert, update on table public.ugc_words to authenticated;
grant all on table public.ugc_words to service_role;

create policy "Users can read their own UGC words"
on public.ugc_words
for select
to authenticated
using (user_id = (select auth.uid()));

create policy "Users can insert their own UGC words"
on public.ugc_words
for insert
to authenticated
with check (user_id = (select auth.uid()));

create policy "Users can update their own UGC words"
on public.ugc_words
for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

comment on table public.ugc_words is
  'User-owned word cards with embedded media and ordered example sentence IDs.';

comment on column public.ugc_words.translations is
  'The single translation for the user''s selected native language, stored as text.';

comment on column public.ugc_words.sentence_ids is
  'Ordered example sentence IDs, without foreign keys to allow independent record arrival.';

-- Source: schemas/41_ugc_sentences.sql

create table public.ugc_sentences (
  user_id uuid not null references auth.users(id) on delete cascade,
  id uuid not null,
  created_at timestamptz(3) not null,
  updated_at timestamptz(3) not null,
  deleted_at timestamptz(3) null,

  lang text not null,
  title text not null,
  sentence_type public.sentence_type not null,
  source text null,

  writing_phonetic text null,
  writing_transliterated text not null,

  difficulty_level smallint null,
  tags text[] not null default '{}'::text[],

  translations text not null,
  breakdown jsonb not null
    default '{"schemaVersion":1,"items":[]}'::jsonb,
  photo jsonb not null default '{}'::jsonb,
  audio jsonb not null default '{}'::jsonb,
  favorited_at timestamptz(3) null,

  primary key (user_id, id),
  constraint ugc_sentences_breakdown_is_object
    check (jsonb_typeof(breakdown) = 'object'),
  constraint ugc_sentences_photo_is_object
    check (jsonb_typeof(photo) = 'object'),
  constraint ugc_sentences_audio_is_object
    check (jsonb_typeof(audio) = 'object')
);

create index ugc_sentences_user_updated_idx
  on public.ugc_sentences (user_id, updated_at, id);

alter table public.ugc_sentences enable row level security;

revoke all on table public.ugc_sentences from anon, authenticated;
grant select, insert, update on table public.ugc_sentences to authenticated;
grant all on table public.ugc_sentences to service_role;

create policy "Users can read their own UGC sentences"
on public.ugc_sentences
for select
to authenticated
using (user_id = (select auth.uid()));

create policy "Users can insert their own UGC sentences"
on public.ugc_sentences
for insert
to authenticated
with check (user_id = (select auth.uid()));

create policy "Users can update their own UGC sentences"
on public.ugc_sentences
for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

comment on table public.ugc_sentences is
  'User-owned sentence cards with embedded media and a word-by-word breakdown.';

comment on column public.ugc_sentences.translations is
  'The single translation for the user''s selected native language, stored as text.';

-- Storage buckets and user upload policies.

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values
  (
    'photos',
    'photos',
    true,
    10485760,
    array['image/jpeg', 'image/png', 'image/webp', 'image/avif']::text[]
  ),
  (
    'audio',
    'audio',
    true,
    20971520,
    array['audio/mpeg', 'audio/mp4', 'audio/x-m4a', 'audio/wav', 'audio/ogg', 'audio/webm']::text[]
  ),
  (
    'videos',
    'videos',
    true,
    524288000,
    array['video/mp4', 'video/webm', 'video/quicktime']::text[]
  ),
  (
    'ugc-photos',
    'ugc-photos',
    true,
    10485760,
    array['image/jpeg', 'image/png', 'image/webp', 'image/avif']::text[]
  ),
  (
    'ugc-audio',
    'ugc-audio',
    true,
    20971520,
    array['audio/mpeg', 'audio/mp4', 'audio/x-m4a', 'audio/wav', 'audio/ogg', 'audio/webm']::text[]
  ),
  (
    'ugc-videos',
    'ugc-videos',
    true,
    524288000,
    array['video/mp4', 'video/webm', 'video/quicktime']::text[]
  )
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types,
  updated_at = now();

create policy "Users can upload their own UGC"
on storage.objects
for insert
to authenticated
with check (
  bucket_id in ('ugc-photos', 'ugc-audio', 'ugc-videos')
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "Users can list their own UGC"
on storage.objects
for select
to authenticated
using (
  bucket_id in ('ugc-photos', 'ugc-audio', 'ugc-videos')
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "Users can delete their own UGC"
on storage.objects
for delete
to authenticated
using (
  bucket_id in ('ugc-photos', 'ugc-audio', 'ugc-videos')
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

notify pgrst, 'reload schema';
