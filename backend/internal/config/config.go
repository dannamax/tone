package config

import (
	"fmt"
	"os"
	"time"

	"github.com/joho/godotenv"
)

type Config struct {
	Server    ServerConfig
	Database  DatabaseConfig
	Redis     RedisConfig
	CodeStore CodeStoreConfig
	Storage   StorageConfig
	JWT       JWTConfig
	Email     EmailConfig
	Exchange  ExchangeRateConfig
	Apple     AppleConfig
}

// ...

type ExchangeRateConfig struct {
	USDToCNY float64
}

type ServerConfig struct {
	Port            string
	ReadTimeout     time.Duration
	WriteTimeout    time.Duration
	ShutdownTimeout time.Duration
}

type DatabaseConfig struct {
	Driver   string // "sqlite" | "postgres"
	Host     string
	Port     string
	User     string
	Password string
	DBName   string
	SSLMode  string
}

// DSN 返回 SQLite 文件路径或 PostgreSQL 连接串。
// SQLite 模式下 DBName 即数据库文件路径（如 ./bountydb.sqlite）。
func (d DatabaseConfig) DSN() string {
	if d.Driver == "postgres" {
		return fmt.Sprintf(
			"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
			d.Host, d.Port, d.User, d.Password, d.DBName, d.SSLMode,
		)
	}
	return d.DBName
}

type RedisConfig struct {
	Addr     string
	Password string
	DB       int
}

// CodeStoreConfig selects where verification codes live.
//   - Kind "memory": in-process map (development / CI / e2e, zero deps)
//   - Kind "redis":  shared Redis (production, multi-replica safe)
type CodeStoreConfig struct {
	Kind string // "memory" | "redis"
}

// StorageConfig selects the object-storage backend for uploaded images.
//   - Backend "local": store on local disk (development / CI)
//   - Backend "cos":   store in Tencent Cloud Object Storage (production)
type StorageConfig struct {
	Backend   string // "local" | "cos"
	LocalDir  string // used when Backend == "local"
	LocalBase string // public base path for local, e.g. "/uploads"

	COSSecretID  string // Tencent Cloud API SecretId (production only, via env)
	COSSecretKey string // Tencent Cloud API SecretKey (production only, via env)
	COSBucket    string // bucket name, e.g. "seekerhub-1301056533"
	COSRegion    string // bucket region, e.g. "ap-hongkong"
}

type JWTConfig struct {
	Secret     string
	ExpireTime time.Duration
}

// SMTPChannelConfig holds the connection details for a single SMTP server.
// Used for both the domestic (China) and international channels.
type SMTPChannelConfig struct {
	Host     string
	Port     int
	Username string
	Password string
	From     string
	UseTLS   bool // implicit TLS (SMTPS, port 465); otherwise STARTTLS
}

// Enabled reports whether this channel has the minimum config to send mail.
func (c SMTPChannelConfig) Enabled() bool {
	return c.Host != "" && c.Port != 0 && c.From != ""
}

// AppleConfig 用于校验 Apple In-App Purchase 回执。
//   - Password: App Store 共享密钥（非订阅 IAP 可留空）
//   - Env: "auto"（production 失败回退 sandbox，推荐）| "production" | "sandbox"
type AppleConfig struct {
	Password string
	Env      string
}

type EmailConfig struct {	// Provider selects the top-level mode: "smtp" (real send via configured
	// channels) or "mock" (console logging only, for dev/CI).
	Provider string
	// Domestic channel: used for Chinese mailbox providers (qq/163/126/...).
	// e.g. your free QQ/163 personal mailbox SMTP.
	Domestic SMTPChannelConfig
	// International channel: used for Gmail/Outlook/iCloud/Yahoo/...
	// Leave empty to fall back to the domestic channel. This is where a paid
	// professional service (Amazon SES, SendGrid, Postmark, Tencent/Aliyun
	// Email Push, etc.) is intended to plug in later — just fill these fields.
	International SMTPChannelConfig
}

