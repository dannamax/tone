package middleware

import (
	"crypto/subtle"
	"net/http"

	"github.com/gin-gonic/gin"
)

// AdminTokenMiddleware 校验运维统计接口的静态令牌（X-Admin-Token）。
// 与用户 JWT 体系解耦，供外部脚本/监控直接调用。
//   - token 未配置（空串）时端点整体禁用，返回 403，避免误部署后裸奔；
//   - token 校验使用恒时比较，防时序侧信道。
func AdminTokenMiddleware(token string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if token == "" {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"code":    40300,
				"message": "admin api disabled (ADMIN_API_TOKEN not set)",
			})
			return
		}
		got := c.GetHeader("X-Admin-Token")
		if subtle.ConstantTimeCompare([]byte(got), []byte(token)) != 1 {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"code":    40100,
				"message": "invalid admin token",
			})
			return
		}
		c.Next()
	}
}
