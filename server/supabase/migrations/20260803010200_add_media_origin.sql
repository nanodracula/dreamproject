create type public.media_origin as enum (
  'ai',
  'user',
  'curated'
);

comment on type public.media_origin is
  'Creation origin for a media asset: AI-generated, user-supplied, or curated.';

alter table public.media_photos
  add column origin public.media_origin not null;

alter table public.media_audio
  add column origin public.media_origin not null;

alter table public.media_videos
  add column origin public.media_origin not null;

comment on column public.media_photos.origin is
  'Creation origin: AI-generated, user-supplied, or curated.';

comment on column public.media_photos.source is
  'Optional provider, source URL, import source, or attribution.';

comment on column public.media_audio.origin is
  'Creation origin: AI-generated, user-supplied, or curated.';

comment on column public.media_audio.source is
  'Optional provider, source URL, import source, or attribution.';

comment on column public.media_videos.origin is
  'Creation origin: AI-generated, user-supplied, or curated.';

comment on column public.media_videos.source is
  'Optional provider, source URL, import source, or attribution.';

notify pgrst, 'reload schema';
