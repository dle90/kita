package progress

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/common"
)

type ProgressHandler struct {
	service *ProgressService
}

func NewProgressHandler(service *ProgressService) *ProgressHandler {
	return &ProgressHandler{service: service}
}

func (h *ProgressHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Get("/", h.GetChallengeSummary)
	r.Get("/vocabulary", h.GetVocabularyProgress)
	r.Get("/pronunciation", h.GetPronunciationProgress)
	r.Get("/skills", h.GetSkillSummary)
	return r
}

func (h *ProgressHandler) GetChallengeSummary(w http.ResponseWriter, r *http.Request) {
	kidID, err := uuid.Parse(chi.URLParam(r, "kidId"))
	if err != nil {
		common.RespondError(w, http.StatusBadRequest, "invalid kid ID")
		return
	}

	summary, svcErr := h.service.GetChallengeSummary(r.Context(), kidID)
	if svcErr != nil {
		if appErr, ok := svcErr.(*common.AppError); ok {
			common.RespondAppError(w, appErr)
			return
		}
		common.RespondError(w, http.StatusInternalServerError, "failed to get progress")
		return
	}

	common.RespondJSON(w, http.StatusOK, summary)
}

func (h *ProgressHandler) GetVocabularyProgress(w http.ResponseWriter, r *http.Request) {
	kidID, err := uuid.Parse(chi.URLParam(r, "kidId"))
	if err != nil {
		common.RespondError(w, http.StatusBadRequest, "invalid kid ID")
		return
	}

	vp, svcErr := h.service.GetVocabularyProgress(r.Context(), kidID)
	if svcErr != nil {
		if appErr, ok := svcErr.(*common.AppError); ok {
			common.RespondAppError(w, appErr)
			return
		}
		common.RespondError(w, http.StatusInternalServerError, "failed to get vocabulary progress")
		return
	}

	common.RespondJSON(w, http.StatusOK, vp)
}

func (h *ProgressHandler) GetPronunciationProgress(w http.ResponseWriter, r *http.Request) {
	kidID, err := uuid.Parse(chi.URLParam(r, "kidId"))
	if err != nil {
		common.RespondError(w, http.StatusBadRequest, "invalid kid ID")
		return
	}

	pp, svcErr := h.service.GetPronunciationProgress(r.Context(), kidID)
	if svcErr != nil {
		if appErr, ok := svcErr.(*common.AppError); ok {
			common.RespondAppError(w, appErr)
			return
		}
		common.RespondError(w, http.StatusInternalServerError, "failed to get pronunciation progress")
		return
	}

	common.RespondJSON(w, http.StatusOK, pp)
}

func (h *ProgressHandler) GetSkillSummary(w http.ResponseWriter, r *http.Request) {
	kidID, err := uuid.Parse(chi.URLParam(r, "kidId"))
	if err != nil {
		common.RespondError(w, http.StatusBadRequest, "invalid kid ID")
		return
	}

	summary, svcErr := h.service.GetSkillSummary(r.Context(), kidID)
	if svcErr != nil {
		if appErr, ok := svcErr.(*common.AppError); ok {
			common.RespondAppError(w, appErr)
			return
		}
		common.RespondError(w, http.StatusInternalServerError, "failed to get skill summary")
		return
	}

	common.RespondJSON(w, http.StatusOK, summary)
}
