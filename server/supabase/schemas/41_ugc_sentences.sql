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
