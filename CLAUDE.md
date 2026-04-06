# Kita English

English learning app for Vietnamese kids age 5-12. MVP is the "7-Day English Speaking Challenge."

## Tech Stack
- **Frontend**: Flutter (Riverpod, GoRouter, Dio) — web deployed on Railway
- **Backend**: Go (Chi router, pgx, JWT) — deployed on Railway
- **Database**: Postgres 16 (Railway managed)
- **Cache**: Redis 7 (Railway managed)
- **Object Storage**: Cloudflare R2 (S3-compatible, bucket: `kita-english`)
- **Speech**: Azure Speech API (phoneme-level pronunciation assessment, region: southeastasia)

## Live URLs
- **Frontend**: https://frontend-production-5567.up.railway.app
- **Backend API**: https://backend-production-3908.up.railway.app
- **Health check**: https://backend-production-3908.up.railway.app/health
- **Railway dashboard**: https://railway.com/project/c5b7b5bd-883e-47c1-9bff-76c95daa9fa4
- **GitHub repo**: https://github.com/dle90/kita

## Railway Service IDs
- **Backend**: `e9973b90-6931-456a-823b-0279b3367ac3`
- **Frontend**: `0b09ec57-d4a1-400b-b2a4-9e25339f713d`
- **Postgres**: `9e198b86-e154-4063-b86e-4cb0da529b42`
- **Redis**: `8c7f8519-0cdc-4423-8422-ee89b5480038`
- **Environment ID**: `526a6c2e-6f4e-4abd-9a24-f42e0a41e263`
- **Project ID**: `c5b7b5bd-883e-47c1-9bff-76c95daa9fa4`

## Deploying

### Backend (from repo root)
```bash
cd backend
railway service link e9973b90-6931-456a-823b-0279b3367ac3
railway up
```

### Frontend (from repo root)
```bash
cd flutter_app
railway service link 0b09ec57-d4a1-400b-b2a4-9e25339f713d
railway up
```

**IMPORTANT**: Always `cd` into the correct subdirectory AND `railway service link` the correct service ID before running `railway up`. Otherwise you deploy the wrong code to the wrong service.

### Checking logs
```bash
railway service link <SERVICE_ID>
railway logs          # runtime logs
railway logs --build  # build logs
```

## Project Structure
```
backend/               Go API server
  cmd/server/          Entry point — auto-runs migrations + seeds on start
  internal/auth/       Register, login, JWT, middleware
  internal/onboarding/ Kid profile CRUD, placement
  internal/session/    7-day sessions, activity generator, difficulty adjustment
  internal/pronunciation/ Azure Speech client, Vietnamese L1 error classifier
  internal/srs/        SM-2 spaced repetition
  internal/progress/   Daily stats, challenge summary
  internal/content/    Vocabulary, sentences, seed loader
  internal/common/     DB, Redis, storage (R2), migrations, response helpers
  migrations/          9 SQL migration files (auto-run on boot)
  seed/                vocabulary.json (50 words), session_templates.json (55 templates)

flutter_app/           Flutter web/mobile app
  lib/core/            Theme, network (Dio + envelope unwrapper), router, storage, audio
  lib/features/auth/   Login, signup
  lib/features/onboarding/ Parent gate, character select, placement test
  lib/features/session/ 4 activity types, session home, activity shell
  lib/features/pronunciation/ Record button, score display, phoneme feedback
  lib/features/srs/    Spaced repetition providers
  lib/features/progress/ Parent dashboard (Vietnamese)
  lib/features/day7/   Showcase recording, certificate
  lib/shared/widgets/  Buttons, cards, character avatar, stars, confetti
```

## Key Architecture Decisions
- **Server-side pronunciation scoring**: Flutter records WAV → uploads to Go backend → Go calls Azure Speech API → runs Vietnamese L1 classifier → returns scores. Azure key stays off device.
- **Response envelope unwrapping**: Go backend wraps all responses in `{"success":true,"data":{...}}`. Dio interceptor in `api_client.dart` unwraps this globally.
- **Web storage fallback**: `flutter_secure_storage` doesn't work on web. `secure_storage.dart` has in-memory fallback for web platform (state lost on refresh — fine for testing).
- **Auto-migrations**: Server reads `migrations/*.up.sql` on boot. All use `IF NOT EXISTS` for idempotency.
- **Vietnamese L1 error classifier**: 6 error types (final consonant drop, th-substitution, r/l confusion, vowel length, cluster simplification, w/v confusion), severity weighted by dialect (northern/central/southern).

## API Contracts
- All JSON uses **snake_case** (Go backend is source of truth)
- Auth: `POST /api/v1/auth/login` accepts `email`, `phone`, or `email_or_phone` fields
- Sessions: `GET /api/v1/kids/:kidId/sessions/:day` returns activities from templates + SRS due cards
- Pronunciation: `POST /api/v1/pronunciation/score` multipart with `audio` file + `reference_text` + `kid_id` form fields
- Go dialect values: `northern`, `central`, `southern` (NOT Vietnamese enum names)
- Go english_level values: `beginner`, `elementary`, `pre_intermediate`

## Known Issues / TODO
- **Onboarding may still fail**: Last deploy might have Docker cache issues. If `POST /kids` returns 400, check dialect/english_level mapping in `onboarding_provider.dart`
- **No sound on placement test**: TTS added via `flutter_tts` but needs verification on deployed web build
- **Web storage is in-memory**: Login state lost on page refresh. Need to implement localStorage fallback for web.
- **No real audio files**: Vocabulary audio URLs in seed data are placeholders. Using TTS as interim solution.
- **Flutter test file error**: `test/widget_test.dart` references `MyApp` — delete or fix
- **Azure pronunciation**: Works but returns empty for non-speech audio (expected). Needs real voice input to test fully.

## Test Accounts
Create new ones via API:
```bash
curl -X POST https://backend-production-3908.up.railway.app/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"new@kita.com","password":"kita1234"}'
```
