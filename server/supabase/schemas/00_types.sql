create type public.content_status as enum (
  'draft',
  'pending',
  'published',
  'archived'
);

create type public.universal_part_of_speech as enum (
  'ADJ',
  'ADP',
  'ADV',
  'AUX',
  'CCONJ',
  'DET',
  'INTJ',
  'NOUN',
  'NUM',
  'PART',
  'PRON',
  'PROPN',
  'PUNCT',
  'SCONJ',
  'SYM',
  'VERB',
  'X'
);

create type public.sentence_type as enum (
  'phrase',
  'sentence',
  'question'
);

create type public.media_owner_type as enum (
  'word',
  'sentence'
);

create type public.media_origin as enum (
  'ai',
  'user',
  'curated'
);

comment on type public.media_origin is
  'Creation origin for a media asset: AI-generated, user-supplied, or curated.';

create type public.media_audio_type as enum (
  'original',
  'translation'
);

create type public.knowledge_level as enum (
  'beginner',
  'intermediate',
  'advanced'
);

create type public.writing_display_mode as enum (
  'standardOnly',
  'standardAndPhonetic',
  'standardAndTransliterated',
  'standardAndPhoneticAndTransliterated'
);

comment on type public.writing_display_mode is
  'Reading aids shown next to the standard writing: phonetic and/or transliterated layers.';

create type public.audio_pace as enum ('slow', 'normal', 'fast');
