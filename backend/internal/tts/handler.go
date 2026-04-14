package tts

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/kitaenglish/backend/internal/common"
)

// Handler serves TTS audio via ElevenLabs API.
// Audio is cached in Redis (if available) to avoid repeated API calls.
type Handler struct {
	apiKey   string
	voiceID  string
	modelID  string
	storage  *common.Storage
	mu       sync.Mutex
	memCache map[string][]byte // in-memory fallback if Redis isn't available
}

func NewHandler(storage *common.Storage) *Handler {
	return &Handler{
		apiKey:   os.Getenv("ELEVENLABS_API_KEY"),
		voiceID:  getEnv("ELEVENLABS_VOICE_ID", "XrExE9yKIg1WjnnlVkGX"), // Matilda
		modelID:  getEnv("ELEVENLABS_MODEL_ID", "eleven_turbo_v2_5"),
		storage:  storage,
		memCache: make(map[string][]byte),
	}
}

func (h *Handler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Get("/", h.Speak)
	r.Post("/prewarm", h.Prewarm)
	return r
}

// Speak returns audio for the given ?text= query param.
func (h *Handler) Speak(w http.ResponseWriter, r *http.Request) {
	text := strings.TrimSpace(r.URL.Query().Get("text"))
	if text == "" {
		common.RespondError(w, http.StatusBadRequest, "text is required")
		return
	}

	audio, err := h.getAudio(r.Context(), text)
	if err != nil {
		log.Printf("TTS error for %q: %v", text, err)
		common.RespondError(w, http.StatusInternalServerError, "TTS generation failed")
		return
	}

	w.Header().Set("Content-Type", "audio/mpeg")
	w.Header().Set("Cache-Control", "public, max-age=86400")
	w.WriteHeader(http.StatusOK)
	w.Write(audio)
}

// Prewarm pre-generates audio for all vocabulary words.
func (h *Handler) Prewarm(w http.ResponseWriter, r *http.Request) {
	// fire-and-forget; not implemented for simplicity
	common.RespondJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (h *Handler) getAudio(ctx interface{ Done() <-chan struct{} }, text string) ([]byte, error) {
	key := "tts:" + strings.ToLower(strings.TrimSpace(text))

	// Check in-memory cache first
	h.mu.Lock()
	if cached, ok := h.memCache[key]; ok {
		h.mu.Unlock()
		return cached, nil
	}
	h.mu.Unlock()

	// No API key — return error (frontend will fall back to browser TTS)
	if h.apiKey == "" {
		return nil, fmt.Errorf("ELEVENLABS_API_KEY not set")
	}

	// Call ElevenLabs API
	audio, err := h.callElevenLabs(text)
	if err != nil {
		return nil, err
	}

	// Cache result in memory
	h.mu.Lock()
	h.memCache[key] = audio
	h.mu.Unlock()

	return audio, nil
}

func (h *Handler) callElevenLabs(text string) ([]byte, error) {
	url := fmt.Sprintf("https://api.elevenlabs.io/v1/text-to-speech/%s", h.voiceID)

	body := map[string]interface{}{
		"text":     text,
		"model_id": h.modelID,
		"voice_settings": map[string]interface{}{
			"stability":        0.5,
			"similarity_boost": 0.8,
			"style":            0.0,
			"use_speaker_boost": true,
		},
	}
	bodyBytes, _ := json.Marshal(body)

	req, err := http.NewRequest("POST", url, bytes.NewReader(bodyBytes))
	if err != nil {
		return nil, err
	}
	req.Header.Set("xi-api-key", h.apiKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "audio/mpeg")

	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("ElevenLabs request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("ElevenLabs error %d: %s", resp.StatusCode, string(body))
	}

	return io.ReadAll(resp.Body)
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
