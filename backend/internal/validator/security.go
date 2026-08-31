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
//
// Two accepted forms:
//   - Absolute http(s) URL: host must match an allowed base host (COS prod).
//   - Path-only URL (local storage mode, e.g. "/uploads/x.jpg"): must be under
//     an allowed path prefix. Without a scheme it can never point off-site.
func IsAllowedImageURL(raw string, allowedBases []string) bool {
	u, err := url.Parse(raw)
	if err != nil {
		return false
	}

	// Absolute URL: host must match one of the allowed bases.
	if u.Scheme == "http" || u.Scheme == "https" {
		host := strings.ToLower(u.Host)
		for _, base := range allowedBases {
			b, err := url.Parse(base)
			if err != nil {
				continue
			}
			if b.Host != "" && host == strings.ToLower(b.Host) {
				return true
			}
		}
		return false
	}

	// Path-only URL: must be under one of the allowed path prefixes
	// (e.g. LocalStorage.PublicBase() == "/uploads").
	for _, base := range allowedBases {
		if strings.HasPrefix(raw, base) {
			return true
		}
	}
	return false
}
