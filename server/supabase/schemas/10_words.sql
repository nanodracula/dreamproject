create table public.words (
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

  constraint words_metadata_is_object
    check (jsonb_typeof(metadata) = 'object')
);

alter table public.words enable row level security;

revoke all on table public.words from anon, authenticated;
grant select on table public.words to anon, authenticated;
grant all on table public.words to service_role;

create policy "Published words are publicly readable"
on public.words
for select
to anon, authenticated
using (status = 'published');

comment on table public.words is
  'Vocabulary entries where each row represents one word sense.';

comment on column public.words.definition is
  'English definition of the word sense.';
