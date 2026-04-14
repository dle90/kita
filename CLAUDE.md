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

**CRITICAL**: Always deploy from the **REPO ROOT** (not subdirectories). Railway needs to find `backend/Dockerfile` or `flutter_app/` from the full repo. Deploying from inside `backend/` causes Railway to fall back to RAILPACK and fail with "Could not find root directory: backend".

### Backend (from repo root)
```bash
# From c:\Users\ducml\Desktop\kita  (the repo root)
railway link --project c5b7b5bd-883e-47c1-9bff-76c95daa9fa4 --environment 526a6c2e-6f4e-4abd-9a24-f42e0a41e263 --service e9973b90-6931-456a-823b-0279b3367ac3
railway up
```

### Frontend (from repo root)
```bash
# From c:\Users\ducml\Desktop\kita  (the repo root)
railway link --project c5b7b5bd-883e-47c1-9bff-76c95daa9fa4 --environment 526a6c2e-6f4e-4abd-9a24-f42e0a41e263 --service 0b09ec57-d4a1-400b-b2a4-9e25339f713d
railway up
```

**Note**: `railway service link <ID>` also works if you're already in the repo root with a `.railway` project config present.

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
    audio/tts_service.dart   TtsService — calls backend /api/v1/tts, static backendRoot
    audio/tts_js.dart        Web impl: JS interop → _kitaPlayAudio(url) in index.html
    audio/tts_stub.dart      Native stub (no-op)
  lib/features/auth/   Login, signup, guest, link account
  lib/features/onboarding/ Parent gate, character select, placement test
    auto_provision_screen.dart  Splash: auto-creates guest account + default kid profile, skips onboarding
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
- **Phase 1**: ✅ Patterns + sentence generation (grammar templates with slots, sentence builder, fill-blank)
- **Phase 2**: ✅ Per-skill mastery (4-skill tracking, skill-balanced activity selection, reading/writing activities)
- **Phase 3**: ✅ Phonics track — implemented
  - `kid_phoneme_mastery` table (migration 014) tracks `perception_score` + `production_score` per phoneme
  - `phonics_listen` (minimal pair discrimination): play two words → Same or Different?
  - `phonics_match` (sound-letter matching): play a word → pick the correct grapheme
  - `srs.PhonemeMasteryRepository` — `GetWeakestPhonemes`, `UpdatePhonemeMastery`
  - `curriculum.SelectPhonemesForSession` — weak first → unseen → any remaining (2 per session)
  - Flutter widgets: `PhonicsActivity` (dual-mode), `PhonemeTip` (mouth position + substitution tip)
- **Phase 4**: ✅ Curriculum DAG — implemented
  - `grammar_structures` table (migration 012) with `prerequisite_ids TEXT[]`
  - `kid_grammar_exposure` table (migration 015) tracks exposure count per kid per structure
  - `curriculum.GetNextGrammarStructure` — 3-pass DAG: (1) first unseen with prereqs met, (2) least-exposed below max, (3) fallback
  - `pattern_intro` activity type: shows grammar name, template, examples (EN+VI), L1 error tip
  - Flutter widget: `GrammarIntroActivity` — always marks correct (intro only, no test)

