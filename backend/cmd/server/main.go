package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"math"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq" // PostgreSQL 驱动 (driver name: "postgres")
	sqlite3 "github.com/mattn/go-sqlite3"

	"seeker/internal/config"
	"seeker/internal/handler"
	"seeker/internal/middleware"
	"seeker/internal/repository"
	"seeker/internal/service"
	"seeker/internal/storage"
	"seeker/internal/websocket"
	"seeker/pkg/discovery"
	"seeker/pkg/email"
	"seeker/pkg/i18n"
	"seeker/pkg/jwt"
	"seeker/pkg/appleiap"
)

// Version 由 CI 在编译时通过 -ldflags "-X main.Version=<git-sha>" 注入，
// 供 /healthz 暴露线上实际运行的 commit，便于核对部署版本。
var Version = "unknown"

// toFloat 将 SQLite 传入的参数安全转为 float64。
func toFloat(v interface{}) float64 {
	switch n := v.(type) {
	case float64:
		return n
	case int64:
		return float64(n)
	case int:
		return float64(n)
	case nil:
		return 0
	default:
		return 0
	}
}

func main() {
	cfg := config.Load()

	// SQLite 核心不包含三角函数，注册 Haversine 距离计算所需的数学函数。
	// 仅在使用 SQLite 驱动时注册自定义的 sqlite3 驱动。
	sqlDriverName := "postgres"
	if cfg.Database.Driver == "sqlite" {
		sqlDriverName = "sqlite3-with-funcs"
		sql.Register("sqlite3-with-funcs", &sqlite3.SQLiteDriver{
			ConnectHook: func(conn *sqlite3.SQLiteConn) error {
				for name, fn := range map[string]func(...interface{}) (interface{}, error){
					"radians": func(args ...interface{}) (interface{}, error) {
						return toFloat(args[0]) * math.Pi / 180, nil
					},
					"cos": func(args ...interface{}) (interface{}, error) {
						return math.Cos(toFloat(args[0])), nil
					},
					"sin": func(args ...interface{}) (interface{}, error) {
						return math.Sin(toFloat(args[0])), nil
					},
					"acos": func(args ...interface{}) (interface{}, error) {
						v := toFloat(args[0])
						if v > 1 {
							v = 1
						} else if v < -1 {
							v = -1
						}
						return math.Acos(v), nil
					},
				} {
					if err := conn.RegisterFunc(name, fn, true); err != nil {
						return err
					}
				}
				return nil
			},
		})
	}

	// --- 数据库连接 ---
	// sqlite: 开发期零依赖；postgres: 腾讯云 PostgreSQL（需 lib/pq）
	db, err := sql.Open(sqlDriverName, cfg.Database.DSN())
	if err != nil {
		log.Fatalf("Failed to open database (driver=%s): %v", sqlDriverName, err)
	}
	if cfg.Database.Driver == "sqlite" {
		db.SetMaxOpenConns(1) // SQLite 单写连接，避免并发写锁
	} else {
		db.SetMaxOpenConns(20) // PostgreSQL 支持并发连接池
		db.SetMaxIdleConns(10)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatalf("Database connection failed: %v", err)
	}

	migrationsDir := "migrations"
	if err := repository.RunMigrations(context.Background(), db, cfg.Database.Driver, migrationsDir); err != nil {
		log.Fatalf("Migration failed: %v", err)
	}

	// --- WebSocket Hub ---
	hub := websocket.NewHub()
	go hub.Run()

	// --- Repositories ---
	userRepo := repository.NewUserRepo(db)
	taskRepo := repository.NewTaskRepo(db)
	submissionRepo := repository.NewSubmissionRepo(db)
	txRepo := repository.NewTransactionRepo(db)
	notifyRepo := repository.NewNotificationRepo(db)
	messageRepo := repository.NewMessageRepo(db)

	// --- Services ---
	// Email Provider (verification codes).
	// Build domestic + international SMTP channels and route by recipient domain
	// via RouterProvider. A free personal-mailbox SMTP can be used now (domestic
	// channel); a paid professional service (Amazon SES / SendGrid / Tencent or
	// Aliyun Email Push / ...) plugs into the international channel later by
	// setting SMTP_INTL_* env vars. Falls back to mock console logging when no
	// channel is configured.
	var emailProv email.Provider
	if cfg.Email.Provider == "resend" {
		// Resend Email API (https://resend.com). Recommended for individual
		// developers — no business license / credit card required to start.
		// The sender domain must be verified in the Resend console first.
		resendProv := email.NewResendProvider(cfg.Email.ResendAPIKey, cfg.Email.ResendFrom)
		if resendProv.IsEnabled() {
			emailProv = resendProv
			log.Printf("[Email] Using Resend provider (from=%s)\n", cfg.Email.ResendFrom)
		} else {
			emailProv = email.NewMockProvider()
			log.Println("[Email] Using Mock provider (RESEND_API_KEY / RESEND_FROM not set; set EMAIL_PROVIDER=resend for production)")
		}
	} else if cfg.Email.Provider == "smtp" {
		var domestic, international *email.SMTPProvider
		if cfg.Email.Domestic.Enabled() {
			domestic = email.NewSMTPProvider(cfg.Email.Domestic.Host, cfg.Email.Domestic.Port,
				cfg.Email.Domestic.Username, cfg.Email.Domestic.Password, cfg.Email.Domestic.From,
				cfg.Email.Domestic.UseTLS, true)
		}
		if cfg.Email.International.Enabled() {
			international = email.NewSMTPProvider(cfg.Email.International.Host, cfg.Email.International.Port,
				cfg.Email.International.Username, cfg.Email.International.Password, cfg.Email.International.From,
				cfg.Email.International.UseTLS, true)
		}
		if domestic != nil || international != nil {
			emailProv = email.NewRouterProvider(domestic, international)
			log.Printf("[Email] Using Router provider (domestic=%v, international=%v)\n",
				cfg.Email.Domestic.Enabled(), cfg.Email.International.Enabled())
		} else {
			emailProv = email.NewMockProvider()
			log.Println("[Email] Using Mock provider (no SMTP channel configured; set EMAIL_PROVIDER=smtp + SMTP_* for production)")
		}
	} else {
		emailProv = email.NewMockProvider()
		log.Println("[Email] Using Mock provider (verification codes logged to console; set EMAIL_PROVIDER=smtp for production)")
	}

	authSvc := service.NewAuthService(userRepo, cfg, emailProv)
	log.Printf("[Auth] Verification code store: %s", cfg.CodeStore.Kind)
	taskSvc := service.NewTaskService(taskRepo, userRepo, notifyRepo, submissionRepo, hub, txRepo)
	subSvc := service.NewSubmissionService(submissionRepo)
	paySvc := service.NewPaymentService(userRepo, taskRepo, txRepo, notifyRepo, hub)
	walletSvc := service.NewWalletService(userRepo, txRepo, notifyRepo)
	rechargeRepo := repository.NewRechargeRepo(db)
	quotaSvc := service.NewQuotaService(rechargeRepo, userRepo, txRepo, appleiap.NewVerifier(cfg.Apple.Password))

	// --- Handlers ---
	authHandler := handler.NewAuthHandler(authSvc, userRepo)
	walletHandler := handler.NewWalletHandler(walletSvc, userRepo, txRepo, notifyRepo)
	quotaHandler := handler.NewQuotaHandler(quotaSvc)
	// --- Object storage backend ---
	var store storage.Storage
	switch cfg.Storage.Backend {
	case "cos":
		cosStore, err := storage.NewCOSStorage(
			cfg.Storage.COSSecretID,
			cfg.Storage.COSSecretKey,
			cfg.Storage.COSBucket,
			cfg.Storage.COSRegion,
		)
		if err != nil {
			log.Fatalf("init COS storage failed: %v", err)
		}
		store = cosStore
		fmt.Printf("[storage] backend=cos bucket=%s region=%s\n", cfg.Storage.COSBucket, cfg.Storage.COSRegion)
	default:
		store = storage.NewLocalStorage(cfg.Storage.LocalDir, cfg.Storage.LocalBase)
		fmt.Printf("[storage] backend=local dir=%s\n", cfg.Storage.LocalDir)
	}
	// Allowed image hosts: the app's own storage base, plus any extra bases
	// via ALLOWED_IMAGE_BASES (comma-separated) for CDN/front-door setups.
	allowedImageBases := []string{store.PublicBase()}
	if extra := strings.TrimSpace(os.Getenv("ALLOWED_IMAGE_BASES")); extra != "" {
		for _, b := range strings.Split(extra, ",") {
			b = strings.TrimSpace(b)
			if b != "" {
				allowedImageBases = append(allowedImageBases, b)
			}
		}
	}
	taskHandler := handler.NewTaskHandler(taskSvc, subSvc, paySvc, messageRepo, allowedImageBases)
	uploadHandler := handler.NewUploadHandler(store)
	configH := handler.NewConfigHandler(cfg)

	// --- Router ---
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(middleware.LanguageMiddleware())
	r.Use(middleware.CORSMiddleware())
	// --- Router ---

	api := r.Group("/api/v1")
	{
		// 公共配置（无需认证）
		api.GET("/config/exchange-rate", configH.GetExchangeRate)
		api.GET("/config/email-domains", configH.GetSupportedEmailDomains)

		// 认证
		api.POST("/auth/send-code", authHandler.SendCode)
		api.POST("/auth/login", authHandler.RegisterOrLogin)
		api.GET("/me", middleware.AuthMiddleware(cfg.JWT.Secret), authHandler.GetProfile)

		// 任务广场 & 任务（具体路由必须放在 /tasks/:id 之前）
		api.GET("/tasks/square", middleware.AuthMiddleware(cfg.JWT.Secret), taskHandler.Square)
		api.GET("/tasks/mine", middleware.AuthMiddleware(cfg.JWT.Secret), taskHandler.MyTasks)
		api.POST("/tasks", middleware.AuthMiddleware(cfg.JWT.Secret), taskHandler.Publish)
		api.GET("/tasks/:id", middleware.AuthMiddleware(cfg.JWT.Secret), taskHandler.Get)
		api.POST("/tasks/:id/claim", middleware.AuthMiddleware(cfg.JWT.Secret), taskHandler.Claim)
		api.POST("/tasks/:id/submit", middleware.AuthMiddleware(cfg.JWT.Secret), taskHandler.Submit)
		api.GET("/tasks/:id/submission", middleware.AuthMiddleware(cfg.JWT.Secret), taskHandler.GetSubmission)
		api.POST("/tasks/:id/confirm", middleware.AuthMiddleware(cfg.JWT.Secret), taskHandler.Confirm)
		api.POST("/tasks/:id/dispute", middleware.AuthMiddleware(cfg.JWT.Secret), taskHandler.Dispute)
		api.POST("/tasks/:id/cancel", middleware.AuthMiddleware(cfg.JWT.Secret), taskHandler.Abandon)
		api.POST("/tasks/:id/refund", middleware.AuthMiddleware(cfg.JWT.Secret), taskHandler.Refund)
		api.POST("/tasks/:id/activate", middleware.AuthMiddleware(cfg.JWT.Secret), taskHandler.Activate)
		// 履约对话消息
		api.GET("/tasks/:id/messages", middleware.AuthMiddleware(cfg.JWT.Secret), taskHandler.GetMessages)
		api.POST("/tasks/:id/messages", middleware.AuthMiddleware(cfg.JWT.Secret), taskHandler.SendMessage)

		// 图片上传
		api.POST("/upload", middleware.AuthMiddleware(cfg.JWT.Secret), uploadHandler.Upload)

		// 钱包 & 通知
		api.GET("/wallet", middleware.AuthMiddleware(cfg.JWT.Secret), walletHandler.GetWallet)
		api.POST("/wallet/recharge", middleware.AuthMiddleware(cfg.JWT.Secret), walletHandler.Recharge)
		api.POST("/wallet/withdraw", middleware.AuthMiddleware(cfg.JWT.Secret), walletHandler.Withdraw)
		api.GET("/wallet/transactions", middleware.AuthMiddleware(cfg.JWT.Secret), walletHandler.GetTransactions)
		// 发布额度（方案1）
		api.GET("/wallet/quota-packages", middleware.AuthMiddleware(cfg.JWT.Secret), quotaHandler.Packages)
		api.POST("/wallet/quota/order", middleware.AuthMiddleware(cfg.JWT.Secret), quotaHandler.CreateOrder)
		api.POST("/wallet/quota/confirm-apple", middleware.AuthMiddleware(cfg.JWT.Secret), quotaHandler.ConfirmApple)
		api.GET("/wallet/quota/order/:id", middleware.AuthMiddleware(cfg.JWT.Secret), quotaHandler.GetOrder)
		api.GET("/notifications", middleware.AuthMiddleware(cfg.JWT.Secret), walletHandler.GetNotifications)
		api.POST("/notifications/:id/read", middleware.AuthMiddleware(cfg.JWT.Secret), walletHandler.MarkRead)
		api.POST("/notifications/read-all", middleware.AuthMiddleware(cfg.JWT.Secret), walletHandler.ReadAllNotifications)
	}

	// WebSocket 通知（token 通过 query 参数 ?token= 传递）
	r.GET("/ws", func(c *gin.Context) {
		tokenStr := c.Query("token")
		lang := i18n.LanguageFromRequest(c.Request)
		if tokenStr == "" {
			c.AbortWithStatusJSON(401, gin.H{"code": 401, "message": i18n.T(lang, "unauthorized")})
			return
		}
		claims, err := jwt.ParseToken(tokenStr, cfg.JWT.Secret)
		if err != nil {
			c.AbortWithStatusJSON(401, gin.H{"code": 401, "message": i18n.T(lang, "token_parse_failed")})
			return
		}
		websocket.ServeWS(hub, c.Writer, c.Request, claims.UserID)
	})

	// 健康检查（/healthz 与 /health 双路径，供负载均衡与部署脚本探测）
	health := func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":  "ok",
			"service": "bountyapp",
			"driver":  cfg.Database.Driver,
			"version": Version,
		})
	}
	r.GET("/health", health)
	r.GET("/healthz", health)

	// 静态文件 — 上传图片可通过 http://IP:8080/uploads/xxx.jpg 访问
	r.Static("/uploads", "uploads")

	// --- 启动 ---
	srv := &http.Server{
		Addr:    ":" + cfg.Server.Port,
		Handler: r,
	}
	go func() {
		log.Printf("[Server] Listening on :%s (driver=%s)", cfg.Server.Port, cfg.Database.Driver)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server startup failed: %v", err)
		}
	}()

	// 局域网自动发现：周期广播自身地址，移动端换 WiFi 后可自动重连
	discovery.Start(cfg)

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("[Server] Shutting down...")
	authSvc.Shutdown()
}
