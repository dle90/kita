package common

import (
	"encoding/json"
	"net/http"
)

type APIResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   *ErrorBody  `json:"error,omitempty"`
}

type ErrorBody struct {
	Code    string            `json:"code"`
	Message string            `json:"message"`
	Fields  map[string]string `json:"fields,omitempty"`
}

func RespondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	resp := APIResponse{
		Success: status >= 200 && status < 300,
		Data:    data,
	}
	json.NewEncoder(w).Encode(resp)
}

func RespondError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	resp := APIResponse{
		Success: false,
		Error: &ErrorBody{
			Code:    http.StatusText(status),
			Message: message,
		},
	}
	json.NewEncoder(w).Encode(resp)
}

func RespondAppError(w http.ResponseWriter, err *AppError) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(err.HTTPStatus)
	resp := APIResponse{
		Success: false,
		Error: &ErrorBody{
			Code:    err.Code,
			Message: err.Message,
		},
	}
	json.NewEncoder(w).Encode(resp)
}

func RespondValidationError(w http.ResponseWriter, fields map[string]string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusUnprocessableEntity)
	resp := APIResponse{
		Success: false,
		Error: &ErrorBody{
			Code:    "VALIDATION_ERROR",
			Message: "Request validation failed",
			Fields:  fields,
		},
	}
	json.NewEncoder(w).Encode(resp)
}
