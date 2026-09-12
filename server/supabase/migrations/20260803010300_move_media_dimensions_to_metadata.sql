alter table public.media_photos
  alter column metadata set default
    '{"schemaVersion":1,"width":null,"height":null,"ai":null}'::jsonb;

update public.media_photos
set metadata =
  '{"schemaVersion":1,"ai":null}'::jsonb
  || metadata
  || jsonb_build_object('width', width, 'height', height);

alter table public.media_photos
  drop column width,
  drop column height;

comment on column public.media_photos.metadata is
  'Versioned photo metadata including dimensions and AI generation details.';

alter table public.media_audio
  alter column metadata set default
    '{"schemaVersion":1,"speakerGender":null,"ai":null}'::jsonb;

update public.media_audio
set metadata =
  '{"schemaVersion":1,"speakerGender":null,"ai":null}'::jsonb
  || metadata;

alter table public.media_videos
  alter column metadata set default
    '{"schemaVersion":1,"width":null,"height":null,"ai":null}'::jsonb;

update public.media_videos
set metadata =
  '{"schemaVersion":1,"ai":null}'::jsonb
  || metadata
  || jsonb_build_object('width', width, 'height', height);

alter table public.media_videos
  drop column width,
  drop column height;

comment on column public.media_videos.metadata is
  'Versioned video metadata including dimensions and AI generation details.';

notify pgrst, 'reload schema';
