-- Kadence v2 schema — auth-backed (updated spec §5, §5a)
--
-- ⚠️  DESTRUCTIVE — DO NOT RUN THIS AGAINST THE LIVE DATABASE.
--
-- This file drops and recreates every table. It was safe exactly once,
-- when the project held nothing but smoke-test data. There is real logged
-- data now, so running it again would delete it.
--
-- It is kept only as a record of the original structure, and as the script
-- you would use to stand up a brand-new, empty Supabase project. Ongoing
-- changes go in supabase/migrations/ as additive files instead.
--
-- This REPLACES the previous open-anon-key schema entirely (drop + recreate,
-- not an in-place migration). Since the project only ever had smoke-test
-- data on it, a clean replacement is simpler and safer than migrating old
-- open-access tables to RLS in place. Run this whole file, once, in the
-- Supabase SQL Editor (Project → SQL Editor → New query → paste → Run).

drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();

drop table if exists log_entry cascade;
drop table if exists reading cascade;
drop table if exists signal cascade;
drop table if exists reflection cascade;
drop table if exists tag cascade;
drop table if exists habit cascade;
drop table if exists profile cascade;

drop type if exists domain_type cascade;
drop type if exists tier_type cascade;
drop type if exists direction_type cascade;
drop type if exists privacy_tier_type cascade;
drop type if exists reading_type cascade;

create extension if not exists pgcrypto;

create type domain_type as enum ('wellbeing', 'knowledge', 'creativity', 'systems');
create type tier_type as enum ('anchor', 'practice');
create type direction_type as enum ('build', 'reduce');
create type privacy_tier_type as enum ('normal', 'sensitive');
create type reading_type as enum ('tarot', 'astrology', 'other');

-- profile ------------------------------------------------------------------
-- One row per user, created automatically on first sign-in (trigger below).
-- birthdate/birth_time/birth_location are captured now for a future
-- chart-calculation feature but have no functional use yet — treat as
-- sensitive (spec §7).
create table profile (
  user_id          uuid primary key references auth.users(id) on delete cascade,
  nickname         text,
  birthdate        date,
  birth_time       time,
  birth_location   text,
  current_location text,
  created_at       timestamptz not null default now()
);

create table habit (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users(id) on delete cascade default auth.uid(),
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

create table log_entry (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade default auth.uid(),
  habit_id      uuid not null references habit(id) on delete cascade,
  date          date not null,
  done_value    smallint not null,
  note          text,
  tags          text[] check (tags is null or array_length(tags, 1) <= 3),
  break_context text,
  created_at    timestamptz not null default now(),
  privacy_tier  privacy_tier_type not null default 'normal',
  unique (habit_id, date)
);

create table reading (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade default auth.uid(),
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
  user_id    uuid not null references auth.users(id) on delete cascade default auth.uid(),
  date       date not null,
  metric     text not null,
  value      numeric not null,
  source     text not null default 'manual',
  created_at timestamptz not null default now()
);

create table reflection (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade default auth.uid(),
  week_start      date not null,
  went_well       text,
  what_broke      text,
  pattern_noticed text,
  created_at      timestamptz not null default now(),
  unique (user_id, week_start)
);

-- Case-insensitive matching (spec §6) happens in the Swift layer (TagService)
-- before insert — canonical is always stored lowercase+trimmed there.
create table tag (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade default auth.uid(),
  canonical   text not null,
  display     text not null,
  usage_count int not null default 0,
  unique (user_id, canonical)
);

create index on log_entry (user_id, habit_id, date);
create index on log_entry (user_id, date);
create index on reading (user_id, date);
create index on signal (user_id, date, metric);
create index on habit (user_id);
create index on tag (user_id);

-- Auto-create a profile row on first sign-in --------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profile (user_id) values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Row Level Security ---------------------------------------------------------
-- Every table scoped to auth.uid() = user_id (spec §5a, §7). This replaces
-- the earlier "anon full access" model entirely — that model is superseded,
-- not layered on top of. The app must now hold an authenticated session
-- (Sign in with Apple) to read or write anything.

alter table profile    enable row level security;
alter table habit      enable row level security;
alter table log_entry  enable row level security;
alter table reading    enable row level security;
alter table signal     enable row level security;
alter table reflection enable row level security;
alter table tag        enable row level security;

create policy "owner only" on profile    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner only" on habit      for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner only" on log_entry  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner only" on reading    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner only" on signal     for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner only" on reflection for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner only" on tag        for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
