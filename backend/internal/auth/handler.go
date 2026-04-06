package auth

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/kitaenglish/backend/internal/common"
)

type AuthHandler struct {
	service *AuthService
}

func NewAuthHandler(service *AuthService) *AuthHandler {
	return &AuthHandler{service: service}
}

func (h *AuthHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Post("/register", h.Register)
	r.Post("/login", h.Login)
	r.Post("/refresh", h.Refresh)
	return r
}

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req RegisterRequest
	if errs := common.DecodeAndValidate(r, &req); errs != nil {
		common.RespondValidationError(w, errs)
		return
	}

	tokens, err := h.service.Register(r.Context(), req)
	if err != nil {
		if appErr, ok := err.(*common.AppError); ok {
			common.RespondAppError(w, appErr)
			return
		}
		common.RespondError(w, http.StatusInternalServerError, "registration failed")
		return
	}

	common.RespondJSON(w, http.StatusCreated, tokens)
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req LoginRequest
	if errs := common.DecodeAndValidate(r, &req); errs != nil {
		common.RespondValidationError(w, errs)
		return
	}

	tokens, err := h.service.Login(r.Context(), req)
	if err != nil {
		if appErr, ok := err.(*common.AppError); ok {
			common.RespondAppError(w, appErr)
			return
		}
		common.RespondError(w, http.StatusInternalServerError, "login failed")
		return
	}

	common.RespondJSON(w, http.StatusOK, tokens)
}

func (h *AuthHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	var req RefreshRequest
	if errs := common.DecodeAndValidate(r, &req); errs != nil {
		common.RespondValidationError(w, errs)
		return
	}

	tokens, err := h.service.RefreshTokens(r.Context(), req.RefreshToken)
	if err != nil {
		if appErr, ok := err.(*common.AppError); ok {
			common.RespondAppError(w, appErr)
			return
		}
		common.RespondError(w, http.StatusInternalServerError, "token refresh failed")
		return
	}

	common.RespondJSON(w, http.StatusOK, tokens)
}
