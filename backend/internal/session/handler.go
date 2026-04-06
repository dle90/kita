package session

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/kitaenglish/backend/internal/auth"
	"github.com/kitaenglish/backend/internal/common"
)

type SessionHandler struct {
	service *SessionService
}

func NewSessionHandler(service *SessionService) *SessionHandler {
	return &SessionHandler{service: service}
}

func (h *SessionHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Get("/", h.ListSessions)
	r.Get("/{day}", h.GetSession)
	r.Post("/{day}/start", h.StartSession)
	r.Post("/{day}/complete", h.CompleteSession)
	return r
}

func (h *SessionHandler) ActivityRoutes() chi.Router {
	r := chi.NewRouter()
	r.Post("/{activityId}/result", h.SubmitActivityResult)
	return r
}

func (h *SessionHandler) ListSessions(w http.ResponseWriter, r *http.Request) {
	kidID, err := uuid.Parse(chi.URLParam(r, "kidId"))
	if err != nil {
		common.RespondError(w, http.StatusBadRequest, "invalid kid ID")
		return
	}

	_ = auth.ParentIDFromContext(r.Context())

	sessions, svcErr := h.service.GetOrCreateSessions(r.Context(), kidID)
	if svcErr != nil {
		if appErr, ok := svcErr.(*common.AppError); ok {
			common.RespondAppError(w, appErr)
			return
		}
		common.RespondError(w, http.StatusInternalServerError, "failed to get sessions")
		return
	}

	common.RespondJSON(w, http.StatusOK, sessions)
}

func (h *SessionHandler) GetSession(w http.ResponseWriter, r *http.Request) {
	kidID, err := uuid.Parse(chi.URLParam(r, "kidId"))
	if err != nil {
		common.RespondError(w, http.StatusBadRequest, "invalid kid ID")
		return
	}

	day, err := strconv.Atoi(chi.URLParam(r, "day"))
	if err != nil || day < 1 || day > 7 {
		common.RespondError(w, http.StatusBadRequest, "day must be between 1 and 7")
		return
	}

	session, svcErr := h.service.GetSession(r.Context(), kidID, day)
	if svcErr != nil {
		if appErr, ok := svcErr.(*common.AppError); ok {
			common.RespondAppError(w, appErr)
			return
		}
		common.RespondError(w, http.StatusInternalServerError, "failed to get session")
		return
	}

	common.RespondJSON(w, http.StatusOK, session)
}

func (h *SessionHandler) StartSession(w http.ResponseWriter, r *http.Request) {
	kidID, err := uuid.Parse(chi.URLParam(r, "kidId"))
	if err != nil {
		common.RespondError(w, http.StatusBadRequest, "invalid kid ID")
		return
	}

	day, err := strconv.Atoi(chi.URLParam(r, "day"))
	if err != nil || day < 1 || day > 7 {
		common.RespondError(w, http.StatusBadRequest, "day must be between 1 and 7")
		return
	}

	session, svcErr := h.service.StartSession(r.Context(), kidID, day)
	if svcErr != nil {
		if appErr, ok := svcErr.(*common.AppError); ok {
			common.RespondAppError(w, appErr)
			return
		}
		common.RespondError(w, http.StatusInternalServerError, "failed to start session")
		return
	}

	common.RespondJSON(w, http.StatusOK, session)
}

func (h *SessionHandler) CompleteSession(w http.ResponseWriter, r *http.Request) {
	kidID, err := uuid.Parse(chi.URLParam(r, "kidId"))
	if err != nil {
		common.RespondError(w, http.StatusBadRequest, "invalid kid ID")
		return
	}

	day, err := strconv.Atoi(chi.URLParam(r, "day"))
	if err != nil || day < 1 || day > 7 {
		common.RespondError(w, http.StatusBadRequest, "day must be between 1 and 7")
		return
	}

	session, svcErr := h.service.CompleteSession(r.Context(), kidID, day)
	if svcErr != nil {
		if appErr, ok := svcErr.(*common.AppError); ok {
			common.RespondAppError(w, appErr)
			return
		}
		common.RespondError(w, http.StatusInternalServerError, "failed to complete session")
		return
	}

	common.RespondJSON(w, http.StatusOK, session)
}

func (h *SessionHandler) SubmitActivityResult(w http.ResponseWriter, r *http.Request) {
	kidID, err := uuid.Parse(chi.URLParam(r, "kidId"))
	if err != nil {
		common.RespondError(w, http.StatusBadRequest, "invalid kid ID")
		return
	}

	activityIDStr := chi.URLParam(r, "activityId")
	// activityId is used as the session ID lookup context
	sessionID, err := uuid.Parse(activityIDStr)
	if err != nil {
		common.RespondError(w, http.StatusBadRequest, "invalid activity ID")
		return
	}

	var req ActivityResultRequest
	if errs := common.DecodeAndValidate(r, &req); errs != nil {
		common.RespondValidationError(w, errs)
		return
	}

	result, svcErr := h.service.SubmitActivityResult(r.Context(), kidID, sessionID, req)
	if svcErr != nil {
		if appErr, ok := svcErr.(*common.AppError); ok {
			common.RespondAppError(w, appErr)
			return
		}
		common.RespondError(w, http.StatusInternalServerError, "failed to submit result")
		return
	}

	common.RespondJSON(w, http.StatusCreated, result)
}
