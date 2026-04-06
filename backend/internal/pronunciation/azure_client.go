package pronunciation

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"

	"github.com/kitaenglish/backend/internal/config"
)

type AzureSpeechClient struct {
	key    string
	region string
	client *http.Client
}

func NewAzureSpeechClient(cfg config.AzureConfig) *AzureSpeechClient {
	return &AzureSpeechClient{
		key:    cfg.SpeechKey,
		region: cfg.SpeechRegion,
		client: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

func (c *AzureSpeechClient) ScorePronunciation(audioData []byte, referenceText string) (*AzureResponse, error) {
	if c.key == "" {
		return c.mockResponse(referenceText), nil
	}

	endpoint := fmt.Sprintf(
		"https://%s.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1",
		c.region,
	)

	pronAssessment := map[string]interface{}{
		"ReferenceText":    referenceText,
		"GradingSystem":    "HundredMark",
		"Granularity":      "Phoneme",
		"PhonemeAlphabet":  "IPA",
		"Dimension":        "Comprehensive",
	}
	pronJSON, _ := json.Marshal(pronAssessment)

	params := url.Values{}
	params.Set("language", "en-US")
	params.Set("format", "detailed")

	reqURL := fmt.Sprintf("%s?%s", endpoint, params.Encode())
	req, err := http.NewRequest("POST", reqURL, bytes.NewReader(audioData))
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	req.Header.Set("Ocp-Apim-Subscription-Key", c.key)
	req.Header.Set("Content-Type", "audio/wav")
	req.Header.Set("Pronunciation-Assessment", string(pronJSON))
	req.Header.Set("Accept", "application/json")

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("calling Azure Speech API: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("Azure Speech API error (status %d): %s", resp.StatusCode, string(body))
	}

	var azureResp AzureResponse
	if err := json.Unmarshal(body, &azureResp); err != nil {
		return nil, fmt.Errorf("parsing Azure response: %w", err)
	}

	return &azureResp, nil
}

func (c *AzureSpeechClient) mockResponse(referenceText string) *AzureResponse {
	return &AzureResponse{
		RecognitionStatus: "Success",
		NBest: []AzureNBest{
			{
				Confidence: 0.95,
				PronunciationAssessment: AzurePronAssessment{
					AccuracyScore:     85.0,
					FluencyScore:      80.0,
					CompletenessScore: 90.0,
					PronScore:         85.0,
				},
				Words: []AzureWord{
					{
						Word: referenceText,
						PronunciationAssessment: AzureWordAssessment{
							AccuracyScore: 85.0,
							ErrorType:     "None",
						},
						Phonemes: []AzurePhoneme{
							{
								Phoneme: "h",
								PronunciationAssessment: AzurePhonemeAssessment{AccuracyScore: 90},
							},
							{
								Phoneme: "ə",
								PronunciationAssessment: AzurePhonemeAssessment{AccuracyScore: 85},
							},
						},
					},
				},
			},
		},
	}
}
