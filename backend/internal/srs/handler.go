package srs

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/auth"
	"github.com/kitaenglish/backend/internal/common"
)

type SrsHandler struct {
	service *SrsService
}

func NewSrsHandler(service *SrsService) *SrsHandler {
	return &SrsHandler{service: service}
}

func (h *SrsHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Get("/due", h.GetDueCards)
	r.Post("/review", h.ReviewCard)
	return r
}

func (h *SrsHandler) GetDueCards(w http.ResponseWriter, r *http.Request) {
	kidID, err := uuid.Parse(chi.URLParam(r, "kidId"))
	if err != nil {
		common.RespondError(w, http.StatusBadRequest, "invalid kid ID")
		return
	}

	_ = auth.ParentIDFromContext(r.Context())

	cards, err := h.service.repo.GetDueCards(r.Context(), kidID, time.Now())
	if err != nil {
		common.RespondError(w, http.StatusInternalServerError, "failed to get due cards")
		return
	}

	if cards == nil {
		cards = []*SrsCard{}
	}

	common.RespondJSON(w, http.StatusOK, cards)
}

func (h *SrsHandler) ReviewCard(w http.ResponseWriter, r *http.Request) {
	kidID, err := uuid.Parse(chi.URLParam(r, "kidId"))
	if err != nil {
		common.RespondError(w, http.StatusBadRequest, "invalid kid ID")
		return
	}

	_ = kidID // ownership check would go here

	var req ReviewRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		common.RespondError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	card, svcErr := h.service.ReviewCard(r.Context(), req.CardID, req.Quality)
	if svcErr != nil {
		if appErr, ok := svcErr.(*common.AppError); ok {
			common.RespondAppError(w, appErr)
			return
		}
		common.RespondError(w, http.StatusInternalServerError, "failed to review card")
		return
	}

	common.RespondJSON(w, http.StatusOK, card)
}
