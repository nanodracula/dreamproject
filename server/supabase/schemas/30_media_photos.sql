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
