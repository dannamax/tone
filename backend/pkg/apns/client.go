// Package apns 封装 Apple Push Notification service（token-based 认证）。
// 未配置 APNS_KEY_PATH 时为 no-op 模式：Send 静默返回 nil，方便本地/测试环境。
package apns

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"sync"
	"time"

	"github.com/sideshow/apns2"
	"github.com/sideshow/apns2/token"
)

// Config APNs 连接配置（全部来自环境变量）
type Config struct {
	KeyPath  string // APNS_KEY_PATH   .p8 私钥文件路径（空 = 禁用推送）
	KeyID    string // APNS_KEY_ID     密钥 ID（ASC Keys 页）
	TeamID   string // APNS_TEAM_ID    开发者团队 ID
	BundleID string // APNS_BUNDLE_ID  App Bundle ID（如 com.gotseeker.app）
	Sandbox  bool   // APNS_SANDBOX    true = 开发证书设备（api.sandbox.push.apple.com）
}

// Client APNs 推送客户端（并发安全）
type Client struct {
	cfg      Config
	mu       sync.Mutex
	client   *apns2.Client
	tokAt    time.Time
	disabled bool
}

// NewClient 从环境变量构建客户端；APNS_KEY_PATH 未设置时返回 no-op 客户端。
func NewClient() *Client {
	cfg := Config{
		KeyPath:  os.Getenv("APNS_KEY_PATH"),
		KeyID:    os.Getenv("APNS_KEY_ID"),
		TeamID:   os.Getenv("APNS_TEAM_ID"),
		BundleID: os.Getenv("APNS_BUNDLE_ID"),
		Sandbox:  os.Getenv("APNS_SANDBOX") == "true",
	}
	if cfg.KeyPath == "" || cfg.KeyID == "" || cfg.TeamID == "" || cfg.BundleID == "" {
		log.Println("[APNs] disabled (APNS_KEY_PATH/APNS_KEY_ID/APNS_TEAM_ID/APNS_BUNDLE_ID not set)")
		return &Client{disabled: true}
	}
	return &Client{cfg: cfg}
}

// apnsClient 构建带 token 认证的客户端，每 50 分钟轮换一次 JWT（有效期 1 小时）
func (c *Client) apnsClient() (*apns2.Client, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.client != nil && time.Since(c.tokAt) < 50*time.Minute {
		return c.client, nil
	}
	authKey, err := token.AuthKeyFromFile(c.cfg.KeyPath)
	if err != nil {
		return nil, fmt.Errorf("load APNs key: %w", err)
	}
	t := &token.Token{
		AuthKey: authKey,
		KeyID:   c.cfg.KeyID,
		TeamID:  c.cfg.TeamID,
	}
	client := apns2.NewTokenClient(t)
	if c.cfg.Sandbox {
		client = client.Development()
	} else {
		client = client.Production()
	}
	c.client = client
	c.tokAt = time.Now()
	return client, nil
}

// Send 向单台设备推送。返回 (是否发送成功, error)。
// no-op 模式或无 key 时返回 (false, nil)。
func (c *Client) Send(deviceToken, title, body string, data map[string]string) (bool, error) {
	if c.disabled {
		return false, nil
	}
	client, err := c.apnsClient()
	if err != nil {
		return false, err
	}
	n := &apns2.Notification{
		DeviceToken: deviceToken,
		Topic:       c.cfg.BundleID,
		Payload:     buildPayload(title, body, data),
	}
	res, err := client.Push(n)
	if err != nil {
		return false, err
	}
	// 410 BadDeviceToken / Unregistered：设备已卸载 App，调用方应清理 token
	if res.Sent() {
		return true, nil
	}
	if res.StatusCode == 410 {
		return false, ErrUnregistered
	}
	return false, fmt.Errorf("apns: %s (%d)", res.Reason, res.StatusCode)
}

// ErrUnregistered 设备 token 已失效（App 卸载）
var ErrUnregistered = fmt.Errorf("device token unregistered")

func buildPayload(title, body string, data map[string]string) []byte {
	alert := map[string]interface{}{"title": title, "body": body}
	aps := map[string]interface{}{
		"alert": alert,
		"sound": "default",
	}
	payload := map[string]interface{}{"aps": aps}
	for k, v := range data {
		payload[k] = v
	}
	b, _ := json.Marshal(payload)
	return b
}
