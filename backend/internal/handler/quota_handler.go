package handler

import (
	"net/http"

	"seeker/internal/middleware"
	"seeker/internal/model"
	"seeker/internal/service"
	"seeker/pkg/i18n"

	"github.com/gin-gonic/gin"
)

// QuotaHandler 发布额度充值接口（方案1）
type QuotaHandler struct {
	quotaSvc *service.QuotaService
}

func NewQuotaHandler(quotaSvc *service.QuotaService) *QuotaHandler {
	return &QuotaHandler{quotaSvc: quotaSvc}
}

// Packages 获取额度套餐列表
// GET /wallet/quota-packages
func (h *QuotaHandler) Packages(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": h.quotaSvc.Packages(c.Request.Context())})
}

// CreateOrder 创建充值订单
// POST /wallet/quota/order  body: {package_id, channel}
func (h *QuotaHandler) CreateOrder(c *gin.Context) {
	userID := middleware.GetUserID(c)
	lang := i18n.LanguageFromRequest(c.Request)

	var req model.CreateRechargeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"code": 400, "message": i18n.T(lang, "invalid_params")})
		return
	}

	order, err := h.quotaSvc.CreateOrder(c.Request.Context(), userID, req.PackageID, req.Channel)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"code": 400, "message": err.Error()})
		return
	}
	c.JSON(http  .StatusOK, gin.H{"code": 0, "message": "ok", "data": order})
}

// ConfirmApple 校验 Apple IAP 并发放额度
// POST /wallet/quota/confirm-apple  body: {order_id, jws, receipt_data?}
//   - jws: StoreKit 2 transaction.jwsRepresentation（优先，本地验签）
//   - receipt_data: legacy verifyReceipt 回退（可选）
func (h *QuotaHandler) ConfirmApple(c *gin.Context) {
	userID := middleware.GetUserID(c)
	lang := i18n.LanguageFromRequest(c.Request)

	var req model.AppleVerifyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"code": 400, "message": i18n.T(lang, "invalid_params")})
		return
	}

	order, err := h.quotaSvc.ConfirmAppleIAP(c.Request.Context(), req.OrderID, req.ReceiptData, req.JWS)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"code": 400, "message": err.Error()})
		return
	}
	// 安全校验：订单归属当前用户
	if order.UserID != userID {
		c.JSON(http.StatusForbidden, gin.H{"code": 403, "message": i18n.T(lang, "unauthorized")})
		return
	}
	c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": order})
}

// Restore 恢复购买：客户端上传 App Store 历史交易 JWS 列表，按 transaction_id
// 幂等关联本地订单并补发（App Store 3.1.1 恢复购买合规）。
// POST /wallet/quota/restore  body: {jws_list: ["...", ...]}
func (h *QuotaHandler) Restore(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	userID := middleware.GetUserID(c)

	var req struct {
		JWSList []string `json:"jws_list" binding:"required,min=1,max=200"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"code": 400, "message": i18n.T(lang, "invalid_params")})
		return
	}

	result, err := h.quotaSvc.RestoreAppleIAP(c.Request.Context(), userID, req.JWSList)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"code": 400, "message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": result})
}

// GetOrder 查询充值订单状态
// GET /wallet/quota/order/:id
func (h *QuotaHandler) GetOrder(c *gin.Context) {
	orderID := c.Param("id")
	order, err := h.quotaSvc.GetOrder(c.Request.Context(), orderID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"code": 500, "message": err.Error()})
		return
	}
	if order == nil {
		c.JSON(http.StatusNotFound, gin.H{"code": 404, "message": i18n.T(i18n.LanguageFromRequest(c.Request), "order_not_found")})
		return
	}
	c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": order})
}
