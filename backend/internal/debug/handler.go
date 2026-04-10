package debug

import (
	"context"
	"log"
	"math/rand"
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/kitaenglish/backend/internal/common"
	"github.com/kitaenglish/backend/internal/content"
)

// DebugHandler exposes endpoints for the testing harness.
// All endpoints are gated behind the DEBUG_ENABLED env var.
type DebugHandler struct {
	pool        *pgxpool.Pool
	contentRepo content.ContentRepository
}

// NewDebugHandler creates a debug handler.
func NewDebugHandler(pool *pgxpool.Pool, contentRepo content.ContentRepository) *DebugHandler {
	return &DebugHandler{pool: pool, contentRepo: contentRepo}
}

// IsEnabled checks whether debug mode is allowed.
func IsEnabled() bool {
	v := os.Getenv("DEBUG_ENABLED")
	return v == "1" || v == "true"
}

// Routes registers debug routes. All handlers check DEBUG_ENABLED.
func (h *DebugHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Use(debugGate)
	r.Post("/load-profile", h.LoadProfile)
	r.Get("/content/all", h.GetAllContent)
	return r
}

// debugGate middleware rejects requests unless DEBUG_ENABLED is set.
func debugGate(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !IsEnabled() {
			common.RespondError(w, http.StatusForbidden, "debug endpoints disabled in production")
			return
		}
		next.ServeHTTP(w, r)
	})
}

// LoadProfileRequest is the JSON body for POST /debug/load-profile.
type LoadProfileRequest struct {
	Profile string `json:"profile" validate:"required"`
	KidID   string `json:"kid_id" validate:"required"`
}

// LoadProfile populates mastery data for a pre-defined test profile.
func (h *DebugHandler) LoadProfile(w http.ResponseWriter, r *http.Request) {
	var req LoadProfileRequest
	if errs := common.DecodeAndValidate(r, &req); errs != nil {
		common.RespondValidationError(w, errs)
		return
	}

	kidID, err := uuid.Parse(req.KidID)
	if err != nil {
		common.RespondError(w, http.StatusBadRequest, "invalid kid_id")
		return
	}

	ctx := r.Context()

	// 1. Clear existing mastery data for this kid
	if _, err := h.pool.Exec(ctx, `DELETE FROM word_skill_mastery WHERE kid_id = $1`, kidID); err != nil {
		log.Printf("debug: failed to clear word_skill_mastery: %v", err)
	}
	if _, err := h.pool.Exec(ctx, `DELETE FROM srs_cards WHERE kid_id = $1`, kidID); err != nil {
		log.Printf("debug: failed to clear srs_cards: %v", err)
	}
	// Reset session completion status
	if _, err := h.pool.Exec(ctx, `UPDATE kid_sessions SET completed_at = NULL, total_stars = 0, accuracy_pct = 0 WHERE kid_id = $1`, kidID); err != nil {
		log.Printf("debug: failed to reset kid_sessions: %v", err)
	}

	// 2. Get all vocabulary grouped by day
	allVocab, err := h.contentRepo.GetVocabulary(ctx, 0, "")
	if err != nil {
		common.RespondError(w, http.StatusInternalServerError, "failed to fetch vocabulary")
		return
	}

	vocabByDay := map[int][]*content.Vocabulary{}
	for _, v := range allVocab {
		vocabByDay[v.DayNumber] = append(vocabByDay[v.DayNumber], v)
	}

	now := time.Now()
	rng := rand.New(rand.NewSource(now.UnixNano()))

	switch req.Profile {
	case "beginner":
		// All zeros, no sessions completed — already cleared above

	case "day3":
		// Days 1-2 complete, words from day 1-2 have mastery
		h.markSessionsComplete(ctx, kidID, []int{1, 2}, now)
		for day := 1; day <= 2; day++ {
			for _, v := range vocabByDay[day] {
				h.insertMastery(ctx, kidID, v.ID, float64(70+jitter(rng, 10)), float64(50+jitter(rng, 10)), float64(60+jitter(rng, 10)), float64(20+jitter(rng, 8)), 3+rng.Intn(3))
				h.insertSrsCard(ctx, kidID, v.ID, 2, 2.5, 3, now.AddDate(0, 0, 1))
			}
		}

	case "day5":
		// Days 1-4 complete, progressive mastery
		h.markSessionsComplete(ctx, kidID, []int{1, 2, 3, 4}, now)
		for day := 1; day <= 4; day++ {
			// Progressive: earlier days have higher mastery
			boost := float64((5 - day) * 10) // day1=40, day2=30, day3=20, day4=10
			for _, v := range vocabByDay[day] {
				h.insertMastery(ctx, kidID, v.ID,
					clamp(45+boost+float64(jitter(rng, 10))),
					clamp(30+boost+float64(jitter(rng, 10))),
					clamp(35+boost+float64(jitter(rng, 10))),
					clamp(5+boost+float64(jitter(rng, 8))),
					3+rng.Intn(4))
				interval := day + 1
				h.insertSrsCard(ctx, kidID, v.ID, day, 2.5, interval, now.AddDate(0, 0, interval-day))
			}
		}

	case "advanced":
		// Days 1-6 complete, most words high mastery except writing
		h.markSessionsComplete(ctx, kidID, []int{1, 2, 3, 4, 5, 6}, now)
		for day := 1; day <= 6; day++ {
			for _, v := range vocabByDay[day] {
				h.insertMastery(ctx, kidID, v.ID,
					clamp(85+float64(jitter(rng, 10))),
					clamp(75+float64(jitter(rng, 10))),
					clamp(80+float64(jitter(rng, 10))),
					clamp(55+float64(jitter(rng, 15))),
					5+rng.Intn(5))
				h.insertSrsCard(ctx, kidID, v.ID, 5, 2.8, 7, now.AddDate(0, 0, 3))
			}
		}

	case "almost_done":
		// All 7 sessions complete, most words at 80%+ on 3 skills, writing at 60%
		h.markSessionsComplete(ctx, kidID, []int{1, 2, 3, 4, 5, 6, 7}, now)
		for day := 1; day <= 7; day++ {
			for _, v := range vocabByDay[day] {
				h.insertMastery(ctx, kidID, v.ID,
					clamp(85+float64(jitter(rng, 10))),
					clamp(82+float64(jitter(rng, 10))),
					clamp(83+float64(jitter(rng, 10))),
					clamp(55+float64(jitter(rng, 15))),
					7+rng.Intn(4))
				h.insertSrsCard(ctx, kidID, v.ID, 6, 3.0, 14, now.AddDate(0, 0, 7))
			}
		}

	default:
		common.RespondError(w, http.StatusBadRequest, "unknown profile: "+req.Profile)
		return
	}

	common.RespondJSON(w, http.StatusOK, map[string]interface{}{
		"profile":     req.Profile,
		"kid_id":      req.KidID,
		"vocab_count": len(allVocab),
		"message":     "Profile loaded successfully",
	})
}

