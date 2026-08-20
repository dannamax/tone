package middleware

import (
	"net/http"
	"strings"

	"seeker/pkg/i18n"

	"github.com/gin-gonic/gin"
)

func DeviceValidateMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		lang := i18n.LanguageFromRequest(c.Request)
		deviceID := c.GetHeader("X-Device-ID")
		if deviceID == "" {
			c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{
				"code":    40001,
				"message": i18n.T(lang, "device_id_required"),
			})
			return
		}
		if len(strings.TrimSpace(deviceID)) < 8 {
			c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{
				"code":    40002,
				"message": i18n.T(lang, "device_id_invalid"),
			})
			return
		}
		c.Set("headerDeviceID", deviceID)
		c.Next()
	}
}

func CORSMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Device-ID")
		c.Header("Access-Control-Max-Age", "86400")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}