func Load() *Config {
	// Load .env if present (silent when absent). Process env vars always win
	// over values in .env, and existing defaults in getEnv still apply.
	_ = godotenv.Load()

	return &Config{
		Server: ServerConfig{
			Port:            getEnv("SERVER_PORT", "8080"),
			ReadTimeout:     30 * time.Second,
			WriteTimeout:    30 * time.Second,
			ShutdownTimeout: 10 * time.Second,
		},
		Database: DatabaseConfig{
			Driver:   getEnv("DB_DRIVER", "sqlite"),
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     getEnv("DB_PORT", "5432"),
			User:     getEnv("DB_USER", "seeker"),
			Password: getEnv("DB_PASSWORD", "seeker123"),
			DBName:   getEnv("DB_NAME", "seekerdb.sqlite"),
			SSLMode:  getEnv("DB_SSLMODE", "disable"),
		},
		Redis: RedisConfig{
			Addr:     getEnv("REDIS_ADDR", "localhost:6379"),
			Password: getEnv("REDIS_PASSWORD", ""),
			DB:       0,
		},
		CodeStore: CodeStoreConfig{
			Kind: getEnv("CODE_STORE", "memory"),
		},
		Storage: StorageConfig{
			Backend:     getEnv("STORAGE_BACKEND", "local"),
			LocalDir:    getEnv("STORAGE_LOCAL_DIR", "uploads"),
			LocalBase:   getEnv("STORAGE_LOCAL_BASE", "/uploads"),
			COSSecretID: getEnv("COS_SECRET_ID", ""),
			COSSecretKey: getEnv("COS_SECRET_KEY", ""),
			COSBucket:    getEnv("COS_BUCKET", ""),
			COSRegion:    getEnv("COS_REGION", ""),
		},
		JWT: JWTConfig{
			Secret:     getEnv("JWT_SECRET", "seeker-secret-key-change-in-production"),
			ExpireTime: 7 * 24 * time.Hour,
		},
		Email: EmailConfig{
			Provider: getEnv("EMAIL_PROVIDER", "mock"),
			Domestic: SMTPChannelConfig{
				Host:     getEnv("SMTP_HOST", ""),
				Port:     getEnvInt("SMTP_PORT", 587),
				Username: getEnv("SMTP_USERNAME", ""),
				Password: getEnv("SMTP_PASSWORD", ""),
				From:     getEnv("SMTP_FROM", "noreply@gotseeker.com"),
				UseTLS:   getEnv("SMTP_USE_TLS", "false") == "true",
			},
			International: SMTPChannelConfig{
				Host:     getEnv("SMTP_INTL_HOST", ""),
				Port:     getEnvInt("SMTP_INTL_PORT", 587),
				Username: getEnv("SMTP_INTL_USERNAME", ""),
				Password: getEnv("SMTP_INTL_PASSWORD", ""),
				From:     getEnv("SMTP_INTL_FROM", ""),
				UseTLS:   getEnv("SMTP_INTL_USE_TLS", "false") == "true",
			},
		},
		Exchange: ExchangeRateConfig{
			USDToCNY: getEnvFloat("EXCHANGE_USD_CNY", 7.2),
		},
		Apple: AppleConfig{
			Password: getEnv("APPLE_IAP_PASSWORD", ""),
			Env:      getEnv("APPLE_IAP_ENV", "auto"),
		},
	}
}

func getEnv(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}

func getEnvFloat(key string, defaultVal float64) float64 {
	val := os.Getenv(key)
	if val == "" {
		return defaultVal
	}
	var f float64
	if _, err := fmt.Sscanf(val, "%f", &f); err == nil && f > 0 {
		return f
	}
	return defaultVal
}

func getEnvInt(key string, defaultVal int) int {
	val := os.Getenv(key)
	if val == "" {
		return defaultVal
	}
	var i int
	if _, err := fmt.Sscanf(val, "%d", &i); err == nil && i > 0 {
		return i
	}
	return defaultVal
}