// GetAllContent returns all content in one response.
func (h *DebugHandler) GetAllContent(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	vocab, err := h.contentRepo.GetVocabulary(ctx, 0, "")
	if err != nil {
		common.RespondError(w, http.StatusInternalServerError, "failed to fetch vocabulary")
		return
	}

	grammar, err := h.contentRepo.GetGrammarStructures(ctx)
	if err != nil {
		common.RespondError(w, http.StatusInternalServerError, "failed to fetch grammar")
		return
	}

	patterns, err := h.contentRepo.GetPatterns(ctx, 0)
	if err != nil {
		common.RespondError(w, http.StatusInternalServerError, "failed to fetch patterns")
		return
	}

	phonemes, err := h.contentRepo.GetPhonemes(ctx)
	if err != nil {
		common.RespondError(w, http.StatusInternalServerError, "failed to fetch phonemes")
		return
	}

	commFunctions, err := h.contentRepo.GetCommunicationFunctions(ctx)
	if err != nil {
		common.RespondError(w, http.StatusInternalServerError, "failed to fetch communication functions")
		return
	}

	result := map[string]interface{}{
		"vocabulary":              vocab,
		"grammar_structures":      grammar,
		"patterns":                patterns,
		"phonemes":                phonemes,
		"communication_functions": commFunctions,
	}

	common.RespondJSON(w, http.StatusOK, result)
}

// --- helpers ---

func (h *DebugHandler) markSessionsComplete(ctx context.Context, kidID uuid.UUID, days []int, now time.Time) {
	for _, day := range days {
		completedAt := now.AddDate(0, 0, -(len(days) - day))
		_, err := h.pool.Exec(ctx,
			`UPDATE kid_sessions SET started_at = $3, completed_at = $4, total_stars = $5, accuracy_pct = $6
			 WHERE kid_id = $1 AND day_number = $2`,
			kidID, day, completedAt.Add(-10*time.Minute), completedAt, 20+day*2, 70.0+float64(day)*3,
		)
		if err != nil {
			log.Printf("debug: failed to mark session %d complete: %v", day, err)
		}
	}
}

func (h *DebugHandler) insertMastery(ctx context.Context, kidID, vocabID uuid.UUID, listening, speaking, reading, writing float64, attempts int) {
	now := time.Now()
	_, err := h.pool.Exec(ctx,
		`INSERT INTO word_skill_mastery (id, kid_id, vocabulary_id,
			listening_score, listening_attempts, speaking_score, speaking_attempts,
			reading_score, reading_attempts, writing_score, writing_attempts,
			overall_mastery, last_seen, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
		 ON CONFLICT (kid_id, vocabulary_id) DO UPDATE SET
			listening_score = $4, listening_attempts = $5,
			speaking_score = $6, speaking_attempts = $7,
			reading_score = $8, reading_attempts = $9,
			writing_score = $10, writing_attempts = $11,
			overall_mastery = $12, last_seen = $13, updated_at = $15`,
		uuid.New(), kidID, vocabID,
		listening, attempts, speaking, attempts,
		reading, attempts, writing, attempts,
		min4(listening, speaking, reading, writing), now, now, now,
	)
	if err != nil {
		log.Printf("debug: failed to insert mastery for %s: %v", vocabID, err)
	}
}

func (h *DebugHandler) insertSrsCard(ctx context.Context, kidID, vocabID uuid.UUID, reps int, ease float64, interval int, nextReview time.Time) {
	now := time.Now()
	_, err := h.pool.Exec(ctx,
		`INSERT INTO srs_cards (id, kid_id, vocabulary_id, repetitions, ease_factor, interval_days, next_review_date, last_review_date, last_quality, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		 ON CONFLICT (kid_id, vocabulary_id) DO UPDATE SET
			repetitions = $4, ease_factor = $5, interval_days = $6,
			next_review_date = $7, last_review_date = $8, last_quality = $9, updated_at = $11`,
		uuid.New(), kidID, vocabID, reps, ease, interval, nextReview, now, 4, now, now,
	)
	if err != nil {
		log.Printf("debug: failed to insert srs card for %s: %v", vocabID, err)
	}
}

func jitter(rng *rand.Rand, max int) int {
	return rng.Intn(max*2+1) - max
}

func clamp(v float64) float64 {
	if v < 0 {
		return 0
	}
	if v > 100 {
		return 100
	}
	return v
}

func min4(a, b, c, d float64) float64 {
	m := a
	if b < m {
		m = b
	}
	if c < m {
		m = c
	}
	if d < m {
		m = d
	}
	return m
}

