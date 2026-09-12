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
