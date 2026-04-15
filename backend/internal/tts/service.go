package tts

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"log"
	"strings"
	"sync"

	"github.com/kitaenglish/backend/internal/common"
)

// AllowedVoices maps friendly voice names → ElevenLabs voice IDs.
// Public clients can only reference voices in this map to prevent abuse.
var AllowedVoices = map[string]string{
	"rachel":  "21m00Tcm4TlvDq8ikWAM",
	"bella":   "EXAVITQu4vr4xnSDxMaL",
	"lily":    "pFZP5JQG7iQjIQuC4Bku",
	"matilda": "XrExE9yKIg1WjnnlVkGX",
	"jessica": "cgSgspJ2msm6clMCkdW9",
}

// ResolveVoice returns the ElevenLabs voice ID for a given friendly name
// (case-insensitive). If the argument is already a raw voice ID present as a
// value in AllowedVoices, it is returned as-is. Otherwise returns "".
func ResolveVoice(nameOrID string) string {
	if nameOrID == "" {
		return ""
	}
	if id, ok := AllowedVoices[strings.ToLower(nameOrID)]; ok {
		return id
	}
	for _, id := range AllowedVoices {
		if id == nameOrID {
			return id
		}
	}
	return ""
}

// Service generates + caches text-to-speech audio.
// On first request for a given (voice, text) pair it calls ElevenLabs and stores
// the mp3 in R2. Subsequent requests are served from R2.
type Service struct {
	client         *ElevenLabsClient
	storage        *common.Storage
	defaultVoiceID string
	modelID        string

	mu      sync.Mutex
	pending map[string]*sync.Mutex // per-key locks to prevent duplicate generation
}

func NewService(client *ElevenLabsClient, storage *common.Storage, defaultVoiceID, modelID string) *Service {
	return &Service{
		client:         client,
		storage:        storage,
		defaultVoiceID: defaultVoiceID,
		modelID:        modelID,
		pending:        make(map[string]*sync.Mutex),
	}
}

// Enabled reports whether the service has the dependencies it needs.
func (s *Service) Enabled() bool {
	return s != nil && s.client != nil && s.storage != nil
}

// DefaultVoice returns the configured default voice ID.
func (s *Service) DefaultVoice() string { return s.defaultVoiceID }

// NormalizeText trims, lowercases, collapses whitespace so "Hello " and "hello" share a cache key.
func NormalizeText(text string) string {
	t := strings.TrimSpace(text)
	t = strings.ToLower(t)
	var b strings.Builder
	prevSpace := false
	for _, r := range t {
		if r == ' ' || r == '\t' || r == '\n' || r == '\r' {
			if !prevSpace {
				b.WriteByte(' ')
			}
			prevSpace = true
			continue
		}
		b.WriteRune(r)
		prevSpace = false
	}
	return b.String()
}

// cacheKey returns the R2 object key for (voice, model, normalized text).
// Format: tts/v1/<voice_id>/<model_id>/<sha256>.mp3
func (s *Service) cacheKey(voiceID, text string) string {
	h := sha256.Sum256([]byte(voiceID + "|" + s.modelID + "|" + text))
	return fmt.Sprintf("tts/v1/%s/%s/%s.mp3", voiceID, s.modelID, hex.EncodeToString(h[:]))
}

// lockFor returns a per-key mutex so two concurrent requests for the same key only generate once.
func (s *Service) lockFor(key string) *sync.Mutex {
	s.mu.Lock()
	defer s.mu.Unlock()
	l, ok := s.pending[key]
	if !ok {
		l = &sync.Mutex{}
		s.pending[key] = l
	}
	return l
}

// EnsureCached makes sure an mp3 exists in R2 for (text, voice) without
// downloading the bytes back. Used by prewarm to avoid wasted reads.
// Returns cacheHit=true when the file already existed.
func (s *Service) EnsureCached(ctx context.Context, rawText, voiceID string) (bool, error) {
	if !s.Enabled() {
		return false, fmt.Errorf("tts service not enabled")
	}
	text := NormalizeText(rawText)
	if text == "" {
		return false, fmt.Errorf("empty text")
	}
	if len(text) > 500 {
		return false, fmt.Errorf("text too long")
	}
	if voiceID == "" {
		voiceID = s.defaultVoiceID
	}
	if voiceID == "" {
		return false, fmt.Errorf("no voice configured")
	}

	key := s.cacheKey(voiceID, text)
	if exists, err := s.storage.ObjectExists(ctx, key); err == nil && exists {
		return true, nil
	}

	lock := s.lockFor(key)
	lock.Lock()
	defer lock.Unlock()
	if exists, err := s.storage.ObjectExists(ctx, key); err == nil && exists {
		return true, nil
	}

	log.Printf("tts: generating '%s' (voice=%s model=%s)", text, voiceID, s.modelID)
	audio, err := s.client.Synthesize(ctx, text, voiceID)
	if err != nil {
		return false, fmt.Errorf("synthesize: %w", err)
	}
	if _, err := s.storage.UploadFile(ctx, key, bytes.NewReader(audio), int64(len(audio)), "audio/mpeg"); err != nil {
		return false, fmt.Errorf("cache upload: %w", err)
	}
	return false, nil
}

// Get returns the mp3 bytes for the given text, generating and caching if needed.
// voiceID may be "" to use the configured default.
// Returns (audio, cacheHit, err).
func (s *Service) Get(ctx context.Context, rawText, voiceID string) ([]byte, bool, error) {
	if !s.Enabled() {
		return nil, false, fmt.Errorf("tts service not enabled")
	}
	text := NormalizeText(rawText)
	if text == "" {
		return nil, false, fmt.Errorf("empty text")
	}
	if len(text) > 500 {
		return nil, false, fmt.Errorf("text too long")
	}
	if voiceID == "" {
		voiceID = s.defaultVoiceID
	}
	if voiceID == "" {
		return nil, false, fmt.Errorf("no voice configured")
	}

	key := s.cacheKey(voiceID, text)

	// Fast path: cache hit
	if exists, err := s.storage.ObjectExists(ctx, key); err == nil && exists {
		data, err := s.storage.GetObjectBytes(ctx, key)
		if err != nil {
			return nil, false, fmt.Errorf("read cached audio: %w", err)
		}
		return data, true, nil
	}

	// Slow path: take per-key lock, re-check cache, generate if still missing
	lock := s.lockFor(key)
	lock.Lock()
	defer lock.Unlock()

	if exists, err := s.storage.ObjectExists(ctx, key); err == nil && exists {
		data, err := s.storage.GetObjectBytes(ctx, key)
		if err != nil {
			return nil, false, fmt.Errorf("read cached audio (post-lock): %w", err)
		}
		return data, true, nil
	}

	log.Printf("tts: generating '%s' (voice=%s model=%s)", text, voiceID, s.modelID)
	audio, err := s.client.Synthesize(ctx, text, voiceID)
	if err != nil {
		return nil, false, fmt.Errorf("synthesize: %w", err)
	}

	if _, err := s.storage.UploadFile(ctx, key, bytes.NewReader(audio), int64(len(audio)), "audio/mpeg"); err != nil {
		log.Printf("tts: warning — failed to cache audio for '%s': %v", text, err)
	}

	return audio, false, nil
}
