# Kita English

English learning app for Vietnamese kids age 5-12. MVP is the "7-Day English Speaking Challenge." Full curriculum covers Pre-A1 to A2 over ~18 months.

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
  internal/auth/       Register, login, JWT, guest accounts, link account
  internal/onboarding/ Kid profile CRUD, placement
  internal/session/    Sessions, dynamic activity generator, difficulty adjustment
  internal/pronunciation/ Azure Speech client, Vietnamese L1 error classifier
  internal/srs/        SM-2 spaced repetition (per-skill mastery coming)
  internal/progress/   Daily stats, challenge summary, pronunciation trends
  internal/content/    Vocabulary, patterns, grammar, seed loader
  internal/common/     DB, Redis, storage (R2), migrations, response helpers
  migrations/          SQL migration files (auto-run on boot, IF NOT EXISTS)
  seed/                vocabulary.json, patterns.json, grammar.json, session_plans.json

flutter_app/           Flutter web/mobile app
  lib/core/            Theme, network, router, storage, audio (TTS, recorder, sound FX)
  lib/features/auth/   Login, signup, guest, link account
  lib/features/onboarding/ Parent gate, character select, placement test
  lib/features/session/ Activity shell + widgets for all activity types
  lib/features/pronunciation/ Record, score display, phoneme feedback, score history
  lib/features/srs/    Spaced repetition providers
  lib/features/progress/ Parent dashboard (Vietnamese)
  lib/features/day7/   Showcase recording, certificate
  lib/shared/widgets/  Buttons, cards, character avatar, stars, confetti
```

## Curriculum Architecture

### Three Pillars
1. **Content Repository** — all teaching atoms (phonemes, words, grammar, patterns, functions, topics)
2. **Curriculum Map** — the learning DAG with prerequisites (not a linear sequence)
3. **Learner State** — per-kid, per-atom, per-skill mastery driving SRS + session assembly

### 6 Content Atoms
1. **Phoneme** (~44) — sounds with L1 interference map, minimal pairs, mouth position
2. **Word** (~2000 for full curriculum) — form + meaning + use + collocations + word family + emoji
3. **Grammar Structure** (~30) — named structures with prerequisite DAG, L1 error patterns
4. **Pattern** (~200) — sentence templates with typed slots, generated sentences at runtime
5. **Communication Function** (~30) — pragmatic functions (greeting, requesting, describing, narrating)
6. **Topic** (~50) — thematic groups with tier-specific word lists (seeds/sprouts/explorers)

### Composition Rules
```
Phonemes → Words (phonics: letter-sound mapping)
Words → Pattern slots (grammar: fill slots with words from kid's vocab pool)
Patterns → Sentences (generation: pattern + words at runtime)
Sentences → Texts (discourse: connect sentences into dialogues/stories)
Functions × Topics → Contextualized communication
```

### 4 Skills × 4 Content Levels
```
              Phoneme    Word         Pattern/Sentence    Text
Listening     Hear /θ/   Hear word    Hear sentence       Hear dialogue
Speaking      Produce    Say word     Say sentence        Role-play
Reading       Letter     Read word    Read sentence       Read story
Writing       Letter     Spell word   Build sentence      Free response
```

### Per-Skill Mastery Tracking
Each word/pattern/phoneme tracks 4 independent skill scores (0-100). A word is MASTERED only when ALL 4 skills ≥ 80% over 5+ spaced encounters. SRS targets the weakest skill.

### 3 Age Tiers (Topic Spiral)
- **Seeds (5-7)** — Pre-A1, ~500 words, 20 patterns, phonics foundation, 40% listening
- **Sprouts (8-10)** — A1, ~1200 words, 50 patterns, balanced 25% each skill
- **Explorers (11-12)** — A1+→A2, ~2000 words, 80+ patterns, read/write emphasis

### Grammar DAG (30 structures with prerequisites)
Seeds: "This is ___" → "I am ___" → "I like ___" → "I can ___" → Wh-questions
Sprouts: 3rd person -s → Present continuous → Simple past → Comparatives
Explorers: Future → Present perfect → Modals → Conditionals → Passive

### Vietnamese L1 Interference (woven into every activity)
- /θ/ /ð/ substitution (critical, all tiers)
- Final consonant dropping (dialect-weighted: severe in Southern VN)
- Consonant cluster simplification
- Missing articles (Vietnamese has none)
- No plural marking
- Word order (adj position differs)
- Syllable-timed → stress-timed rhythm transition

### Dynamic Session Generation
```
generate_session(kid):
  1. SRS DUE — words/patterns due for review, sorted by weakest skill
  2. CURRICULUM NEXT — next unit's target words/patterns/phonics
  3. SKILL GAPS — identify weakest skill, problematic phonemes, grammar errors
  4. ASSEMBLE — pick activities targeting gaps, balance 4 skills, calibrate difficulty
```

### Build Phases
- **Phase 1**: Patterns + sentence generation (grammar templates with slots, sentence builder, fill-blank)
- **Phase 2**: Per-skill mastery (4-skill tracking, skill-balanced activity selection, reading/writing activities)
- **Phase 3**: Phonics track (phoneme table, phonics drills, minimal pairs)
- **Phase 4**: Curriculum DAG (unit system, prerequisites, tier transitions, adaptive paths)

## Key Architecture Decisions
- **Server-side pronunciation scoring**: Flutter records WAV/webm → uploads to Go backend → Go calls Azure Speech API → runs Vietnamese L1 classifier → returns phoneme-level scores
- **Response envelope unwrapping**: Go backend wraps all responses in `{"success":true,"data":{...}}`. Dio interceptor unwraps globally
- **Web audio recording**: JS MediaRecorder API bridged to Dart via conditional imports (dart:js_interop)
- **Web storage fallback**: In-memory storage on web (flutter_secure_storage doesn't work). State lost on refresh
- **Auto-migrations**: Server reads `migrations/*.up.sql` on boot. All use `IF NOT EXISTS`
- **Guest-first onboarding**: No login required. Guest account auto-created. Link email/phone later
- **Sound effects**: Web Audio API synthesized tones (no audio files needed)
- **Docker cache busting**: Single COPY layer + --pwa-strategy=none for reliable deploys

## API Contracts
- All JSON uses **snake_case** (Go backend is source of truth)
- Auth: `POST /api/v1/auth/guest` (anonymous), `/login`, `/register`, `/link` (upgrade guest)
- Sessions: `GET /api/v1/kids/:kidId/sessions/:day` returns dynamically generated activities
- Pronunciation: `POST /api/v1/pronunciation/score` multipart with `audio` + `reference_text` + `kid_id`
- SRS: `GET /api/v1/kids/:kidId/srs/due`, `POST .../review`
- Progress: `GET /api/v1/kids/:kidId/progress` (summary + vocabulary + pronunciation)

## Test Accounts
No login needed — app starts with guest onboarding. Or create via API:
```bash
curl -X POST https://backend-production-3908.up.railway.app/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"new@kita.com","password":"kita1234"}'
```
