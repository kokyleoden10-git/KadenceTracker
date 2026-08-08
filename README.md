# Kadence v2

Personal habit tracker. iOS app (SwiftUI) + Supabase (Postgres) backend, so
data is reachable from the iPhone app or any browser via the Supabase
dashboard. See [`docs/kadence-guide.md`](docs/kadence-guide.md) for the "why"
and [`docs/kadence-spec.md`](docs/kadence-spec.md) for the full technical
spec — this README only covers getting the project running.

## One-time setup

**1. Install Xcode** (App Store) — the Command Line Tools alone aren't
enough to build/run this.

**2. Fix Homebrew, if needed.** This Mac's Homebrew was installed at the
Intel path (`/usr/local`) instead of the Apple Silicon path (`/opt/homebrew`)
and is missing its own git data — reinstall it fresh:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**3. Install XcodeGen and the GitHub CLI:**

```bash
brew install xcodegen gh
gh auth login
```

**4. Generate the Xcode project** (the `.xcodeproj` isn't committed —
`project.yml` is the source of truth):

```bash
cd ~/Developer/kadence-v2
xcodegen generate
open Kadence.xcodeproj
```

**5. Add your Supabase credentials:**

```bash
cp Kadence/Config/Secrets.example.plist Kadence/Config/Secrets.plist
```

Fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY` from your Supabase project's
**Settings → API** page. `Secrets.plist` is git-ignored. (This project
already has a Supabase project provisioned — ask if you need the values
again rather than creating a second project.)

**6. Set up the database schema:** open your Supabase project's **SQL
Editor**, paste in [`supabase/schema.sql`](supabase/schema.sql), and run it
once. It creates all six tables from spec §5 and enables RLS with an
open policy for the anon key (see the comment at the bottom of that file —
this is a deliberate tradeoff for a solo project with no login screen).

**7. Build and run** in Xcode. `ContentView` is currently a connectivity
smoke test — it fetches from the `habit` table and shows how many rows
exist. Replace it with the real daily-log screen next (spec §8, step 2).

## Project layout

```
Kadence/
  KadenceApp.swift        — app entry point
  Models/                 — Habit, LogEntry, Reading, Signal, Reflection, Tag
  Services/                — Secrets.swift (reads Secrets.plist), SupabaseService.swift
  Theme/                  — colors carried over from the v1 web app's palette
  Views/                  — ContentView.swift (placeholder)
supabase/
  schema.sql              — full schema, run once in the Supabase SQL editor
docs/
  kadence-guide.md        — the why
  kadence-spec.md         — the full technical spec
```

## Notes carried over from v1

The old app (single-file `index.html`, GitHub Pages) had a dark theme and a
color palette worth keeping — see `Kadence/Theme/Theme.swift`. It used the
fonts DM Serif Display + Inter, but the font files themselves weren't in
the repo, so the theme currently falls back to system fonts. No app icon
existed in v1. See `docs/kadence-guide.md` for what v1 got wrong
functionally (this v2 spec addresses all of it).
