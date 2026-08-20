package i18n

import (
	"context"
	"fmt"
	"net/http"
	"strings"
)

// Language constants
const (
	LangEN = "en"
	LangZH = "zh"
)

// Context key for language
type langCtxKey struct{}

// WithLanguage stores the language in context.
func WithLanguage(ctx context.Context, lang string) context.Context {
	return context.WithValue(ctx, langCtxKey{}, lang)
}

// LanguageFromCtx extracts language from context, defaults to EN.
func LanguageFromCtx(ctx context.Context) string {
	lang, ok := ctx.Value(langCtxKey{}).(string)
	if !ok || lang == "" {
		return LangEN
	}
	return lang
}

// ParseAcceptLanguage extracts the preferred language from Accept-Language header.
func ParseAcceptLanguage(header string) string {
	if header == "" {
		return LangEN
	}
	lang := header
	if idx := strings.IndexAny(lang, ",;"); idx != -1 {
		lang = lang[:idx]
	}
	lang = strings.TrimSpace(lang)
	if strings.HasPrefix(lang, "zh") {
		return LangZH
	}
	return LangEN
}

var messages = map[string]map[string]string{
	LangEN: enMessages,
	LangZH: zhMessages,
}

// T returns a translated message for the given key and language.
func T(lang, key string, args ...any) string {
	bundle, ok := messages[lang]
	if !ok {
		bundle = messages[LangEN]
	}
	msg, ok := bundle[key]
	if !ok {
		msg = messages[LangEN][key]
		if msg == "" {
			return key
		}
	}
	if len(args) > 0 {
		return fmt.Sprintf(msg, args...)
	}
	return msg
}

// TCtx is a convenience: T(LanguageFromCtx(ctx), key, args...).
func TCtx(ctx context.Context, key string, args ...any) string {
	return T(LanguageFromCtx(ctx), key, args...)
}

// --- Error codes (machine-readable, kept in English) ---
const (
	ErrCodeInvalidEmail      = "INVALID_EMAIL"
	ErrCodeCodeExpired       = "CODE_EXPIRED"
	ErrCodeCodeInvalid       = "CODE_INVALID"
	ErrCodeRateLimit         = "RATE_LIMITED"
	ErrCodeEmailSendFailed   = "EMAIL_SEND_FAILED"
	ErrCodeBadRequest        = "BAD_REQUEST"
	ErrCodeUnauthorized      = "UNAUTHORIZED"
	ErrCodeTaskNotFound      = "TASK_NOT_FOUND"
	ErrCodeInsufficientFunds = "INSUFFICIENT_FUNDS"
	ErrCodeInternalError     = "INTERNAL_ERROR"
	ErrCodeUserNotFound      = "USER_NOT_FOUND"
	ErrCodeTargetNotFound    = "TARGET_USER_NOT_FOUND"
	ErrCodeWithdrawMin       = "WITHDRAW_BELOW_MIN"
	ErrCodeFrozenNotAvail    = "FROZEN_NOT_AVAILABLE"
	ErrCodeInvalidAmount     = "INVALID_AMOUNT"
	ErrCodeTxnNotFound       = "TRANSACTION_NOT_FOUND"
	ErrCodeNotOwner          = "NOT_OWNER"
	ErrCodeTaskStatusWrong   = "TASK_STATUS_WRONG"
	ErrCodeNotFound          = "NOT_FOUND"
)

// APIError is a structured error with code and localized message.
type APIError struct {
	Code    int    `json:"-"`
	ErrCode string `json:"code"`
	Message string `json:"message"`
}

func (e *APIError) Error() string {
	return e.Message
}

func NewAPIError(httpStatus int, errCode string, message string) *APIError {
	return &APIError{
		Code:    httpStatus,
		ErrCode: errCode,
		Message: message,
	}
}

// LanguageFromRequest extracts language from request headers.
func LanguageFromRequest(r *http.Request) string {
	return ParseAcceptLanguage(r.Header.Get("Accept-Language"))
}
