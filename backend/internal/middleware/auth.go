package middleware

import (
	"net/http"
	"strings"

	"seeker/pkg/i18n"
	"seeker/pkg/jwt"

	"github.com/gin-gonic/gin"
)

const (
	ContextKeyUserID   = "userID"
	ContextKeyEmail    = "email"
	ContextKeyDeviceID = "deviceID"
)

func AuthMiddleware(jwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		lang := i18n.LanguageFromRequest(c.Request)

		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"code":    40100,
				"message": i18n.T(lang, "auth_header_missing"),
			})
			return
		}

		tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
		if tokenStr == authHeader {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"code":    40100,
				"message": i18n.T(lang, "auth_scheme_invalid"),
			})
			return
		}

		claims, err := jwt.ParseToken(tokenStr, jwtSecret)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"code":    40101,
				"message": i18n.T(lang, "token_parse_failed"),
			})
			return
		}

		c.Set(ContextKeyUserID, claims.UserID)
		c.Set(ContextKeyEmail, claims.Email)
		c.Set(ContextKeyDeviceID, claims.DeviceID)
		c.Next()
	}
}

func GetUserID(c *gin.Context) string {
	v, _ := c.Get(ContextKeyUserID)
	return v.(string)
}

func GetEmail(c *gin.Context) string {
	v, _ := c.Get(ContextKeyEmail)
	return v.(string)
}

func GetDeviceID(c *gin.Context) string {
	v, _ := c.Get(ContextKeyDeviceID)
	return v.(string)
}
