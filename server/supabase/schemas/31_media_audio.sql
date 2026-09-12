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
