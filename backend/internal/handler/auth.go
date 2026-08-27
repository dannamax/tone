package handler

import (
	"strings"

	"seeker/internal/middleware"
	"seeker/internal/repository"
	"seeker/internal/service"
	"seeker/pkg/i18n"
	"seeker/pkg/response"

	"github.com/gin-gonic/gin"
)

type AuthHandler struct {
	authSvc *service.AuthService
	userRepo *repository.UserRepo
	accountSvc *service.AccountService
}

func NewAuthHandler(authSvc *service.AuthService, userRepo *repository.UserRepo, accountSvc *service.AccountService) *AuthHandler {
	return &AuthHandler{authSvc: authSvc, userRepo: userRepo, accountSvc: accountSvc}
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
	lang := i18n.LanguageFromRequest(c.Request)
	userID := middleware.GetUserID(c)
	user, err := h.userRepo.FindByID(c.Request.Context(), userID)
	if err != nil {
		response.Unauthorized(c, err.Error())
		return
	}
	// 账户已删除（旧 JWT 仍能通过签名校验但用户不存在）→ 视为未授权
	if user == nil {
		response.Unauthorized(c, i18n.T(lang, "user_not_found"))
		return
	}
	response.Success(c, user)
}

// DeleteAccount 彻底删除账户及全部个人数据（App Store 5.1.1(v) / GDPR 合规）。
// 有进行中任务时返回 409，提示先完成或放弃。
func (h *AuthHandler) DeleteAccount(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	userID := middleware.GetUserID(c)

	if err := h.accountSvc.DeleteAccount(c.Request.Context(), userID); err != nil {
		if strings.Contains(err.Error(), i18n.T(lang, "account_delete_active_tasks")) {
			response.Error(c, 409, 40900, err.Error())
			return
		}
		response.InternalError(c, i18n.T(lang, "account_delete_failed"))
		return
	}
	response.SuccessWithMessage(c, i18n.T(lang, "account_deleted"), nil)
}