## Text-Only Test Mode
The session shell has a `TXT` badge button in the header that toggles `_textMode`. In text mode:
- All activity widgets are bypassed; `_buildTextModeContent()` renders structured text cards
- Each activity type has a specific text view (phonics shows word/symbol/options, grammar shows template/examples)
- `patternIntro` gets a single "Next" button (always correct — it's intro content)
- `phonicsListen`/`phonicsMatch` get Correct/Wrong buttons for manual testing
- Toggle by tapping `TXT` in the top-right of the session screen

## Session Plan Configuration
`backend/seed/session_plans.json` is loaded ONCE via `sync.Once` at first session request and takes priority over the Go fallback in `session_plan.go`. The disk file must be updated whenever the plan changes — updating only the Go code has no effect on a running server.

Current 12-slot plan (generates 13 activities for a fresh kid):
1. warmup/srs_due × 2 (adapts to weakest skill)
2. warmup/srs_due/listen × 1
3. phonics/phonics_listen × 1 (weakest phoneme)
4. phonics/phonics_match × 1 (second weakest phoneme)
5. grammar/pattern_intro × 1 (next unlocked grammar structure)
6. new_content/flashcard_intro × 1
7. new_content/listen_and_repeat × 1
8. practice/fill_blank × 1
9. practice/build_sentence × 1
10. practice/speak_word × 1 (error_focus source)
11. practice/word_match × 1
12. fun_finish/word_match × 1

## Key Architecture Decisions
- **Server-side pronunciation scoring**: Flutter records WAV → uploads to Go backend → Go calls Azure Speech API → runs Vietnamese L1 classifier → returns phoneme-level scores
- **WebM → WAV conversion (CRITICAL)**: Chrome's MediaRecorder outputs `audio/webm;codecs=opus`. Azure REST API only accepts **16kHz mono PCM WAV** and silently returns a non-Success `RecognitionStatus` for any other format (causing backend 500 → Flutter fallback score of 70). Fix: `_kitaToWavBase64(blob)` in `web/index.html` decodes via `AudioContext.decodeAudioData()` then re-encodes as PCM WAV before base64-encoding. Flutter passes `contentType: 'audio/wav'` to the upload call.
- **TTS via backend**: `TtsService` calls `GET /api/v1/tts?text=...` (ElevenLabs Matilda voice). `_backendRoot` is a static field derived from `ApiEndpoints.baseUrl` constant — no constructor args needed, so all 6+ activity widgets that do `TtsService()` work automatically. Web path: Dart → `tts_js.dart` → JS interop → `_kitaPlayAudio(url)` in `index.html` → browser `new Audio(url).play()`.
- **Response envelope unwrapping**: Go backend wraps all responses in `{"success":true,"data":{...}}`. Dio interceptor unwraps globally
- **Web audio recording**: JS MediaRecorder API bridged to Dart via conditional imports (dart:js_interop)
- **Web storage fallback**: In-memory storage on web (flutter_secure_storage doesn't work). State lost on refresh
- **Auto-migrations**: Server reads `migrations/*.up.sql` on boot. All use `IF NOT EXISTS`
- **Auto-provision onboarding (skips manual onboarding)**: App starts at `/` (splash) → `AutoProvisionScreen` calls `POST /auth/guest` then `POST /kids` with defaults (`display_name: 'Dev Kid'`, age 7, dialect: northern, character: mochi) → saves IDs → navigates to `/home`. Reset button on home screen clears storage and returns to splash for a fresh profile.
- **Router guard (bidirectional)**: If user has a kid profile and lands on a public/onboarding path → redirect to `/home`. If user has NO kid profile and lands on any protected path (e.g. page reload on `/session/1`) → redirect to `/` to auto-provision. Prevents "Kid profile ID not found" crashes on reload.
- **Vocabulary distractors (theme consistency)**: `listen_and_choose` distractors prefer same-unit words first, then same-category, then any vocab. Prevents cross-theme confusion (e.g. weather words mixed into greetings lesson).
- **Session complete → next lesson**: `SessionCompleteScreen` shows a "Bài tiếp theo" button for days 1-6 that resets session state and navigates to `/session/{day+1}`.
- **Sound effects**: Web Audio API synthesized tones (no audio files needed)
- **Docker cache busting**: Single COPY layer + --pwa-strategy=none for reliable deploys
- **session_plans.json sync.Once**: File is loaded once per process. Changing the file without redeploying has no effect. Always update the file, not just the Go fallback.

## Known Issues / To Debug
- **RESOLVED 2026-04-14**: Backend deployments were failing because `railway up` was run from inside `backend/` instead of the repo root. Railway's service is configured with `rootDirectory=backend` and `dockerfilePath=backend/Dockerfile`. Running from inside `backend/` caused Railway to use RAILPACK (no `backend/` subdirectory found) instead of Dockerfile. Fix: always deploy from repo root. See Deploying section above.
- **RESOLVED 2026-04-14**: Pronunciation score always returned 70 — Chrome MediaRecorder outputs WebM/Opus which Azure rejects with non-Success `RecognitionStatus` → backend 500 → Flutter fallback 70. Fixed by WAV conversion in browser JS. See WebM→WAV note in Key Architecture Decisions.
- **RESOLVED 2026-04-14**: "Kid profile ID not found" crash on page reload — web in-memory storage is cleared on reload. GoRouter was not guarding the "no profile on protected route" case. Fixed with bidirectional redirect guard in `app_router.dart`.
- **RESOLVED 2026-04-14**: TTS silent on all activity widgets — `TtsService()` was constructed without `backendBase` arg in 6+ widgets. Fixed by making `_backendRoot` a static field computed from `ApiEndpoints.baseUrl`.
- **RESOLVED 2026-04-14**: Can't proceed to lesson 2 after lesson 1 — `SessionCompleteScreen` had no "next lesson" navigation. Fixed with "Bài tiếp theo" button for days 1-6.

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
