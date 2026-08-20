package middleware

import (
	"seeker/pkg/i18n"

	"github.com/gin-gonic/gin"
)

// LanguageMiddleware extracts Accept-Language from request headers and
// injects it into the request context so downstream services can localize.
func LanguageMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		lang := i18n.LanguageFromRequest(c.Request)
		ctx := i18n.WithLanguage(c.Request.Context(), lang)
		c.Request = c.Request.WithContext(ctx)
		c.Next()
	}
}
