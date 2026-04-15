package tts

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// ElevenLabsClient calls the ElevenLabs text-to-speech API.
type ElevenLabsClient struct {
	apiKey  string
	modelID string
	http    *http.Client
}

func NewElevenLabsClient(apiKey, modelID string) *ElevenLabsClient {
	if modelID == "" {
		modelID = "eleven_turbo_v2_5"
	}
	return &ElevenLabsClient{
		apiKey:  apiKey,
		modelID: modelID,
		http:    &http.Client{Timeout: 30 * time.Second},
	}
}

type ttsRequest struct {
	Text          string         `json:"text"`
	ModelID       string         `json:"model_id"`
	VoiceSettings *voiceSettings `json:"voice_settings,omitempty"`
}

type voiceSettings struct {
	Stability       float64 `json:"stability"`
	SimilarityBoost float64 `json:"similarity_boost"`
	Style           float64 `json:"style"`
	UseSpeakerBoost bool    `json:"use_speaker_boost"`
}

// Synthesize converts text into an mp3 byte slice using ElevenLabs.
// Returns the raw mp3 bytes (mp3_44100_128).
func (c *ElevenLabsClient) Synthesize(ctx context.Context, text, voiceID string) ([]byte, error) {
	body := ttsRequest{
		Text:    text,
		ModelID: c.modelID,
		VoiceSettings: &voiceSettings{
			Stability:       0.55,
			SimilarityBoost: 0.75,
			Style:           0.15,
			UseSpeakerBoost: true,
		},
	}
	buf, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	url := fmt.Sprintf("https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128", voiceID)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(buf))
	if err != nil {
		return nil, fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("xi-api-key", c.apiKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "audio/mpeg")

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("elevenlabs request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		errBody, _ := io.ReadAll(io.LimitReader(resp.Body, 2048))
		return nil, fmt.Errorf("elevenlabs %d: %s", resp.StatusCode, string(errBody))
	}

	audio, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read audio: %w", err)
	}
	if len(audio) == 0 {
		return nil, fmt.Errorf("elevenlabs returned empty audio")
	}
	return audio, nil
}
