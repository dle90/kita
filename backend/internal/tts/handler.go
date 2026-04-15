package tts

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/kitaenglish/backend/internal/common"
	"github.com/kitaenglish/backend/internal/content"
)

type Handler struct {
	service     *Service
	contentRepo content.ContentRepository
}

func NewHandler(service *Service, contentRepo content.ContentRepository) *Handler {
	return &Handler{service: service, contentRepo: contentRepo}
}

func (h *Handler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Get("/", h.Synthesize)
	r.Post("/prewarm", h.Prewarm)
	return r
}

// Synthesize handles GET /api/v1/tts?text=hello[&voice=rachel]
// Returns audio/mpeg bytes with long Cache-Control so browsers + CDNs cache it.
// The `voice` param is optional and must match a name in AllowedVoices.
func (h *Handler) Synthesize(w http.ResponseWriter, r *http.Request) {
	if !h.service.Enabled() {
		common.RespondError(w, http.StatusServiceUnavailable, "tts service not configured")
		return
	}
	text := r.URL.Query().Get("text")
	if text == "" {
		common.RespondError(w, http.StatusBadRequest, "text query parameter is required")
		return
	}

	var voiceID string
	if v := r.URL.Query().Get("voice"); v != "" {
		voiceID = ResolveVoice(v)
		if voiceID == "" {
			common.RespondError(w, http.StatusBadRequest, "unknown voice (allowed: rachel, bella, lily, matilda, jessica)")
			return
		}
	}

	audio, cacheHit, err := h.service.Get(r.Context(), text, voiceID)
	if err != nil {
		log.Printf("tts: synthesize failed for %q: %v", text, err)
		common.RespondError(w, http.StatusInternalServerError, "tts generation failed")
		return
	}

	w.Header().Set("Content-Type", "audio/mpeg")
	w.Header().Set("Content-Length", strconv.Itoa(len(audio)))
	// Immutable: cache key is content-addressed so the mp3 for a given ?text never changes.
	w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
	if cacheHit {
		w.Header().Set("X-Cache", "HIT")
	} else {
		w.Header().Set("X-Cache", "MISS")
	}
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(audio)
}

// PrewarmRequest is the JSON body for POST /api/v1/tts/prewarm.
// Limit=0 means all words. Limit>0 generates only the first N words alphabetically.
type PrewarmRequest struct {
	Limit          int      `json:"limit"`
	Words          []string `json:"words,omitempty"`           // optional explicit list
	IncludeExample bool     `json:"include_example,omitempty"` // also synthesize example_sentence
}

type PrewarmResult struct {
	Generated int      `json:"generated"`
	Cached    int      `json:"cached"`
	Failed    int      `json:"failed"`
	Total     int      `json:"total"`
	Errors    []string `json:"errors,omitempty"`
	DurationS float64  `json:"duration_s"`
}

// Prewarm handles POST /api/v1/tts/prewarm
// Generates mp3s for every vocabulary word (or a subset) and stores them in R2.
// Safe to re-run — cached items are skipped without touching ElevenLabs.
// Gated by DEBUG_ENABLED to prevent public abuse.
func (h *Handler) Prewarm(w http.ResponseWriter, r *http.Request) {
	if !isDebugEnabled() {
		common.RespondError(w, http.StatusForbidden, "prewarm is disabled (set DEBUG_ENABLED=1)")
		return
	}
	if !h.service.Enabled() {
		common.RespondError(w, http.StatusServiceUnavailable, "tts service not configured")
		return
	}

	var req PrewarmRequest
	if r.ContentLength > 0 {
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			common.RespondError(w, http.StatusBadRequest, "invalid json body")
			return
		}
	}

	// Build the list of texts to synthesize.
	var texts []string
	if len(req.Words) > 0 {
		texts = append(texts, req.Words...)
	} else {
		// Pull everything from the vocabulary table.
		ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
		defer cancel()
		vocab, err := h.contentRepo.GetVocabulary(ctx, 0, "")
		if err != nil {
			common.RespondError(w, http.StatusInternalServerError, "failed to load vocabulary: "+err.Error())
			return
		}
		seen := map[string]struct{}{}
		for _, v := range vocab {
			if v.Word != "" {
				if _, ok := seen[v.Word]; !ok {
					texts = append(texts, v.Word)
					seen[v.Word] = struct{}{}
				}
			}
			if req.IncludeExample && v.ExampleSentence != "" {
				if _, ok := seen[v.ExampleSentence]; !ok {
					texts = append(texts, v.ExampleSentence)
					seen[v.ExampleSentence] = struct{}{}
				}
			}
		}
	}

	if req.Limit > 0 && req.Limit < len(texts) {
		texts = texts[:req.Limit]
	}

	start := time.Now()
	result := PrewarmResult{Total: len(texts)}

	// Use a background context so the work isn't tied to the HTTP request lifecycle.
	// Railway's edge proxy caps a single request at ~60s; pre-warming 50+ words can exceed
	// that. We let the handler return early if needed but the work continues.
	bgCtx := context.Background()

	for i, text := range texts {
		ctx, cancel := context.WithTimeout(bgCtx, 30*time.Second)
		cacheHit, err := h.service.EnsureCached(ctx, text, "")
		cancel()
		if err != nil {
			result.Failed++
			if len(result.Errors) < 10 {
				result.Errors = append(result.Errors, text+": "+err.Error())
			}
			log.Printf("tts prewarm: [%d/%d] %q failed: %v", i+1, len(texts), text, err)
			continue
		}
		if cacheHit {
			result.Cached++
		} else {
			result.Generated++
		}
		if (i+1)%10 == 0 || i+1 == len(texts) {
			log.Printf("tts prewarm: [%d/%d] generated=%d cached=%d failed=%d", i+1, len(texts), result.Generated, result.Cached, result.Failed)
		}
	}

	result.DurationS = time.Since(start).Seconds()
	common.RespondJSON(w, http.StatusOK, result)
}

func isDebugEnabled() bool {
	v := os.Getenv("DEBUG_ENABLED")
	return v == "1" || v == "true"
}
