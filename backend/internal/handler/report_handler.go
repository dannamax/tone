package handler

import (
	"seeker/internal/middleware"
	"seeker/internal/model"
	"seeker/internal/service"
	"seeker/pkg/i18n"
	"seeker/pkg/response"

	"github.com/gin-gonic/gin"
)

type ReportHandler struct {
	reportSvc *service.ReportService
}

func NewReportHandler(reportSvc *service.ReportService) *ReportHandler {
	return &ReportHandler{reportSvc: reportSvc}
}

// BlockUser POST /users/:id/block — 拉黑用户。
func (h *ReportHandler) BlockUser(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	userID := middleware.GetUserID(c)
	targetID := c.Param("id")

	if err := h.reportSvc.Block(c.Request.Context(), userID, targetID); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	response.SuccessWithMessage(c, i18n.T(lang, "user_blocked"), nil)
}

// UnblockUser DELETE /users/:id/block — 解除拉黑。
func (h *ReportHandler) UnblockUser(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	userID := middleware.GetUserID(c)
	targetID := c.Param("id")

	if err := h.reportSvc.Unblock(c.Request.Context(), userID, targetID); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.SuccessWithMessage(c, i18n.T(lang, "user_unblocked"), nil)
}

// ListBlocked GET /users/blocked — 拉黑列表。
func (h *ReportHandler) ListBlocked(c *gin.Context) {
	list, err := h.reportSvc.ListBlocked(c.Request.Context(), middleware.GetUserID(c))
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, list)
}

// CreateReport POST /reports — 举报任务 / 用户 / 消息。
func (h *ReportHandler) CreateReport(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	var req model.ReportRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, i18n.T(lang, "bad_request"))
		return
	}
	if err := h.reportSvc.Report(c.Request.Context(), middleware.GetUserID(c), &req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	response.SuccessWithMessage(c, i18n.T(lang, "report_submitted"), nil)
}
