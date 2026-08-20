package email

import (
	"fmt"
	"strings"
)

// DomesticEmailSuffixes are the common Chinese mailbox domains routed to the
// domestic (China) SMTP channel. Add more as needed.
var DomesticEmailSuffixes = []string{
	"qq.com", "163.com", "126.com", "foxmail.com",
	"sina.com", "sina.cn", "sohu.com", "yeah.net",
	"aliyun.com", "139.com", "189.cn",
}

// RouterProvider routes outgoing mail to the appropriate SMTP channel based on
// the recipient's domain. It is the production entry point intended to:
//   - use the domestic channel for Chinese mailbox providers (qq/163/126/...),
//     which can be a free personal mailbox SMTP during early stages;
//   - use the international channel for Gmail/Outlook/iCloud/Yahoo/...,
//     where a paid professional service (Amazon SES, SendGrid, Postmark,
//     Tencent/Aliyun Email Push, etc.) is expected to plug in later.
//
// If the international channel is not configured, mail falls back to the
// domestic channel. If neither channel is enabled, it degrades to console
// logging (mock-like) so the app still runs in dev/CI.
type RouterProvider struct {
	domestic     *SMTPProvider
	international *SMTPProvider
}

// NewRouterProvider builds a router from two optional SMTP channels.
// Either channel may be nil (disabled).
func NewRouterProvider(domestic, international *SMTPProvider) *RouterProvider {
	return &RouterProvider{
		domestic:      domestic,
		international: international,
	}
}

// isDomestic reports whether the address belongs to a Chinese mailbox provider.
func isDomestic(addr string) bool {
	lower := strings.ToLower(addr)
	for _, suffix := range DomesticEmailSuffixes {
		if strings.HasSuffix(lower, "@"+suffix) {
			return true
		}
	}
	return false
}

// SendCode routes the message to the best available channel.
func (r *RouterProvider) SendCode(to, code, lang string) error {
	// Prefer the international channel for non-domestic recipients.
	if !isDomestic(to) && r.international != nil && r.international.IsEnabled() {
		return r.international.SendCode(to, code, lang)
	}
	// Domestic recipients (or international channel unavailable) go domestic.
	if r.domestic != nil && r.domestic.IsEnabled() {
		return r.domestic.SendCode(to, code, lang)
	}
	// International recipient but no international channel -> best-effort domestic.
	if r.international == nil && r.domestic != nil && r.domestic.IsEnabled() {
		return r.domestic.SendCode(to, code, lang)
	}
	// No real channel available: degrade gracefully to console logging.
	fmt.Printf("[Mock Email] Verification code sent to %s: %s (lang=%s) — no SMTP channel configured\n", to, code, lang)
	return nil
}
