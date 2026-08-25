package validator

import (
	"net/url"
	"regexp"
	"strings"
)

// urlPattern matches http(s) links and common bare domains/URL-ish tokens so
// that users cannot smuggle external links into chat messages.
var urlPattern = regexp.MustCompile(`(?i)(https?://|www\.|[a-z0-9-]+\.(com|cn|net|org|io|co|me|app|xyz|info|biz|tv|cc|vip|top)(/[^\s]*)?)`)

// ContainsURL reports whether the text contains an http(s) link, a "www."
// prefix, or a bare domain that looks like an external URL.
func ContainsURL(text string) bool {
	return urlPattern.MatchString(text)
}

// IsAllowedImageURL reports whether the given URL belongs to one of the allowed
// public bases (e.g. the app's own COS bucket or local /uploads path). This
// prevents users from referencing arbitrary external images.
func IsAllowedImageURL(raw string, allowedBases []string) bool {
	u, err := url.Parse(raw)
	if err != nil {
		return false
	}
	// Must be absolute http(s) and host must match one of the allowed bases.
	if u.Scheme != "http" && u.Scheme != "https" {
		return false
	}
	host := strings.ToLower(u.Host)
	for _, base := range allowedBases {
		b, err := url.Parse(base)
		if err != nil {
			// base may be a path-only prefix like "/uploads"
			if strings.HasPrefix(raw, base) {
				return true
			}
			continue
		}
		if host == strings.ToLower(b.Host) {
			return true
		}
	}
	return false
}
