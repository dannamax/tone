package handler

import (
	"net/http"

	"seeker/internal/middleware"
	"seeker/internal/repository"
	"seeker/pkg/response"

	"github.com/gin-gonic/gin"
)

// DeviceHandler 推送设备登记
type DeviceHandler struct {
	deviceRepo *repository.DeviceTokenRepo
}

func NewDeviceHandler(deviceRepo *repository.DeviceTokenRepo) *DeviceHandler {
	return &DeviceHandler{deviceRepo: deviceRepo}
}

// Register 登记设备的 APNs 推送 token。
// POST /devices/register  body: {token: "...", platform: "ios"}
// 同一 token 重复上报会更新归属用户（换账号登录场景）。
func (h *DeviceHandler) Register(c *gin.Context) {
	userID := middleware.GetUserID(c)

	var req struct {
		Token    string `json:"token" binding:"required"`
		Platform string `json:"platform"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"code": 400, "message": "invalid params"})
		return
	}
	if req.Platform == "" {
		req.Platform = "ios"
	}
	if err := h.deviceRepo.Upsert(c.Request.Context(), userID, req.Token, req.Platform); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"code": 500, "message": "failed to register device"})
		return
	}
	response.SuccessWithMessage(c, "device registered", nil)
}
