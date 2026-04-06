package common

import (
	"fmt"
	"net/http"
)

type AppError struct {
	Code       string `json:"code"`
	Message    string `json:"message"`
	HTTPStatus int    `json:"-"`
}

func (e *AppError) Error() string {
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

func NewAppError(code string, message string, httpStatus int) *AppError {
	return &AppError{
		Code:       code,
		Message:    message,
		HTTPStatus: httpStatus,
	}
}

func ErrNotFound(message string) *AppError {
	return NewAppError("NOT_FOUND", message, http.StatusNotFound)
}

func ErrUnauthorized(message string) *AppError {
	return NewAppError("UNAUTHORIZED", message, http.StatusUnauthorized)
}

func ErrBadRequest(message string) *AppError {
	return NewAppError("BAD_REQUEST", message, http.StatusBadRequest)
}

func ErrInternal(message string) *AppError {
	return NewAppError("INTERNAL_ERROR", message, http.StatusInternalServerError)
}

func ErrConflict(message string) *AppError {
	return NewAppError("CONFLICT", message, http.StatusConflict)
}

func ErrForbidden(message string) *AppError {
	return NewAppError("FORBIDDEN", message, http.StatusForbidden)
}
