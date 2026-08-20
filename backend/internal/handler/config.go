package handler

import (
	"seeker/internal/config"
	"seeker/pkg/response"

	"github.com/gin-gonic/gin"
)

type ConfigHandler struct {
	cfg *config.Config
}

func NewConfigHandler(cfg *config.Config) *ConfigHandler {
	return &ConfigHandler{cfg: cfg}
}

// GetExchangeRate returns the current exchange rates.
func (h *ConfigHandler) GetExchangeRate(c *gin.Context) {
	response.Success(c, gin.H{
		"usd_to_cny": h.cfg.Exchange.USDToCNY,
		"updated_at": "manual", // placeholder; replace with API-fetched timestamp
	})
}

// GetSupportedEmailDomains returns common email domains for autocomplete hints.
// NOTE: this is only a UI suggestion — registration does NOT restrict to this
// list. Any RFC-compliant email address is accepted by the backend.
func (h *ConfigHandler) GetSupportedEmailDomains(c *gin.Context) {
	response.Success(c, gin.H{
		"domains": []string{
			// International
			"gmail.com", "outlook.com", "hotmail.com", "live.com",
			"icloud.com", "me.com", "yahoo.com", "proton.me", "protonmail.com",
			// Domestic (China)
			"qq.com", "163.com", "126.com", "yeah.net", "foxmail.com",
			"sina.com", "sina.cn", "sohu.com", "aliyun.com",
			"139.com", "189.cn",
		},
	})
}
