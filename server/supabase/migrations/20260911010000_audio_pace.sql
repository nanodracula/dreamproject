create type public.audio_pace as enum ('slow', 'normal', 'fast');

alter table public.media_audio
  add column pace public.audio_pace not null default 'normal';

drop index public.media_audio_one_primary_per_variant_idx;

create unique index media_audio_one_primary_per_variant_idx
  on public.media_audio (owner_type, owner_id, audio_type, lang, locale, pace)
  nulls not distinct
  where is_primary;

comment on column public.media_audio.pace is
  'Recording pace label; independent of playback rate and provider voice settings.';

notify pgrst, 'reload schema';
