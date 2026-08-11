-- Kadence — additive migration: card log, natal chart, daily energy.
--
-- ADDITIVE ONLY. Nothing here drops, truncates, or alters an existing
-- table, so it is safe to run against a database already holding real
-- habit data. Every statement is guarded, so re-running it is also safe.
--
-- Run in the Supabase SQL Editor (Project → SQL Editor → New query →
-- paste → Run). Unlike schema.sql, this file does NOT rebuild anything.

create extension if not exists pgcrypto;

-- Types ---------------------------------------------------------------------
-- Guarded rather than `drop type ... cascade` (which would drop dependent
-- columns). `if not exists` isn't available for create type, hence the
-- exception block.

do $$ begin
  create type draw_role as enum ('daily', 'jumper');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type zodiac_sign as enum (
    'aries', 'taurus', 'gemini', 'cancer', 'leo', 'virgo',
    'libra', 'scorpio', 'sagittarius', 'capricorn', 'aquarius', 'pisces'
  );
exception when duplicate_object then null;
end $$;

-- deck ----------------------------------------------------------------------
-- `tradition` is plain text rather than an enum: adding a tradition later
-- to a Postgres enum needs an ALTER TYPE, and decks are exactly the kind of
-- thing that grows. Zodiac signs get an enum because that set is closed.
create table if not exists deck (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade default auth.uid(),
  name           text not null,
  tradition      text not null default 'Rider-Waite-Smith',
  uses_reversals boolean not null default true,
  created_at     timestamptz not null default now(),
  archived_at    timestamptz
);

-- natal_chart ---------------------------------------------------------------
-- user_id is the primary key, so one chart per user is enforced by the
-- database rather than by whichever query happens to run first — the
-- duplicate-chart bug can't recur.
create table if not exists natal_chart (
  user_id                    uuid primary key references auth.users(id) on delete cascade default auth.uid(),
  sun                        zodiac_sign not null,
  moon                       zodiac_sign not null,
  mercury                    zodiac_sign not null,
  venus                      zodiac_sign not null,
  mars                       zodiac_sign not null,
  jupiter                    zodiac_sign not null,
  saturn                     zodiac_sign not null,
  uranus                     zodiac_sign not null,
  neptune                    zodiac_sign not null,
  pluto                      zodiac_sign not null,
  ascendant                  zodiac_sign not null,
  midheaven                  zodiac_sign not null,
  birth_date_description     text,
  birth_time_description     text,
  birth_location_description text,
  user_note                  text,
  created_at                 timestamptz not null default now(),
  updated_at                 timestamptz not null default now()
);

-- entry ---------------------------------------------------------------------
-- One row per day (unique on user_id, date), matching log_entry's shape so
-- a day's card and a day's habits join on the same date.
--
-- deck_id is `on delete set null`: removing a deck must not erase the
-- history of what you drew from it.
create table if not exists entry (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users(id) on delete cascade default auth.uid(),
  date               date not null,
  deck_id            uuid references deck(id) on delete set null,
  skipped            boolean not null default false,
  morning_read       text,
  evening_reflection text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (user_id, date)
);

-- draw ----------------------------------------------------------------------
-- resonance_tier/resonance_note are frozen at draw time (v3 spec §Data
-- model): if the chart is corrected later, past entries must still read as
-- they did on the day, or the archive rewrites its own history.
--
-- card_name is stored alongside card_id so an entry stays readable even if
-- a catalog id is ever renamed.
create table if not exists draw (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade default auth.uid(),
  entry_id       uuid not null references entry(id) on delete cascade,
  card_id        text,
  card_name      text not null,
  role           draw_role not null default 'daily',
  reversed       boolean not null default false,
  resonance_tier text,
  resonance_note text,
  created_at     timestamptz not null default now()
);

-- day_energy ----------------------------------------------------------------
-- The 1–3 capacity check (Cosmic Container spec §2). Kept in its own table
-- rather than added to `signal`: signal is objective instrument data, this
-- is self-reported, and the philosophy is explicit that the two never
-- blend.
create table if not exists day_energy (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade default auth.uid(),
  date       date not null,
  value      smallint not null check (value between 1 and 3),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, date)
);

-- Indexes -------------------------------------------------------------------
create index if not exists entry_user_date_idx on entry (user_id, date desc);
create index if not exists draw_entry_idx on draw (entry_id);
-- Card history (v3 spec's Tier 3 reference) reads every past draw of one
-- card; this is the index that makes that a lookup rather than a scan.
create index if not exists draw_user_card_idx on draw (user_id, card_id);
create index if not exists day_energy_user_date_idx on day_energy (user_id, date desc);

-- Row Level Security --------------------------------------------------------
alter table deck        enable row level security;
alter table natal_chart enable row level security;
alter table entry       enable row level security;
alter table draw        enable row level security;
alter table day_energy  enable row level security;

do $$ begin
  create policy "owner only" on deck for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
exception when duplicate_object then null;
end $$;

do $$ begin
  create policy "owner only" on natal_chart for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
exception when duplicate_object then null;
end $$;

do $$ begin
  create policy "owner only" on entry for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
exception when duplicate_object then null;
end $$;

do $$ begin
  create policy "owner only" on draw for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
exception when duplicate_object then null;
end $$;

do $$ begin
  create policy "owner only" on day_energy for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
exception when duplicate_object then null;
end $$;
