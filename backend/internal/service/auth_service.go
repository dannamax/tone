package service

import (
	"context"
	"crypto/rand"
	"fmt"
	"math/big"
	"os"
	"regexp"
	"strings"
	"time"

	"seeker/internal/config"
	"seeker/internal/model"
	"seeker/internal/repository"
	"seeker/pkg/email"
	"seeker/pkg/i18n"
	"seeker/pkg/jwt"
)

// emailRegex is a simple, globally-compatible email matcher.
var emailRegex = regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)

type verificationCode struct {
	Code      string
	ExpiresAt time.Time
	CreatedAt time.Time
	Attempts  int // failed verification attempts
}

// maxCodeAttempts is the number of wrong-code submissions allowed before the
// code is invalidated, mitigating brute-force of the 6-digit code.
const maxCodeAttempts = 5

// codeTTL and resendCooldown define the verification code lifetime and the
// minimum interval between two sends to the same address.
const (
	codeTTL         = 5 * time.Minute
	resendCooldown  = 60 * time.Second
)

type AuthService struct {
	userRepo  *repository.UserRepo
	cfg       *config.Config
	emailProv email.Provider
	store     CodeStore
}

func NewAuthService(userRepo *repository.UserRepo, cfg *config.Config, emailProv email.Provider) *AuthService {
	// NewCodeStore always returns a usable store: memory for dev/CI, or Redis
	// with a memory fallback when Redis is degraded (never fails hard).
	store := NewCodeStore(cfg)
	return &AuthService{
		userRepo:  userRepo,
		cfg:       cfg,
		emailProv: emailProv,
		store:     store,
	}
}

// Shutdown releases resources.
func (s *AuthService) Shutdown() {
	fmt.Println("[AuthService] Shutting down")
}

// SendCode sends a verification code to the given email address.
func (s *AuthService) SendCode(ctx context.Context, emailAddr string) error {
	emailAddr = strings.ToLower(strings.TrimSpace(emailAddr))
	if !emailRegex.MatchString(emailAddr) {
		return i18n.NewAPIError(400, i18n.ErrCodeInvalidEmail, i18n.T(i18n.LangEN, "invalid_email"))
	}

	// Rate limit: block resends within the cooldown window (60s).
	if s.inCooldown(ctx, emailAddr) {
		return i18n.NewAPIError(429, i18n.ErrCodeRateLimit, i18n.T(i18n.LangEN, "rate_limited"))
	}

	code := generateCode()
	// For automated end-to-end testing with the mock provider, allow a fixed
	// code via environment variable. Never set this in production.
	if fixed := os.Getenv("MOCK_FIXED_CODE"); fixed != "" && len(fixed) == 6 {
		code = fixed
	}

	// Store verification code (expires in 5 minutes).
	if err := s.store.Save(ctx, emailAddr, code, codeTTL); err != nil {
		return i18n.NewAPIError(500, i18n.ErrCodeInternalError, i18n.T(i18n.LangEN, "send_failed"))
	}
	// Mark the cooldown window so repeated sends are throttled.
	_ = s.store.Save(ctx, emailAddr+":cooldown", "1", resendCooldown)

	// Send via email provider (language follows the request's Accept-Language)
	lang := i18n.LanguageFromCtx(ctx)
	fmt.Printf("[Auth] Sending code to %s code=%s\n", emailAddr, code)
	return s.emailProv.SendCode(emailAddr, code, lang)
}

// inCooldown reports whether a resend is still blocked by the cooldown window.
func (s *AuthService) inCooldown(ctx context.Context, emailAddr string) bool {
	_, _, ok, _ := s.store.Get(ctx, emailAddr+":cooldown")
	return ok
}

// RegisterOrLogin verifies code and returns token response.
func (s *AuthService) RegisterOrLogin(ctx context.Context, emailAddr, code, deviceID string) (*model.TokenResponse, error) {
	emailAddr = strings.ToLower(strings.TrimSpace(emailAddr))

	// Verify code
	storedCode, attempts, exists, err := s.store.Get(ctx, emailAddr)
	if err != nil {
		return nil, i18n.NewAPIError(500, i18n.ErrCodeInternalError, i18n.T(i18n.LangEN, "internal_error"))
	}
	if !exists {
		return nil, i18n.NewAPIError(400, i18n.ErrCodeCodeInvalid, i18n.T(i18n.LangEN, "code_expired"))
	}
	if storedCode != code {
		// Increment attempts; if too many failures, invalidate the code.
		newAttempts, _ := s.store.IncrementAttempts(ctx, emailAddr)
		if newAttempts >= maxCodeAttempts {
			_ = s.store.Delete(ctx, emailAddr)
			return nil, i18n.NewAPIError(400, i18n.ErrCodeCodeExpired, i18n.T(i18n.LangEN, "code_expired"))
		}
		return nil, i18n.NewAPIError(400, i18n.ErrCodeCodeInvalid, i18n.T(i18n.LangEN, "code_invalid"))
	}

	// Code correct — consume it so it cannot be reused.
	if err := s.store.Delete(ctx, emailAddr); err != nil {
		return nil, i18n.NewAPIError(500, i18n.ErrCodeInternalError, i18n.T(i18n.LangEN, "internal_error"))
	}
	_ = attempts // reserved for future telemetry

	// Find or create user
	user, err := s.userRepo.FindByEmail(ctx, emailAddr)
	if err != nil || user == nil {
		user, err = s.userRepo.CreateByEmail(ctx, emailAddr, deviceID)
		if err != nil || user == nil {
			return nil, i18n.NewAPIError(500, i18n.ErrCodeInternalError, i18n.T(i18n.LangEN, "register_failed"))
		}
	}

	// Generate JWT token
	tokenStr, expiresAt, err := jwt.GenerateToken(user.ID, user.Email, deviceID, s.cfg.JWT.Secret, s.cfg.JWT.ExpireTime)
	if err != nil {
		return nil, i18n.NewAPIError(500, i18n.ErrCodeInternalError, i18n.T(i18n.LangEN, "token_generate_failed"))
	}

	return &model.TokenResponse{
		AccessToken: tokenStr,
		ExpiresIn:   expiresAt,
		User: model.User{
			ID:       user.ID,
			Email:    maskEmail(emailAddr),
			Nickname: user.Nickname,
			Avatar:   user.Avatar,
			Balance:  user.Balance,
			Role:     user.Role,
		},
	}, nil
}

func generateCode() string {
	n, err := rand.Int(rand.Reader, big.NewInt(900000))
	if err != nil {
		return "123456"
	}
	return fmt.Sprintf("%06d", n.Int64()+100000)
}

func maskEmail(emailAddr string) string {
	parts := strings.Split(emailAddr, "@")
	if len(parts) != 2 {
		return emailAddr
	}
	local := parts[0]
	domain := parts[1]
	if len(local) <= 2 {
		return "***@" + domain
	}
	visible := 1
	hidden := len(local) - visible - 1
	if hidden <= 0 {
		hidden = 1
	}
	masked := local[:visible] + strings.Repeat("*", hidden) + local[len(local)-1:]
	return masked + "@" + domain
}
