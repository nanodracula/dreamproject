create table public.curated_sentences (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  status public.content_status not null default 'published',

  lang text not null,
  title text not null,
  sentence_type public.sentence_type not null,
  source text null,

  writing_phonetic text null,
  writing_transliterated text not null,

  difficulty_level smallint null,
  tags text[] not null default '{}'::text[],

  translations jsonb not null default '{}'::jsonb,
  breakdown jsonb not null
    default '{"schemaVersion":1,"items":[]}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,

  constraint curated_sentences_metadata_is_object
    check (jsonb_typeof(metadata) = 'object')
);

alter table public.curated_sentences enable row level security;

revoke all on table public.curated_sentences from anon, authenticated;
grant select on table public.curated_sentences to anon, authenticated;
grant all on table public.curated_sentences to service_role;

create policy "Published curated sentences are publicly readable"
on public.curated_sentences
for select
to anon, authenticated
using (status = 'published');

comment on table public.curated_sentences is
  'Curated phrases, complete sentences, and questions used as learning content.';

comment on column public.curated_sentences.sentence_type is
  'Classified as question when interrogative, sentence when complete, otherwise phrase.';
