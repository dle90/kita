package common

import (
	"encoding/json"
	"fmt"
	"net/http"
	"reflect"
	"strings"
)

func DecodeAndValidate(r *http.Request, dst interface{}) map[string]string {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		return map[string]string{"body": "Invalid JSON: " + err.Error()}
	}
	return ValidateStruct(dst)
}

func ValidateStruct(s interface{}) map[string]string {
	errors := make(map[string]string)
	v := reflect.ValueOf(s)
	if v.Kind() == reflect.Ptr {
		v = v.Elem()
	}
	t := v.Type()

	for i := 0; i < v.NumField(); i++ {
		field := t.Field(i)
		value := v.Field(i)
		tag := field.Tag.Get("validate")
		if tag == "" {
			continue
		}

		jsonName := field.Tag.Get("json")
		if jsonName == "" || jsonName == "-" {
			jsonName = field.Name
		}
		jsonName = strings.Split(jsonName, ",")[0]

		rules := strings.Split(tag, ",")
		for _, rule := range rules {
			rule = strings.TrimSpace(rule)
			if rule == "required" {
				if isZero(value) {
					errors[jsonName] = fmt.Sprintf("%s is required", jsonName)
				}
			}
			if strings.HasPrefix(rule, "min=") {
				minStr := strings.TrimPrefix(rule, "min=")
				var minVal int
				fmt.Sscanf(minStr, "%d", &minVal)
				if value.Kind() == reflect.String && len(value.String()) < minVal {
					errors[jsonName] = fmt.Sprintf("%s must be at least %d characters", jsonName, minVal)
				}
			}
			if strings.HasPrefix(rule, "max=") {
				maxStr := strings.TrimPrefix(rule, "max=")
				var maxVal int
				fmt.Sscanf(maxStr, "%d", &maxVal)
				if value.Kind() == reflect.String && len(value.String()) > maxVal {
					errors[jsonName] = fmt.Sprintf("%s must be at most %d characters", jsonName, maxVal)
				}
			}
		}
	}

	if len(errors) == 0 {
		return nil
	}
	return errors
}

func isZero(v reflect.Value) bool {
	switch v.Kind() {
	case reflect.String:
		return v.String() == ""
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return v.Int() == 0
	case reflect.Float32, reflect.Float64:
		return v.Float() == 0
	case reflect.Bool:
		return !v.Bool()
	case reflect.Ptr, reflect.Interface:
		return v.IsNil()
	case reflect.Slice, reflect.Map:
		return v.IsNil() || v.Len() == 0
	default:
		return false
	}
}
