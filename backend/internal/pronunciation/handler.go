package pronunciation

import (
	"io"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/common"
	"github.com/kitaenglish/backend/internal/onboarding"
)

type PronunciationHandler struct {
	service *PronunciationService
	kidRepo onboarding.KidRepository
}

func NewPronunciationHandler(service *PronunciationService, kidRepo onboarding.KidRepository) *PronunciationHandler {
	return &PronunciationHandler{service: service, kidRepo: kidRepo}
}

func (h *PronunciationHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Post("/score", h.ScorePronunciation)
	return r
}

func (h *PronunciationHandler) ScorePronunciation(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseMultipartForm(10 << 20); err != nil { // 10MB max
		common.RespondError(w, http.StatusBadRequest, "failed to parse multipart form")
		return
	}

	// Get audio file and its content type
	audioFile, audioHeader, err := r.FormFile("audio")
	if err != nil {
		common.RespondError(w, http.StatusBadRequest, "audio file is required")
		return
	}
	defer audioFile.Close()

	audioData, err := io.ReadAll(audioFile)
	if err != nil {
		common.RespondError(w, http.StatusBadRequest, "failed to read audio file")
		return
	}

	// Get form fields directly (matching Flutter client)
	referenceText := r.FormValue("reference_text")
	if referenceText == "" {
		common.RespondError(w, http.StatusBadRequest, "reference_text is required")
		return
	}

	kidIDStr := r.FormValue("kid_id")
	kidID, err := uuid.Parse(kidIDStr)
	if err != nil {
		common.RespondError(w, http.StatusBadRequest, "valid kid_id is required")
		return
	}

	var vocabularyID *uuid.UUID
	if vocabStr := r.FormValue("vocabulary_id"); vocabStr != "" {
		if vid, err := uuid.Parse(vocabStr); err == nil {
			vocabularyID = &vid
		}
	}

	// Look up kid's dialect for L1 error classification
	dialect := "northern"
	if kid, err := h.kidRepo.GetKid(r.Context(), kidID); err == nil && kid != nil {
		dialect = kid.Dialect
	}

	// Detect audio content type from uploaded file
	audioContentType := audioHeader.Header.Get("Content-Type")
	if audioContentType == "" {
		audioContentType = "audio/wav"
	}

	score, svcErr := h.service.ScorePronunciation(r.Context(), kidID, audioData, referenceText, dialect, vocabularyID, audioContentType)
	if svcErr != nil {
		if appErr, ok := svcErr.(*common.AppError); ok {
			common.RespondAppError(w, appErr)
			return
		}
		common.RespondError(w, http.StatusInternalServerError, "pronunciation scoring failed")
		return
	}

	common.RespondJSON(w, http.StatusOK, score)
}
