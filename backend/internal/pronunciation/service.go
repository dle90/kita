package pronunciation

import (
	"bytes"
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/common"
)

type PronunciationService struct {
	repo        PronunciationRepository
	azureClient *AzureSpeechClient
	storage     *common.Storage
}

func NewPronunciationService(repo PronunciationRepository, azureClient *AzureSpeechClient, storage *common.Storage) *PronunciationService {
	return &PronunciationService{
		repo:        repo,
		azureClient: azureClient,
		storage:     storage,
	}
}

func (s *PronunciationService) ScorePronunciation(ctx context.Context, kidID uuid.UUID, audioData []byte, referenceText string, dialect string, vocabularyID *uuid.UUID, contentType ...string) (*PronunciationScore, error) {
	// Determine audio format
	audioMime := "audio/wav"
	audioExt := "wav"
	if len(contentType) > 0 && contentType[0] != "" {
		audioMime = contentType[0]
		if audioMime == "audio/webm" || audioMime == "audio/webm;codecs=opus" {
			audioExt = "webm"
		}
	}

	// Upload audio to storage
	audioKey := fmt.Sprintf("pronunciation/%s/%s.%s", kidID.String(), uuid.New().String(), audioExt)
	audioURL, err := s.storage.UploadFile(ctx, audioKey, bytes.NewReader(audioData), int64(len(audioData)), audioMime)
	if err != nil {
		return nil, common.ErrInternal("failed to upload audio file")
	}

	// Call Azure Speech API
	azureResp, err := s.azureClient.ScorePronunciation(audioData, referenceText, audioMime)
	if err != nil {
		return nil, common.ErrInternal(fmt.Sprintf("pronunciation scoring failed: %v", err))
	}

	if len(azureResp.NBest) == 0 {
		return nil, common.ErrInternal("no pronunciation results returned")
	}

	best := azureResp.NBest[0]
	assessment := best.PronunciationAssessment

	// Extract phoneme results
	var phonemes []PhonemeResult
	for _, word := range best.Words {
		for _, ph := range word.Phonemes {
			phonemes = append(phonemes, PhonemeResult{
				Phoneme:   ph.Phoneme,
				Score:     ph.PronunciationAssessment.AccuracyScore,
				IsCorrect: ph.PronunciationAssessment.AccuracyScore >= 60,
				Expected:  ph.Phoneme,
				Actual:    ph.Phoneme,
			})
		}
	}

	// Run L1 error classification
	l1Errors := ClassifyL1Errors(best.Words, dialect)

	score := &PronunciationScore{
		ID:                 uuid.New(),
		KidID:              kidID,
		VocabularyID:       vocabularyID,
		ReferenceText:      referenceText,
		AudioURL:           audioURL,
		AccuracyScore:      assessment.AccuracyScore,
		FluencyScore:       assessment.FluencyScore,
		CompletenessScore:  assessment.CompletenessScore,
		PronunciationScore: assessment.PronScore,
		Phonemes:           phonemes,
		L1Errors:           l1Errors,
		CreatedAt:          time.Now(),
	}

	if err := s.repo.SaveScore(ctx, score); err != nil {
		return nil, common.ErrInternal("failed to save pronunciation score")
	}

	return score, nil
}
