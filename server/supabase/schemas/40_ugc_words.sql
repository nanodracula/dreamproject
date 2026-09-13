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
