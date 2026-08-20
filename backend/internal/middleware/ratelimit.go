package middleware

import (
	"net/http"

	"seeker/pkg/i18n"

	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"
)

type IPRateLimiter struct {
	limiters map[string]*rate.Limiter
	rate     rate.Limit
	burst    int
}

func NewIPRateLimiter(r rate.Limit, b int) *IPRateLimiter {
	return &IPRateLimiter{
		limiters: make(map[string]*rate.Limiter),
		rate:     r,
		burst:    b,
	}
}

func (l *IPRateLimiter) GetLimiter(ip string) *rate.Limiter {
	limiter, exists := l.limiters[ip]
	if !exists {
		limiter = rate.NewLimiter(l.rate, l.burst)
		l.limiters[ip] = limiter
	}
	return limiter
}

func RateLimitMiddleware(rps float64, burst int) gin.HandlerFunc {
	limiter := NewIPRateLimiter(rate.Limit(rps), burst)
	return func(c *gin.Context) {
		ip := c.ClientIP()
		if !limiter.GetLimiter(ip).Allow() {
			lang := i18n.LanguageFromRequest(c.Request)
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"code":    42900,
				"message": i18n.T(lang, "rate_limited"),
			})
			return
		}
		c.Next()
	}
}
