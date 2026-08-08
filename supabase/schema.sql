-- Kadence v2 schema
-- Mirrors docs/kadence-spec.md §5. Run this in the Supabase SQL editor
-- (Project → SQL Editor → New query) once, on a fresh project.

create extension if not exists pgcrypto;

create type domain_type as enum ('wellbeing', 'knowledge', 'creativity', 'systems');
create type tier_type as enum ('anchor', 'practice');
create type direction_type as enum ('build', 'reduce');
create type privacy_tier_type as enum ('normal', 'sensitive');
create type reading_type as enum ('tarot', 'astrology', 'other');

create table habit (
  id                 uuid primary key default gen_random_uuid(),
  name               text not null,
  domain             domain_type not null,
  tier               tier_type not null,
  direction          direction_type not null default 'build',
  days_active        int[] not null default '{0,1,2,3,4,5,6}',
  identity_statement text,
  stack_cue          text,
  streak_count       int not null default 0,
  created_at         timestamptz not null default now(),
  archived_at        timestamptz
);

-- done_value holds a boolean-as-0/1 for anchor-style habits, or a 1-5 scale
-- for habits configured with a scale. Which interpretation applies is a
-- property of the parent habit (app-layer concern), not the schema.
create table log_entry (
  id            uuid primary key default gen_random_uuid(),
  habit_id      uuid not null references habit(id) on delete cascade,
  date          date not null,
  done_value    smallint not null,
  note          text,
  tags          text[] check (tags is null or array_length(tags, 1) <= 3),
  break_context text,
  created_at    timestamptz not null default now(),
  privacy_tier  privacy_tier_type not null default 'normal'
);

create table reading (
  id         uuid primary key default gen_random_uuid(),
  date       date not null,
  type       reading_type not null,
  deck       text,
  spread     text,
  cards      text[],
  notes      text not null default '',
  tags       text[] check (tags is null or array_length(tags, 1) <= 3),
  created_at timestamptz not null default now()
);

create table signal (
  id         uuid primary key default gen_random_uuid(),
  date       date not null,
  metric     text not null,
  value      numeric not null,
  source     text not null default 'manual',
  created_at timestamptz not null default now()
);

create table reflection (
  id              uuid primary key default gen_random_uuid(),
  week_start      date not null unique,
  went_well       text,
  what_broke      text,
  pattern_noticed text,
  created_at      timestamptz not null default now()
);

create table tag (
  id           uuid primary key default gen_random_uuid(),
  canonical    text not null unique,
  display      text not null,
  usage_count  int not null default 0
);

create index on log_entry (habit_id, date);
create index on log_entry (date);
create index on reading (date);
create index on signal (date, metric);

-- Row Level Security -----------------------------------------------------
-- This app has no Supabase Auth login screen: the iOS app connects with the
-- anon key only. The policies below grant that key full read/write access.
-- That means anyone who obtains the project URL + anon key can read or
-- write this data. That's an accepted tradeoff for a solo personal project
-- (see docs/kadence-spec.md §7) — revisit with real auth if that changes.

alter table habit      enable row level security;
alter table log_entry  enable row level security;
alter table reading    enable row level security;
alter table signal     enable row level security;
alter table reflection enable row level security;
alter table tag        enable row level security;

create policy "anon full access" on habit      for all using (true) with check (true);
create policy "anon full access" on log_entry  for all using (true) with check (true);
create policy "anon full access" on reading    for all using (true) with check (true);
create policy "anon full access" on signal     for all using (true) with check (true);
create policy "anon full access" on reflection for all using (true) with check (true);
create policy "anon full access" on tag        for all using (true) with check (true);
