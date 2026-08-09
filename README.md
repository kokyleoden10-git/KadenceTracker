# Kadence v2

Personal habit tracker. iOS app (SwiftUI) + Supabase (Postgres + Auth)
backend. See [`docs/kadence-guide.md`](docs/kadence-guide.md) for the "why"
and [`docs/kadence-spec.md`](docs/kadence-spec.md) for the full technical
spec — this README only covers getting the project running and the current
state of the build.

## Current state (spec §8 build order)

- ✅ Auth — email/password live; Sign in with Apple coded but hidden behind
  `AuthFeatureFlags.appleSignInEnabled` until Apple Developer + Supabase
  provider setup is done (see below).
- ✅ Daily log screen (`HomeView`) — today's active habits only (per
  `days_active`), tap a habit's checkbox to mark done/not-done, long-press
  for explicit "mark not done"/clear, optional note+tags+break-context
  detail sheet one tap further away.
- ✅ Habit management (`ManageHabitsView`, `HabitFormView`) — create/edit/
  archive, shows every habit regardless of today's schedule. Deliberately
  separate screen from the daily log (spec calls these out as two
  different build-order steps for a reason: one is "log fast," the other
  is configuration, and conflating them was last pass's mistake).
- ✅ Settings (`SettingsView`) — profile fields (date/time pickers, MapKit
  location autocomplete, info icons explaining why each field exists),
  JSON export/import, sign out, full data reset.
- ✅ Astrology palette + real DM Serif Display/Inter fonts, app icon + home
  screen logo, home header (personalized title, weather via Open-Meteo,
  rotating quote).
- ✅ Tags — case-insensitive resolution + autosuggest + usage-count ranking
  (`TagService`), wired into the daily log's detail sheet.
- ⬜ Reading module, Signal module, Streaks computation, Reflection —
  not built yet.
- ⬜ Trends/AI analysis — explicitly deferred per spec.

## ⚠️ Required database migration

`supabase/migrations/001_log_entry_unique_habit_date.sql` adds a unique
constraint on `log_entry (habit_id, date)` that the daily log screen
depends on for its tap-to-toggle upsert behavior. **Run this in the SQL
Editor before testing habit logging** — without it, tapping any habit's
checkbox fails with `there is no unique or exclusion constraint matching
the ON CONFLICT specification` (confirmed directly against the live
project before writing this). It's additive — doesn't touch existing rows.
`supabase/schema.sql` already includes this constraint for fresh installs;
the migration file is only needed because your project predates it.

## Regenerating the Xcode project

The `.xcodeproj` isn't committed — `project.yml` is the source of truth,
and must be regenerated after any Swift file add/remove or `project.yml`
edit:

```bash
cd ~/Developer/kadence-v2
xcodegen generate
open Kadence.xcodeproj
```

## Setting up Sign in with Apple (optional, currently disabled)

Email/password works out of the box against any Supabase project. Sign in
with Apple's code exists (`AuthService.prepareAppleRequest`/
`completeAppleSignIn`, the button in `SignInView`) but is hidden behind
`AuthFeatureFlags.appleSignInEnabled = false` — flip that once you've done
the following (a free Apple ID can't provision this capability, so the
entitlement is also currently omitted from `project.yml`; both need
restoring together):

1. **Apple Developer Portal** (paid membership required): create a
   Services ID for `com.kyleoden.kadence` and a Sign in with Apple key.
   You'll get a Team ID, Key ID, and a `.p8` private key file.
2. **Supabase Dashboard → Authentication → Providers → Apple**: enable it,
   paste in the Team ID, Key ID, Services ID, and private key.
3. **Xcode → Signing & Capabilities**: select your paid-team Apple ID, then
   re-add the `com.apple.developer.applesignin` entitlement to
   `project.yml` (removed in an earlier commit — see git history) and
   regenerate.

## Project layout

```
Kadence/
  KadenceApp.swift
  Models/       — Habit, LogEntry, Reading, Signal, Reflection, Tag, Profile
  Services/     — SupabaseService, AuthService, ProfileService, HabitService,
                  LogEntryService, TagService, WeatherService, DataExportService
  Theme/        — Theme.swift (palette + fonts), Quotes.swift
  Views/        — ContentView, SignInView, HomeView, HomeHeaderView,
                  ManageHabitsView, HabitFormView, HabitRow, DailyHabitRow,
                  LogDetailSheet, SettingsView, LocationSearchField, InfoButton
  Resources/    — Assets.xcassets (app icon + logo), Fonts/
supabase/
  schema.sql       — full schema incl. auth/RLS, for fresh installs
  migrations/      — additive changes to run against an existing project
docs/
  kadence-guide.md
  kadence-spec.md
```

## Not built yet

Reading module, Signal module, Streaks (the `habit.streak_count` column
exists and is displayed when non-zero, but nothing computes it yet),
Reflection screen. See spec §8 for the intended order.
