package email

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// ResendEndpoint is the Resend REST API base URL for sending emails.
const ResendEndpoint = "https://api.resend.com/emails"

// ResendProvider sends verification codes via the Resend Email API (HTTPS).
//
// Unlike SMTP providers, Resend exposes only a REST API (no SMTP endpoint),
// so this provider performs a single authenticated POST per send. It is the
// recommended choice for individual developers: no business license and no
// credit card are required to start (free tier: 3,000 emails/month), and it
// natively supports transactional verification emails worldwide.
//
// The sender address (From) MUST belong to a domain you have verified in the
// Resend console (SPF + DKIM); otherwise the API returns 400/422.
type ResendProvider struct {
	apiKey string
	from   string
	client *http.Client
}

// NewResendProvider creates a Resend API provider.
// apiKey is the Resend API key (starts with "re_"). from is the verified
// sender address, e.g. "Seeker <noreply@gotseeker.com>".
func NewResendProvider(apiKey, from string) *ResendProvider {
	return &ResendProvider{
		apiKey: apiKey,
		from:   from,
		client: &http.Client{Timeout: 10 * time.Second},
	}
}

// resendRequest is the minimal payload for the Resend "send email" endpoint.
type resendRequest struct {
	From    string   `json:"from"`
	To      []string `json:"to"`
	Subject string   `json:"subject"`
	Html    string   `json:"html"`
}

// resendError models the error body returned by the Resend API.
type resendError struct {
	Name    string `json:"name"`
	Message string `json:"message"`
}

// SendCode delivers the verification code to the given email address via the
// Resend API. lang selects the email copy language (zh / others).
func (p *ResendProvider) SendCode(to, code, lang string) error {
	if p.apiKey == "" || p.from == "" {
		// Degrade gracefully to console logging so the app still runs in dev.
		fmt.Printf("[Mock Email] Verification code sent to %s: %s (lang=%s) — Resend not configured\n", to, code, lang)
		return nil
	}

	subject, html := emailContent(lang, code)
	payload := resendRequest{
		From:    p.from,
		To:      []string{strings.ToLower(strings.TrimSpace(to))},
		Subject: subject,
		Html:    html,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("resend marshal: %w", err)
	}

	req, err := http.NewRequest(http.MethodPost, ResendEndpoint, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("resend new request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+p.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := p.client.Do(req)
	if err != nil {
		return fmt.Errorf("resend http: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		fmt.Printf("[Resend] Code delivered to %s (lang=%s)\n", strings.ToLower(to), lang)
		return nil
	}

	respBody, _ := io.ReadAll(resp.Body)
	var re resendError
	if json.Unmarshal(respBody, &re) == nil && re.Message != "" {
		return fmt.Errorf("resend api %d: %s", resp.StatusCode, re.Message)
	}
	return fmt.Errorf("resend api %d: %s", resp.StatusCode, string(respBody))
}

// IsEnabled reports whether the Resend provider has the minimum config.
func (p *ResendProvider) IsEnabled() bool {
	return p.apiKey != "" && p.from != ""
}
