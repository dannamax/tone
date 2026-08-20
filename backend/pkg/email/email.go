package email

import (
	"bytes"
	"crypto/tls"
	"encoding/base64"
	"fmt"
	"net/smtp"
	"strings"
)

// Provider interface for sending verification codes via email.
type Provider interface {
	SendCode(to, code, lang string) error
}

// SMTPProvider sends verification codes via an SMTP server.
//
// It supports both implicit TLS (SMTPS, port 465) and STARTTLS (port 587/25),
// which is required to interoperate with major Chinese mailbox providers
// (QQ Mail, 163, etc.) as well as international ones (Gmail, SES, SendGrid).
type SMTPProvider struct {
	host     string
	port     int
	username string
	password string
	from     string
	useTLS   bool // implicit TLS (SMTPS, usually port 465)
	enabled  bool
}

// NewSMTPProvider creates a new SMTP-based email provider.
// Set enabled=false to use mock mode (console logging only) for development.
// useTLS=true selects implicit TLS (port 465); otherwise STARTTLS is attempted.
func NewSMTPProvider(host string, port int, username, password, from string, useTLS, enabled bool) *SMTPProvider {
	if host == "" || port == 0 || from == "" {
		enabled = false
	}
	return &SMTPProvider{
		host:     host,
		port:     port,
		username: username,
		password: password,
		from:     from,
		useTLS:   useTLS,
		enabled:  enabled,
	}
}

// buildMessage assembles a simple MIME email with the verification code.
// lang selects the email copy language ("zh" / others default to English).
func buildMessage(from, to, code, lang string) string {
	subject, body := emailContent(lang, code)
	var buf bytes.Buffer
	buf.WriteString(fmt.Sprintf("From: %s\r\n", from))
	buf.WriteString(fmt.Sprintf("To: %s\r\n", to))
	buf.WriteString(fmt.Sprintf("Subject: =?UTF-8?B?%s?=\r\n", base64.StdEncoding.EncodeToString([]byte(subject))))
	buf.WriteString("MIME-Version: 1.0\r\n")
	buf.WriteString("Content-Type: text/html; charset=UTF-8\r\n")
	buf.WriteString("Content-Transfer-Encoding: base64\r\n")
	buf.WriteString("\r\n")
	buf.WriteString(base64.StdEncoding.EncodeToString([]byte(body)))
	return buf.String()
}

// emailContent returns (subject, htmlBody) for the given language.
func emailContent(lang, code string) (string, string) {
	if strings.HasPrefix(lang, "zh") {
		subject := "Seeker 验证码"
		body := fmt.Sprintf(
			`<div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:420px;margin:0 auto;padding:24px;">`+
				`<h2 style="color:#1a1a1a;">Seeker</h2>`+
				`<p style="color:#444;font-size:15px;line-height:1.6;">您的验证码为：</p>`+
				`<p style="font-size:32px;font-weight:700;letter-spacing:4px;color:#b8923b;margin:12px 0;">%s</p>`+
				`<p style="color:#888;font-size:13px;">该验证码 5 分钟内有效。若非本人操作，请忽略此邮件。</p>`+
				`</div>`, code)
		return subject, body
	}
	subject := "Seeker Verification Code"
	body := fmt.Sprintf(
		`<div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:420px;margin:0 auto;padding:24px;">`+
			`<h2 style="color:#1a1a1a;">Seeker</h2>`+
			`<p style="color:#444;font-size:15px;line-height:1.6;">Your verification code is:</p>`+
			`<p style="font-size:32px;font-weight:700;letter-spacing:4px;color:#b8923b;margin:12px 0;">%s</p>`+
			`<p style="color:#888;font-size:13px;">This code expires in 5 minutes. If you did not request it, ignore this email.</p>`+
			`</div>`, code)
	return subject, body
}

// SendCode delivers the verification code to the given email address.
// lang selects the email language ("zh" for Chinese, otherwise English).
func (p *SMTPProvider) SendCode(to, code, lang string) error {
	if !p.enabled {
		fmt.Printf("[Mock Email] Verification code sent to %s: %s\n", to, code)
		return nil
	}

	addr := fmt.Sprintf("%s:%d", p.host, p.port)
	auth := smtp.PlainAuth("", p.username, p.password, p.host)

	var c *smtp.Client
	var err error

	if p.useTLS {
		// Implicit TLS (SMTPS, port 465).
		tlsCfg := &tls.Config{ServerName: p.host}
		conn, derr := tls.Dial("tcp", addr, tlsCfg)
		if derr != nil {
			return fmt.Errorf("smtp tls dial: %w", derr)
		}
		c, err = smtp.NewClient(conn, p.host)
	} else {
		// Plain or STARTTLS (port 587/25).
		c, err = smtp.Dial(addr)
	}
	if err != nil {
		return fmt.Errorf("smtp dial: %w", err)
	}
	defer c.Quit()

	if !p.useTLS {
		if ok, _ := c.Extension("STARTTLS"); ok {
			tlsCfg := &tls.Config{ServerName: p.host}
			if err := c.StartTLS(tlsCfg); err != nil {
				return fmt.Errorf("smtp starttls: %w", err)
			}
		}
	}

	if err := c.Auth(auth); err != nil {
		return fmt.Errorf("smtp auth: %w", err)
	}
	if err := c.Mail(p.from); err != nil {
		return fmt.Errorf("smtp mail: %w", err)
	}
	if err := c.Rcpt(to); err != nil {
		return fmt.Errorf("smtp rcpt: %w", err)
	}
	w, err := c.Data()
	if err != nil {
		return fmt.Errorf("smtp data: %w", err)
	}
	msg := buildMessage(p.from, to, code, lang)
	if _, err := w.Write([]byte(msg)); err != nil {
		return fmt.Errorf("smtp write: %w", err)
	}
	if err := w.Close(); err != nil {
		return fmt.Errorf("smtp close: %w", err)
	}
	fmt.Printf("[SMTP Email] Code delivered to %s (lang=%s)\n", strings.ToLower(to), lang)
	return nil
}

// IsEnabled reports whether the real SMTP server is active (non-mock).
func (p *SMTPProvider) IsEnabled() bool {
	return p.enabled
}

// ---------- Mock Provider ----------

// MockProvider logs the verification code to console without real sending.
type MockProvider struct{}

// NewMockProvider creates a mock provider for development.
func NewMockProvider() *MockProvider {
	return &MockProvider{}
}

// SendCode logs the code to stdout.
func (m *MockProvider) SendCode(to, code, lang string) error {
	fmt.Printf("[Mock Email] Verification code sent to %s: %s (lang=%s)\n", to, code, lang)
	return nil
}

