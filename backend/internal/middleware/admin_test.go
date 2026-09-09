package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func adminTestRequest() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Status(http.StatusOK)
	}
}

func runAdminMW(t *testing.T, headerToken string, mw, downstream gin.HandlerFunc) *httptest.ResponseRecorder {
	t.Helper()
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.GET("/protected", mw, downstream)
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	if headerToken != "" {
		req.Header.Set("X-Admin-Token", headerToken)
	}
	r.ServeHTTP(w, req)
	return w
}

func TestAdminTokenMiddleware_DisabledWhenNotConfigured(t *testing.T) {
	w := runAdminMW(t, "", AdminTokenMiddleware(""), adminTestRequest())
	if w.Code != http.StatusForbidden {
		t.Errorf("empty configured token: code = %d, want 403", w.Code)
	}
}

func TestAdminTokenMiddleware_WrongToken(t *testing.T) {
	// 请求头携带的 token 与服务器配置不一致 → 401
	w := runAdminMW(t, "wrong-token", AdminTokenMiddleware("secret-token"), adminTestRequest())
	if w.Code != http.StatusUnauthorized {
		t.Errorf("wrong token: code = %d, want 401", w.Code)
	}
}

func TestAdminTokenMiddleware_MissingHeader(t *testing.T) {
	w := runAdminMW(t, "", AdminTokenMiddleware("secret-token"), adminTestRequest())
	if w.Code != http.StatusUnauthorized {
		t.Errorf("missing header: code = %d, want 401", w.Code)
	}
}

func TestAdminTokenMiddleware_CorrectToken(t *testing.T) {
	w := runAdminMW(t, "secret-token", AdminTokenMiddleware("secret-token"), adminTestRequest())
	if w.Code != http.StatusOK {
		t.Errorf("correct token: code = %d, want 200", w.Code)
	}
}

func TestAdminTokenMiddleware_QueryToken(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.GET("/protected", AdminTokenMiddleware("secret-token"), func(c *gin.Context) {
		c.Status(http.StatusOK)
	})
	w := httptest.NewRecorder()
	// 无自定义 header 的简单 GET（浏览器 HTML 页面场景），token 走查询参数
	req := httptest.NewRequest(http.MethodGet, "/protected?admin_token=secret-token", nil)
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Errorf("query token: code = %d, want 200", w.Code)
	}
}
