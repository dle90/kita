package onboarding

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/auth"
	"github.com/kitaenglish/backend/internal/common"
)

type OnboardingHandler struct {
	service *OnboardingService
}

func NewOnboardingHandler(service *OnboardingService) *OnboardingHandler {
	return &OnboardingHandler{service: service}
}

func (h *OnboardingHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Post("/", h.CreateKid)
	r.Get("/", h.ListKids)
	r.Get("/{kidId}", h.GetKid)
	r.Put("/{kidId}", h.UpdateKid)
	r.Post("/{kidId}/placement", h.SubmitPlacement)
	return r
}

func (h *OnboardingHandler) CreateKid(w http.ResponseWriter, r *http.Request) {
	parentID := auth.ParentIDFromContext(r.Context())
	if parentID == uuid.Nil {
		common.RespondError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req CreateKidRequest
	if errs := common.DecodeAndValidate(r, &req); errs != nil {
		common.RespondValidationError(w, errs)
		return
	}

	kid, err := h.service.CreateKid(r.Context(), parentID, req)
	if err != nil {
		if appErr, ok := err.(*common.AppError); ok {
			common.RespondAppError(w, appErr)
			return
		}
		common.RespondError(w, http.StatusInternalServerError, "failed to create kid")
		return
	}

	common.RespondJSON(w, http.StatusCreated, KidResponse{Kid: *kid})
}

func (h *OnboardingHandler) ListKids(w http.ResponseWriter, r *http.Request) {
	parentID := auth.ParentIDFromContext(r.Context())
	if parentID == uuid.Nil {
		common.RespondError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	kids, err := h.service.GetKidsByParent(r.Context(), parentID)
	if err != nil {
		if appErr, ok := err.(*common.AppError); ok {
			common.RespondAppError(w, appErr)
			return
		}
		common.RespondError(w, http.StatusInternalServerError, "failed to list kids")
		return
	}

	common.RespondJSON(w, http.StatusOK, kids)
}

func (h *OnboardingHandler) GetKid(w http.ResponseWriter, r *http.Request) {
	kidID, err := uuid.Parse(chi.URLParam(r, "kidId"))
	if err != nil {
		common.RespondError(w, http.StatusBadRequest, "invalid kid ID")
		return
	}

	kid, svcErr := h.service.GetKid(r.Context(), kidID)
	if svcErr != nil {
		if appErr, ok := svcErr.(*common.AppError); ok {
			common.RespondAppError(w, appErr)
			return
		}
		common.RespondError(w, http.StatusInternalServerError, "failed to get kid")
		return
	}

	common.RespondJSON(w, http.StatusOK, KidResponse{Kid: *kid})
}

func (h *OnboardingHandler) UpdateKid(w http.ResponseWriter, r *http.Request) {
	kidID, err := uuid.Parse(chi.URLParam(r, "kidId"))
	if err != nil {
		common.RespondError(w, http.StatusBadRequest, "invalid kid ID")
		return
	}

	var req UpdateKidRequest
	if errs := common.DecodeAndValidate(r, &req); errs != nil {
		common.RespondValidationError(w, errs)
		return
	}

	kid, svcErr := h.service.UpdateKid(r.Context(), kidID, req)
	if svcErr != nil {
		if appErr, ok := svcErr.(*common.AppError); ok {
			common.RespondAppError(w, appErr)
			return
		}
		common.RespondError(w, http.StatusInternalServerError, "failed to update kid")
		return
	}

	common.RespondJSON(w, http.StatusOK, KidResponse{Kid: *kid})
}

func (h *OnboardingHandler) SubmitPlacement(w http.ResponseWriter, r *http.Request) {
	kidID, err := uuid.Parse(chi.URLParam(r, "kidId"))
	if err != nil {
		common.RespondError(w, http.StatusBadRequest, "invalid kid ID")
		return
	}

	var req PlacementResultRequest
	if errs := common.DecodeAndValidate(r, &req); errs != nil {
		common.RespondValidationError(w, errs)
		return
	}

	kid, svcErr := h.service.SubmitPlacement(r.Context(), kidID, req)
	if svcErr != nil {
		if appErr, ok := svcErr.(*common.AppError); ok {
			common.RespondAppError(w, appErr)
			return
		}
		common.RespondError(w, http.StatusInternalServerError, "failed to submit placement")
		return
	}

	common.RespondJSON(w, http.StatusOK, KidResponse{Kid: *kid})
}
