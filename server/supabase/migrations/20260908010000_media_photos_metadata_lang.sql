alter table public.media_photos
  alter column metadata set default
    '{"schemaVersion":1,"width":null,"height":null,"lang":null,"ai":null}'::jsonb;

notify pgrst, 'reload schema';
