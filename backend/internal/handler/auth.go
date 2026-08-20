package handler

import (
	"seeker/internal/middleware"
	"seeker/internal/service"
	"seeker/pkg/i18n"
	"seeker/pkg/response"

	"github.com/gin-gonic/gin"
)

type AuthHandler struct {
	authSvc *service.AuthService
}

func NewAuthHandler(authSvc *service.AuthService) *AuthHandler {
	return &AuthHandler{authSvc: authSvc}
}

func (h *AuthHandler) SendCode(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	var req struct {
		Email string `json:"email" binding:"required,email"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, i18n.T(lang, "invalid_email"))
		return
	}

	if err := h.authSvc.SendCode(c.Request.Context(), req.Email); err != nil {
		if apiErr, ok := err.(*i18n.APIError); ok {
			response.Error(c, apiErr.Code, 40000, apiErr.Message)
		} else {
			response.BadRequest(c, err.Error())
		}
		return
	}

	response.SuccessWithMessage(c, i18n.T(lang, "code_sent"), nil)
}

func (h *AuthHandler) RegisterOrLogin(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	var req struct {
		Email    string `json:"email" binding:"required,email"`
		Code     string `json:"code" binding:"required"`
		DeviceID string `json:"device_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, i18n.T(lang, "bad_request"))
		return
	}

	tokenResp, err := h.authSvc.RegisterOrLogin(c.Request.Context(), req.Email, req.Code, req.DeviceID)
	if err != nil {
		if apiErr, ok := err.(*i18n.APIError); ok {
			response.Error(c, apiErr.Code, 40000, apiErr.Message)
		} else {
			response.BadRequest(c, err.Error())
		}
		return
	}

	response.Success(c, tokenResp)
}

func (h *AuthHandler) GetProfile(c *gin.Context) {
	userID := middleware.GetUserID(c)
	response.Success(c, gin.H{"user_id": userID})
}
