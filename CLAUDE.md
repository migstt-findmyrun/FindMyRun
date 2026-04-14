# run-db — Project Context for Claude

## What this project is
A data pipeline that syncs upcoming group runs from Strava clubs into a Supabase
database. The database powers a content generation app (in development) that maps
routes against weather and a runner's personal pace.

## Repo structure
```
sync.js                  — main sync script (Node.js, runs via GitHub Actions)
api/                     — Vercel serverless functions (admin portal backend)
  _auth.js               — shared Bearer token auth helper
  auth.js                — POST /api/auth — admin login
  clubs.js               — GET/POST /api/clubs
  club.js                — PUT/DELETE /api/club?id=
  events.js              — GET /api/events (upcoming only, joined with clubs + routes)
  strava-lookup.js       — GET /api/strava-lookup?slug= (proxies Strava club lookup)
  strava-limits.js       — GET /api/strava-limits (Strava API rate limit status)
  trigger-sync.js        — POST /api/trigger-sync (fires GitHub Actions workflow)
public/
  index.html             — admin portal (single-page, vanilla JS + Tailwind)
migrations/
  001_initial_schema.sql — all 6 Supabase tables
  002_seed.sql           — system Strava token + 3 initial clubs
```

## Services
| Service | Purpose | URL |
|---|---|---|
| Supabase | Database (PostgreSQL) | https://fznbkrpgfhfeahkdehps.supabase.co |
| Vercel | Hosts admin portal + API routes | https://run-db-blush.vercel.app |
| GitHub Actions | Runs sync.js on schedule | migstt-findmyrun/run-db |
| Strava API | Source of club event data | api.strava.com |

## Supabase schema
- `clubs` — tracked Strava clubs (`active` flag toggles sync on/off)
- `events` — one row per occurrence, unique on `(strava_event_id, occurs_at)`
- `routes` — distance, elevation, summary + full polyline (encoded, Google format)
- `strava_tokens` — single-row system OAuth token, auto-refreshed by sync
- `users` — app users linked to Supabase Auth + their own Strava OAuth tokens
- `athlete_stats` — per-user avg pace, weekly distance, YTD (not yet populated)

## Strava API notes
- Club events endpoint is **undocumented**: `GET /clubs/{id}/group_events?upcoming=true`
- Route IDs are int64 — exceed JS safe integer range, **must use json-bigint** package
- Rate limits: 200 requests / 15 min, 2000 / day
- Token stored in `strava_tokens` table, refreshed automatically on each sync

## Sync logic (sync.js)
1. Load system token from Supabase, refresh if expiring within 5 min
2. Load all `active = true` clubs
3. For each club: fetch upcoming events from Strava
4. For each event with a `route_id`: fetch full route (distance, elevation, polylines)
5. Upsert events + routes into Supabase (idempotent — safe to re-run)
6. Update `last_synced_at` on each club

## Seeded clubs (Toronto)
| Club | Strava ID | Slug |
|---|---|---|
| Portland Runners Toronto | 580281 | portlandrunnerstoronto |
| BlackToe Running | 278092 | BlackToeRunning |
| The Local Toronto Lululemon | 318797 | thelocaltoronto |

## Sync schedule (GitHub Actions — all times ET)
- Daily midnight → `0 4 * * *` UTC
- Friday 5pm → `0 21 * * 5` UTC
- Saturday noon → `0 16 * * 6` UTC

## Environment variables
Needed in both `.env` (local) and Vercel / GitHub Actions secrets:
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `STRAVA_CLIENT_ID` = 220687
- `STRAVA_CLIENT_SECRET`
- `ADMIN_PASSWORD` (Vercel only — admin portal login)
- `GITHUB_TOKEN` (Vercel only — for manual sync trigger)

## Next phase: end-user mobile app
- **Platform**: React Native / Expo (targeting iOS via Xcode on Mac)
- **Auth**: Supabase Auth + Strava OAuth per user
- **Core feature**: show upcoming runs from the database, overlay route on map,
  factor in user's pace (from `athlete_stats`) and weather to generate content
- `users` and `athlete_stats` tables are already in the schema, ready to populate
- Polylines are stored encoded — decode with a standard Google Polyline decoder
  before rendering on a map (Mapbox, Google Maps, or MapKit)
