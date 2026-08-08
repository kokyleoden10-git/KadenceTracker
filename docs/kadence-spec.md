# Kadence v2 — technical spec

Personal habit-tracking app. Single user, local-first, privacy-first. This document is the build spec for implementation.

## 1. Philosophy (drives every design decision below)

1. **Rotation over uniformity** — not every domain demands attention every day. Daily load varies by day of week; no uniform pressure across all habits.
2. **Instrument, not judge** — the app observes and reflects, it doesn't score or shame. Streaks are motivating context, not verdicts.
3. **Objective vs subjective data stays typed and separate** — never silently blended, so later correlation analysis is honest.
4. **Log fast, reflect slow** — daily interaction under 2 minutes. Weekly Reflection is where analysis and meaning-making happen.
5. **Advancement, not maintenance** — habits should carry a sense of direction, not just repetition.
6. **Flexible by design** — schedule, domains, and habits are all user-editable at runtime. Nothing requires a rebuild to reconfigure.
7. **Extensible by default** — every table is timestamped, typed, and normalized from day one so trends/correlation/AI-analysis can be added later as a read-only layer, never a migration.
8. **Privacy first** — local-first storage, no third-party analytics, no ambient cloud sync. See §6.

## 2. Behavioral science applied

- **Identity-based habits (Atomic Habits):** each Habit has an optional `identity_statement` field (e.g. "I am someone who protects their sleep").
- **2-minute rule + habit stacking (Atomic Habits):** Anchors default to smallest viable version. Optional `stack_cue` field ("after I close my laptop, I...").
- **Cue tracking on breaks (Power of Habit):** when a Log Entry is marked not-done, prompt (optional, non-blocking) "what happened right before?" — stored as `break_context` on the Log Entry.
- **Quadrant II framing (7 Habits):** Practices are explicitly framed in the UI as "important, not urgent" — the app's core value proposition is protecting this time.
- **Autonomy-supportive scheduling (Self-Determination Theory):** user chooses which Practices are active each week rather than a fixed assigned schedule. No rigid enforcement.

## 3. Vocabulary

| Term | Definition |
|---|---|
| Domain | One of the four life areas: Wellbeing, Knowledge, Creativity, Systems |
| Anchor | Small daily habit within a domain, always active, low effort |
| Practice | Deeper habit within a domain, active on user-chosen days (rotates) |
| Reading | First-class object for tarot/astrology entries (see §4) |
| Signal | Objective metric entry (sleep, HRV, recovery, etc.) |
| Streak | Consecutive-day completion count, tracked per Habit |
| Reflection | Weekly review entry, three fixed prompts |

## 4. Domains

- **Wellbeing** — sleep, meditation, tarot, substance use (reduce-type), recovery
- **Knowledge** — reading, language learning, educational content
- **Creativity** — music, drawing, making
- **Systems** — chores, scheduling, finances, productivity (renamed from "Admin" — infrastructure that supports the other three domains, not drudgery)

## 5. Data model

### `habit`
```
id            uuid, pk
name          text
domain        enum(wellbeing, knowledge, creativity, systems)
tier          enum(anchor, practice)
direction     enum(build, reduce)
days_active   int[]  -- 0=Sun..6=Sat; anchors default to all 7
identity_statement  text, nullable
stack_cue     text, nullable
streak_count  int, computed
created_at    timestamptz
archived_at   timestamptz, nullable   -- soft delete, never hard-delete user data
```

### `log_entry`
```
id            uuid, pk
habit_id      uuid, fk -> habit
date          date
done          boolean | int (1-5 scale, habit-configurable)
note          text, nullable
tags          text[], max 3
break_context text, nullable   -- populated only when done=false, optional prompt response
created_at    timestamptz
privacy_tier  enum(normal, sensitive)  -- 'sensitive' default for direction=reduce habits
```

### `reading` (first-class, not a generic log_entry subtype)
```
id            uuid, pk
date          date
type          enum(tarot, astrology, other)
deck          text, nullable
spread        text, nullable
cards         text[], nullable
notes         text
tags          text[], max 3   -- e.g. TarotReading, Astrology
created_at    timestamptz
```

