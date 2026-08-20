package handler

import (
	"fmt"

	"seeker/internal/middleware"
	"seeker/internal/model"
	"seeker/internal/repository"
	"seeker/internal/service"
	"seeker/pkg/i18n"
	"seeker/pkg/response"

	"github.com/gin-gonic/gin"
)

type WalletHandler struct {
	walletSvc  *service.WalletService
	userRepo   *repository.UserRepo
	txRepo     *repository.TransactionRepo
	notifyRepo *repository.NotificationRepo
}

func NewWalletHandler(walletSvc *service.WalletService, userRepo *repository.UserRepo, txRepo *repository.TransactionRepo, notifyRepo *repository.NotificationRepo) *WalletHandler {
	return &WalletHandler{walletSvc: walletSvc, userRepo: userRepo, txRepo: txRepo, notifyRepo: notifyRepo}
}

func (h *WalletHandler) GetWallet(c *gin.Context) {
	info, err := h.walletSvc.GetWalletInfo(c.Request.Context(), middleware.GetUserID(c))
	if err != nil {
		response.InternalError(c, i18n.T(i18n.LanguageFromRequest(c.Request), "load_wallet_failed"))
		return
	}
	response.Success(c, info)
}

func (h *WalletHandler) Withdraw(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	var req model.WithdrawRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, i18n.T(lang, "bad_request"))
		return
	}

	userID := middleware.GetUserID(c)

	if err := h.walletSvc.Withdraw(c.Request.Context(), userID, &req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, i18n.T(lang, "withdraw_submitted"), nil)
}

func (h *WalletHandler) Recharge(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	var req struct {
		Amount float64 `json:"amount" binding:"required,gt=0"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, i18n.T(lang, "bad_request"))
		return
	}

	userID := middleware.GetUserID(c)
	if err := h.walletSvc.Recharge(c.Request.Context(), userID, req.Amount); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	info, err := h.walletSvc.GetWalletInfo(c.Request.Context(), userID)
	if err != nil {
		response.InternalError(c, i18n.T(lang, "load_wallet_failed"))
		return
	}
	response.SuccessWithMessage(c, i18n.T(lang, "recharge_success"), info)
}

func (h *WalletHandler) GetTransactions(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	userID := middleware.GetUserID(c)
	page := 1
	size := 20
	fmt.Sscanf(c.DefaultQuery("page", "1"), "%d", &page)
	fmt.Sscanf(c.DefaultQuery("size", "20"), "%d", &size)
	if page <= 0 {
		page = 1
	}
	if size <= 0 || size > 50 {
		size = 20
	}

	txs, total, err := h.txRepo.FindByUser(c.Request.Context(), userID, page, size)
	if err != nil {
		response.InternalError(c, i18n.T(lang, "load_transactions_failed"))
		return
	}

	response.Paginated(c, txs, total, page, size)
}

func (h *WalletHandler) GetNotifications(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	userID := middleware.GetUserID(c)
	page := 1
	size := 20
	fmt.Sscanf(c.DefaultQuery("page", "1"), "%d", &page)
	fmt.Sscanf(c.DefaultQuery("size", "20"), "%d", &size)
	if page <= 0 {
		page = 1
	}
	if size <= 0 || size > 50 {
		size = 20
	}

	notifs, total, err := h.walletSvc.GetNotifications(c.Request.Context(), userID, page, size)
	if err != nil {
		response.InternalError(c, i18n.T(lang, "load_notifications_failed"))
		return
	}

	response.Paginated(c, notifs, total, page, size)
}

func (h *WalletHandler) ReadAllNotifications(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	userID := middleware.GetUserID(c)
	if err := h.walletSvc.MarkAllRead(c.Request.Context(), userID); err != nil {
		response.InternalError(c, i18n.T(lang, "operation_failed"))
		return
	}
	response.SuccessWithMessage(c, i18n.T(lang, "mark_all_read"), nil)
}

func (h *WalletHandler) MarkRead(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	id := c.Param("id")
	userID := middleware.GetUserID(c)
	if err := h.notifyRepo.MarkRead(c.Request.Context(), id, userID); err != nil {
		response.InternalError(c, i18n.T(lang, "operation_failed"))
		return
	}
	response.SuccessWithMessage(c, i18n.T(lang, "mark_read"), nil)
}