### `signal`
```
id            uuid, pk
date          date
metric        text        -- e.g. "sleep_score", "hrv", "recovery_pct"
value         numeric
source        text        -- e.g. "manual", "peakwatch", "apple_watch"
created_at    timestamptz
```

### `reflection`
```
id            uuid, pk
week_start    date
went_well     text
what_broke    text        -- includes prompt: what happened right before?
pattern_noticed  text     -- cross-domain / signal-reading correlation notes
created_at    timestamptz
```

### `tag` (normalization support, not a strict foreign-key enforcement)
```
id            uuid, pk
canonical     text        -- lowercase, trimmed, stored form
display       text        -- first-used casing, shown in UI
usage_count   int
```

## 6. Tagging system

- Max 3 tags per Log Entry / Reading.
- **Case-insensitive matching**: on save, normalize tag to lowercase+trimmed for comparison against existing `tag.canonical`. If a match exists, reuse that tag's `id` and `display` casing rather than creating a duplicate ("Japanese" and "japanese" resolve to the same tag).
- **Autosuggest, not enforce**: as the user types, query `tag` table for prefix/fuzzy matches and show suggestions in a dropdown. Selecting a suggestion reuses the existing tag. Typing a new value and submitting anyway always succeeds — no hard validation, no blocking. This is a nudge, not a gate.
- No pre-built tag library or activity→context taxonomy (v1 mistake — see §9). Tags are freeform strings, full stop.

## 7. Privacy model

- **Local-first storage by default** (SQLite or local Supabase instance under user control — no managed third-party cloud by default).
- **No third-party analytics or telemetry.**
- **`privacy_tier` on log_entry**: entries for `direction=reduce` habits (substance use, etc.) default to `sensitive`. Sensitive entries are excludable from any future export/share/AI-analysis view via a single filter — never included in aggregate views unless explicitly opted in per-action.
- **No ambient cloud sync.** Any future integration (PeakWatch API, Apple Watch, AI analysis) is an explicit, visible, user-triggered connection — never silently enabled.
- **Long-form notes (Reading notes, Reflection text) stored as plain text**, never transmitted to any external service unless the user explicitly triggers an AI-analysis feature, and only the fields the user selects at that time.

## 8. Build order (suggested phasing)

1. **Core schema + local storage** — `habit`, `log_entry`, `tag` tables. Basic CRUD.
2. **Daily log screen** — the 2-minute-a-day surface. Shows today's active Anchors + Practices (per `days_active`), quick done/not-done, tag input with autosuggest.
3. **Habit management** — create/edit/archive habits, set domain/tier/direction/days_active. Must stay simple: this is the screen most likely to trigger perfectionist paralysis, so favor sensible defaults over exhaustive config.
4. **Reading module** — dedicated entry form (deck, spread, cards, notes), separate from generic log_entry.
5. **Signal module** — manual entry first. API sync (PeakWatch, Apple Watch) is a later, explicitly-opted-in integration.
6. **Streaks** — computed field, per-habit, displayed on daily screen.
7. **Reflection** — weekly prompt screen, three fixed fields.
8. **(Later, deferred) Trends & AI analysis** — read-only layer over existing tables. No schema changes required if §5 is followed correctly. This is the payoff of building it right the first time.

## 9. What v1 got wrong (for context, don't repeat)

- Logged individual events ("Smoke Session," "Worked on Habit App - 2") rather than tracking habit completion — turned into a journal, not a tracker.
- Built a combinatorial `activity` × `context` library (every activity had 5-7 possible contexts, most irrelevant, e.g. "Errands" mapped to Kitchen/Bathroom/Bedroom) — high setup cost, low value, main source of "this could get out of hand" feeling.
- No distinction between build and reduce habits — reduce-type entries (substance use) were logged then manually `excluded` from calculations rather than modeled correctly.
- Tarot readings, the richest and most consistently-used data in the whole export, were treated as generic entries rather than a first-class object.

## 10. Explicitly deferred (not v1 of the rebuild)

- `Rhythm` and `Arc` as separate objects — folded into `days_active` field and skipped entirely, respectively, until real need emerges.
- API sync for Signals.
- Trends dashboard / AI analysis layer.
- Any multi-user, sharing, or social feature (also why privacy_tier and local-first matter now, not later).
